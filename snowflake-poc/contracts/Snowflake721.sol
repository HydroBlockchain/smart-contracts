pragma solidity ^0.4.23;

import "./zeppelin/ownership/Ownable.sol";

import "./libraries/bytesLibrary.sol";
import "./libraries/bytes32Set.sol";
import "./libraries/addressSet.sol";


contract RaindropClient {
    function userNameTaken(string userName) external view returns (bool taken);
    function getUserByName(string userName) external view returns (address userAddress);
    function getUserByAddress(address _address) external view returns (string userName);
}


contract Snowflake721 is Ownable {
    using bytes32Set for bytes32Set._bytes32Set;
    using addressSet for addressSet._addressSet;

    address raindropClientAddress;

    // Mapping from token ID to owner
    mapping (uint256 => address) public tokenOwner;
    mapping (address => uint256) public ownerToToken;
    mapping (uint256 => Identity) internal tokenIdentities;
    mapping (address => bool) public validators;
    Identity[] internal identityList;

    struct Field {
        bytes32 fieldValue;
        bytes32Set._bytes32Set validations;
    }

    struct NamedFields {
        bytes32Set._bytes32Set availableFields;
        mapping (bytes32 => string) fieldNames;
        mapping (bytes32 => bytes32) fieldValues;
        mapping (bytes32 => bytes32Set._bytes32Set) validations;
        mapping (bytes32 => addressSet._addressSet) resolvers;
    }

    struct Name {
        addressSet._addressSet resolvers;
        Field givenName;
        Field middleName;
        Field surname;
    }

    struct DoB {
        addressSet._addressSet resolvers;
        Field day;
        Field month;
        Field year;
    }

    struct ContactInformation {
        NamedFields emails;
        NamedFields phoneNumbers;
        NamedFields addresses;
    }

    struct Miscellaneous {
        NamedFields miscellaneousFields;
    }

    struct Identity {
        address hydroIdAddress;
        string hydroId;
        Name fullName;
        DoB dateOfBirth;
        ContactInformation contactInformation;
        Miscellaneous miscellaneous;
    }

    modifier canTransfer(address _to, uint _id) {
        require(isOwner(msg.sender, _id), "You do not own the token you are trying to send.");

        require(validators[_to] || msg.sender == owner, "The to address is not an approved validator");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender], "You are not a validator.");
        _;
    }

    modifier onlyTokenOwnerOrValidator(uint _tokenId) {
        require(isOwner(msg.sender, _tokenId) || validators[msg.sender], "You are not the token owner or a validator.");
        _;
    }

    function isOwner(address _spender, uint256 _tokenId) internal view returns (bool) {
        address owner = ownerOf(_tokenId);
        return _spender == owner;
    }

    /**
     * @dev Gets the owner of the specified token ID
     * @param _tokenId uint256 ID of the token to query the owner of
     * @return owner address currently marked as the owner of the given token ID
     */
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = tokenOwner[_tokenId];
        require(owner != address(0), "No one owns this token.");
        return owner;
    }

    function tokenOf(address _address) public view returns (uint256) {
        uint256 tokenId = ownerToToken[_address];
        return tokenId;
    }

    function setValidator(address _validator) public onlyOwner {
        validators[_validator] = true;
    }

    function setRaindropClientAddress(address _address) public onlyOwner {
        raindropClientAddress = _address;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public canTransfer(_to, _tokenId) {
        require(_from != address(0));
        require(_to != address(0));
        addTokenTo(_to, _tokenId);

        emit Transfer(_from, _to, _tokenId);
    }

    function addTokenTo(address _to, uint256 _tokenId) internal {
        require(tokenOwner[_tokenId] == address(0));
        tokenOwner[_tokenId] = _to;
    }

    function mintIdentityToken(
        uint _tokenId,
        bytes32[] information,
        address _id,
        bytes32 _initialValidator
    )
        public
        onlyOwner
    {
        require(tokenOf(_id) == 0, "This address already has an identity token.");

        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        string memory hydroId = raindropClient.getUserByAddress(_id);

        ContactInformation memory contactInfo;
        Misc memory misc;
        tokenIdentities[_tokenId] = Identity(
            _id,
            hydroId,
            DOB(
                Field(information[0], new bytes32[](0)),
                Field(information[1], new bytes32[](0)),
                Field(information[2], new bytes32[](0))
              ),
            Name(
                Field(information[3], new bytes32[](0)),
                Field(information[4], new bytes32[](0))
              ),
            Address(
                Field(information[5], new bytes32[](0))
              ),
            contactInfo,
            misc
        );

        tokenIdentities[_tokenId].dateOfBirth.month.validations.push(_initialValidator);
        tokenIdentities[_tokenId].dateOfBirth.day.validations.push(_initialValidator);
        tokenIdentities[_tokenId].dateOfBirth.year.validations.push(_initialValidator);
        tokenIdentities[_tokenId].fullName.givenName.validations.push(_initialValidator);
        tokenIdentities[_tokenId].fullName.familyName.validations.push(_initialValidator);
        tokenIdentities[_tokenId].homeAddress.homeAddress.validations.push(_initialValidator);

        transferFrom(msg.sender, _id, _tokenId);
    }

    function addEmail(uint256 _tokenId, bytes32 _newEmail)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.contactInformation.emails.insert(_newEmail);
    }

    function removeEmail(uint256 _tokenId, bytes32 _email)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.contactInformation.emails.remove(_email);
    }

    function addPhone(uint256 _tokenId, bytes32 _newPhone)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.contactInformation.phoneNumbers.insert(_newPhone);
    }

    function removePhone(uint256 _tokenId, bytes32 _phone)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.contactInformation.phoneNumbers.remove(_phone);
    }

    function addMisc(uint256 _tokenId, bytes32 _category, bytes32 _data)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.other.miscellaneous[_category] = _data;
    }

    function removeMisc(uint256 _tokenId, bytes32 _category)
        public
        onlyTokenOwnerOrValidator(_tokenId)
    {
        Identity storage id = tokenIdentities[_tokenId];
        id.other.miscellaneous[_category] = 0x0;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _tokenId
    );
}
