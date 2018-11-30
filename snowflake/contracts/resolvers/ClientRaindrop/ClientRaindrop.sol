pragma solidity ^0.5.0;

import "./StringUtils.sol";
import "../../SnowflakeResolver.sol";
import "../../interfaces/IdentityRegistryInterface.sol";
import "../../interfaces/HydroInterface.sol";
import "../../interfaces/SnowflakeInterface.sol";

interface OldClientRaindrop {
    function userNameTaken(string calldata userName) external view returns (bool);
    function getUserByName(string calldata userName) external view returns (string memory, address);
}

contract ClientRaindrop is SnowflakeResolver {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;

    // other SCs
    HydroInterface private hydroToken;
    IdentityRegistryInterface private identityRegistry;
    OldClientRaindrop private oldClientRaindrop;

    // staking requirements
    uint public hydroStakeUser;
    uint public hydroStakeDelegatedUser;

    // User account template
    struct User {
        uint ein;
        address _address;
        string casedHydroID;
        bool initialized;
        bool destroyed;
    }

    // Mapping from uncased hydroID hashes to users
    mapping (bytes32 => User) private userDirectory;
    // Mapping from EIN to uncased hydroID hashes
    mapping (uint => bytes32) private einDirectory;
    // Mapping from address to uncased hydroID hashes
    mapping (address => bytes32) private addressDirectory;



    constructor(
        address snowflakeAddress, address oldClientRaindropAddress, uint _hydroStakeUser, uint _hydroStakeDelegatedUser
    )
        SnowflakeResolver(
            "Client Raindrop", "A registry that links EINs to HydroIDs to power Client Raindrop MFA.",
            snowflakeAddress,
            true, true
        )
        public
    {
        setSnowflakeAddress(snowflakeAddress);
        setOldClientRaindropAddress(oldClientRaindropAddress);
        setStakes(_hydroStakeUser, _hydroStakeDelegatedUser);
    }

    // Requires an address to have a minimum number of Hydro
    modifier requireStake(address _address, uint stake) {
        require(hydroToken.balanceOf(_address) >= stake, "Insufficient staked HYDRO balance.");
        _;
    }

    // set the snowflake address, and hydro token + identity registry contract wrappers
    function setSnowflakeAddress(address snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(snowflakeAddress);

        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
        hydroToken = HydroInterface(snowflake.hydroTokenAddress());
        identityRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
    }

    // set the old client raindrop address
    function setOldClientRaindropAddress(address oldClientRaindropAddress) public onlyOwner() {
        oldClientRaindrop = OldClientRaindrop(oldClientRaindropAddress);
    }

    // set minimum hydro balances required for sign ups
    function setStakes(uint _hydroStakeUser, uint _hydroStakeDelegatedUser) public onlyOwner() {
        // <= the airdrop amount
        require(_hydroStakeUser <= 222222 * 10**18, "Stake is too high.");
        hydroStakeUser = _hydroStakeDelegatedUser;

        // <= 1% of total supply
        require(_hydroStakeDelegatedUser <= hydroToken.totalSupply() / 100, "Stake is too high.");
        hydroStakeDelegatedUser = _hydroStakeDelegatedUser;
    }

    // function for users calling signup for themselves
    function signUp(address _address, string memory casedHydroId) public requireStake(msg.sender, hydroStakeUser) {
        uint ein = identityRegistry.getEIN(msg.sender);
        require(
            identityRegistry.isAssociatedAddressFor(ein, _address),
            "The passed address is not associated with the calling Identity."
        );
        _signUp(ein, casedHydroId, _address);
    }

    // function for users signing up through the snowflake provider
    function onAddition(uint ein, uint, bytes memory extraData)
        // solium-disable-next-line security/no-tx-origin
        public senderIsSnowflake() requireStake(tx.origin, hydroStakeDelegatedUser) returns (bool)
    {
        (address _address, string memory casedHydroID) = abi.decode(extraData, (address, string));
        require(identityRegistry.isProviderFor(ein, msg.sender), "Snowflake is not a Provider for the passed EIN.");
        _signUp(ein, casedHydroID, _address);
        return true;
    }

    // Common internal logic for all user signups
    function _signUp(uint ein, string memory casedHydroID, address _address) internal {
        require(bytes(casedHydroID).length > 2 && bytes(casedHydroID).length < 33, "HydroID has invalid length.");
        require(identityRegistry.isResolverFor(ein, address(this)), "The passed EIN has not set this resolver.");
        checkForOldHydroID(casedHydroID, _address);

        bytes32 uncasedHydroIDHash = keccak256(abi.encodePacked(casedHydroID.toSlice().copy().toString().lower()));
        // check conditions specific to this resolver
        require(hydroIDAvailable(uncasedHydroIDHash), "HydroID is unavailable.");
        require(einDirectory[ein] == bytes32(0), "EIN is already mapped to a HydroID.");
        require(addressDirectory[_address] == bytes32(0), "Address is already mapped to a HydroID.");

        // update mappings
        userDirectory[uncasedHydroIDHash] = User(ein, _address, casedHydroID, true, false);
        einDirectory[ein] = uncasedHydroIDHash;
        addressDirectory[_address] = uncasedHydroIDHash;

        emit HydroIDClaimed(ein, casedHydroID, _address);
    }

    function checkForOldHydroID(string memory casedHydroID, address _address) public view {
        bool usernameTaken = oldClientRaindrop.userNameTaken(casedHydroID);
        if (usernameTaken) {
            (, address takenAddress) = oldClientRaindrop.getUserByName(casedHydroID);
            require(_address == takenAddress, "This Hydro ID is already claimed by another address.");
        }
    }

    function onRemoval(uint ein, bytes memory) public senderIsSnowflake() returns (bool) {
        bytes32 uncasedHydroIDHash = einDirectory[ein];
        assert(uncasedHydroIDHashActive(uncasedHydroIDHash));

        emit HydroIDDestroyed(
            ein, userDirectory[uncasedHydroIDHash].casedHydroID, userDirectory[uncasedHydroIDHash]._address
        );

        delete addressDirectory[userDirectory[uncasedHydroIDHash]._address];
        delete einDirectory[ein];
        delete userDirectory[uncasedHydroIDHash].casedHydroID;
        delete userDirectory[uncasedHydroIDHash]._address;
        userDirectory[uncasedHydroIDHash].destroyed = true;
    }


    // returns whether a given hydroID is available
    function hydroIDAvailable(string memory uncasedHydroID) public view returns (bool available) {
        return hydroIDAvailable(keccak256(abi.encodePacked(uncasedHydroID.lower())));
    }

    // Returns a bool indicating whether a given uncasedHydroIDHash is available
    function hydroIDAvailable(bytes32 uncasedHydroIDHash) private view returns (bool) {
        return !userDirectory[uncasedHydroIDHash].initialized;
    }

    // returns whether a given hydroID is destroyed
    function hydroIDDestroyed(string memory uncasedHydroID) public view returns (bool destroyed) {
        return hydroIDDestroyed(keccak256(abi.encodePacked(uncasedHydroID.lower())));
    }

    // Returns a bool indicating whether a given hydroID is destroyed
    function hydroIDDestroyed(bytes32 uncasedHydroIDHash) private view returns (bool) {
        return userDirectory[uncasedHydroIDHash].destroyed;
    }

    // returns whether a given hydroID is active
    function hydroIDActive(string memory uncasedHydroID) public view returns (bool active) {
        return uncasedHydroIDHashActive(keccak256(abi.encodePacked(uncasedHydroID.lower())));
    }

    // Returns a bool indicating whether a given hydroID is active
    function uncasedHydroIDHashActive(bytes32 uncasedHydroIDHash) private view returns (bool) {
        return !hydroIDAvailable(uncasedHydroIDHash) && !hydroIDDestroyed(uncasedHydroIDHash);
    }


    // Returns details by uncased hydroID
    function getDetails(string memory uncasedHydroID) public view
        returns (uint ein, address _address, string memory casedHydroID)
    {
        User storage user = getDetails(keccak256(abi.encodePacked(uncasedHydroID.lower())));
        return (user.ein, user._address, user.casedHydroID);
    }

    // Returns details by EIN
    function getDetails(uint ein) public view returns (address _address, string memory casedHydroID) {
        User storage user = getDetails(einDirectory[ein]);
        return (user._address, user.casedHydroID);
    }

    // Returns details by address
    function getDetails(address _address) public view returns (uint ein, string memory casedHydroID) {
        User storage user = getDetails(addressDirectory[_address]);
        return (user.ein, user.casedHydroID);
    }

    // common logic for all getDetails
    function getDetails(bytes32 uncasedHydroIDHash) private view returns (User storage) {
        require(uncasedHydroIDHashActive(uncasedHydroIDHash), "HydroID is not active.");
        return userDirectory[uncasedHydroIDHash];
    }

    // Events for when a user signs up for Raindrop Client and when their account is deleted
    event HydroIDClaimed(uint indexed ein, string hydroID, address userAddress);
    event HydroIDDestroyed(uint indexed ein, string hydroID, address userAddress);
}
