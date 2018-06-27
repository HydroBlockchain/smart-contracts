pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";
import "../libraries/addressSet.sol";


contract Snowflake {
    function getTokenId(address _address) public view returns (uint tokenId);
}


contract AddressOwnership is SnowflakeResolver {
    using addressSet for addressSet._addressSet;

    mapping (bytes32 => uint) internal initiatedClaims;
    mapping (uint => addressSet._addressSet) internal snowflakeToOwnedAddresses;

    constructor () public {
        snowflakeName = "Address Ownership";
        snowflakeDescription = "Allows Snowflake holders to claim ownership over any number of Ethereum addresses.";
    }

    function ownedAddresses(uint tokenId) public view returns (address[]) {
        return snowflakeToOwnedAddresses[tokenId].members;
    }

    function ownsAddress(uint tokenId, address _address) public view returns (bool) {
        return snowflakeToOwnedAddresses[tokenId].contains(_address);
    }

    // to claim an address, users need to send a transaction from their snowflake address containing a sealed claim
    // sealedClaims are: keccak256(abi.encodePacked("Link Address to Snowflake", <address>, <secret>)),
    // where <address> is the address you'd like to claim, and <secret> is a SECRET bytes32 value.
    function initiateClaim(bytes32 sealedClaim) public {
        require(initiatedClaims[sealedClaim] == 0, "This sealed claim has already been submitted.");

        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);

        initiatedClaims[sealedClaim] = tokenId;
    }

    // claims are finalized by submitting the plaintext values of the claim, as well as a signature of the claim, i.e.
    // keccak256(abi.encodePacked("Link Address to Snowflake", <address>, <secret>))
    function finalizeClaim(address _address, uint8 v, bytes32 r, bytes32 s, bytes32 secret) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);

        bytes32 claimedSealedBid = keccak256(abi.encodePacked("Link Address to Snowflake", _address, secret));

        require(initiatedClaims[claimedSealedBid] == tokenId, "The Snowflake did not initiate this sealed claim.");
        require(isSigned(_address, claimedSealedBid, v, r, s), "The signature was incorrect.");

        snowflakeToOwnedAddresses[tokenId].insert(_address);
        emit AddressClaimed(tokenId, _address);
    }

    function unclaimAddress(address _address) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);

        snowflakeToOwnedAddresses[tokenId].remove(_address);
        emit AddressUnclaimed(tokenId, _address);
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

    event AddressClaimed(uint indexed tokenId, address claimedAddress);
    event AddressUnclaimed(uint indexed tokenId, address unclaimedAddress);
}
