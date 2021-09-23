pragma solidity ^0.5.0;

interface HydroInterface {
    function balances(address) external view returns (uint);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function allowed(address, address) external view returns (uint);
    function transfer(address _to, uint256 _amount) external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool success);
    function balanceOf(address _owner) external view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) external returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData)
        external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function totalSupply() external view returns (uint);
    
    function authenticate(uint _value, uint _challenge, uint _partnerId) external;
    function burn(address _from, uint _value) external returns(uint burnAmount);
   
    function changeMaxBurn(uint256 _newBurn) external returns(uint256);
    function _whiteListDapp(address _dappAddress) external returns(bool);
    function _blackListDapp(address _dappAddress)external returns(bool);
    function setRaindropAddress(address _raindrop) external;
    
}