pragma solidity ^0.4.21;

import "./Withdrawable.sol";
import "./libraries/stringUtils.sol";


contract RaindropClient is Withdrawable {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;
    // Events for when a user signs up for Raindrop Client and when their account is deleted
    event UserSignUp(string casedUserName, address userAddress, bool delegated);
    event UserDeleted(string casedUserName);

    // Variables allowing this contract to interact with the Hydro token
    address public hydroTokenAddress;
    uint public minimumHydroStakeUser;
    uint public minimumHydroStakeDelegatedUser;

    // User account template
    struct User {
        string casedUserName;
        address userAddress;
        bool delegated;
        bool _initialized;
    }

    // Mapping from hashed uncased names to users (primary User directory)
    mapping (bytes32 => User) internal userDirectory;
    // Mapping from addresses to hashed uncased names (secondary directory for account recovery based on address)
    mapping (address => bytes32) internal nameDirectory;

    // Requires an address to have a minimum number of Hydro
    modifier requireStake(address _address, uint stake) {
        ERC20Basic hydro = ERC20Basic(hydroTokenAddress);
        require(hydro.balanceOf(_address) >= stake);
        _;
    }

    // Allows applications to sign up users on their behalf iff users signed their permission
    function signUpDelegatedUser(string casedUserName, address userAddress, uint8 v, bytes32 r, bytes32 s)
        public
        requireStake(msg.sender, minimumHydroStakeDelegatedUser)
    {
        require(isSigned(userAddress, keccak256("Create RaindropClient Hydro Account"), v, r, s));
        _userSignUp(casedUserName, userAddress, true);
    }

    // Allows users to sign up with their own address
    function signUpUser(string casedUserName) public requireStake(msg.sender, minimumHydroStakeUser) {
        return _userSignUp(casedUserName, msg.sender, false);
    }

    // Allows users to delete their accounts
    function deleteUser() public {
        bytes32 uncasedUserNameHash = nameDirectory[msg.sender];
        require(userDirectory[uncasedUserNameHash]._initialized);

        string memory casedUserName = userDirectory[uncasedUserNameHash].casedUserName;

        delete nameDirectory[msg.sender];
        delete userDirectory[uncasedUserNameHash];

        emit UserDeleted(casedUserName);
    }

    // Allows the Hydro API to link to the Hydro token
    function setHydroTokenAddress(address _hydroTokenAddress) public onlyOwner {
        hydroTokenAddress = _hydroTokenAddress;
    }

    // Allows the Hydro API to set minimum hydro balances required for sign ups
    function setMinimumHydroStakes(uint newMinimumHydroStakeUser, uint newMinimumHydroStakeDelegatedUser)
        public onlyOwner
    {
        ERC20Basic hydro = ERC20Basic(hydroTokenAddress);
        require(newMinimumHydroStakeUser <= (hydro.totalSupply() / 100 / 100)); // <= .01% of total supply
        require(newMinimumHydroStakeDelegatedUser <= (hydro.totalSupply() / 100 / 2)); // <= .5% of total supply
        minimumHydroStakeUser = newMinimumHydroStakeUser;
        minimumHydroStakeDelegatedUser = newMinimumHydroStakeDelegatedUser;
    }

    // Returns a bool indicated whether a given userName has been claimed
    function userNameTaken(string casedUserName) public view returns (bool taken) {
        bytes32 uncasedUserNameHash = keccak256(casedUserName.lower());
        return userDirectory[uncasedUserNameHash]._initialized;
    }

    // Returns user details by user name
    function getUserByName(string casedUserName) public view returns (address userAddress, bool delegated) {
        bytes32 uncasedUserNameHash = keccak256(casedUserName.lower());
        User storage _user = userDirectory[uncasedUserNameHash];
        require(_user._initialized);

        return (_user.userAddress, _user.delegated);
    }

    // Returns user details by user address
    function getUserByAddress(address _address) public view returns (string casedUserName, bool delegated) {
        bytes32 uncasedUserNameHash = nameDirectory[_address];
        User storage _user = userDirectory[uncasedUserNameHash];
        require(_user._initialized);

        return (_user.casedUserName, _user.delegated);
    }

    // Checks whether the provided (v, r, s) signature was created by the private key associated with _address
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return (_isSigned(_address, messageHash, v, r, s) || _isSignedPrefixed(_address, messageHash, v, r, s));
    }

    // Checks unprefixed signatures
    function _isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        return ecrecover(messageHash, v, r, s) == _address;
    }

    // Checks prefixed signatures (e.g. those created with web3.eth.sign)
    function _isSignedPrefixed(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedMessageHash = keccak256(prefix, messageHash);

        return ecrecover(prefixedMessageHash, v, r, s) == _address;
    }

    // Common internal logic for all user signups
    function _userSignUp(string casedUserName, address userAddress, bool delegated) internal {
        require(bytes(casedUserName).length < 50);

        bytes32 uncasedUserNameHash = keccak256(casedUserName.toSlice().copy().toString().lower());
        require(!userDirectory[uncasedUserNameHash]._initialized);

        userDirectory[uncasedUserNameHash] = User(casedUserName, userAddress, delegated, true);
        nameDirectory[userAddress] = uncasedUserNameHash;

        emit UserSignUp(casedUserName, userAddress, delegated);
    }
}
