pragma solidity ^0.5.0;

import "../SnowflakeResolver.sol";
import "../interfaces/SnowflakeInterface.sol";
import "../zeppelin/math/SafeMath.sol";
import "../interfaces/IdentityRegistryInterface.sol";

contract SnowflakeSnippets is SnowflakeResolver {
    //Revision history
    //v1.0: basic features

    using SafeMath for uint;
    
    //Owner Fields
    struct User{
        uint ein; //PK
  
    }
 
 
    //one hydro is represented as 1000000000000000000
    uint private signUpFee = uint(1).mul(10**18);

    //users registry by ein
    mapping (uint => User) private users;
    

    constructor (address snowflakeAddress)
        SnowflakeResolver("Snowflake snippets v1", "Basic solidity code examples", snowflakeAddress, true, false) public
    {  
        
        
    }
    
       // implement signup function
    function onAddition(uint ein, uint, bytes memory ) 
    public 
    senderIsSnowflake() 
    returns (bool) {
        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
        snowflake.withdrawSnowflakeBalanceFrom(ein, owner(), signUpFee);
      
       users[ein].ein = ein;
     
        return true;
    }
     
    function onRemoval(uint, bytes memory) 
    public 
    senderIsSnowflake() returns (bool) {
       
         return true;
    }

     // move funds from snowflake balance to contract balance
    function doScrow(uint _snowflakeId, uint _totalHydro)
    public{
        SnowflakeInterface snowflake = SnowflakeInterface(snowflakeAddress);
          
        //1.preconditions for escrow
        require(snowflake.resolverAllowances(_snowflakeId,address(this)) >= _totalHydro.mul(10**18),"Users's allowance must be equal or greater than totalHydro");
        require(snowflake.deposits(_snowflakeId) >= _totalHydro.mul(10**18),"User's funds must be equal or greater than totalHydro");
            
        //2.escrow reward from snowflake to resolver
        snowflake.withdrawSnowflakeBalanceFrom(_snowflakeId, address(this), _totalHydro.mul(10**18));
        
    } 
    
    // move funds from contract balance to snowflake balance
    function doReward(uint _snowflakeId, uint _totalHydro)
    public{
         //1. preconditions for transfer
         require(address(this).balance >= _totalHydro.mul(10**18),"User's funds must be equal or greater than totalHydro");
      
         //2. make the transfer
         transferHydroBalanceTo(_snowflakeId,_totalHydro.mul(10**18));
    }
  
 
  
}
