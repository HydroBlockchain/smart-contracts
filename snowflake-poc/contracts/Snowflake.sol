pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20.sol";
import "./zeppelin/math/SafeMath.sol";

import "./libraries/uint8Set.sol";
import "./libraries/stringSet.sol";
import "./libraries/addressSet.sol";


interface ClientRaindrop {
    function getUserByAddress(address _address) external view returns (string userName);
}


contract Snowflake is Ownable {
    using SafeMath for uint256;
    using uint8Set for uint8Set._uint8Set;
    using stringSet for stringSet._stringSet;
    using addressSet for addressSet._addressSet;

    // hydro token wrapper variables
    mapping (address => uint256) public deposits;
    uint public balance;

    // Token lookup mappings
    mapping (uint256 => Identity) internal tokenIdentities;
    mapping (address => uint256) public ownerToToken;
    mapping (string => uint256) internal hydroIdToToken;

    // contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;
    uint internal nextTokenId = 1;

    string[6] public nameOrder = ["prefix", "givenName", "middleName", "surname", "suffix", "preferredName"];
    stringSet._stringSet internal editableNameEntries;
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
        addressSet._addressSet thirdPartyResolvers; // optional, set of third-party resolvers
    }

    enum AllowedSnowflakeFields { Name, DateOfBirth, Emails, PhoneNumbers, PhysicalAddresses, MAXIMUM }
    mapping (uint8 => bool) public allowedFields;

    constructor () public {
        // initialize allowed snowflake fields
        for (uint8 i; i < uint8(AllowedSnowflakeFields.MAXIMUM); i++) {
            allowedFields[i] = true;
        }
        editableNameEntries.insert("prefix");
        editableNameEntries.insert("suffix");
        editableNameEntries.insert("preferredName");
    }

    modifier requireMinimumBalance(address _address, uint _balance) {
        require(deposits[_address] >= _balance, "Insufficient HYDRO balance.");
        _;
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = tokenIdentities[_tokenId].owner;
        require(owner != address(0), "This token has not yet been minted.");
        return owner;
    }

    function tokenOfAddress(address _address) public view returns (uint256) {
        uint256 tokenId = ownerToToken[_address];
        require(tokenId != 0, "This address does not possess a token.");
        return tokenId;
    }

    function tokenOfHydroID(string hydroId) public view returns (uint256) {
        uint256 tokenId = hydroIdToToken[hydroId];
        require(tokenId != 0, "This address does not possess a token.");
        return tokenId;
    }

    function setClientRaindropAddress(address _address) public onlyOwner {
        clientRaindropAddress = _address;
    }

    function setHydroTokenAddress(address _address) public onlyOwner {
        hydroTokenAddress = _address;
    }

    function mintIdentityToken(bytes32[6] names, bytes32[3] dateOfBirth) public returns(uint tokenId) {
        require(ownerToToken[msg.sender] == 0, "This address is already associated with an identity.");

        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        string memory _hydroId = clientRaindrop.getUserByAddress(msg.sender);

        assert(hydroIdToToken[_hydroId] == 0);

        uint newTokenId = nextTokenId++;
        Identity storage identity = tokenIdentities[newTokenId];

        identity.owner = msg.sender;
        identity.hydroId = _hydroId;

        for (uint8 i; i < names.length; i++) {
            if (names[i] != bytes32(0x0)) {
                identity.fields[uint8(AllowedSnowflakeFields.Name)].entries[nameOrder[i]].saltedHash = names[i];
                identity.fields[uint8(AllowedSnowflakeFields.Name)].entriesAttestedTo.insert(nameOrder[i]);
            }
        }
        identity.fieldsAttestedTo.insert(uint8(AllowedSnowflakeFields.Name));

        for (uint8 j; j < dateOfBirth.length; j++) {
            if (dateOfBirth[j] != bytes32(0x0)) {
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)]
                    .entries[dateOrder[j]].saltedHash = dateOfBirth[j];
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)].entriesAttestedTo.insert(dateOrder[j]);
            }
        }
        identity.fieldsAttestedTo.insert(uint8(AllowedSnowflakeFields.DateOfBirth));

        ownerToToken[msg.sender] = newTokenId;
        hydroIdToToken[_hydroId] = newTokenId;

        return newTokenId;
    }

    function addResolver(uint8 field, string entry, address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        if (bytes(entry).length == 0) {
            for (uint i; i < resolvers.length; i++) {
                identity.fields[field].resolversFor.insert(resolvers[i]);
            }
        } else {
            for (uint j; j < resolvers.length; j++) {
                identity.fields[field].entries[entry].resolversFor.insert(resolvers[j]);
            }
        }

        emit AddedEntryResolver(field, entry, resolvers);
    }

    function removeResolver(uint8 field, string entry, address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        if (bytes(entry).length == 0) {
            for (uint i; i < resolvers.length; i++) {
                identity.fields[field].resolversFor.remove(resolvers[i]);
            }
        } else {
            for (uint j; j < resolvers.length; j++) {
                identity.fields[field].entries[entry].resolversFor.remove(resolvers[j]);
            }
        }

        emit RemovedEntryResolver(field, entry, resolvers);
    }

    function addThirdPartyResolvers(address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        for (uint i; i < resolvers.length; i++) {
            identity.thirdPartyResolvers.insert(resolvers[i]);
        }

        emit AddedResolver(tokenId, resolvers);
    }

    function removeThirdPartyResolvers(address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        for (uint i; i < resolvers.length; i++) {
            identity.thirdPartyResolvers.remove(resolvers[i]);
        }

        emit RemovedResolver(tokenId, resolvers);
    }
    function addUpdateFieldEntries(uint8 field, string[] entries, bytes32[] saltedHashes) public {
        require(allowedFields[field], "Invalid field.");
        require(field != uint8(AllowedSnowflakeFields.DateOfBirth), "This field cannot be modified.");
        require(entries.length == saltedHashes.length, "Malformed inputs.");

        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < entries.length; i++) {
            if (field == uint8(AllowedSnowflakeFields.Name))
                require(editableNameEntries.contains(entries[i]));
            identity.fields[field].entries[entries[i]].saltedHash = saltedHashes[i];
            identity.fields[field].entries[entries[i]].resolversFor = getEmptyAddressSet();
            identity.fields[field].entriesAttestedTo.insert(entries[i]);
        }
        identity.fieldsAttestedTo.insert(field);
    }

    function removeFieldEntries(uint8 field, string[] entries, bytes32[] saltedHashes) public {
        require(allowedFields[field], "Invalid field.");
        require(field > uint8(AllowedSnowflakeFields.DateOfBirth), "These fields cannot be removed.");
        require(entries.length == saltedHashes.length, "Malformed inputs.");

        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < entries.length; i++) {
            delete identity.fields[field].entries[entries[i]].saltedHash;
            identity.fields[field].entries[entries[i]].resolversFor = getEmptyAddressSet();
            identity.fields[field].entriesAttestedTo.remove(entries[i]);
        }

        if (identity.fields[field].entriesAttestedTo.length() == 0)
            identity.fieldsAttestedTo.remove(field);
    }

    // functions to check resolver membership
    function hasResolver(uint tokenId, address resolver) public view returns (bool) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");

        return identity.thirdPartyResolvers.contains(resolver);
    }

    function hasResolver(uint tokenId, uint8 field, address resolver) public view returns (bool) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
        if (!identity.fieldsAttestedTo.contains(field)) {
            return false;
        }

        return identity.fields[field].resolversFor.contains(resolver);
    }

    function hasResolver(uint tokenId, uint8 field, string entry, address resolver) public view returns (bool) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
        if (!identity.fieldsAttestedTo.contains(field) || !identity.fields[field].entriesAttestedTo.contains(entry)) {
            return false;
        }

        return identity.fields[field].entries[entry].resolversFor.contains(resolver);
    }

    // functions to check attestations
    function haAttested(uint tokenId, uint8 field) public view returns (bool) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");

        return identity.fieldsAttestedTo.contains(field);
    }

    function haAttested(uint tokenId, uint8 field, string entry) public view returns (bool) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
        if (!identity.fieldsAttestedTo.contains(field)) {
            return false;
        }

        return identity.fields[field].entriesAttestedTo.contains(entry);
    }

    // functions to read token values
    function getDetails(uint tokenId) public view returns (
        address owner, string hydroId, uint8[] fieldsAttestedTo, address[] thirdPartyResolvers
    ) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
        return (
            identity.owner,
            identity.hydroId,
            identity.fieldsAttestedTo.members,
            identity.thirdPartyResolvers.members
        );
    }

    function getDetails(uint tokenId, uint8 field) public view returns (
        string[] entriesAttestedTo, address[] resolversFor
    ) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
        require(identity.fieldsAttestedTo.contains(field));
        return (
            identity.fields[field].entriesAttestedTo.members,
            identity.fields[field].resolversFor.members
        );
    }

    function getDetails(uint tokenId, uint8 field, string entry) public view returns (
        bytes32 saltedHash, address[] resolversFor
    ) {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0), "This token has not yet been minted.");
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

    function getSnowflakeBalance(address _user) public view returns(uint){
        return deposits[_user];
    }

    function getContractBalance() public view returns(uint){
        return balance;
    }

    function getEmptyAddressSet() internal pure returns (addressSet._addressSet memory) {
        addressSet._addressSet memory empty;
        return empty;
    }

    // events
    event SnowflakeDeposit(address _owner, uint _amount);
    event SnowflakeTransfer(address _sender, address _to, uint _amount);
    event SnowflakeWithdraw(address _to, uint _amount);
    event AddedEntryResolver(uint8 _field, string _entry, address[] _resolvers);
    event RemovedEntryResolver(uint8 _field, string _entry, address[] _resolvers);
    event AddedResolver(uint _tokenId, address[] _resolvers);
    event RemovedResolver(uint _tokenId, address[] _resolvers);
}
