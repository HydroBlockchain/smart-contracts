pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";
import "./bytes32Set.sol";
import "./addressSet.sol";

contract Snowflake {
    function ownerToToken(address _sender) public view returns(uint256);
}

contract HydroKYC is SnowflakeResolver {
    using bytes32Set for bytes32Set._bytes32Set;
    using addressSet for addressSet._addressSet;

    bytes32Set._bytes32Set internal KYCStandards;

    struct KYCSet {
      passedKYC[] passedStandards;
      mapping(bytes32 => uint) standardLookup;
    }

    struct passedKYC {
      uint blockNumber;
      bytes32 standard;
      addressSet._addressSet attesters;
    }

    mapping (uint => KYCSet) internal usersToKYC;

    function addKYCStandard(bytes32 _standard) public {
      require(!KYCStandards.contains(_standard), "This standard is already added.");
      KYCStandards.insert(_standard);
    }

    function attestToUsersKYC(bytes32 _standard, uint _id) public {
      require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
      uint membersId;
      if (usersToKYC[_id].standardLookup[_standard] > 0){
        membersId = usersToKYC[_id].standardLookup[_standard];
        usersToKYC[_id].passedStandards[membersId - 1].attesters.insert(msg.sender);
        usersToKYC[_id].passedStandards[membersId - 1].blockNumber = block.number;
      } else {
        membersId = usersToKYC[_id].passedStandards.push(passedKYC(block.number, _standard, getEmptyAddressSet()));
        usersToKYC[_id].passedStandards[membersId - 1].attesters.insert(msg.sender);
        usersToKYC[_id].standardLookup[_standard] = membersId;
      }
    }

    function getAttestationsToUser(bytes32 _standard, uint _id) public view returns(address[]) {
      require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
      require(usersToKYC[_id].standardLookup[_standard] > 0, "This standard is not passed by this user.");

      uint membersId = usersToKYC[_id].standardLookup[_standard];
      return usersToKYC[_id].passedStandards[membersId - 1].attesters.members;
    }

    function getEmptyAddressSet() internal pure returns (addressSet._addressSet memory) {
        addressSet._addressSet memory empty;
        return empty;
    }

}
