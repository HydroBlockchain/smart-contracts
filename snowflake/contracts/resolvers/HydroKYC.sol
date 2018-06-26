pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";
import "../libraries/bytes32Set.sol";
import "../libraries/addressSet.sol";

contract Snowflake {
    function tokenExists(uint _tokenId) public view returns(bool);
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
    mapping(address => uint) attestersToBlockNumber;
    bytes32 standard;
    addressSet._addressSet attesters;
  }

  mapping (uint => KYCSet) internal usersToKYC;

  function addKYCStandard(bytes32 _standard) public {
    require(!KYCStandards.contains(_standard), "This standard is already added.");
    KYCStandards.insert(_standard);
  }

  function attestToUsersKYC(bytes32 _standard, uint _id) public {
    Snowflake snowflake = Snowflake(snowflakeAddress);
    require(snowflake.tokenExists(_id), "This snowflake id does not exist.");
    require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
    uint membersId;
    if (usersToKYC[_id].standardLookup[_standard] > 0){
      membersId = usersToKYC[_id].standardLookup[_standard];

      require(!usersToKYC[_id].passedStandards[membersId - 1].attesters.contains(msg.sender), "This address has already attested this user/standard combination.");

      usersToKYC[_id].passedStandards[membersId - 1].attesters.insert(msg.sender);
      usersToKYC[_id].passedStandards[membersId - 1].attestersToBlockNumber[msg.sender] = block.number;
    } else {
      passedKYC memory kyc;
      membersId = usersToKYC[_id].passedStandards.push(kyc);
      usersToKYC[_id].passedStandards[membersId - 1].attesters.insert(msg.sender);
      usersToKYC[_id].passedStandards[membersId - 1].standard = _standard;
      usersToKYC[_id].passedStandards[membersId - 1].attestersToBlockNumber[msg.sender] = block.number;
      usersToKYC[_id].standardLookup[_standard] = membersId;
    }
  }

  function getAttestationsToUser(bytes32 _standard, uint _id) public view returns(address[]) {
    Snowflake snowflake = Snowflake(snowflakeAddress);
    require(snowflake.tokenExists(_id), "This snowflake id does not exist.");
    require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_id].standardLookup[_standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_id].standardLookup[_standard];
    return usersToKYC[_id].passedStandards[membersId - 1].attesters.members;
  }

  function getAttestationCountToUser(bytes32 _standard, uint _id) public view returns(uint) {
    Snowflake snowflake = Snowflake(snowflakeAddress);
    require(snowflake.tokenExists(_id), "This snowflake id does not exist.");
    require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_id].standardLookup[_standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_id].standardLookup[_standard];
    return usersToKYC[_id].passedStandards[membersId - 1].attesters.members.length;
  }

  function getTimeOfAttestation(bytes32 _standard, uint _id, address _attester) public view returns(uint) {
    Snowflake snowflake = Snowflake(snowflakeAddress);
    require(snowflake.tokenExists(_id), "This snowflake id does not exist.");
    require(KYCStandards.contains(_standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_id].standardLookup[_standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_id].standardLookup[_standard];

    require(usersToKYC[_id].passedStandards[membersId - 1].attesters.contains(_attester), "The given address has not attested to this standard.");

    return usersToKYC[_id].passedStandards[membersId - 1].attestersToBlockNumber[_attester];
  }

  function getEmptyAddressSet() internal pure returns (addressSet._addressSet memory) {
    addressSet._addressSet memory empty;
    return empty;
  }

}
