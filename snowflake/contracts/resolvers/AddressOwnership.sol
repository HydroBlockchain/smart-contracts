pragma solidity ^0.4.24;

import "./SnowflakeResolver.sol";
import "../libraries/addressSet.sol";


contract Snowflake {
    function hasToken(address _address) public view returns (bool);
    function getHydroId(address _address) public view returns (string hydroId);
}


contract AddressOwnership is SnowflakeResolver {
    using addressSet for addressSet._addressSet;

    mapping (bytes32 => string) internal initiatedClaims;
    mapping (string => addressSet._addressSet) internal snowflakeToOwnedAddresses;

    constructor () public {
        snowflakeName = "Address Ownership";
        snowflakeDescription = "Allows Snowflake holders to claim ownership over any number of Ethereum addresses.";
    }

    // get list of all of a snowflake's owned addresses. does not throw for invalid inputs, just returns []
    function ownedAddresses(string hydroId) public view returns (address[]) {
        return snowflakeToOwnedAddresses[hydroId].members;
    }

    // queries the list of all of a snowflake's owned addresses. does not throw for invalid inputs, just returns false
    function ownsAddress(string hydroId, address owned) public view returns (bool) {
        return snowflakeToOwnedAddresses[hydroId].contains(owned);
    }

    // to claim an address, users need to send a transaction from their snowflake address containing a sealed claim
    // sealedClaims are: keccak256(abi.encodePacked("Link Address to Snowflake", <address>, <secret>)),
    // where <address> is the address you'd like to claim, and <secret> is a SECRET bytes32 value.
    function initiateClaim(bytes32 sealedClaim) public {
        require(bytes(initiatedClaims[sealedClaim]).length == 0, "This sealed claim has already been submitted.");

        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);

        initiatedClaims[sealedClaim] = hydroId;

        // on first interaction, add the sending/snowflake address to the registry
        snowflakeToOwnedAddresses[hydroId].insert(msg.sender);
    }

    // claims are finalized by submitting the plaintext values of the claim, as well as a signature of the claim, i.e.
    // keccak256(abi.encodePacked("Link Address to Snowflake", <address>, <secret>))
    function finalizeClaim(address _address, uint8 v, bytes32 r, bytes32 s, bytes32 secret) public {
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);

        bytes32 claimedSealedBid = keccak256(abi.encodePacked("Link Address to Snowflake", _address, secret));

        require(
            keccak256(abi.encodePacked(initiatedClaims[claimedSealedBid])) == keccak256(abi.encodePacked(hydroId)),
            "The sending Snowflake did not initiate this claim."
        );
        require(isSigned(_address, claimedSealedBid, v, r, s), "The signature was incorrect.");

        snowflakeToOwnedAddresses[hydroId].insert(_address);
        emit AddressClaimed(msg.sender, hydroId, _address);
    }

    function unclaimAddress(address _address) public {
        require(msg.sender != _address, "Cannot unclaim your own address.");
        Snowflake snowflake = Snowflake(snowflakeAddress);
        string memory hydroId = snowflake.getHydroId(msg.sender);

        if (snowflakeToOwnedAddresses[hydroId].contains(_address)) {
            snowflakeToOwnedAddresses[hydroId].remove(_address);
            emit AddressUnclaimed(msg.sender, hydroId, _address);
        }
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

    event AddressClaimed(address indexed ownerAddress, string hydroId, address claimedAddress);
    event AddressUnclaimed(address indexed ownerAddress, string hydroId, address unclaimedAddress);
}
