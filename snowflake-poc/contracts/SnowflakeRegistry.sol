pragma solidity ^0.4.23;

import "./libraries/BytesLibrary.sol";
import "./libraries/bytes32Set.sol";
import "./Withdrawable.sol";


// contract raindropClient {}

contract SnowflakeRegistry is Withdrawable {
    using BytesLib for bytes;
    using bytes32Set for bytes32Set._bytes32Set;

    // Events for when an application is signed up for Snowflake and when their account is deleted
    event ApplicationSignUp(string applicationName);
    event VerifierChanged(string applicationName, address verifierAddress);
    event ApplicationDeleted(string applicationName);
    event DataRequested(string applicationName, string userName);

    address public raindropClientAddress;
    address public hydroRelayerAddress;
    address public escrowAddress;

    _bytes32Set public supportedFields;

    // Encryption key template
    struct EncryptionKey {
        string key;
        string keyType;
    }

    // Address book template
    struct AddressBook {
        address ownerAddress;
        address relayerAddress;
        address verifierAddress;
    }

    // Application account template
    struct Application {
        string applicationName;
        AddressBook applicationAddressBook;
        EncryptionKey applicationEncryptionKey;
        bool _initialized;
    }

    // Mapping from hashed names to users (primary User directory)
    mapping (bytes32 => Application) internal applicationDirectory;
    // Mapping from verifier addresses to applications (secondary application directory)
    mapping (address => bytes32) internal nameDirectory;

    // users => hashedFields => saltedHashedValues
    mapping (bytes32 => mapping (bytes32 => bytes32)) internal saltedHashes;

    function signUpApplication(
        string applicationName,
        address ownedAddress,
        string key,
        string keyType
    )
    public onlyOwner
    {
        require(bytes(applicationName).length < 100);
        bytes32 applicationNameHash = keccak256(applicationName);
        require(!applicationDirectory[applicationNameHash]._initialized);

        userDirectory[userNameHash] = User(userName, userAddress, delegated, true);
        nameDirectory[userAddress] = userNameHash;

        applicationAccounts[keccak256(applicationName)] = Application(
            applicationName,
            AddressBook(
                ownedAddress,
                ownedAddress
            ),
            EncryptionKey(
                key,
                keyType
            ),
            true
        );

        emit ApplicationSignUp(applicationName);
    }

    function designateVerifier(bytes32 applicationNameHash, address verifierAddress) public onlyOwner {
        Application application = applicationDirectory[applicationNameHash];
        require(application._initialized);
        application.addressEntry.verifierAddress = verifierAddress;
    }

    function getApplication(string applicationName) public returns (
        address ownedAddress,
        address verifierAddress,
        string key,
        string keyType
    )
    {
        bytes32 applicationNameHash = keccak256(applicationName);
        Application application = applicationDirectory[applicationNameHash];
        require(application._initialized);

        return (
            application.applicationAddressEntry.ownedAddress,
            application.applicationAddressEntry.verifierAddress,
            application.applicationEncryptionKey.key,
            application.applicationEncryptionKey.keyType,
        );
    }

    function deleteApplication(bytes32 applicationNameHash) public onlyOwner {
        require(applicationDirectory[applicationNameHash]._initialized);
        delete applicationDirectory[applicationNameHash];
    }

    function updateAddresses(address _raindropClientAddress, address _hydroRelayerAddress, address _escrowAddress)
    public onlyOwner
    {
        raindropClientAddress = _raindropClientAddress;
        hydroRelayerAddress = _hydroRelayerAddress;
        escrowAddress = _escrowAddress;
    }

    function addSupportedField(bytes32 fieldName) public {
        supportedFields.push(fieldName);
    }

    /* function requestData(bytes32[] fieldNames, string userName) public {
        emit DataRequested(string applicationName, string userName);
    } */

    /* function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) {
        _extraData
    } */

    /* function parseFields() internal {
        bytes memory slice1 = memBytes.slice(0, 2);
        bytes memory slice2 = memBytes.slice(2, 2);
    } */
}
