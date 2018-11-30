pragma solidity ^0.5.0;

import "./zeppelin/ownership/Ownable.sol";

import "./interfaces/SnowflakeViaInterface.sol";

contract SnowflakeVia is Ownable {
    address public snowflakeAddress;

    constructor(address _snowflakeAddress) public {
        setSnowflakeAddress(_snowflakeAddress);
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // this can be overriden to initialize other variables, such as e.g. an ERC20 object to wrap the HYDRO token
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    // all snowflakeCall functions **must** use the senderIsSnowflake modifier, because otherwise there is no guarantee
    // that HYDRO tokens were actually sent to this smart contract prior to the snowflakeCall. Further accounting checks
    // of course make this possible to check, but since this is tedious and a low value-add,
    // it's officially not recommended
    function snowflakeCall(address resolver, uint einFrom, uint einTo, uint amount, bytes memory snowflakeCallBytes)
        public;
    function snowflakeCall(
        address resolver, uint einFrom, address payable to, uint amount, bytes memory snowflakeCallBytes
    ) public;
    function snowflakeCall(address resolver, uint einTo, uint amount, bytes memory snowflakeCallBytes) public;
    function snowflakeCall(address resolver, address payable to, uint amount, bytes memory snowflakeCallBytes) public;
}
