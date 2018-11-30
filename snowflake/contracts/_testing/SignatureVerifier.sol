pragma solidity ^0.5.0;

/// @title Provides helper functions to determine the validity of passed signatures.
/// @author Noah Zinsmeister
/// @dev Supports both prefixed and un-prefixed signatures.
contract SignatureVerifier {
    /// @notice Determines whether the passed signature of `messageHash` was made by the private key of `_address`.
    /// @param _address The address that may or may not have signed the passed messageHash.
    /// @param messageHash The messageHash that may or may not have been signed.
    /// @param v The v component of the signature.
    /// @param r The r component of the signature.
    /// @param s The s component of the signature.
    /// @return true if the signature can be verified, false otherwise.
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool) {
        return _isSigned(_address, messageHash, v, r, s) || _isSignedPrefixed(_address, messageHash, v, r, s);
    }

    /// @dev Checks unprefixed signatures.
    function _isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        internal pure returns (bool)
    {
        return ecrecover(messageHash, v, r, s) == _address;
    }

    /// @dev Checks prefixed signatures.
    function _isSignedPrefixed(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        internal pure returns (bool)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        return _isSigned(_address, keccak256(abi.encodePacked(prefix, messageHash)), v, r, s);
    }
}
