pragma solidity ^0.4.24;

import "./ERC735.sol";
import "./KeyHolder.sol";

contract ClaimHolder is KeyHolder, ERC735 {

    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer; // msg.sender
        bytes signature; // this.address + topic + data
        bytes data;
        string uri;
    }

    struct Claims {
        mapping (bytes32 => Claim) byId;
        mapping (uint256 => bytes32[]) byTopic;
    }

    Claims claims;

    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes _signature,
        bytes _data,
        string _uri
    )
        public
        returns (bytes32 claimRequestId)
    {
        bytes32 claimId = keccak256(abi.encodePacked(_issuer, _topic));

        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), 3), "Sender does not have claim signer key");
        }

        if (claims.byId[claimId].issuer != _issuer) {
            claims.byTopic[_topic].push(claimId);
        }

        claims.byId[claimId].topic = _topic;
        claims.byId[claimId].scheme = _scheme;
        claims.byId[claimId].issuer = _issuer;
        claims.byId[claimId].signature = _signature;
        claims.byId[claimId].data = _data;
        claims.byId[claimId].uri = _uri;

        emit ClaimAdded(
            claimId,
            _topic,
            _scheme,
            _issuer,
            _signature,
            _data,
            _uri
        );

        return claimId;
    }

    function removeClaim(bytes32 _claimId) public returns (bool success) {
        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), 1), "Sender does not have management key");
        }

        emit ClaimRemoved(
            _claimId,
            claims.byId[_claimId].topic,
            claims.byId[_claimId].scheme,
            claims.byId[_claimId].issuer,
            claims.byId[_claimId].signature,
            claims.byId[_claimId].data,
            claims.byId[_claimId].uri
        );

        delete claims.byId[_claimId];
        return true;
    }

    function getClaim(bytes32 _claimId)
        public
        view
        returns(
            uint256 claimType,
            uint256 scheme,
            address issuer,
            bytes signature,
            bytes data,
            string uri
        )
    {
        return (
            claims.byId[_claimId].topic,
            claims.byId[_claimId].scheme,
            claims.byId[_claimId].issuer,
            claims.byId[_claimId].signature,
            claims.byId[_claimId].data,
            claims.byId[_claimId].uri
        );
    }

    function getClaimIdsByTopic(uint256 _topic)
        public
        view
        returns(bytes32[] claimIds)
    {
        return claims.byTopic[_topic];
    }

}
