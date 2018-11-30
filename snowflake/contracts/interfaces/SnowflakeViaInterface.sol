pragma solidity ^0.5.0;

interface SnowflakeViaInterface {
    function snowflakeCall(address resolver, uint einFrom, uint einTo, uint amount, bytes calldata snowflakeCallBytes)
        external;
    function snowflakeCall(
        address resolver, uint einFrom, address payable to, uint amount, bytes calldata snowflakeCallBytes
    ) external;
    function snowflakeCall(address resolver, uint einTo, uint amount, bytes calldata snowflakeCallBytes) external;
    function snowflakeCall(address resolver, address payable to, uint amount, bytes calldata snowflakeCallBytes)
        external;
}
