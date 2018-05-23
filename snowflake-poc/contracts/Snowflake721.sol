pragma solidity ^0.4.23;

import "./zeppelin/ownership/Ownable.sol";

import "./libraries/bytesLibrary.sol";
import "./libraries/bytes32Set.sol";


contract RaindropClient {
    function userNameTaken(string userName) external view returns (bool taken);
    function getUserByName(string userName) external view returns (address userAddress);
    function getUserByAddress(address _address) external view returns (string userName);
}

contract Snowflake721 is Ownable {

    address raindropClientAddress;

    // Mapping from token ID to owner
    mapping (uint256 => address) internal tokenOwner;

    struct Field {
        bytes32 fieldValue;
        bytes32[] validations;
    }

    struct DOB {
        Field month;
        Field day;
        Field year;
    }

    struct Name {
        Field givenName;
        Field familyName;
    }

    struct Address {
        Field homeAddress;
    }

    struct ContactInformation {
        bytes32Set emails;
        bytes32Set phoneNumbers;
    }

    struct Misc {
        mapping (bytes32 => bytes32) miscellaneous;
    }

    struct Identity {
        address id;
        string hydroId;
        DOB dateOfBirth;
        Name fullName;
        Address homeAddress;
        ContactInformation contactInformation;
        Misc other;
    }

    mapping (address => bool) validators;
    mapping (uint => Identity) tokenIdentities;


    modifier canTransfer(address _to, uint _id) {
        require(
          isOwner(msg.sender, _id),
          "You do not own the token you are trying to send."
        );

        require(
          validators[_to] ||
          msg.sender == owner,
          "The to address is not an approved validator"
        );

        _;
    }

    function isOwner(
      address _spender,
      uint256 _tokenId
    )
      internal
      view
      returns (bool)
    {
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
      require(owner != address(0));
      return owner;
    }

    function setValidator(address _validator) public onlyOwner {
        validators[_validator] = true;
    }

    function setRaindropClientAddress(address _address) public onlyOwner {
        raindropClientAddress = _address;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId)
      public
      canTransfer(_to)
    {
        require(_from != address(0));
        require(_to != address(0));
        addTokenTo(_to, _tokenId);

        emit Transfer(_from, _to, _tokenId);
    }

    function setUserIdentity(
        uint _tokenId,
        bytes32[] information,
        address _id,
        bytes32 _initialValidator
    )
        public
        onlyOwner
    {
        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        string memory hydroId = raindropClient.getUserByAddress(_id);

        ContactInformation memory contactInfo;
        Misc memory misc;
        tokenIdentities[_tokenId] = Identity(
              _id,
              hydroId,
              DOB(
                  Field(information[0], new bytes32[](0)),//bytes32List(_initialValidator)),
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

        safeTransferFrom(msg.sender, _id, _tokenId);
    }
}
