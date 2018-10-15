pragma solidity ^0.4.24;

import "./ClaimHolder.sol";
import "../SnowflakeResolver.sol";

contract Snowflake {
    function getHydroId(address _address) public view returns (string hydroId);
    function getDetails(string hydroId) public view returns (
        address owner,
        address[] resolvers,
        address[] ownedAddresses,
        uint256 balance
    );
}

contract Snowflake725Registry is SnowflakeResolver {

    constructor () public {
        snowflakeName = "Snowflake ERC725 Registry";
        snowflakeDescription = "A registry of ERC725 contracts and their corresponding Snowflake owners";
        callOnSignUp = false;
    }

    mapping(string => address) snowflakeTo725;

    function create725() public returns(address) {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);

        require(snowflakeTo725[hydroId] == address(0), "You already have a 725");

        ClaimHolder claim = new ClaimHolder();
        require(claim.addKey(keccak256(abi.encodePacked(msg.sender)), 1, 1));

        snowflakeTo725[hydroId] = claim;
        return(claim);
    }

    function claim725(address _contract) public returns(bool) {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);
        address[] memory ownedAddresses;
        (,,ownedAddresses,) = snowflake.getDetails(hydroId);

        require(snowflakeTo725[hydroId] == address(0), "You already have a 725");

        ClaimHolder claim =  ClaimHolder(_contract);
        bytes32 key;

        for (uint x = 0; x < ownedAddresses.length; x++) {
            (,,key) = claim.getKey(keccak256(abi.encodePacked(ownedAddresses[x])));
            if (key == keccak256(abi.encodePacked(ownedAddresses[x]))) {
                snowflakeTo725[hydroId] = _contract;
                return true;
            }
        }

        return false;
    }

    function remove725() public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);

        snowflakeTo725[hydroId] = address(0);
    }

    function get725(string _hydroId) public view returns(address) {
        return snowflakeTo725[_hydroId];
    }

}
