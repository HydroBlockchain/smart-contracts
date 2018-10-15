pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";


interface Snowflake {
    function whitelistResolver(address resolver) external;
    function withdrawSnowflakeBalanceFrom(string hydroIdFrom, address to, uint amount) external;
    function getHydroId(address _address) external returns (string hydroId);
}


contract Status is SnowflakeResolver {
    mapping (string => string) internal statuses;

    uint signUpFee = 1000000000000000000;
    string firstStatus = "My first status 😎";

    constructor (address snowflakeAddress) public {
        snowflakeName = "Status";
        snowflakeDescription = "Set your status.";
        setSnowflakeAddress(snowflakeAddress);

        callOnSignUp = true;

        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.whitelistResolver(address(this));
    }

    // implement signup function
    function onSignUp(string hydroId, uint allowance) public senderIsSnowflake() returns (bool) {
        require(allowance >= signUpFee, "Must set an allowance of at least 1 HYDRO.");
        Snowflake snowflake = Snowflake(snowflakeAddress);
        snowflake.withdrawSnowflakeBalanceFrom(hydroId, owner, signUpFee);
        statuses[hydroId] = firstStatus;
        emit StatusUpdated(hydroId, firstStatus);
        return true;
    }

    function getStatus(string hydroId) public view returns (string) {
        return statuses[hydroId];
    }

    // example function that calls withdraw on a linked hydroID
    function setStatus(string status) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);
        statuses[hydroId] = status;
        emit StatusUpdated(hydroId, status);
    }

    event StatusUpdated(string hydroId, string status);
}
