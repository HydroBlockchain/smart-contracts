pragma solidity ^0.4.19;

import "./zeppelin/ownership/Ownable.sol";

/* pragma solidity ^0.4.11;

contract StringToLower {
	function _toLower(string str) internal returns (string) {
		bytes memory bStr = bytes(str);
		bytes memory bLower = new bytes(bStr.length);
		for (uint i = 0; i < bStr.length; i++) {
			// Uppercase character...
			if ((bStr[i] >= 65) && (bStr[i] <= 90)) {
				// So we add 32 to make it lowercase
				bLower[i] = bytes1(int(bStr[i]) + 32);
			} else {
				bLower[i] = bStr[i];
			}
		}
		return string(bLower);
	}
} */

contract Verifier is Ownable {
    // Event for when a user signs up for Hydro 2FA
    event UserSignUp(bytes32 indexed userNameHash, string userName, bool official);
    // Event for when an application signs up for Hydro 2FA
    event ApplicationSignUp(bytes32 indexed applicationNameHash, string applicationName, bool official);

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

    function deleteUser(string userName) public onlyOwner {
        require(userNameTaken(userName));
        bytes32 userNameHash = keccak256(userName);
        delete userDirectory[userNameHash];
    }

    // these *Taken functions are redundant in that we have to hash names twice
    // but they're useful to call as public functions
    function userNameTaken(string userName) public view returns (bool taken) {
        bytes32 userNameHash = keccak256(userName);
        return userDirectory[userNameHash]._initialized;
    }

    function applicationNameTaken(string applicationName) public view returns (bool officialTaken, bool unofficialTaken) {
        bytes32 applicationNameHash = keccak256(applicationName);
        return (
            officialApplicationDirectory[applicationNameHash]._initialized,
            unofficialApplicationDirectory[applicationNameHash]._initialized
        );
    }

    function Verifier() public {}

    // called exclusively by the Hydro API when users sign up through the app
    function officialUserSignUp(string userName, address userAddress) public onlyOwner returns (bytes32 userNameHash) {
        return _userSignUp(userName, userAddress, true);
    }

    // called by individuals who want to create their own account
    function unofficialUserSignUp(string userName) public payable returns (bytes32 userNameHash) {
        require(msg.value >= unofficialUserSignUpFee);
        require(bytes(userName).length < 100);

        return _userSignUp(userName, msg.sender, false);
    }

    // common logic for all user signups regardless of origin
    function _userSignUp(string userName, address userAddress, bool official) internal returns (bytes32 userNameHash) {
        require(!userNameTaken(userName));
        bytes32 _userNameHash = keccak256(userName);
        userDirectory[_userNameHash] = User(userName, userAddress, official, true);

        UserSignUp(_userNameHash, userName, official);

        return _userNameHash;
    }

    // called exclusively by the Hydro API when official applications are added
    function officialApplicationSignUp(string applicationName) public onlyOwner returns (bytes32 applicationNameHash) {
        var (nameTaken, ) = applicationNameTaken(applicationName);
        require(!nameTaken);
        bytes32 _applicationNameHash = keccak256(applicationName);
        officialApplicationDirectory[_applicationNameHash] = Application(applicationName, true, true);

        ApplicationSignUp(_applicationNameHash, applicationName, true);

        return _applicationNameHash;
    }

    // called by applications that want to create their own account
    function unofficialApplicationSignUp(string applicationName) public payable returns (bytes32 applicationNameHash) {
        require(msg.value >= unofficialApplicationSignUpFee);
        require(bytes(applicationName).length < 100);

        var (, nameTaken) = applicationNameTaken(applicationName);
        require(!nameTaken);
        bytes32 _applicationNameHash = keccak256(applicationName);
        unofficialApplicationDirectory[_applicationNameHash] = Application(applicationName, false, true);

        ApplicationSignUp(_applicationNameHash, applicationName, false);

        return _applicationNameHash;
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

    // add withdrawToken functionality?
    // require the payment to be in HYDRO rather than ETH?
    function withdraw(address to) public onlyOwner {
        to.transfer(this.balance);
    }
}
