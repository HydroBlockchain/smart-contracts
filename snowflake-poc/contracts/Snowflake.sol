pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20.sol";
import "./zeppelin/math/SafeMath.sol";

import "./libraries/uint8Set.sol";
import "./libraries/stringSet.sol";
import "./libraries/addressSet.sol";


contract ClientRaindrop {
    function getUserByAddress(address _address) public view returns (string userName);
}


contract Snowflake is Ownable {
    using SafeMath for uint;
    using uint8Set for uint8Set._uint8Set;
    using stringSet for stringSet._stringSet;
    using addressSet for addressSet._addressSet;

    // hydro token wrapper variables
    mapping (address => uint) public deposits;
    uint public balance;

    // resolver list
    addressSet._addressSet internal listedResolvers;
    uint public resolverCost;

    // Token lookup mappings
    mapping (uint => Identity) internal tokenDirectory;
    mapping (address => uint) public ownerToToken;

    // contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;
    uint internal nextTokenId = 1;

    string[6] public nameOrder = ["prefix", "givenName", "middleName", "surname", "suffix", "preferredName"];
    string[3] public dateOrder = ["day", "month", "year"];

    struct Entry {
        bytes32 saltedHash; // required, encrypted plaintext data. specifically: keccak256(abi.encodePacked(data, salt))
        addressSet._addressSet resolversFor; // optional, set of addresses that contain additional data about this field
    }

    struct SnowflakeField {
        mapping (string => Entry) entries; // required, entries with encrypted data attested to by users and other info
        stringSet._stringSet entriesAttestedTo; // required, entries that the user has made
        addressSet._addressSet resolversFor; // optional, set of addresses that contain additional data about this field
    }

    struct Identity {
        address owner;
        string hydroId;
        mapping (uint8 => SnowflakeField) fields; // mapping of AllowedSnowflakeFields to SnowflakeFields
        uint8Set._uint8Set fieldsAttestedTo;
        addressSet._addressSet resolversFor; // optional, set of third-party resolvers
    }

    enum AllowedSnowflakeFields { Name, DateOfBirth, Emails, PhoneNumbers, PhysicalAddresses }
    mapping (uint8 => bool) public allowedFields;
    mapping (uint8 => mapping (string => bool)) internal lockedFieldEntries;

    constructor () public {
        // initialize allowed snowflake fields
        allowedFields[uint8(AllowedSnowflakeFields.Name)] = true;
        allowedFields[uint8(AllowedSnowflakeFields.Emails)] = true;
        allowedFields[uint8(AllowedSnowflakeFields.PhoneNumbers)] = true;
        allowedFields[uint8(AllowedSnowflakeFields.PhysicalAddresses)] = true;

        // initialized locked fields
        lockedFieldEntries[uint8(AllowedSnowflakeFields.Name)]["givenName"] = true;
        lockedFieldEntries[uint8(AllowedSnowflakeFields.Name)]["middleName"] = true;
        lockedFieldEntries[uint8(AllowedSnowflakeFields.Name)]["surname"] = true;
    }

    modifier hasToken(bool check) {
        require((ownerToToken[msg.sender] == 0) != check);
        _;
    }

    modifier _tokenExists(uint tokenId) {
        require(tokenDirectory[tokenId].owner != address(0), "This token has not yet been minted.");
        _;
    }

    // wrapper to ownerToToken that throws if the address doesn't own a token
    function getTokenId(address _address) public view returns (uint tokenId) {
        require(ownerToToken[_address] != 0);
        return ownerToToken[_address];
    }

    function setAddresses(address clientRaindrop, address hydroToken) public onlyOwner {
        clientRaindropAddress = clientRaindrop;
        hydroTokenAddress = hydroToken;
    }

    function mintIdentityToken(bytes32[6] names, bytes32[3] dateOfBirth) public hasToken(false) returns(uint tokenId) {
        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        string memory _hydroId = clientRaindrop.getUserByAddress(msg.sender);

        uint newTokenId = nextTokenId++;
        Identity storage identity = tokenDirectory[newTokenId];

        identity.owner = msg.sender;
        identity.hydroId = _hydroId;

        for (uint8 i; i < names.length; i++) {
            if (names[i] != bytes32(0x0)) {
                identity.fields[uint8(AllowedSnowflakeFields.Name)].entries[nameOrder[i]].saltedHash = names[i];
                identity.fields[uint8(AllowedSnowflakeFields.Name)].entriesAttestedTo.insert(nameOrder[i]);
                // putting this here creates some unnecessary checks, but it catches the case when all elements are 0x0
                identity.fieldsAttestedTo.insert(uint8(AllowedSnowflakeFields.Name));
            }
        }

        for (uint8 j; j < dateOfBirth.length; j++) {
            if (dateOfBirth[j] != bytes32(0x0)) {
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)].entries[dateOrder[j]]
                    .saltedHash = dateOfBirth[j];
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)].entriesAttestedTo.insert(dateOrder[j]);
                // putting this here creates some unnecessary checks, but it catches the case when all elements are 0x0
                identity.fieldsAttestedTo.insert(uint8(AllowedSnowflakeFields.DateOfBirth));
            }
        }

        ownerToToken[msg.sender] = newTokenId;

        return newTokenId;
    }

    // modify resolvers
    function modifyResolvers(address[] resolvers, bool add) public hasToken(true) {
        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(listedResolvers.contains(resolvers[i]), "The given address is not a listed resolver.");
            add ? identity.resolversFor.insert(resolvers[i]) : identity.resolversFor.remove(resolvers[i]);
        }

        emit ResolversModified(ownerToToken[msg.sender], resolvers, add);
    }

    function modifyResolvers(uint8 field, address[] resolvers, bool add) public hasToken(true) {
        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];
        require(identity.fieldsAttestedTo.contains(field), "This field has not been attested to.");

        for (uint i; i < resolvers.length; i++) {
            require(listedResolvers.contains(resolvers[i]), "The given address is not a listed resolver.");
            add ?
                identity.fields[field].resolversFor.insert(resolvers[i]) :
                identity.fields[field].resolversFor.remove(resolvers[i]);
        }

        emit ResolversModified(ownerToToken[msg.sender], field, resolvers, add);
    }

    function modifyResolvers(uint8 field, string entry, address[] resolvers, bool add) public hasToken(true) {
        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];
        require(identity.fieldsAttestedTo.contains(field), "This field has not been attested to.");
        require(identity.fields[field].entriesAttestedTo.contains(entry), "This entry has not been attested to.");

        for (uint i; i < resolvers.length; i++) {
            require(listedResolvers.contains(resolvers[i]), "The given address is not a listed resolver.");
            add ?
                identity.fields[field].entries[entry].resolversFor.insert(resolvers[i]) :
                identity.fields[field].entries[entry].resolversFor.remove(resolvers[i]);
        }

        emit ResolversModified(ownerToToken[msg.sender], field, entry, resolvers, add);
    }

    // modify field entries
    function modifyFieldEntries(uint8 field, string[] entries, bytes32[] saltedHashes, bool add) public hasToken(true) {
        require(allowedFields[field], "Invalid field.");
        require(entries.length == saltedHashes.length, "Malformed inputs.");

        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];

        for (uint i; i < entries.length; i++) {
            require(!lockedFieldEntries[field][entries[i]], "One of the passed entry is locked.");
            if (add) {
                identity.fields[field].entries[entries[i]].saltedHash = saltedHashes[i];
                identity.fields[field].entriesAttestedTo.insert(entries[i]);
            } else {
                delete identity.fields[field].entries[entries[i]].saltedHash;
                identity.fields[field].entriesAttestedTo.remove(entries[i]);
            }
            identity.fields[field].entries[entries[i]].resolversFor = getEmptyAddressSet(); // todo: check this
        }
        if (add) {
            identity.fieldsAttestedTo.insert(field);
        } else if (identity.fields[field].entriesAttestedTo.length() == 0) {
            identity.fieldsAttestedTo.remove(field);
        }
    }

    // check resolver membership
    function hasResolver(uint tokenId, address resolver) public view _tokenExists(tokenId) returns (bool) {
        Identity storage identity = tokenDirectory[tokenId];

        return identity.resolversFor.contains(resolver);
    }

    function hasResolver(uint tokenId, uint8 field, address resolver) public view _tokenExists(tokenId) returns (bool) {
        Identity storage identity = tokenDirectory[tokenId];

        if (!identity.fieldsAttestedTo.contains(field)) {
            return false;
        }

        return identity.fields[field].resolversFor.contains(resolver);
    }

    function hasResolver(uint tokenId, uint8 field, string entry, address resolver)
        public
        view
        _tokenExists(tokenId)
        returns (bool)
    {
        Identity storage identity = tokenDirectory[tokenId];

        if (!identity.fieldsAttestedTo.contains(field) || !identity.fields[field].entriesAttestedTo.contains(entry)) {
            return false;
        }

        return identity.fields[field].entries[entry].resolversFor.contains(resolver);
    }

    // functions to check attestations
    function hasAttested(uint tokenId, uint8 field) public view _tokenExists(tokenId) returns (bool) {
        Identity storage identity = tokenDirectory[tokenId];

        return identity.fieldsAttestedTo.contains(field);
    }

    function hasAttested(uint tokenId, uint8 field, string entry) public view _tokenExists(tokenId) returns (bool) {
        Identity storage identity = tokenDirectory[tokenId];

        if (!identity.fieldsAttestedTo.contains(field)) {
            return false;
        }

        return identity.fields[field].entriesAttestedTo.contains(entry);
    }

    function tokenExists(uint _tokenId) public view returns(bool) {
        return tokenDirectory[_tokenId].owner != address(0);
    }

    // functions to read token values
    function getDetails(uint tokenId) public view _tokenExists(tokenId) returns (
        address owner,
        string hydroId,
        uint8[] fieldsAttestedTo,
        address[] resolversFor
    ) {
        Identity storage identity = tokenDirectory[tokenId];

        return (
            identity.owner,
            identity.hydroId,
            identity.fieldsAttestedTo.members,
            identity.resolversFor.members
        );
    }

    function getDetails(uint tokenId, uint8 field) public view _tokenExists(tokenId) returns (
        string[] entriesAttestedTo,
        address[] resolversFor
    ) {
        Identity storage identity = tokenDirectory[tokenId];

        require(identity.fieldsAttestedTo.contains(field));

        return (
            identity.fields[field].entriesAttestedTo.members,
            identity.fields[field].resolversFor.members
        );
    }

    function getDetails(uint tokenId, uint8 field, string entry) public view _tokenExists(tokenId) returns (
        bytes32 saltedHash,
        address[] resolversFor
    ) {
        Identity storage identity = tokenDirectory[tokenId];

        require(identity.fieldsAttestedTo.contains(field));
        require(identity.fields[field].entriesAttestedTo.contains(entry));

        return (
            identity.fields[field].entries[entry].saltedHash,
            identity.fields[field].entries[entry].resolversFor.members
        );
    }

    // functions that enbale HYDRO functionality
    function receiveApproval(address _sender, uint _amount, address _tokenAddress, bytes) public {
        require(msg.sender == _tokenAddress);
        require(_tokenAddress == hydroTokenAddress);
        deposits[_sender] = deposits[_sender].add(_amount);
        balance = balance.add(_amount);
        ERC20 hydro = ERC20(_tokenAddress);
        require(hydro.transferFrom(_sender, address(this), _amount));
        emit SnowflakeDeposit(_sender, _amount);
    }

    function withdrawSnowflakeBalance(uint _amount) public {
        require(_amount > 0);
        require(deposits[msg.sender] >= _amount, "Your balance is too low to withdraw this amount.");
        deposits[msg.sender] = deposits[msg.sender].sub(_amount);
        balance = balance.sub(_amount);
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(hydro.transfer(msg.sender, _amount));
        emit SnowflakeWithdraw(msg.sender, _amount);
    }

    function transferSnowflakeBalance(address _to, uint _amount) public {
        require(_amount > 0);
        require(deposits[msg.sender] >= _amount, "Your balance is too low to transfer this amount.");
        deposits[msg.sender] = deposits[msg.sender].sub(_amount);
        deposits[_to] = deposits[_to].add(_amount);
        emit SnowflakeTransfer(msg.sender, _to, _amount);
    }

    function addResolver(address _resolver) public {
        transferSnowflakeBalance(owner, resolverCost);
        listedResolvers.insert(_resolver);
    }

    function getEmptyAddressSet() internal pure returns (addressSet._addressSet memory) {
        addressSet._addressSet memory empty;
        return empty;
    }

    // events
    event SnowflakeDeposit(address _owner, uint _amount);
    event SnowflakeTransfer(address _sender, address _to, uint _amount);
    event SnowflakeWithdraw(address _to, uint _amount);

    event ResolversModified(uint _tokenId, address[] _resolvers, bool added);
    event ResolversModified(uint _tokenId, uint8 field, address[] _resolvers, bool added);
    event ResolversModified(uint _tokenId, uint8 field, string entry, address[] _resolvers, bool added);
}
