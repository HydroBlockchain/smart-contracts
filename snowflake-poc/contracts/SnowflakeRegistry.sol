pragma solidity ^0.4.23;

import "./Withdrawable.sol";

import "./libraries/bytesLibrary.sol";
import "./libraries/bytes32Set.sol";


interface RaindropClient {
    function userNameTaken(string userName) external view returns (bool taken);
    function getUserByName(string userName) external view returns (address userAddress, bool delegated);
    function getUserByAddress(address _address) external view returns (string userName, bool delegated);
}

interface SnowflakeEscrow {
    function initiateEscrow(
        address _application,
        address _user,
        address _relayer,
        address _validator,
        uint _amount_
    )
        external returns(uint escrowId);
    function closeEscrow(uint _escrowId) external;
    function cancelEscrow(uint _escrowId) external;
}


contract SnowflakeRegistry is Withdrawable {
    using BytesLibrary for bytes;
    using bytes32Set for bytes32Set._bytes32Set;

    // Events for when an application is signed up for Snowflake and when their account is deleted
    event ApplicationSignUp(string applicationName);
    event DataRequested(string applicationName, string userName, bytes32[] dataFields);

    address public escrowAddress;
    address public hydroTokenAddress;
    address public raindropClientAddress;

    bytes32Set._bytes32Set internal supportedKeyTypes;
    mapping (bytes32 => string) internal keyNames;

    bytes32Set._bytes32Set internal supportedDataFields;
    mapping (bytes32 => string) internal dataFieldNames;
    // hydro userNames => dataFields => set of saltedHashedValues
    mapping (bytes32 => mapping (bytes32 => bytes32Set._bytes32Set)) internal userSaltedHashes;

    // Encryption key template
    struct EncryptionKey {
        string key;
        bytes32 keyType;
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

    // Mapping from hashed names to applications (primary application directory)
    mapping (bytes32 => Application) internal applicationDirectory;
    // Mapping from owner addresses to applications (secondary application directory)
    mapping (address => bytes32) internal ownerAddressLookup;

    // users to applications to escrow IDs
    mapping (bytes32 => mapping (bytes32 => uint)) internal escrowIds;

    function signUpApplication(
        string applicationName,
        address ownerAddress,
        address relayerAddress,
        address verifierAddress,
        string key,
        string keyType
    )
        public onlyOwner
    {
        require(bytes(applicationName).length < 100);
        bytes32 applicationNameHash = keccak256(applicationName);
        require(!applicationDirectory[applicationNameHash]._initialized, "Application already exists.");

        require(supportedKeyTypes.contains(keccak256(keyType)), "Passed keyType is not supported.");

        applicationDirectory[applicationNameHash] = Application(
            applicationName,
            AddressBook(
                ownerAddress,
                relayerAddress,
                verifierAddress
            ),
            EncryptionKey(
                key,
                keccak256(keyType)
            ),
            true
        );
        ownerAddressLookup[ownerAddress] = applicationNameHash;

        emit ApplicationSignUp(applicationName);
    }

    function modifyApplicationAddresses(
        bytes32 applicationNameHash,
        address ownerAddress,
        address relayerAddress,
        address verifierAddress
    )
        public onlyOwner
    {
        Application storage application = applicationDirectory[applicationNameHash];
        require(application._initialized, "Application does not exist.");
        application.applicationAddressBook.ownerAddress = ownerAddress;
        ownerAddressLookup[ownerAddress] = applicationNameHash;
        application.applicationAddressBook.relayerAddress = relayerAddress;
        application.applicationAddressBook.verifierAddress = verifierAddress;
    }

    function getApplication(string applicationName) public view returns (
        address ownerAddress,
        address relayerAddress,
        address verifierAddress,
        string key,
        string keyType
    )
    {
        bytes32 applicationNameHash = keccak256(applicationName);
        Application storage application = applicationDirectory[applicationNameHash];
        require(application._initialized, "Application does not exist.");

        return (
            application.applicationAddressBook.ownerAddress,
            application.applicationAddressBook.relayerAddress,
            application.applicationAddressBook.verifierAddress,
            application.applicationEncryptionKey.key,
            keyNames[application.applicationEncryptionKey.keyType]
        );
    }

    function deleteApplication(bytes32 applicationNameHash) public onlyOwner {
        require(applicationDirectory[applicationNameHash]._initialized, "Application does not exist.");
        address ownerAddress = applicationDirectory[applicationNameHash].applicationAddressBook.ownerAddress;
        delete applicationDirectory[applicationNameHash];
        delete ownerAddressLookup[ownerAddress];
    }

    function addKeyType(string keyType) public onlyOwner {
        bytes32 keyTypeHash = keccak256(keyType);
        supportedKeyTypes.insert(keyTypeHash);
        keyNames[keyTypeHash] = keyType;
    }

    function addDataField(string dataFieldName) public onlyOwner {
        bytes32 dataFieldNameHash = keccak256(dataFieldName);
        supportedDataFields.insert(dataFieldNameHash);
        dataFieldNames[dataFieldNameHash] = dataFieldName;
    }

    function modifyContractAddresses(
        address _escrowAddress,
        address _hydroTokenAddress,
        address _raindropClientAddress
    )
        public onlyOwner
    {
        escrowAddress = _escrowAddress;
        hydroTokenAddress = _hydroTokenAddress;
        raindropClientAddress = _raindropClientAddress;
    }

    function addDataDelegated(address userAddress, string userName, bytes32[] dataFields, bytes32[] saltedHashes)
        public onlyOwner
    {
        _addData(userAddress, userName, dataFields, saltedHashes);
    }

    function addData(string userName, bytes32[] dataFields, bytes32[] saltedHashes) public {
        _addData(msg.sender, userName, dataFields, saltedHashes);
    }

    function _addData(address userAddress, string userName, bytes32[] dataFields, bytes32[] saltedHashes)
        internal
    {
        require(dataFields.length == saltedHashes.length, "Malformed inputs.");
        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        address raindropClientUserAddress;
        (raindropClientUserAddress, ) = raindropClient.getUserByName(userName);
        require(raindropClientUserAddress == userAddress, "Incorrect user information");
        for (uint i = 0; i < dataFields.length; i++) {
            require(supportedDataFields.contains(dataFields[i]), "Unsupported data field.");
            bytes32Set._bytes32Set storage currentFields = userSaltedHashes[keccak256(userName)][dataFields[i]];
            currentFields.insert(saltedHashes[i]);
        }
    }

    function getSaltedHashes(string userName, string dataField) public view returns (bytes32[]) {
        return userSaltedHashes[keccak256(userName)][keccak256(dataField)].members;
    }

    function removeDataDelegated(address userAddress, string userName, bytes32[] dataFields, bytes32[] saltedHashes)
        public onlyOwner
    {
        _removeData(userAddress, userName, dataFields, saltedHashes);
    }

    function removeData(string userName, bytes32[] dataFields, bytes32[] saltedHashes) public {
        _removeData(msg.sender, userName, dataFields, saltedHashes);
    }

    function _removeData(address userAddress, string userName, bytes32[] dataFields, bytes32[] saltedHashes)
        internal
    {
        require(dataFields.length == saltedHashes.length, "Malformed inputs.");
        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        address raindropClientUserAddress;
        (raindropClientUserAddress, ) = raindropClient.getUserByName(userName);
        require(raindropClientUserAddress == userAddress, "Incorrect user information");
        for (uint i = 0; i < dataFields.length; i++) {
            require(supportedDataFields.contains(dataFields[i]), "Unsupported data field.");
            userSaltedHashes[keccak256(userName)][dataFields[i]].remove(saltedHashes[i]);
        }
    }

    // the application's verifier is the one that must call this
    function receiveApproval(address _from, uint _value, address _token, bytes _extraData) public {
        require(_token == hydroTokenAddress, "Function call not generated from the HYDRO token");
        address ownerAddress;
        address userAddress;
        bytes32[] memory dataFields;
        (ownerAddress, userAddress, dataFields) = parseFields(_extraData);

        requestData(_from, ownerAddress, userAddress, _value, dataFields);
    }

    function requestData(
        address tokenSender,
        address ownerAddress,
        address userAddress,
        uint amount,
        bytes32[] dataFields
    )
        internal
    {
        // make sure the token sender is the passed application's verifier
        bytes32 applicationNameHash = ownerAddressLookup[ownerAddress];
        Application storage application = applicationDirectory[applicationNameHash];
        require(
            application.applicationAddressBook.verifierAddress == tokenSender,
            "The token sender is not the verifier of the application."
        );

        // get the user name from the passed address
        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        string memory userName;
        (userName, ) = raindropClient.getUserByAddress(userAddress);

        // initiate the escrow
        SnowflakeEscrow escrow = SnowflakeEscrow(escrowAddress);
        uint escrowId = escrow.initiateEscrow(
            ownerAddress, userAddress, application.applicationAddressBook.relayerAddress, tokenSender, amount
        );
        escrowIds[keccak256(userName)][applicationNameHash] = escrowId;

        emit DataRequested(application.applicationName, userName, dataFields);
    }

    function closeEscrow(uint escrowId) public onlyOwner {
        SnowflakeEscrow escrow = SnowflakeEscrow(escrowAddress);
        escrow.closeEscrow(escrowId);
    }

    function cancelEscrow(uint escrowId) public onlyOwner {
        SnowflakeEscrow escrow = SnowflakeEscrow(escrowAddress);
        escrow.cancelEscrow(escrowId);
    }


    function parseFields(bytes memory _bytes) internal pure returns (
        address ownerAddress,
        address userAddress,
        bytes32[] memory dataFields
    )
    {
        require((_bytes.length - 40) % 32 == 0, "Malformed bytes.");
        address _ownerAddress = _bytes.toAddress(0);
        address _userAddress = _bytes.toAddress(20);
        uint numberOfFields = (_bytes.length - 40) / 32;
        bytes32[] memory _dataFields;
        for (uint i = 0; i < numberOfFields; i++) {
            dataFields[i] = _bytes.slice(40 + (i * 32), 40 + ((i + 1) * 32)).toBytes32();
        }

        return (_ownerAddress, _userAddress, _dataFields);
    }
}
