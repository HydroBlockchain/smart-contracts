pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./SnowflakeResolver.sol";
import "../libraries/bytes32Set.sol";
import "../libraries/addressSet.sol";
import "../libraries/stringSet.sol";

contract Snowflake {
  function getHydroId(address _address) public view returns (string hydroId);
}

contract HydroKYC is SnowflakeResolver {
  using addressSet for addressSet._addressSet;
  using stringSet for stringSet._stringSet;
  using bytes32Set for bytes32Set._bytes32Set;

  bytes32Set._bytes32Set internal KYCStandards;
  mapping(bytes32 => string) KYCStandardsStrings;

  stringSet._stringSet internal members;

  struct KYCSet {
    passedKYC[] passedStandards;
    mapping(bytes32 => uint) standardLookup;
  }

  struct passedKYC {
    mapping(address => uint) attestersToBlockNumber;
    bytes32 standard;
    addressSet._addressSet attesters;
  }

  mapping (string => KYCSet) internal usersToKYC;

  constructor () public {
    snowflakeName = "Hydro KYC";
    snowflakeDescription = "A KYC dApp for Snowflake owners.";
    snowflakeAddress = 0x920b3eD908F5E63DC859C0D61cA2a270f0663e58;
  }

  // implement signup function
  function onSignUp(string hydroId, uint allowance) public returns (bool) {
    require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");

    if (members.contains(hydroId)) {
      return false;
    }
    members.insert(hydroId);
    return true;
  }

  function addKYCStandard(string _standard) public {
    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));

    require(!KYCStandards.contains(bytes32Standard), "This standard is already added.");
    KYCStandards.insert(bytes32Standard);
    KYCStandardsStrings[bytes32Standard] = _standard;
  }

  function attestToUsersKYC(string _standard, string _hydroId) public {
    require(members.contains(_hydroId));

    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));
    require(KYCStandards.contains(bytes32Standard), "This standard does not currently exist in the smart contract.");
    uint membersId;

    if (usersToKYC[_hydroId].standardLookup[bytes32Standard] > 0){
      membersId = usersToKYC[_hydroId].standardLookup[bytes32Standard];

      require(!usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.contains(msg.sender), "This address has already attested this user/standard combination.");

      usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.insert(msg.sender);
      usersToKYC[_hydroId].passedStandards[membersId - 1].attestersToBlockNumber[msg.sender] = block.number;
    } else {
      passedKYC memory kyc;
      membersId = usersToKYC[_hydroId].passedStandards.push(kyc);
      usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.insert(msg.sender);
      usersToKYC[_hydroId].passedStandards[membersId - 1].standard = bytes32Standard;
      usersToKYC[_hydroId].passedStandards[membersId - 1].attestersToBlockNumber[msg.sender] = block.number;
      usersToKYC[_hydroId].standardLookup[bytes32Standard] = membersId;
    }
  }

  function removeUserKYC(string _standard, string _hydroId) public {
    require(members.contains(_hydroId));

    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));

    uint membersId = usersToKYC[_hydroId].standardLookup[bytes32Standard];
    usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.remove(msg.sender);
  }

  function getAllStandards() public view returns(bytes32[]) {
    return KYCStandards.members;
  }

  function getPassedStandards(string _hydroId) public view returns(bytes32[]) {
    require(members.contains(_hydroId));

    uint passedStandardsCount = usersToKYC[_hydroId].passedStandards.length;

    bytes32[] memory passedStandards = new bytes32[](passedStandardsCount);
    for (uint i = 0; i < passedStandardsCount; i++) {
        passedStandards[i] = usersToKYC[_hydroId].passedStandards[i].standard;
    }

    return passedStandards;
  }

  function getStandardString(bytes32 _standard) public view returns(string) {
    require(KYCStandards.contains(_standard));

    return KYCStandardsStrings[_standard];
  }

  function getAttestationsToUser(string _standard, string _hydroId) public view returns(address[]) {
    require(members.contains(_hydroId));

    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));
    require(KYCStandards.contains(bytes32Standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_hydroId].standardLookup[bytes32Standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_hydroId].standardLookup[bytes32Standard];
    return usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.members;
  }

  function getAttestationCountToUser(string _standard, string _hydroId) public view returns(uint) {
    require(members.contains(_hydroId));

    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));
    require(KYCStandards.contains(bytes32Standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_hydroId].standardLookup[bytes32Standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_hydroId].standardLookup[bytes32Standard];
    return usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.members.length;
  }

  function getTimeOfAttestation(string _standard, string _hydroId, address _attester) public view returns(uint) {
    require(members.contains(_hydroId));

    bytes32 bytes32Standard = keccak256(abi.encodePacked(_standard));
    require(KYCStandards.contains(bytes32Standard), "This standard does not currently exist in the smart contract.");
    require(usersToKYC[_hydroId].standardLookup[bytes32Standard] > 0, "This standard is not passed by this user.");

    uint membersId = usersToKYC[_hydroId].standardLookup[bytes32Standard];

    require(usersToKYC[_hydroId].passedStandards[membersId - 1].attesters.contains(_attester), "The given address has not attested to this standard.");

    return usersToKYC[_hydroId].passedStandards[membersId - 1].attestersToBlockNumber[_attester];
  }

}
