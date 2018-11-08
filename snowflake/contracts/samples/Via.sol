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

contract Via is SnowflakeVia {
    SnowflakeInterface private snowflake;
    ERC20 private hydroToken;

    constructor (address _snowflakeAddress) SnowflakeVia(_snowflakeAddress) public {
        setSnowflakeAddress(_snowflakeAddress);
    }

    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner() {
        super.setSnowflakeAddress(_snowflakeAddress);

        snowflake = SnowflakeInterface(_snowflakeAddress);
        hydroToken = ERC20(snowflake.hydroTokenAddress());
    }

    // this contract is responsible for funding itself with ETH, and must be entrusted to do so
    function fund() public payable {}

    // EIN -> ETH balances
    mapping (uint => uint) public balances;

    // a dummy exchange rate between HYDRO and ETH s.t. 10 HYDRO := 1 ETH for testing purposes
    uint exchangeRate = 10;
    function convertHydroToEth(uint amount) public view returns (uint) {
        return amount / exchangeRate; // UNSAFE, please don't do this except when testing :)
    }

    // end recipient is an EIN, credit their (ETH) balance
    function snowflakeCall(address, uint, uint einTo, uint amount, bytes) public senderIsSnowflake() {
        creditEIN(einTo, amount);
    }

    function snowflakeCall(address, uint einTo, uint amount, bytes) public senderIsSnowflake() {
        creditEIN(einTo, amount);
    }

    function creditEIN(uint einTo, uint amount) private {
        balances[einTo] += convertHydroToEth(amount); // UNSAFE, please use SafeMath when not testing :)
    }

    // end recipient is an address, send them ETH
    function snowflakeCall(address, uint, address to, uint amount, bytes) public senderIsSnowflake() {
        creditAddress(to, amount);
    }

    function snowflakeCall(address, address to, uint amount, bytes) public senderIsSnowflake() {
        creditAddress(to, amount);
    }

    function creditAddress(address to, uint amount) private {
        to.transfer(convertHydroToEth(amount)); // UNSAFE, please use SafeMath when not testing :)
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
