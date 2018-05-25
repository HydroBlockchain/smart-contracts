pragma solidity ^0.4.23;

import "./zeppelin/ownership/Ownable.sol";

import "./libraries/bytesLibrary.sol";
import "./libraries/bytes32Set.sol";
import "./libraries/addressSet.sol";

contract Snowflake {
    function ownerToToken(address _sender) public view returns(uint256);
}

contract HydroRepuation is Ownable {

    address snowflakeAddress = 0x0;

    struct AddressGroup {
        address[] addressList;
        mapping (address => bool) addressLookup;
    }

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }

    mapping (address => Reputation) internal reputationList;
    mapping (address => string[]) addedReputationsList;
    mapping (address => mapping(string => bool)) addedReputationsLookup;

    struct Reputation {
        uint256 identityTokenId;
        RepuationField[] repuationFieldsList;
        mapping(string => RepuationField) repuationFieldsLookup;
    }

    struct RepuationField {
        string fieldName;
        AddressGroup addresses;
    }

    function joinHydroRepuation() {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint256 tokenId = snowflake.ownerToToken(msg.sender);
        reputationList[msg.sender].identityTokenId = tokenId;
    }

    function addReputationField(string _field) {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint256 tokenId = snowflake.ownerToToken(msg.sender);

        require(!addedReputationsLookup[msg.sender][_field],"");

        addedReputationsList[msg.sender].push(_field);
        addedReputationsLookup[msg.sender][_field] = true;
        reputationList[msg.sender].repuationFields.push(RepuationField(_field, ));
    }

    function attestToReputation(address _user, string _field) {
        require(addedReputationsLookup[msg.sender][_field],"");

        require(!reputationList[_user].repuationFieldsLookup[_field].addresses.addressLookup[msg.sender], "");
        

    }

}
