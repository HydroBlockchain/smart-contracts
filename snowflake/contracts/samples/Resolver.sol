pragma solidity ^0.4.24;

import "../SnowflakeResolver.sol";

interface IdentityRegistryInterface {
    function getEIN(address _address) external view returns (uint ein);
}

interface SnowflakeInterface {
    function identityRegistryAddress() external view returns (address);
    function transferSnowflakeBalanceFrom(uint einFrom, uint einTo, uint amount) external;
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) external;
    function transferSnowflakeBalanceFromVia(uint einFrom, address via, uint einTo, uint amount, bytes _bytes) external;
    function withdrawSnowflakeBalanceFromVia(uint einFrom, address via, address to, uint amount, bytes _bytes) external;
}


contract Resolver is SnowflakeResolver {
    SnowflakeInterface private snowflake;
    IdentityRegistryInterface private identityRegistry;

    constructor (address _snowflakeAddress)
        SnowflakeResolver("Sample Resolver", "This is a sample Snowflake resolver.", snowflakeAddress, true, true)
        public
    {
        setSnowflakeAddress(_snowflakeAddress);
    }

    // set the snowflake address, and hydro token + identity registry contract wrappers
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);
        snowflake = SnowflakeInterface(_snowflakeAddress);
        identityRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());
    }

    // implement signup function
    function onSignUp(uint ein, uint allowance) public senderIsSnowflake() returns (bool) {
        require(allowance >= 2000000000000000000, "Must set an allowance of >=2 HYDRO.");
        snowflake.withdrawSnowflakeBalanceFrom(ein, address(this), allowance / 2);
        return true;
    }

    // implement removal function
    function onRemoval(uint, uint allowance) public view senderIsSnowflake() returns (bool) {
        // this is just arbitrary, to test functionality
        if (allowance > 0) {
            return false;
        } else {
            return true;
        }
    }

    // example functions to test *From token functions
    function transferSnowflakeBalanceFrom(uint einTo, uint amount) public {
        snowflake.transferSnowflakeBalanceFrom(identityRegistry.getEIN(msg.sender), einTo, amount);
    }

    function withdrawSnowflakeBalanceFrom(address to, uint amount) public {
        snowflake.withdrawSnowflakeBalanceFrom(identityRegistry.getEIN(msg.sender), to, amount);
    }

    function transferSnowflakeBalanceFromVia(address via, uint einTo, uint amount) public {
        bytes memory _;
        snowflake.transferSnowflakeBalanceFromVia(identityRegistry.getEIN(msg.sender), via, einTo, amount, _);
    }

    function withdrawSnowflakeBalanceFromVia(address via, address to, uint amount) public {
        bytes memory _;
        snowflake.withdrawSnowflakeBalanceFromVia(identityRegistry.getEIN(msg.sender), via, to, amount, _);
    }

    // example functions to test *To token functions
    function _transferHydroBalanceTo(uint einTo, uint amount) public onlyOwner {
        transferHydroBalanceTo(einTo, amount);
    }

    function _withdrawHydroBalanceTo(address to, uint amount) public onlyOwner {
        withdrawHydroBalanceTo(to, amount);
    }

    function _transferHydroBalanceToVia(address via, uint einTo, uint amount) public onlyOwner {
        bytes memory _;
        transferHydroBalanceToVia(via, einTo, amount, _);
    }

    function _withdrawHydroBalanceToVia(address via, address to, uint amount) public onlyOwner {
        bytes memory _;
        withdrawHydroBalanceToVia(via, to, amount, _);
    }
}
