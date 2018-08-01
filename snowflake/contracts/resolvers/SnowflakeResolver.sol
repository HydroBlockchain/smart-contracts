pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;
    address public snowflakeAddress;

    function setSnowflakeAddress(address _address) public onlyOwner {
        snowflakeAddress = _address;
    }

    // function called every time a user sets your contract as a resolver
    // it's *highly* recommended that this function include:
    // require(msg.sender == snowflakeAddress);
    // returning false will disallow users from setting your contract as a resolver
    function onSignUp(string hydroId, uint allowance) public returns (bool);
}
