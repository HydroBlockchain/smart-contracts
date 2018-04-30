pragma solidity ^0.4.21;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20Basic.sol";

contract SnowflakeEscrow is Ownable {

  struct escrow{
    address application;
    address user;
    address relayer;
    address validator;
    uint deposit;
    bool completed;
  }

  address hydroAddress = 0x0;
  address snowflakeAddress = 0x0;
  uint balance;

  uint userPercent = 0;

  function setUserPercent(uint _percent) public onlyOwner {
    userPercent = _percent;
  }

  uint relayerPercent = 0;

  function setRelayerPercent(uint _percent) public onlyOwner {
    relayerPercent = _percent;
  }

  uint validatorPercent = 0;

  function setValidatorPercent(uint _percent) public onlyOwner {
    validatorPercent = _percent;
  }

  modifier onlySnowflake() {
    require(msg.sender == snowflakeAddress);
    _;
  }

  escrow[] public escrowList;

  function setSnowflakeAddress(address _address) public onlyOwner {
    snowflakeAddress = _address;
  }

  function setHydroAddress(address _address) public onlyOwner {
    hydroAddress = _address;
  }

  function initiateEscrow(address _application, address _user, address _relayer, address _validator, uint _amount) public onlySnowflake returns(uint escrowId){
    escrowId = escrowList.push(escrow(_application, _user, _relayer, _validator, _amount, false)) - 1;
    balance += _amount;
    emit EscrowCreated(escrowId, _application, _user, _amount);
  }

  function closeEscrow(uint _escrowId) public onlySnowflake {
    require(balance >= escrowList[_escrowId].deposit);
    ERC20Basic hydro = ERC20Basic(hydroAddress);

    uint userAmount = (escrowList[_escrowId].deposit * userPercent)/100;
    uint relayerAmount = (escrowList[_escrowId].deposit * relayerPercent)/100;
    uint validatorAmount = (escrowList[_escrowId].deposit * validatorPercent)/100;
    uint applicationAmount = escrowList[_escrowId].deposit - userAmount - relayerAmount - validatorAmount;

    hydro.transfer(escrowList[_escrowId].user, userAmount);
    hydro.transfer(escrowList[_escrowId].relayer, relayerAmount);
    hydro.transfer(escrowList[_escrowId].validator, validatorAmount);
    hydro.transfer(escrowList[_escrowId].application, applicationAmount);

    emit EscrowClosed(_escrowId, escrowList[_escrowId].application, escrowList[_escrowId].user, escrowList[_escrowId].deposit);
  }

  function cancelEscrow(uint _escrowId) public onlySnowflake {
    require(balance >= escrowList[_escrowId].deposit);

    ERC20Basic hydro = ERC20Basic(hydroAddress);
    hydro.transfer(escrowList[_escrowId].application, escrowList[_escrowId].deposit);

    emit EscrowCanceled(_escrowId, escrowList[_escrowId].application, escrowList[_escrowId].user, escrowList[_escrowId].deposit);
  }

  event EscrowCreated(uint id, address application, address user, uint amount);
  event EscrowClosed(uint id, address application, address user, uint amount);
  event EscrowCanceled(uint id, address application, address user, uint amount);

}
