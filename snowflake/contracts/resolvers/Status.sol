pragma solidity ^0.4.24;

import "../SnowflakeResolver.sol";


interface Snowflake {
    function identityRegistryAddress() external view returns (address);
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) external;
}

interface IdentityRegistry {
    function getEIN(address _address) external view returns (uint ein);
}

contract Status is SnowflakeResolver {
    mapping (uint => string) private statuses;

    uint signUpFee = 1000000000000000000;
    string firstStatus = "My first status 😎";

    constructor (address snowflakeAddress)
        SnowflakeResolver("Status", "Set your status.", snowflakeAddress, true, false) public
    {}

    // implement signup function
    function onSignUp(uint ein, uint allowance) public senderIsSnowflake() returns (bool) {
        require(allowance >= signUpFee, "Must set an allowance of at least 1 HYDRO.");
        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.withdrawSnowflakeBalanceFrom(ein, owner(), signUpFee);
        statuses[ein] = firstStatus;
        emit StatusUpdated(ein, firstStatus);
        return true;
    }

    function getStatus(uint ein) public view returns (string) {
        return statuses[ein];
    }

    // example function that calls withdraw on a linked hydroID
    function setStatus(string status) public {
        uint ein = IdentityRegistry(Snowflake(snowflakeAddress).identityRegistryAddress()).getEIN(msg.sender);
        statuses[ein] = status;
        emit StatusUpdated(ein, status);
    }

    event StatusUpdated(uint ein, string status);
}
