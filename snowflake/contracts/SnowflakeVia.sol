pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";

contract ViaContract {
    function snowflakeCall(address resolver, uint einFrom, uint einTo, uint amount, bytes _bytes) public;
    function snowflakeCall(address resolver, uint einFrom, address to, uint amount, bytes _bytes) public;
    function snowflakeCall(address resolver, uint einTo, uint amount, bytes _bytes) public;
    function snowflakeCall(address resolver, address to, uint amount, bytes _bytes) public;
}

contract SnowflakeVia is Ownable, ViaContract {
    address public snowflakeAddress;

    constructor(address _snowflakeAddress) public {
        setSnowflakeAddress(_snowflakeAddress);
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    // it's *strictly* required that snowflakeCalls use the senderIsSnowflake modifier, because otherwise there is no
    // guarantee that HYDRO tokens were actually sent to this smart contract prior to the snowflakeCall.
    // further accounting checks of course make this possible to check, but since this is tedious and a low
    // value-add, it's offially not recommended
}
