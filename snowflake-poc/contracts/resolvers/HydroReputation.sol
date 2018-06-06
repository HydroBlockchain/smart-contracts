pragma solidity ^0.4.23;

import "./SnowflakeResolver.sol";


contract Snowflake {
    function ownerToToken(address _sender) public view returns(uint256);
}


contract HydroReputation is SnowflakeResolver {
    struct AddressGroup {
        address[] addressList;
        mapping (address => bool) addressLookup;
    }

    mapping (address => Reputation) internal reputationList;
    mapping (address => string[]) addedReputationsList;
    mapping (address => mapping(string => uint)) addedReputationsLookup;

    AddressGroup[] addresses;

    struct Reputation {
        uint256 identityTokenId;
        ReputationField[] reputationFieldsList;
        mapping(string => ReputationField) reputationFieldsLookup;
    }

    struct ReputationField {
        string fieldName;
        uint256 addressGroupIndex;
    }

    function joinHydroReputation() public {
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
        reputationList[msg.sender].reputationFieldsList.push(ReputationField(_field, addressListId));
        reputationList[msg.sender].reputationFieldsLookup[_field].fieldName = _field;
        reputationList[msg.sender].reputationFieldsLookup[_field].addressGroupIndex = addressListId;
    }

    function attestToReputation(address _user, string _field) public {
        require(addedReputationsLookup[_user][_field] > 0,"");

        require(!addresses[reputationList[_user].reputationFieldsLookup[_field].addressGroupIndex].addressLookup[msg.sender], "");

        uint256 id = addedReputationsLookup[_user][_field] - 1;
        uint addressId = reputationList[_user].reputationFieldsList[id].addressGroupIndex;
        addresses[addressId].addressList.push(msg.sender);
        addresses[addressId].addressLookup[msg.sender] = true;
    }

    function getReputation(address _user, string _field) public view returns(uint){
        require(addedReputationsLookup[_user][_field] > 0,"");
        uint addressId = reputationList[_user].reputationFieldsLookup[_field].addressGroupIndex;
        return addresses[addressId].addressList.length;
    }

    function alreadyAttested(address _user, string _field) public view returns(bool){
        return addresses[reputationList[_user].reputationFieldsLookup[_field].addressGroupIndex].addressLookup[msg.sender];
    }

    function addedRepLookup(address _user, string _field) public view returns(uint){
        return addedReputationsLookup[_user][_field];
    }

}
