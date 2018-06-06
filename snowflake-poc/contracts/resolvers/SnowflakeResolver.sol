pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";


contract SnowflakeResolver is Ownable {
    string snowflakeName;
    string snowflakeDescription;
    address snowflakeAddress;

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }
}
