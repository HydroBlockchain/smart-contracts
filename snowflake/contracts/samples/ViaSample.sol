pragma solidity ^0.4.24;

import "../SnowflakeVia.sol";

interface ERC20 {
    function balanceOf(address who) external returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface SnowflakeInterface {
    function hydroTokenAddress() external view returns (address);
    function getEIN(address _address) external view returns (uint ein);
}

contract ViaSample is SnowflakeVia {
    SnowflakeInterface private snowflake;
    ERC20 private hydroToken;

    constructor (address snowflakeAddress) SnowflakeVia(snowflakeAddress) public {
        setSnowflakeAddress(snowflakeAddress);
    }

    function setSnowflakeAddress(address snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(snowflakeAddress);

        snowflake = SnowflakeInterface(snowflakeAddress);
        hydroToken = ERC20(snowflake.hydroTokenAddress());
    }

    // this contract is responsible for funding itself with ETH
    function fund() public payable {}

    mapping (uint => uint) balances;

    // a dummy exchange rate between HYDRO and ETH s.t. 10 HYDRO := 1 ETH for testing purposes
    uint exchangeRate = 10;

    function convertHydroToEth(uint amount) public view returns (uint) {
        return amount / exchangeRate; // UNSAFE, please don't do this except when testing :)
    }

    // receive tokens, convert to ETH, then add to the hydroId's balance
    function snowflakeCall(address, uint, uint einTo, uint amount, bytes) public senderIsSnowflake() {
        balances[einTo] += convertHydroToEth(amount); // UNSAFE, please use SafeMath when not testing :)
    }

    // receive tokens, convert to ETH, then send to the 'to' address at the current HYDRO exchange rate
    function snowflakeCall(address, uint, address to, uint amount, bytes) public senderIsSnowflake() {
        to.transfer(convertHydroToEth(amount));
    }

    // allows hydroIds with balances to withdraw their accumulated eth balance to an address
    function withdrawTo(address to) public {
        to.transfer(balances[snowflake.getEIN(msg.sender)]);
    }

    // allows the owner to withdraw the contract's accumulated hydro balance to an address
    function withdrawHydroTo(address to) public onlyOwner() {
        require(hydroToken.transfer(to, hydroToken.balanceOf(address(this))), "Transfer was unsuccessful");
    }
}
