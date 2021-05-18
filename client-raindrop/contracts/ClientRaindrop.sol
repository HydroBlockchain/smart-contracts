/**
 *Submitted for verification at Etherscan.io on 2019-01-09
*/

pragma solidity ^0.5.0;

// thanks to https://github.com/willitscale/solidity-util and https://github.com/Arachnid/solidity-stringutils
library StringUtils {
    struct slice {
        uint _len;
        uint _ptr;
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self) internal pure returns (slice memory ) {
        uint ptr;
        assembly { ptr := add(self, 0x20) } // solium-disable-line security/no-inline-assembly
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns a new slice containing the same data as the current slice.
     * @param self The slice to copy.
     * @return A new slice containing the same data as `self`.
     */
    function copy(slice memory self) internal pure returns (slice memory ) {
        return slice(self._len, self._ptr);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self) internal pure returns (string memory ) {
        string memory ret = new string(self._len);
        uint retptr;
        assembly { retptr := add(ret, 0x20) } // solium-disable-line security/no-inline-assembly

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    /**
    * Lower
    *
    * Converts all the values of a string to their corresponding lower case
    * value.
    *
    * @param _base When being used for a data type this is the extended object
    *              otherwise this is the string base to convert to lower case
    * @return string
    */
    function lower(string memory _base) internal pure returns (string memory ) {
        bytes memory _baseBytes = bytes(_base);
        for (uint i = 0; i < _baseBytes.length; i++) {
            _baseBytes[i] = _lower(_baseBytes[i]);
        }
        return string(_baseBytes);
    }

    /**
    * Lower
    *
    * Convert an alphabetic character to lower case and return the original
    * value when not alphabetic
    *
    * @param _b1 The byte to be converted to lower case
    * @return bytes1 The converted value if the passed value was alphabetic
    *                and in a upper case otherwise returns the original value
    */
    function _lower(bytes1 _b1) internal pure returns (bytes1) {
        if (_b1 >= 0x41 && _b1 <= 0x5A) {
            return bytes1(uint8(_b1) + 32);
        }
        return _b1;
    }

    function memcpy(uint dest, uint src, uint len) private pure { // solium-disable-line security/no-assign-params
        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly { mstore(dest, mload(src)) } // solium-disable-line security/no-inline-assembly
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint mask = 256 ** (32 - len) - 1;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }
}

interface OldClientRaindropInterface {
    function userNameTaken(string calldata userName) external view returns (bool);
    function getUserByName(string calldata userName) external view returns (string memory, address);
}

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() public {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
    * @return the address of the owner.
    */
    function owner() public view returns(address) {
        return _owner;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
    * @return true if `msg.sender` is the owner of the contract.
    */
    function isOwner() public view returns(bool) {
        return msg.sender == _owner;
    }

    /**
    * @dev Allows the current owner to relinquish control of the contract.
    * @notice Renouncing to ownership will leave the contract without an owner.
    * It will not be possible to call the functions with the `onlyOwner`
    * modifier anymore.
    */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
    * @dev Transfers control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface HydroInterface {
    function balances(address) external view returns (uint);
    function allowed(address, address) external view returns (uint);
    function transfer(address _to, uint256 _amount) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) external returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData)
        external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function totalSupply() external view returns (uint);

    function authenticate(uint _value, uint _challenge, uint _partnerId) external;
}

interface SnowflakeInterface {
    function deposits(uint) external view returns (uint);
    function resolverAllowances(uint, address) external view returns (uint);

    function identityRegistryAddress() external returns (address);
    function hydroTokenAddress() external returns (address);
    function clientRaindropAddress() external returns (address);

    function setAddresses(address _identityRegistryAddress, address _hydroTokenAddress) external;
    function setClientRaindropAddress(address _clientRaindropAddress) external;

    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, string calldata casedHydroId,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function removeProvidersFor(
        address approvingAddress, address[] calldata providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function upgradeProvidersFor(
        address approvingAddress, address[] calldata newProviders, address[] calldata oldProviders,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function addResolver(address resolver, bool isSnowflake, uint withdrawAllowance, bytes calldata extraData) external;
    function addResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, uint withdrawAllowance, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function changeResolverAllowances(address[] calldata resolvers, uint[] calldata withdrawAllowances) external;
    function changeResolverAllowancesDelegated(
        address approvingAddress, address[] calldata resolvers, uint[] calldata withdrawAllowances,
        uint8 v, bytes32 r, bytes32 s
    ) external;
    function removeResolver(address resolver, bool isSnowflake, bytes calldata extraData) external;
    function removeResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, bytes calldata extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;

    function triggerRecoveryAddressChangeFor(
        address approvingAddress, address newRecoveryAddress, uint8 v, bytes32 r, bytes32 s
    ) external;

    function transferSnowflakeBalance(uint einTo, uint amount) external;
    function withdrawSnowflakeBalance(address to, uint amount) external;
    function transferSnowflakeBalanceFrom(uint einFrom, uint einTo, uint amount) external;
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) external;
    function transferSnowflakeBalanceFromVia(uint einFrom, address via, uint einTo, uint amount, bytes calldata _bytes)
        external;
    function withdrawSnowflakeBalanceFromVia(uint einFrom, address via, address to, uint amount, bytes calldata _bytes)
        external;
}

interface SnowflakeResolverInterface {
    function callOnAddition() external view returns (bool);
    function callOnRemoval() external view returns (bool);
    function onAddition(uint ein, uint allowance, bytes calldata extraData) external returns (bool);
    function onRemoval(uint ein, bytes calldata extraData) external returns (bool);
}

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;

    address public snowflakeAddress;

    bool public callOnAddition;
    bool public callOnRemoval;

    constructor(
        string memory _snowflakeName, string memory _snowflakeDescription,
        address _snowflakeAddress,
        bool _callOnAddition, bool _callOnRemoval
    )
        public
    {
        snowflakeName = _snowflakeName;
        snowflakeDescription = _snowflakeDescription;

        setSnowflakeAddress(_snowflakeAddress);

        callOnAddition = _callOnAddition;
        callOnRemoval = _callOnRemoval;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // this can be overriden to initialize other variables, such as e.g. an ERC20 object to wrap the HYDRO token
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    // if callOnAddition is true, onAddition is called every time a user adds the contract as a resolver
    // this implementation **must** use the senderIsSnowflake modifier
    // returning false will disallow users from adding the contract as a resolver
    function onAddition(uint ein, uint allowance, bytes memory extraData) public returns (bool);

    // if callOnRemoval is true, onRemoval is called every time a user removes the contract as a resolver
    // this function **must** use the senderIsSnowflake modifier
    // returning false soft prevents users from removing the contract as a resolver
    // however, note that they can force remove the resolver, bypassing onRemoval
    function onRemoval(uint ein, bytes memory extraData) public returns (bool);

    function transferHydroBalanceTo(uint einTo, uint amount) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(hydro.approveAndCall(snowflakeAddress, amount, abi.encode(einTo)), "Unsuccessful approveAndCall.");
    }

    function withdrawHydroBalanceTo(address to, uint amount) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(hydro.transfer(to, amount), "Unsuccessful transfer.");
    }

    function transferHydroBalanceToVia(address via, uint einTo, uint amount, bytes memory snowflakeCallBytes) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(
            hydro.approveAndCall(
                snowflakeAddress, amount, abi.encode(true, address(this), via, einTo, snowflakeCallBytes)
            ),
            "Unsuccessful approveAndCall."
        );
    }

    function withdrawHydroBalanceToVia(address via, address to, uint amount, bytes memory snowflakeCallBytes) internal {
        HydroInterface hydro = HydroInterface(SnowflakeInterface(snowflakeAddress).hydroTokenAddress());
        require(
            hydro.approveAndCall(
                snowflakeAddress, amount, abi.encode(false, address(this), via, to, snowflakeCallBytes)
            ),
            "Unsuccessful approveAndCall."
        );
    }
}

