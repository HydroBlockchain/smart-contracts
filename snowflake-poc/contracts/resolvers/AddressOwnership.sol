pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";
import "../libraries/addressSet.sol";


contract Snowflake {
    function getTokenId(address _address) public view returns (uint tokenId);
}


contract AddressOwnership is SnowflakeResolver {
    using addressSet for addressSet._addressSet;

    uint blockLag;
    mapping (bytes32 => uint) public initiatedClaims;
    mapping (uint => addressSet._addressSet) internal snowflakeToOwnedAddresses;

    constructor () public {
        blockLag = 20;
    }

    function setBlockLag(uint _blockLag) public onlyOwner {
        blockLag = _blockLag;
    }

    function ownedAddresses(uint tokenId) public view returns (address[]) {
        require(
            snowflakeToOwnedAddresses[tokenId].length() >= 1, "This token has not proved ownership over any addresses"
        );
        return snowflakeToOwnedAddresses[tokenId].members;
    }

    function ownsAddress(uint tokenId, address _address) public view returns (bool) {
        return snowflakeToOwnedAddresses[tokenId].contains(_address);
    }

    // to claim an address, users need to send a transaction from their snowflake address that includes the address
    // they'd like to claim, as well as a signature from that address of:
    // keccak256(abi.encodePacked("Link Address to Snowflake", blockhash(block.number), where block.number is any of the
    // last blockLag blocks

    function initiateClaim(bytes32 sealedSignature) public {
        require(initiatedClaims[sealedSignature] == 0, "This sealed signature has already been submitted.");

        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);

        initiatedClaims[sealedSignature] = tokenId;
    }

    function finalizeClaim(address _address, uint8 v, bytes32 r, bytes32 s) public returns (bool success) {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);

        bytes32 claimedSealedBid = keccak256(abi.encodePacked(_address, v, r, s));

        require(initiatedClaims[claimedSealedBid] == tokenId, "This token has not.");
        uint i;
        bool signed;
        bytes32 challengeMessage;
        while(!signed && (i < blockLag)) {
            challengeMessage = keccak256(abi.encodePacked("Link Address to Snowflake", blockhash(block.number - ++i)));
            signed = isSigned(_address, challengeMessage, v, r, s);
        }
        if (signed) {
            snowflakeToOwnedAddresses[tokenId].insert(_address);
            return true;
        } else {
            return false;
        }
    }

    function unclaimAddress(address _address) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        uint tokenId = snowflake.getTokenId(msg.sender);
        snowflakeToOwnedAddresses[tokenId].remove(_address);
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
}
