pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;
    address public snowflakeAddress;

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }

    function onSignUp(string, uint) public view returns (bool) {
        require(msg.sender == snowflakeAddress);
        return true;
    }
}
