pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";

contract ViaContract {
    function snowflakeCall(address resolver, uint einFrom, uint einTo, uint amount, bytes memory _bytes) public;
    function snowflakeCall(address resolver, uint einFrom, address to, uint amount, bytes memory _bytes) public;
}

contract SnowflakeVia is Ownable, ViaContract {
    address public snowflakeAddress;

    constructor(address _snowflakeAddress) public {
        setSnowflakeAddress(_snowflakeAddress);
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // it's not *strictly* required that snowflakeCall use the senderIsSnowflake modifier, but it's *highly recommended*
    // because otherwise there is no guarantee that HYDRO tokens were actually sent to this smart contract
    // prior to the snowflakeCall, and further accounting checks are required. since this is tedious and a low
    // value-add, all contracts are officially recommended to use the senderIsSnowflake modifier
}
