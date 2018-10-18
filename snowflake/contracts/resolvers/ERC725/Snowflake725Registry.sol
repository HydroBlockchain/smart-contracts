pragma solidity ^0.4.24;

import "./ClaimHolder.sol";
import "../../SnowflakeResolver.sol";

contract IdentityRegistry {
    function getEIN(address _address) public view returns (uint ein);
    function getDetails(uint ein) public view
        returns (address recoveryAddress, address[] associatedAddresses, address[] providers, address[] resolvers);
}

contract Snowflake725Registry is SnowflakeResolver {

    IdentityRegistry registry;

    constructor (address _identityRegistryAddress) public {
        snowflakeName = "Snowflake ERC725 Registry";
        snowflakeDescription = "A registry of ERC725 contracts and their corresponding Snowflake owners";
        callOnSignUp = false;
        registry = IdentityRegistry(_identityRegistryAddress);
    }

    mapping(uint => address) einTo725;

    function create725() public returns(address) {
        uint ein = registry.getEIN(msg.sender);

        require(einTo725[ein] == address(0), "You already have a 725");

        ClaimHolder claim = new ClaimHolder();
        require(claim.addKey(keccak256(abi.encodePacked(msg.sender)), 1, 1), "Key not added.");

        einTo725[ein] = claim;
        return(claim);
    }

    function claim725(address _contract) public returns(bool) {
        uint ein = registry.getEIN(msg.sender);

        address[] memory ownedAddresses;
        (,ownedAddresses,,) = registry.getDetails(ein);

        require(einTo725[ein] == address(0), "You already have a 725");

        ClaimHolder claim = ClaimHolder(_contract);
        bytes32 key;

        for (uint x = 0; x < ownedAddresses.length; x++) {
            (,,key) = claim.getKey(keccak256(abi.encodePacked(ownedAddresses[x])));
            if (key == keccak256(abi.encodePacked(ownedAddresses[x]))) {
                einTo725[ein] = _contract;
                return true;
            }
        }

        return false;
    }

    function remove725() public {
        uint ein = registry.getEIN(msg.sender);

        einTo725[ein] = address(0);
    }

    function get725(uint _ein) public view returns(address) {
        return einTo725[_ein];
    }

}
