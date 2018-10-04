pragma solidity ^0.4.24;

import "../resolvers/SnowflakeResolver.sol";


interface Snowflake {
    function whitelistResolver(address resolver) external;
    function transferSnowflakeBalanceFrom(string hydroIdFrom, string hydroIdTo, uint amount) external;
    function withdrawSnowflakeBalanceFrom(string hydroIdFrom, address to, uint amount) external;
    function withdrawSnowflakeBalanceFromVia(
        string hydroIdFrom, address via, string hydroIdTo, uint amount, bytes _bytes
    ) external;
    function withdrawSnowflakeBalanceFromVia(
        string hydroIdFrom, address via, address to, uint amount, bytes _bytes
    ) external;
}


contract TestingResolver is SnowflakeResolver {
    mapping (string => bool) internal signedUp;

    constructor (address snowflakeAddress) public {
        snowflakeName = "Testing Resolver";
        snowflakeDescription = "This is an example Snowflake resolver.";
        setSnowflakeAddress(snowflakeAddress);

        callOnSignUp = true;
        callOnRemoval = true;

        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.whitelistResolver(address(this));
    }

    // implement signup function
    function onSignUp(string hydroId, uint allowance) public returns (bool) {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        require(allowance > 0, "Must set an allowance."); // obviously useless without a corresponding withdrawal!
        signedUp[hydroId] = true;
        return true;
    }

    // implement removal function
    function onRemoval(string hydroId, uint allowance) public returns (bool) {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        signedUp[hydroId] = false;
        // this is just arbitrary, to test functionality
        if (allowance > 0) {
            return false;
        } else {
            return true;
        }
    }

    // example functions to test *From token functions
    function transferSnowflakeBalanceFrom(string hydroIdFrom, string hydroIdTo, uint amount) public onlyOwner {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.transferSnowflakeBalanceFrom(hydroIdFrom, hydroIdTo, amount);
    }

    function withdrawSnowflakeBalanceFrom(string hydroIdFrom, address to, uint amount) public onlyOwner {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.withdrawSnowflakeBalanceFrom(hydroIdFrom, to, amount);
    } 

    function withdrawSnowflakeBalanceFromVia(string hydroIdFrom, address via, string hydroIdTo, uint amount)
        public onlyOwner
    {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        bytes memory _;
        snowflake.withdrawSnowflakeBalanceFromVia(hydroIdFrom, via, hydroIdTo, amount, _);
    }

    function withdrawSnowflakeBalanceFromVia(string hydroIdFrom, address via, address to, uint amount)
        public onlyOwner
    {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        bytes memory _;
        snowflake.withdrawSnowflakeBalanceFromVia(hydroIdFrom, via, to, amount, _);
    }
}
