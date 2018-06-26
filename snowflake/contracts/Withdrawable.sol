pragma solidity ^0.4.23;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20.sol";


contract Withdrawable is Ownable {
    // Allows owner to withdraw ether from the contract
    function withdrawEther(address to) public onlyOwner {
        to.transfer(address(this).balance);
    }

    // Allows owner to withdraw ERC20 tokens from the contract
    function withdrawERC20Token(address tokenAddress, address to) public onlyOwner {
        ERC20 token = ERC20(tokenAddress);
        token.transfer(to, token.balanceOf(address(this)));
    }
}
