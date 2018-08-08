pragma solidity ^0.4.24;

/**
* @title Ownable
* @dev The Ownable contract has an owner address, and provides basic authorization control
* functions, this simplifies the implementation of "user permissions".
*/
contract Ownable {
    address public owner;


    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    /**
    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
    * account.
    */
    constructor() public {
        owner = msg.sender;
    }

    /**
    * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}

interface DecentralizationAmbassadors {
    function finalizeNominationVoting(bool _decision, address _ambassador) external;
    function finalizeRemovalVoting(bool _decision, address _ambassador) external;
}

contract Voting is Ownable {
    address daAddress;

    function setDaAddress(address _address) public onlyOwner {
        daAddress = _address;
    }

    function initiateNomination(address _ambassador) public {
        require(msg.sender == daAddress);
    }

    function finalizeNomination(bool _decision, address _ambassador) public onlyOwner {
        DecentralizationAmbassadors da = DecentralizationAmbassadors(daAddress);
        da.finalizeNominationVoting(_decision, _ambassador);
    }

    function initiateRemoval(address _ambassador) public {
        require(msg.sender == daAddress);
    }

    function finalizeRemoval(bool _decision, address _ambassador) public {
        DecentralizationAmbassadors da = DecentralizationAmbassadors(daAddress);
        da.finalizeRemovalVoting(_decision, _ambassador);
    }

}
