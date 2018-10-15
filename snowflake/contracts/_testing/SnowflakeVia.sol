pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";

contract ViaContract {
    function snowflakeCall(address resolver, string hydroIdFrom, string hydroIdTo, uint amount, bytes _bytes) public;
    function snowflakeCall(address resolver, string hydroIdFrom, address to, uint amount, bytes _bytes) public;
}

contract SnowflakeVia is Ownable, ViaContract {
    address public snowflakeAddress;
    address public hydroTokenAddress;

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }

    function setHydroTokenAddress(address _address) public onlyOwner {
        hydroTokenAddress = _address;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // it's not *strictly* required that snowflakeCall use the senderIsSnowflake modifier, but it's *highly recommended*
    // because otherwise there is no guarantee that HYDRO tokens were actually sent to this smart contract
    // prior to the snowflakeCall, and further accounting checks are required. since this is tedious and a low
    // value-add, all contracts are officialy recommended to use the senderIsSnowflake modifier
}
