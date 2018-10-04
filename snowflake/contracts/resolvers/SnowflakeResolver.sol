pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;
    address public snowflakeAddress;

    bool public callOnSignUp;
    bool public callOnRemoval;

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // onSignUp is called every time a user sets your contract as a resolver if callOnSignUp is true
    // this function **must** use the senderIsSnowflake modifier
    // returning false will disallow users from setting your contract as a resolver
    // function onSignUp(string hydroId, uint allowance) public returns (bool);

    // onRemoval is called every time a user sets your contract as a resolver if callOnRemoval is true
    // this function **must** use the senderIsSnowflake modifier
    // returning false soft prevents users from removing your contract as a resolver
    // however, they can force remove your resolver, bypassing this function
    // function onRemoval(string hydroId, uint allowance) public returns (bool);
}
