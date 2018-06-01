pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Withdrawable.sol";

import "./libraries/stringSet.sol";
import "./libraries/bytes32Set.sol";
import "./libraries/addressSet.sol";


interface ClientRaindrop {
    function getUserByAddress(address _address) external view returns (string userName);
}

contract Snowflake is Withdrawable {
    using stringSet for stringSet._stringSet;
    using bytes32Set for bytes32Set._bytes32Set;
    using addressSet for addressSet._addressSet;

    mapping (address => uint256) public staking;
    uint public balance;

    // Token lookup mappings
    mapping (uint256 => Identity) internal tokenIdentities;
    mapping (address => uint256) public ownerToToken;
    mapping (string => uint256) internal hydroIdToToken;
    // contract variables
    address public raindropClientAddress;
    address public hydroTokenAddress;
    uint internal nextTokenId = 1;

    string[4] public nameOrder = ["givenName", "middleName", "surname", "preferredName"];
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
        addressSet._addressSet thirdPartyResolvers; // optional, set of third-party resolvers
    }

    enum AllowedSnowflakeFields { Name, DateOfBirth, Emails, PhoneNumbers, PhysicalAddresses, MAXIMUM }
    mapping (uint8 => bool) public allowedFields;

    function Snowflake () public {
        // initialize allowed snowflake fields
        for (uint8 i; i < uint8(AllowedSnowflakeFields.MAXIMUM); i++) {
            allowedFields[i] = true;
        }
    }

    modifier requireStake(address _address, uint stake) {
        require(staking[_address] >= stake, "Insufficient HYDRO balance.");
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

    function mintIdentityToken(bytes32[4] names, bytes32[3] dateOfBirth) public returns(uint tokenId) {
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

        for (uint8 j; j < dateOfBirth.length; j++) {
            if (dateOfBirth[j] != bytes32(0x0)) {
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)].entries[dateOrder[j]].saltedHash =
                    dateOfBirth[j];
                identity.fields[uint8(AllowedSnowflakeFields.DateOfBirth)].entriesAttestedTo.insert(dateOrder[j]);
            }
        }

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
    }

    function addThirdPartyResolvers(address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        for (uint i; i < resolvers.length; i++) {
            identity.thirdPartyResolvers.insert(resolvers[i]);
        }
    }

    function removeThirdPartyResolvers(address[] resolvers) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        // setting resolvers for an entire field vs. for an entry within a field
        for (uint i; i < resolvers.length; i++) {
            identity.thirdPartyResolvers.remove(resolvers[i]);
        }
    }

    function modifyFieldEntries(uint8 field, string[] entries, bytes32[] saltedHashes) public {
        require(allowedFields[field], "Invalid field.");
        require(field > uint8(AllowedSnowflakeFields.DateOfBirth), "This field cannot be modified.");
        require(entries.length == saltedHashes.length, "Malformed inputs.");

        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < entries.length; i++) {
            identity.fields[field].entries[entries[i]].saltedHash = saltedHashes[i];
            identity.fields[field].entriesAttestedTo.insert(entries[i]);
        }
    }

    function removeFieldEntries(uint8 field, string[] entries, bytes32[] saltedHashes) public {
        require(allowedFields[field], "Invalid field.");
        require(field > uint8(AllowedSnowflakeFields.DateOfBirth), "This field cannot be modified.");
        require(entries.length == saltedHashes.length, "Malformed inputs.");

        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < entries.length; i++) {
            delete identity.fields[field].entries[entries[i]].saltedHash;
            identity.fields[field].entriesAttestedTo.remove(entries[i]);
        }
    }

    function receiveApproval(address _sender, uint _amount, address _tokenAddress, bytes _extraData) public {
        require(msg.sender == _tokenAddress);
        require(_tokenAddress == hydroTokenAddress);
        ERC20Basic hydro = ERC20Basic(_tokenAddress);
        require(hydro.transferFrom(_sender, this, _amount));
        staking[_sender] += _amount;
        balance += _amount;
    }

    function withdraw() public {
        require(staking[msg.sender] > 0);
        require(staking[msg.sender] < balance);
        ERC20Basic hydro = ERC20Basic(_tokenAddress);
        hydro.transfer(msg.sender, staking[msg.sender]);
    }

    function snowflakeTransfer(address _to, uint _amount) public {
        require(staking[msg.sender] >= _amount, "Your balance is too low to transfer this amount");
        staking[msg.sender] -= _amount; //todo add SafeMath
        staking[_to] += _amount;
        emit SnowflakeTransfer(msg.sender, _to, _amount);
    }

    event SnowflakeTransfer(address _from, address _to, address _amount);

}
