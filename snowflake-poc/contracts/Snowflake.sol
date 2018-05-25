pragma solidity ^0.4.23;

import "./Withdrawable.sol";

import "./libraries/bytes32Set.sol";
import "./libraries/addressSet.sol";


contract RaindropClient {
    function userNameTaken(string userName) external view returns (bool taken);
    function getUserByName(string userName) external view returns (address userAddress);
    function getUserByAddress(address _address) external view returns (string userName);
}


contract Snowflake is Withdrawable {
    using bytes32Set for bytes32Set._bytes32Set;
    using addressSet for addressSet._addressSet;

    // Token lookup variables
    mapping (uint256 => Identity) internal tokenIdentities;
    mapping (address => uint256) public ownerToToken;
    // approved validators
    addressSet._addressSet internal validators;

    address public raindropClientAddress;
    uint internal nextTokenId = 1;

    bytes32Set._bytes32Set internal validNameFields;
    bytes32Set._bytes32Set internal validDateOfBirthFields;
    bytes32Set._bytes32Set internal validContactInformationNamedFields;

    struct Field {
        bytes32 fieldValue;
        bytes32Set._bytes32Set validations;
    }

    struct NamedField {
        string fieldName;
        bytes32 fieldValue;
        bytes32Set._bytes32Set validations;
        addressSet._addressSet resolvers;
    }

    struct Identity {
        address owner;
        string hydroId;

        mapping (bytes32 => Field) name;
        addressSet._addressSet nameResolvers;

        mapping (bytes32 => Field) dateOfBirth;
        addressSet._addressSet dateOfBirthResolvers;

        mapping (bytes32 => NamedField) contactInformation;
        mapping (bytes32 => bytes32Set._bytes32Set) contactInformationEntered;

        mapping (bytes32 => mapping (bytes32 => NamedField)) miscellaneous;
        mapping (bytes32 => bytes32Set._bytes32Set) miscellaneousEntered;
    }

    function Snowflake () public {
        validNameFields.insert(keccak256("givenName"));
        validNameFields.insert(keccak256("middleName"));
        validNameFields.insert(keccak256("surname"));

        validDateOfBirthFields.insert(keccak256("day"));
        validDateOfBirthFields.insert(keccak256("month"));
        validDateOfBirthFields.insert(keccak256("year"));

        validContactInformationNamedFields.insert(keccak256("emails"));
        validContactInformationNamedFields.insert(keccak256("phoneNumbers"));
        validContactInformationNamedFields.insert(keccak256("addresses"));
    }

    modifier onlyValidator() {
        require(validators.contains(msg.sender), "You are not a validator.");
        _;
    }

    modifier onlyTokenOwnerOrValidator(uint _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender || validators.contains(msg.sender),
            "You are not the token owner or a validator."
        );
        _;
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = tokenIdentities[_tokenId].owner;
        require(owner != address(0), "No one owns this token.");
        return owner;
    }

    function tokenOf(address _address) public view returns (uint256) {
        uint256 tokenId = ownerToToken[_address];
        return tokenId;
    }

    function setValidator(address _validator) public onlyOwner {
        validators.insert(_validator);
    }

    function setRaindropClientAddress(address _address) public onlyOwner {
        raindropClientAddress = _address;
    }

    function mintIdentityToken(address tokenOwner) public returns(uint tokenId) {
        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        string memory _hydroId = raindropClient.getUserByAddress(tokenOwner);
        require(ownerToToken[msg.sender] == 0, "This address has already minted an identity.");
        uint mintedTokenId = nextTokenId++;
        Identity storage identity = tokenIdentities[mintedTokenId];

        identity.owner = tokenOwner;
        identity.hydroId = _hydroId;

        return mintedTokenId;
    }

    function updateName(bytes32[] fields, bytes32[] fieldValues) public {
        require(fields.length == fieldValues.length, "Malformed inputs.");
        require(ownerToToken[msg.sender] != 0, "Sender has not yet minted an identity.");
        Identity storage identity = tokenIdentities[ownerToToken[msg.sender]];
        for (uint8 i; i < fields.length; i++) {
            require(validNameFields.contains(fields[i]), "Invalid Field Identifier");
            identity.name[fields[i]].fieldValue = fieldValues[i];
            identity.name[fields[i]].validations = getEmptyBytes32Set();
        }
    }

    function updateNameResolver(address[] resolvers) public {
        require(resolvers.length < 256, "Malformed inputs.");
        require(ownerToToken[msg.sender] != 0, "Sender has not yet minted an identity.");
        Identity storage identity = tokenIdentities[ownerToToken[msg.sender]];
        for (uint8 i; i < resolvers.length; i++) {
            identity.nameResolvers.insert(resolvers[i]);
        }
    }

    function getEmptyBytes32Set() internal pure returns (bytes32Set._bytes32Set) {
        bytes32Set._bytes32Set memory empty;
        return empty;
    }
}
