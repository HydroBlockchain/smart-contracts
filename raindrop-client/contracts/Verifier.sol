pragma solidity ^0.4.21;

import "./zeppelin/ownership/Ownable.sol";

contract ERC20Basic {
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
}

contract Verifier is Ownable {
    // Event for when a user signs up for Hydro 2FA / deletes their account
    event UserSignUp(string userName, address userAddress, bool official);
    event UserDeleted(string userName, address userAddress, bool official);
    // Event for when an application signs up for Hydro 2FA / deletes their account
    event ApplicationSignUp(string applicationName, bool official);
    event ApplicationDeleted(string applicationName, bool official);

    uint public unofficialUserSignUpFee;
    uint public unofficialApplicationSignUpFee;

    struct User {
        string userName;
        address userAddress;
        bool official;
        bool _initialized;
    }

    struct Application {
        string applicationName;
        bool official;
        bool _initialized;
    }

    mapping (bytes32 => User) userDirectory;
    mapping (bytes32 => Application) officialApplicationDirectory;
    mapping (bytes32 => Application) unofficialApplicationDirectory;

    function Verifier() public {}

    // these *Taken functions are redundant in that we have to hash names twice
    // but they're useful to call as public functions
    function userNameTaken(string userName) public view returns (bool taken) {
        bytes32 userNameHash = keccak256(userName);
        return userDirectory[userNameHash]._initialized;
    }

    function applicationNameTaken(string applicationName, bool official) public view returns (bool taken) {
        bytes32 applicationNameHash = keccak256(applicationName);
        if (official) {
            return officialApplicationDirectory[applicationNameHash]._initialized;
        } else {
            return unofficialApplicationDirectory[applicationNameHash]._initialized;
        }
    }

    // app users must sign "Delete" with their public key for the Hydro API to be able to delete their account
    function deleteUserForUser(string userName, uint8 v, bytes32 r, bytes32 s) public onlyOwner {
        require(userNameTaken(userName));
        bytes32 userNameHash = keccak256(userName);
        address userAddress = userDirectory[userNameHash].userAddress;
        require(isSigned(userAddress, keccak256("Delete"), v, r, s));

        delete userDirectory[userNameHash];

        emit UserDeleted(userName, userAddress, true);

    }

    // alternatively, users can can call this function from their registered address
    function deleteUser(string userName) public {
        require(userNameTaken(userName));
        bytes32 userNameHash = keccak256(userName);
        require(userDirectory[userNameHash].userAddress == msg.sender);
        address userAddress = userDirectory[userNameHash].userAddress;

        delete userDirectory[userNameHash];

        emit UserDeleted(userName, userAddress, true);
    }

    function deleteApplication(string applicationName, bool official) public onlyOwner {
        require(applicationNameTaken(applicationName, official));
        bytes32 applicationNameHash = keccak256(applicationName);
        if (official) {
            delete officialApplicationDirectory[applicationNameHash];
        } else {
            delete unofficialApplicationDirectory[applicationNameHash];
        }
    }

    function allLower(string memory _string) public pure returns (bool) {
        bytes memory bytesString = bytes(_string);
        for (uint i = 0; i < bytesString.length; i++) {
			// Uppercase characters
            if ((bytesString[i] >= 65) && (bytesString[i] <= 90)) {
                return false;
			}
        }
        return true;
    }

    // called exclusively by the Hydro API when users sign up through the app
    function officialUserSignUp(string userName, address userAddress) public onlyOwner {
        _userSignUp(userName, userAddress, true);
    }

    // called by individuals who want to create their own account
    function unofficialUserSignUp(string userName) public payable {
        require(msg.value >= unofficialUserSignUpFee);
        require(bytes(userName).length < 100);

        return _userSignUp(userName, msg.sender, false);
    }

    // common logic for all user signups regardless of origin
    function _userSignUp(string userName, address userAddress, bool official) internal {
        require(!userNameTaken(userName));
        bytes32 _userNameHash = keccak256(userName);
        userDirectory[_userNameHash] = User(userName, userAddress, official, true);

        emit UserSignUp(userName, userAddress, official);
    }

    // called exclusively by the Hydro API when official applications are added
    function officialApplicationSignUp(string applicationName) public onlyOwner {
        bool officialNameTaken = applicationNameTaken(applicationName, true);
        require(!officialNameTaken);
        bytes32 _applicationNameHash = keccak256(applicationName);
        officialApplicationDirectory[_applicationNameHash] = Application(applicationName, true, true);

        emit ApplicationSignUp(applicationName, true);
    }

    // called by applications that want to create their own account (must be all lowercase)
    function unofficialApplicationSignUp(string applicationName) public payable {
        require(msg.value >= unofficialApplicationSignUpFee);
        require(bytes(applicationName).length < 100);

        require(allLower(applicationName));
        require(!applicationNameTaken(applicationName, false));

        bytes32 _applicationNameHash = keccak256(applicationName);
        unofficialApplicationDirectory[_applicationNameHash] = Application(applicationName, false, true);

        emit ApplicationSignUp(applicationName, false);
    }

    function recoverAddress(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (address) {
        return ecrecover(messageHash, v, r, s);
    }

    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return ecrecover(messageHash, v, r, s) == _address;
    }

    function getUserByName(string userName) public view returns (address userAddress, bool official) {
        require(userNameTaken(userName));
        bytes32 userNameHash = keccak256(userName);
        User storage _user = userDirectory[userNameHash];
        return (_user.userAddress, _user.official);
    }

    function setUnofficialUserSignUpFee(uint newFee) public onlyOwner {
        unofficialUserSignUpFee = newFee;
    }

    function setUnofficialApplicationSignUpFee(uint newFee) public onlyOwner {
        unofficialApplicationSignUpFee = newFee;
    }

    function withdrawEther(address to) public onlyOwner {
        to.transfer(address(this).balance);
    }

    // safety valve ensuring that no ERC-20 token can ever be "stuck" in the contract
    function withdrawToken(address tokenAddress, address to) public onlyOwner {
        ERC20Basic token = ERC20Basic(tokenAddress);
        token.transfer(to, token.balanceOf(address(this)));
    }
}
