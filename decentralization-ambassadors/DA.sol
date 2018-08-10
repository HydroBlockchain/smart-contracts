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

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

library addressSet {
    struct _addressSet {
        address[] members;
        mapping(address => uint) memberIndices;
    }

    function insert(_addressSet storage self, address other) public {
        if (!contains(self, other)) {
            assert(length(self) < 2**256-1);
            self.members.push(other);
            self.memberIndices[other] = length(self);
        }
    }

    function remove(_addressSet storage self, address other) public {
        if (contains(self, other)) {
            uint replaceIndex = self.memberIndices[other];
            address lastMember = self.members[length(self)-1];
            // overwrite other with the last member and remove last member
            self.members[replaceIndex-1] = lastMember;
            self.members.length--;
            // reflect this change in the indices
            self.memberIndices[lastMember] = replaceIndex;
            delete self.memberIndices[other];
        }
    }

    function contains(_addressSet storage self, address other) public view returns (bool) {
        return self.memberIndices[other] > 0;
    }

    function length(_addressSet storage self) public view returns (uint) {
        return self.members.length;
    }
}

interface Voting {
    function initiateNomination(address _nominee) external returns (bool);
    function initiateRemoval(address _ambassador) external returns (bool);
}

interface HydroToken {
    function transfer(address _to, uint256 _amount) external returns (bool);
    function balanceOf(address _owner) external view returns (uint);
}

contract DecentralizationAmbassadors is Ownable {
    using SafeMath for uint;
    using addressSet for addressSet._addressSet;

    addressSet._addressSet internal ambassadors;
    addressSet._addressSet internal nominees;
    mapping(address => uint) internal lastPayout;
    uint payoutBlockNumber = 180000;
    uint payoutHydroAmount = 222222000000000000000000;

    address hydroAddress = 0xEBBdf302c940c6bfd49C6b165f457fdb324649bc;
    address votingAddress;

    function setVotingAddress(address _address) public onlyOwner {
        votingAddress = _address;
    }

    modifier onlyDA() {
        require(ambassadors.contains(msg.sender));
        _;
    }

    function nominateAmbassador(address _ambassador) public {
        require(!nominees.contains(_ambassador));
        nominees.insert(_ambassador);

        Voting voting = Voting(votingAddress);
        voting.initiateNomination(_ambassador);

        emit InitiateNomination(_ambassador);
    }

    function finalizeNominationVoting(bool _decision, address _ambassador) public {
        require(msg.sender == votingAddress);
        if (_decision) {
          ambassadors.insert(_ambassador);
          emit FinalizeNomination(_ambassador);
        }
    }

    function ownerAddAmbassador(address _ambassador) public onlyOwner {
        require(ambassadors.members.length < 10);
        ambassadors.insert(_ambassador);

        emit FinalizeNomination(_ambassador);
    }

    function initiateAmbassadorRemoval(address _ambassador) public {
        require(ambassadors.contains(_ambassador));

        Voting voting = Voting(votingAddress);
        voting.initiateRemoval(_ambassador);

        emit InitiateRemoval(msg.sender);
    }

    function finalizeRemovalVoting(bool _decision, address _ambassador) public {
        require(msg.sender == votingAddress);
        if (_decision) {
          ambassadors.remove(_ambassador);
          emit FinalizeRemoval(_ambassador);
        }
    }

    function selfRemoval() public onlyDA {
        ambassadors.remove(msg.sender);
        emit FinalizeRemoval(msg.sender);
    }

    function recieveHydro() public onlyDA {
        HydroToken hydro = HydroToken(hydroAddress);

        require(hydro.balanceOf(this)  >= payoutHydroAmount);
        uint daLastPayoutBlock = lastPayout[msg.sender];

        if (daLastPayoutBlock + payoutBlockNumber < block.number){
            if (hydro.transfer(msg.sender, payoutHydroAmount)) {
                lastPayout[msg.sender] = daLastPayoutBlock + payoutBlockNumber;
                emit Payout(msg.sender, payoutHydroAmount);
            }
        }
    }

    event InitiateNomination(address _nominee);
    event FinalizeNomination(address _nominee);
    event InitiateRemoval(address _ambassador);
    event FinalizeRemoval(address _ambassador);
    event Payout(address _ambassador, uint _amount);

}