interface IdentityRegistryInterface {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        external pure returns (bool);

    // Identity View Functions /////////////////////////////////////////////////////////////////////////////////////////
    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAssociatedAddressFor(uint ein, address _address) external view returns (bool);
    function isProviderFor(uint ein, address provider) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function getIdentity(uint ein) external view returns (
        address recoveryAddress,
        address[] memory associatedAddresses, address[] memory providers, address[] memory resolvers
    );

    // Identity Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function createIdentity(address recoveryAddress, address[] calldata providers, address[] calldata resolvers)
        external returns (uint ein);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, address[] calldata resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAssociatedAddress(
        address approvingAddress, address addressToAdd, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function removeAssociatedAddress() external;
    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function addProviders(address[] calldata providers) external;
    function addProvidersFor(uint ein, address[] calldata providers) external;
    function removeProviders(address[] calldata providers) external;
    function removeProvidersFor(uint ein, address[] calldata providers) external;
    function addResolvers(address[] calldata resolvers) external;
    function addResolversFor(uint ein, address[] calldata resolvers) external;
    function removeResolvers(address[] calldata resolvers) external;
    function removeResolversFor(uint ein, address[] calldata resolvers) external;

    // Recovery Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function triggerRecoveryAddressChange(address newRecoveryAddress) external;
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function triggerDestruction(
        uint ein, address[] calldata firstChunk, address[] calldata lastChunk, bool resetResolvers
    ) external;
}

contract ClientRaindrop is SnowflakeResolver {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;

    // other SCs
    HydroInterface private hydroToken;
    IdentityRegistryInterface private identityRegistry;
    OldClientRaindropInterface private oldClientRaindrop;

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
        oldClientRaindrop = OldClientRaindropInterface(oldClientRaindropAddress);
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
        _signUp(identityRegistry.getEIN(msg.sender), casedHydroId, _address);
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
        require(
            identityRegistry.isAssociatedAddressFor(ein, _address),
            "The passed address is not associated with the calling Identity."
        );
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

        return true;
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