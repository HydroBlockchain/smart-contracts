pragma solidity ^0.5.0;

interface ClientRaindropInterface {
    function hydroStakeUser() external returns (uint);
    function hydroStakeDelegatedUser() external returns (uint);

    function setSnowflakeAddress(address _snowflakeAddress) external;
    function setStakes(uint _hydroStakeUser, uint _hydroStakeDelegatedUser) external;

    function signUp(address _address, string calldata casedHydroId) external;

    function hydroIDAvailable(string calldata uncasedHydroID) external view returns (bool available);
    function hydroIDDestroyed(string calldata uncasedHydroID) external view returns (bool destroyed);
    function hydroIDActive(string calldata uncasedHydroID) external view returns (bool active);

    function getDetails(string calldata uncasedHydroID) external view
        returns (uint ein, address _address, string memory casedHydroID);
    function getDetails(uint ein) external view returns (address _address, string memory casedHydroID);
    function getDetails(address _address) external view returns (uint ein, string memory casedHydroID);
}
