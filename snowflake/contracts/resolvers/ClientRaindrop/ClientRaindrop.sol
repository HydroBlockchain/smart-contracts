pragma solidity ^0.4.24;

import "./StringUtils.sol";
import "../SnowflakeResolver.sol";


interface ERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
}

interface IdentityRegistry {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAddressFor(uint ein, address _address) external view returns (bool);
    function isProviderFor(uint ein, address provider) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    // function identityExists(uint ein) external view returns (bool);
}

interface Snowflake {
    function hydroTokenAddress() external view returns (address);
    function identityRegistryAddress() external view returns (address);
}


contract ClientRaindrop is SnowflakeResolver {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;

    // other SCs
    ERC20 private hydroToken;
    IdentityRegistry private identityRegistry;

    // staking requirements
    uint public minimumHydroStakeUser;
    uint public minimumHydroStakeDelegatedUser;

    // User account template
    struct User {
        uint ein;
        address _address;
        string casedHydroID;

        bool initialized;
        bool poisoned;
    }

    // Mapping from uncased hydroID hashes to users
    mapping (bytes32 => User) private userDirectory;
    // Mapping from EIN to uncased hydroID hashes
    mapping (uint => bytes32) private einDirectory;
    // Mapping from address to uncased hydroID hashes
    mapping (address => bytes32) private addressDirectory;


    constructor(address _snowflakeAddress, uint _minimumHydroStakeUser, uint _minimumHydroStakeDelegatedUser)
        SnowflakeResolver(
            "Client Raindrop", "A registry that links EINs to HydroIDs to power Client Raindrop MFA.",
            _snowflakeAddress,
            false, true
        )
        public
    {
        setSnowflakeAddress(_snowflakeAddress);
        setStakes(_minimumHydroStakeUser, _minimumHydroStakeDelegatedUser);
    }

    // Requires an address to have a minimum number of Hydro
    modifier requireStake(address _address, uint stake) {
        require(hydroToken.balanceOf(_address) >= stake, "Insufficient staked HYDRO balance.");
        _;
    }

    // set the snowflake address, and hydro token/identity registry contract wrappers
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
        
        Snowflake snowflake = Snowflake(snowflakeAddress);
        hydroToken = ERC20(snowflake.hydroTokenAddress());
        identityRegistry = IdentityRegistry(snowflake.identityRegistryAddress());
    }

    // set minimum hydro balances required for sign ups
    function setStakes(uint newMinimumHydroStakeUser, uint newMinimumHydroStakeDelegatedUser) public onlyOwner {
        // <= the airdrop amount
        require(newMinimumHydroStakeUser <= 222222 * 10**18, "Stake is too high.");
        minimumHydroStakeUser = newMinimumHydroStakeUser;

        // <= 1% of total supply
        require(newMinimumHydroStakeDelegatedUser <= hydroToken.totalSupply() / 100, "Stake is too high.");
        minimumHydroStakeDelegatedUser = newMinimumHydroStakeDelegatedUser;
    }


    // Allows users to sign up with their own address
    function signUp(string casedHydroID) public requireStake(msg.sender, minimumHydroStakeUser) {
        _signUp(identityRegistry.getEIN(msg.sender), casedHydroID, msg.sender);
    }

    // Allows providers to sign up users on their behalf
    function signUp(uint ein, string casedHydroID, address _address)
        public requireStake(msg.sender, minimumHydroStakeDelegatedUser)
    {
        require(identityRegistry.isAddressFor(ein, _address), "Passed address is not associated with passed EIN.");
        require(identityRegistry.isProviderFor(ein, msg.sender), "msg.sender is not a Provider for the passed EIN.");

        _signUp(ein, casedHydroID, _address);
    }

    // Common internal logic for all user signups
    function _signUp(uint ein, string casedHydroID, address _address) internal {
        require(bytes(casedHydroID).length > 2 && bytes(casedHydroID).length < 33, "HydroID has invalid length.");
        require(identityRegistry.isResolverFor(ein, address(this)), "The passed EIN has not set this resolver.");

        bytes32 uncasedHydroIDHash = keccak256(abi.encodePacked(casedHydroID.toSlice().copy().toString().lower()));
        // check conditions specific to this resolver
        require(hydroIDAvailable(uncasedHydroIDHash), "HydroID is unavailable.");
        require(einDirectory[ein] == bytes32(0), "EIN is already mapped to a HydroID.");
        require(addressDirectory[_address] == bytes32(0), "Address is already mapped to a HydroID");

        // update mappings
        userDirectory[uncasedHydroIDHash] = User(ein, _address, casedHydroID, true, false);
        einDirectory[ein] = uncasedHydroIDHash;
        addressDirectory[_address] = uncasedHydroIDHash;

        emit HydroIDClaimed(ein, casedHydroID, _address);
    }

    function onRemoval(uint ein) public senderIsSnowflake() returns (bool) {
        bytes32 uncasedHydroIDHash = einDirectory[ein];
        assert(uncasedHydroIDHashActive(uncasedHydroIDHash));

        emit HydroIDPoisoned(
            ein, userDirectory[uncasedHydroIDHash].casedHydroID, userDirectory[uncasedHydroIDHash]._address
        );

        delete addressDirectory[userDirectory[uncasedHydroIDHash]._address];
        delete einDirectory[ein];
        delete userDirectory[uncasedHydroIDHash].casedHydroID;
        delete userDirectory[uncasedHydroIDHash]._address;
        userDirectory[uncasedHydroIDHash].poisoned = true;
    }

    // returns whether a given hydroID is available
    function hydroIDAvailable(string uncasedHydroID) public view returns (bool available) {
        return hydroIDAvailable(keccak256(abi.encodePacked(uncasedHydroID.lower())));
    }

    // Returns a bool indicating whether a given uncasedHydroIDHash is available
    function hydroIDAvailable(bytes32 uncasedHydroIDHash) private view returns (bool) {
        return !userDirectory[uncasedHydroIDHash].initialized;
    }

    // Returns a bool indicating whether a given hydroID is poisoned
    function hydroIDPoisoned(bytes32 uncasedHydroIDHash) private view returns (bool) {
        return userDirectory[uncasedHydroIDHash].poisoned;
    }

    // Returns a bool indicating whether a given hydroID is active
    function uncasedHydroIDHashActive(bytes32 uncasedHydroIDHash) private view returns (bool taken) {
        return !hydroIDAvailable(uncasedHydroIDHash) && !hydroIDPoisoned(uncasedHydroIDHash);
    }


    // Returns details by uncased hydroID
    function getDetails(string uncasedHydroID) public view returns (uint ein, address _address, string casedHydroID) {
        User storage user = getDetails(keccak256(abi.encodePacked(uncasedHydroID.lower())));
        return (user.ein, user._address, user.casedHydroID);
    }

    // Returns details by EIN
    function getDetails(uint ein) public view returns (address _address, string casedHydroID) {
        User storage user = getDetails(einDirectory[ein]);
        return (user._address, user.casedHydroID);
    }

    // Returns details by address
    function getDetails(address _address) public view returns (uint ein, string casedHydroID) {
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
    event HydroIDPoisoned(uint indexed ein, string hydroID, address userAddress);
}
