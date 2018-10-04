pragma solidity ^0.4.24;

import "./SnowflakeVia.sol";

interface ERC20 {
    function balanceOf(address who) external returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface Snowflake {
    function whitelistResolver(address resolver) external;
    function getHydroId(address _address) external returns (string hydroId);
}

contract TestingVia is SnowflakeVia {
    constructor (address snowflakeAddress, address hydroTokenAddress) public {
        setSnowflakeAddress(snowflakeAddress);
        setHydroTokenAddress(hydroTokenAddress);
    }

    // this contract is responsible for funding itself with ETH
    function fund() public payable {}

    mapping (string => uint) balances;

    // a dummy exchange rate between HYDRO and ETH s.t. 10 HYDRO := 1 ETH for testing purposes
    uint exchangeRate = 10;

    function convertHydroToEth(uint amount) public view returns (uint) {
        return amount / exchangeRate; // UNSAFE, please don't do this except when testing :)
    }

    // receive tokens, convert to ETH, then add to the hydroId's balance
    function snowflakeCall(address, string, string hydroIdTo, uint amount, bytes)
        public senderIsSnowflake()
    {
        balances[hydroIdTo] += convertHydroToEth(amount); // UNSAFE, please use SafeMath when not testing :)
    }

    // receive tokens, convert to ETH, then send to the 'to' address at the current HYDRO exchange rate
    function snowflakeCall(address, string, address to, uint amount, bytes)
        public senderIsSnowflake()
    {
        to.transfer(convertHydroToEth(amount));
    }

    // allows hydroIds with balances to withdraw their accumulated eth balance to an address
    function withdrawTo(address to) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        to.transfer(balances[snowflake.getHydroId(msg.sender)]);
    }

    // allows the owner to withdraw the contract's accumulated hydro balance to an address
    function withdrawHydroTo(address to) public onlyOwner {
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(hydro.transfer(to, hydro.balanceOf(address(this))), "Transfer was unsuccessful");
    }
}
