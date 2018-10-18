pragma solidity ^0.4.23;

import "../zeppelin/ownership/Ownable.sol";

interface ApproveAndCaller {
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) external returns (bool success);
}

interface SnowflakeAddress {
    function hydroTokenAddress() external view returns (address);
}

contract SnowflakeResolver is Ownable {
    string public snowflakeName;
    string public snowflakeDescription;

    address public snowflakeAddress;

    bool public callOnSignUp;
    bool public callOnRemoval;

    constructor(
        string _snowflakeName, string _snowflakeDescription,
        address _snowflakeAddress,
        bool _callOnSignUp, bool _callOnRemoval
    )
        public
    {
        snowflakeName = _snowflakeName;
        snowflakeDescription = _snowflakeDescription;

        snowflakeAddress = _snowflakeAddress;

        callOnSignUp = _callOnSignUp;
        callOnRemoval = _callOnRemoval;
    }

    modifier senderIsSnowflake() {
        require(msg.sender == snowflakeAddress, "Did not originate from Snowflake.");
        _;
    }

    // this can be overriden to initialize other variables, such as an ERC20 object to wrap the HYDRO token
    function setSnowflakeAddress(address _snowflakeAddress) public onlyOwner {
        snowflakeAddress = _snowflakeAddress;
    }

    function depositHydroBalanceTo(uint einTo, uint amount) public onlyOwner {
        // convert einTo to bytes
        bytes32 _bytes32 = bytes32(einTo);
        bytes memory convertedEINTo = new bytes(32);
        for (uint i = 0; i < 32; i++) {convertedEINTo[i] = _bytes32[i];}
        
        ApproveAndCaller hydro = ApproveAndCaller(SnowflakeAddress(snowflakeAddress).hydroTokenAddress());
        require(hydro.approveAndCall(snowflakeAddress, amount, convertedEINTo), "Unsuccessful approveAndCall.");
    }

    // onSignUp is called every time a user sets your contract as a resolver if callOnSignUp is true
    // this function **must** use the senderIsSnowflake modifier
    // returning false will disallow users from setting your contract as a resolver
    // function onSignUp(uint ein, uint allowance) public senderIsSnowflake() returns (bool);

    // onRemoval is called every time a user sets your contract as a resolver if callOnRemoval is true
    // this function **must** use the senderIsSnowflake modifier
    // returning false soft prevents users from removing your contract as a resolver
    // however, they can force remove your resolver, bypassing this function
    // function onRemoval(uint ein) public senderIsSnowflake() returns (bool);
}
