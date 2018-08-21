pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";


contract Snowflake {
    function withdrawFrom(string hydroIdFrom, address to, uint amount) public returns (bool);
}


contract DummyResolver is SnowflakeResolver {
    mapping (string => bool) internal signedUp;

    constructor () public {
        snowflakeName = "Dummy Resolver";
        snowflakeDescription = "This is an example Snowflake resolver.";
        callOnSignUp = true;
    }

    // implement signup function
    function onSignUp(string hydroId, uint allowance) public returns (bool) {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        require(allowance > 0, "Must set an allowance.");
        signedUp[hydroId] = true;
        return true;
    }

    // example function that calls withdraw on a linked hydroID
    function withdrawFrom(string hydroId, uint amount) public onlyOwner {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        require(snowflake.withdrawFrom(hydroId, owner, amount), "Amount was not withdrawn.");
    }
}
