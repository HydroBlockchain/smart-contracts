pragma solidity ^0.5.0;

import "../SnowflakeResolver.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/SnowflakeInterface.sol";


contract Resolver is SnowflakeResolver {
    SnowflakeInterface private snowflake;
    IdentityRegistryInterface private identityRegistry;

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
        identityRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
    }

    // implement signup function
    function onAddition(uint ein, uint allowance, bytes memory) public senderIsSnowflake() returns (bool) {
        require(allowance >= 2000000000000000000, "Must set an allowance of >=2 HYDRO.");
        snowflake.withdrawSnowflakeBalanceFrom(ein, address(this), allowance / 2);
        return true;
    }

    // implement removal function
    function onRemoval(uint, bytes memory) public senderIsSnowflake() returns (bool) {}

    // example functions to test *From token functions
    function transferSnowflakeBalanceFrom(uint einTo, uint amount) public {
        snowflake.transferSnowflakeBalanceFrom(identityRegistry.getEIN(msg.sender), einTo, amount);
    }

    function withdrawSnowflakeBalanceFrom(address to, uint amount) public {
        snowflake.withdrawSnowflakeBalanceFrom(identityRegistry.getEIN(msg.sender), to, amount);
    }

    function transferSnowflakeBalanceFromVia(address via, uint einTo, uint amount) public {
        snowflake.transferSnowflakeBalanceFromVia(identityRegistry.getEIN(msg.sender), via, einTo, amount, hex"");
    }

    function withdrawSnowflakeBalanceFromVia(address via, address to, uint amount) public {
        snowflake.withdrawSnowflakeBalanceFromVia(identityRegistry.getEIN(msg.sender), via, to, amount, hex"");
    }

    // example functions to test *To token functions
    function _transferHydroBalanceTo(uint einTo, uint amount) public onlyOwner {
        transferHydroBalanceTo(einTo, amount);
    }

    function _withdrawHydroBalanceTo(address to, uint amount) public onlyOwner {
        withdrawHydroBalanceTo(to, amount);
    }

    function _transferHydroBalanceToVia(address via, uint einTo, uint amount) public onlyOwner {
        transferHydroBalanceToVia(via, einTo, amount, hex"");
    }

    function _withdrawHydroBalanceToVia(address via, address to, uint amount) public onlyOwner {
        withdrawHydroBalanceToVia(via, to, amount, hex"");
    }
}
