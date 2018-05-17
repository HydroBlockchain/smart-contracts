pragma solidity ^0.4.23;

import "./Withdrawable.sol";
import "./libraries/StringUtils.sol";


contract ClientRaindrop is Withdrawable {
    // attach the StringUtils library
    using StringUtils for string;
    using StringUtils for StringUtils.slice;
    // Events for when a user signs up for Raindrop Client and when their account is deleted
    event UserSignUp(string casedUserName, address userAddress);
    event UserDeleted(string casedUserName);

    // Variables allowing this contract to interact with the Hydro token
    address public hydroTokenAddress;
    uint public minimumHydroStakeUser;
    uint public minimumHydroStakeDelegatedUser;

    // User account template
    struct User {
        string casedUserName;
        address userAddress;
    }

    // Mapping from hashed uncased names to users (primary User directory)
    mapping (bytes32 => User) internal userDirectory;
    // Mapping from addresses to hashed uncased names (secondary directory for account recovery based on address)
    mapping (address => bytes32) internal nameDirectory;

    // Requires an address to have a minimum number of Hydro
    modifier requireStake(address _address, uint stake) {
        ERC20Basic hydro = ERC20Basic(hydroTokenAddress);
        require(hydro.balanceOf(_address) >= stake, "Insufficient HYDRO balance.");
        _;
    }

    // Allows applications to sign up users on their behalf iff users signed their permission
    function signUpDelegatedUser(string casedUserName, address userAddress, uint8 v, bytes32 r, bytes32 s)
        public
        requireStake(msg.sender, minimumHydroStakeDelegatedUser)
    {
        require(isSigned(
            userAddress,
            keccak256(abi.encodePacked("Create RaindropClient Hydro Account")), v, r, s), "Permission denied."
        );
        _userSignUp(casedUserName, userAddress);
    }

    // Allows users to sign up with their own address
    function signUpUser(string casedUserName) public requireStake(msg.sender, minimumHydroStakeUser) {
        return _userSignUp(casedUserName, msg.sender);
    }

    // Allows users to delete their accounts
    function deleteUser() public {
        bytes32 uncasedUserNameHash = nameDirectory[msg.sender];
        require(initialized(uncasedUserNameHash), "No user associated with the sender address.");

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
        // <= the airdrop amount
        require(newMinimumHydroStakeUser <= (222222 * 10**18), "Stake is too high.");
        // <= .01% of total supply
        require(newMinimumHydroStakeDelegatedUser <= (hydro.totalSupply() / 100 / 100), "Stake is too high.");
        minimumHydroStakeUser = newMinimumHydroStakeUser;
        minimumHydroStakeDelegatedUser = newMinimumHydroStakeDelegatedUser;
    }

    // Returns a bool indicating whether a given userName has been claimed (either exactly or as any case-variant)
    function userNameTaken(string userName) public view returns (bool taken) {
        bytes32 uncasedUserNameHash = keccak256(abi.encodePacked(userName.lower()));
        return initialized(uncasedUserNameHash);
    }

    // Returns user details (including cased username) by any cased/uncased user name that maps to a particular user
    function getUserByName(string userName) public view returns (string casedUserName, address userAddress) {
        bytes32 uncasedUserNameHash = keccak256(abi.encodePacked(userName.lower()));
        require(initialized(uncasedUserNameHash), "User does not exist.");

        return (userDirectory[uncasedUserNameHash].casedUserName, userDirectory[uncasedUserNameHash].userAddress);
    }

    // Returns user details by user address
    function getUserByAddress(address _address) public view returns (string casedUserName) {
        bytes32 uncasedUserNameHash = nameDirectory[_address];
        require(initialized(uncasedUserNameHash), "User does not exist.");

        return userDirectory[uncasedUserNameHash].casedUserName;
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
        bytes32 prefixedMessageHash = keccak256(abi.encodePacked(prefix, messageHash));

        return ecrecover(prefixedMessageHash, v, r, s) == _address;
    }

    // Common internal logic for all user signups
    function _userSignUp(string casedUserName, address userAddress) internal {
        require(bytes(casedUserName).length < 31, "Username too long.");
        require(bytes(casedUserName).length > 3, "Username too short.");

        bytes32 uncasedUserNameHash = keccak256(abi.encodePacked(casedUserName.toSlice().copy().toString().lower()));
        require(!initialized(uncasedUserNameHash), "Username taken.");

        userDirectory[uncasedUserNameHash] = User(casedUserName, userAddress);
        nameDirectory[userAddress] = uncasedUserNameHash;

        emit UserSignUp(casedUserName, userAddress);
    }

    function initialized(bytes32 uncasedUserNameHash) internal view returns (bool) {
        return userDirectory[uncasedUserNameHash].userAddress == 0x0; // a sufficient initialization check
    }
}
