pragma solidity ^0.4.24;

import "../SnowflakeResolver.sol";


interface SnowflakeInterface {
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


contract ResolverSample is SnowflakeResolver {
    SnowflakeInterface private snowflake;

    mapping (string => bool) internal signedUp;

    constructor (address snowflakeAddress) 
        SnowflakeResolver("Sample Resolver", "This is a sample Snowflake resolver.", snowflakeAddress, true, true)
        public
    {
        setSnowflakeAddress(snowflakeAddress);
    }

    // set the snowflake address, and hydro token + identity registry contract wrappers
    function setSnowflakeAddress(address snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(snowflakeAddress);
        snowflake = SnowflakeInterface(snowflakeAddress);
    }

    // implement signup function
    function onSignUp(string hydroId, uint allowance) public senderIsSnowflake() returns (bool) {
        require(allowance > 0, "Must set an allowance."); // obviously useless without a corresponding withdrawal!
        return signedUp[hydroId] = true;
    }

    // implement removal function
    function onRemoval(string hydroId, uint allowance) public senderIsSnowflake() returns (bool) {
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
        snowflake.transferSnowflakeBalanceFrom(hydroIdFrom, hydroIdTo, amount);
    }

    function withdrawSnowflakeBalanceFrom(string hydroIdFrom, address to, uint amount) public onlyOwner {
        snowflake.withdrawSnowflakeBalanceFrom(hydroIdFrom, to, amount);
    } 

    function withdrawSnowflakeBalanceFromVia(string hydroIdFrom, address via, string hydroIdTo, uint amount)
        public onlyOwner
    {
        bytes memory _;
        snowflake.withdrawSnowflakeBalanceFromVia(hydroIdFrom, via, hydroIdTo, amount, _);
    }

    function withdrawSnowflakeBalanceFromVia(string hydroIdFrom, address via, address to, uint amount)
        public onlyOwner
    {
        bytes memory _;
        snowflake.withdrawSnowflakeBalanceFromVia(hydroIdFrom, via, to, amount, _);
    }
}
