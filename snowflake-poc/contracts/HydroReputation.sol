pragma solidity ^0.4.23;

import "./zeppelin/ownership/Ownable.sol";

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
    mapping (address => mapping(string => uint)) addedReputationsLookup;

    Reputation[] public reputations;
    mapping(address => uint256) internal addressToreputationId;
    mapping(uint256 => uint256) internal snowflakeToReputationId;

    AddressGroup[] addresses;

    struct Reputation {
        uint256 identityTokenId;
        RepuationField[] repuationFieldsList;
        mapping(string => RepuationField) repuationFieldsLookup;
    }

    struct RepuationField {
        string fieldName;
        uint256 addressGroupIndex;
    }

    function joinHydroRepuation() public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint256 tokenId = snowflake.ownerToToken(msg.sender);
        reputationList[msg.sender].identityTokenId = tokenId;
    }

    function addReputationField(string _field) public {
        require(addedReputationsLookup[msg.sender][_field] == 0,"");

        uint256 id = addedReputationsList[msg.sender].push(_field);
        addedReputationsLookup[msg.sender][_field] = id;
        AddressGroup memory group;
        uint256 addressListId = addresses.push(group) - 1;
        reputationList[msg.sender].repuationFieldsList.push(RepuationField(_field, addressListId));
        reputationList[msg.sender].repuationFieldsLookup[_field].fieldName = _field;
        reputationList[msg.sender].repuationFieldsLookup[_field].addressGroupIndex = addressListId;
    }

    function attestToReputation(address _user, string _field) public {
        require(addedReputationsLookup[_user][_field] > 0,"");

        require(!reputationList[_user].repuationFieldsLookup[_field].addresses.addressLookup[msg.sender], "");

        uint256 id = addedReputationsLookup[_user][_field] - 1;
        reputationList[_user].repuationFieldsList[id].addresses.addressList.push(msg.sender);
        reputationList[_user].repuationFieldsList[id].addresses.addressLookup[msg.sender] = true;
        reputationList[_user].repuationFieldsLookup[_field].addresses.addressList.push(msg.sender);
        reputationList[_user].repuationFieldsLookup[_field].addresses.addressLookup[msg.sender] = true;
    }

    function getReputation(address _user, string _field) public view returns(uint){
        require(addedReputationsLookup[_user][_field] > 0,"");
        return reputationList[_user].repuationFieldsLookup[_field].addresses.addressList.length;
    }

    function alreadyAttested(address _user, string _field) public view returns(bool){
        return reputationList[_user].repuationFieldsLookup[_field].addresses.addressLookup[msg.sender];
    }

    function addedRepLookup(address _user, string _field) public view returns(uint){
        return addedReputationsLookup[_user][_field];
    }

}
