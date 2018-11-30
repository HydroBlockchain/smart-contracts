pragma solidity ^0.5.0;

import "../SnowflakeResolver.sol";
import "../interfaces/IdentityRegistryInterface.sol";
import "../interfaces/HydroInterface.sol";
import "../interfaces/SnowflakeInterface.sol";

contract Status is SnowflakeResolver {
    mapping (uint => string) private statuses;

    uint signUpFee = 1000000000000000000;
    string firstStatus = "My first status 😎";

    constructor (address snowflakeAddress)
        SnowflakeResolver("Status", "Set your status.", snowflakeAddress, true, false) public
    {}

    // implement signup function
    function onAddition(uint ein, uint, bytes memory) public senderIsSnowflake() returns (bool) {
        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
        snowflake.withdrawSnowflakeBalanceFrom(ein, owner(), signUpFee);

        statuses[ein] = firstStatus;

        emit StatusSignUp(ein);

        return true;
    }

    function onRemoval(uint, bytes memory) public senderIsSnowflake() returns (bool) {}

    function getStatus(uint ein) public view returns (string memory) {
        return statuses[ein];
    }

    function setStatus(string memory status) public {
        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
        IdentityRegistryInterface identityRegistry = IdentityRegistryInterface(snowflake.identityRegistryAddress());

        uint ein = identityRegistry.getEIN(msg.sender);
        require(identityRegistry.isResolverFor(ein, address(this)), "The EIN has not set this resolver.");

        statuses[ein] = status;

        emit StatusUpdated(ein, status);
    }

    function withdrawFees(address to) public onlyOwner() {
        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
        HydroInterface hydro = HydroInterface(snowflake.hydroTokenAddress());
        withdrawHydroBalanceTo(to, hydro.balanceOf(address(this)));
    }

    event StatusSignUp(uint ein);
    event StatusUpdated(uint ein, string status);
}
