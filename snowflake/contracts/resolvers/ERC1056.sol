pragma solidity ^0.4.24;

interface IdentityRegistryInterface {
    function getEIN(address _address) external view returns (uint ein);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function identityExists(uint ein) external view returns (bool);
    function getDetails(uint ein) external view
      returns (address recoveryAddress, address[] associatedAddresses, address[] providers, address[] resolvers);
}

interface EthereumDIDRegistry {
    function identityOwner(address identity) external view returns(address);
    function validDelegate(address identity, bytes32 delegateType, address delegate) external view returns(bool);
    function changeOwner(address identity, address newOwner) external;
    function changeOwnerSigned(address identity, uint8 sigV, bytes32 sigR, bytes32 sigS, address newOwner) external;
    function addDelegate(address identity, bytes32 delegateType, address delegate, uint validity) external;
    function revokeDelegate(address identity, bytes32 delegateType, address delegate) external;
    function setAttribute(address identity, bytes32 name, bytes value, uint validity) external;
    function revokeAttribute(address identity, bytes32 name, bytes value) external;
}

contract SignatureVerifier {
    // define the Ethereum prefix for signing a message of length 32
    bytes private prefix = "\x19Ethereum Signed Message:\n32";

    // checks if the provided (v, r, s) signature of messageHash was created by the private key associated with _address
    function recoverAddress(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public view returns (address) {
        return _recoverAddressPrefixed(messageHash, v, r, s);
    }

    // checks unprefixed signatures
    function _recoverAddress(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        private pure returns (address)
    {
        return ecrecover(messageHash, v, r, s);
    }

    // checks prefixed signatures
    function _recoverAddressPrefixed(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        private view returns (address)
    {
        return _recoverAddress(keccak256(abi.encodePacked(prefix, messageHash)), v, r, s);
    }
}

contract ERC1056RegistryResolver is SignatureVerifier {
    IdentityRegistryInterface identityRegistry;
    EthereumDIDRegistry ethereumDIDRegistry;

    constructor (address identityRegistryAddress, address ethereumDIDRegistryAddress) public {
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);
        ethereumDIDRegistry = EthereumDIDRegistry(ethereumDIDRegistryAddress);
    }

    mapping(uint => address) public einToDID;
    mapping(uint => uint) public actionNonce;

    function initialize(address identity, uint8 sigV, bytes32 sigR, bytes32 sigS) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        require(einToDID[ein] == address(0), "This EIN has already been initialized");
        ethereumDIDRegistry.changeOwnerSigned(identity, sigV, sigR, sigS, address(this));
        einToDID[ein] = identity;
    }

    function changeOwner(address newOwner) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _changeOwner(einToDID[ein], newOwner);
    }

    function changeOwnerDelegated(address newOwner, uint8 sigV, bytes32 sigR, bytes32 sigS, uint einDelegated) public {
        uint ein = recoverEIN(
            keccak256(abi.encodePacked("changeOwnerDelegated", newOwner, actionNonce[einDelegated])), sigV, sigR, sigS
        );
        require(ein == einDelegated, "The signing address did not pass the correct EIN");
        actionNonce[ein]++;
        _changeOwner(einToDID[ein], newOwner);
    }

    function _changeOwner(address _did, address _newOwner) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.changeOwner(_did, _newOwner);
    }

    function addDelegate(bytes32 delegateType, address delegate, uint validity) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _addDelegate(einToDID[ein], delegateType, delegate, validity);
    }

    function addDelegateDelegated(
        bytes32 delegateType, address delegate, uint validity, uint8 sigV, bytes32 sigR, bytes32 sigS, uint einDelegated
    )
        public
    {
        uint ein = recoverEIN(
            keccak256(
                abi.encodePacked("addDelegateDelegated", delegateType, delegate, validity, actionNonce[einDelegated])
            ),
            sigV, sigR, sigS);
        require(ein == einDelegated, "The signing address did not pass the correct EIN");
        actionNonce[ein]++;
        _addDelegate(einToDID[ein], delegateType, delegate, validity);
    }

    function _addDelegate(address _did, bytes32 _delegateType, address _delegate, uint _validity) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.addDelegate(_did, _delegateType, _delegate, _validity);
    }

    function revokeDelegate(bytes32 delegateType, address delegate) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _revokeDelegate(einToDID[ein], delegateType, delegate);
    }

    function revokeDelegateDelegated(bytes32 delegateType, address delegate, uint8 sigV, bytes32 sigR, bytes32 sigS, uint einDelegated) public {
        uint ein = recoverEIN(
            keccak256(
                abi.encodePacked("revokeDelegateDelegated", delegateType, delegate, actionNonce[einDelegated])
            ),
            sigV, sigR, sigS
        );
        require(ein == einDelegated, "The signing address did not pass the correct EIN");
        actionNonce[ein]++;
        _revokeDelegate(einToDID[ein], delegateType, delegate);
    }

    function _revokeDelegate(address _did, bytes32 _delegateType, address _delegate) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.revokeDelegate(_did, _delegateType, _delegate);
    }

    function setAttribute(bytes32 name, bytes value, uint validity) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _setAttribute(einToDID[ein], name, value, validity);
    }

    function setAttributeDelegated(bytes32 name, bytes value, uint validity, uint8 sigV, bytes32 sigR, bytes32 sigS, uint einDelegated) public {
        uint ein = recoverEIN(
            keccak256(
                abi.encodePacked("setAttributeDelegated", name, value, validity, actionNonce[einDelegated])
            ),
            sigV, sigR, sigS
        );
        require(ein == einDelegated, "The signing address did not pass the correct EIN");
        actionNonce[ein]++;
        _setAttribute(einToDID[ein], name, value, validity);
    }

    function _setAttribute(address _did, bytes32 _name, bytes _value, uint _validity) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.setAttribute(_did, _name, _value, _validity);
    }

    function revokeAttribute(bytes32 name, bytes value) public {
        uint ein = identityRegistry.getEIN(msg.sender);
        _revokeAttribute(einToDID[ein], name, value);
    }

    function revokeAttributeDelegated(
        bytes32 name, bytes value, uint8 sigV, bytes32 sigR, bytes32 sigS, uint einDelegated
    )
        public
    {
        uint ein = recoverEIN(
            keccak256(
                abi.encodePacked("revokeDelegateDelegated", name, value, actionNonce[einDelegated])
            ),
            sigV, sigR, sigS
        );
        require(ein == einDelegated, "The signing address did not pass the correct EIN");
        actionNonce[ein]++;
        _revokeAttribute(einToDID[ein], name, value);
    }

    function _revokeAttribute(address _did, bytes32 _name, bytes _value) internal {
        require(_did != address(0), "This EIN has not been initialized");
        ethereumDIDRegistry.revokeAttribute(_did, _name, _value);
    }

    function recoverEIN(bytes32 _hash, uint8 _sigV, bytes32 _sigR, bytes32 _sigS) internal view returns(uint){
        address delegatedAddress = recoverAddress(_hash, _sigV, _sigR, _sigS);
        uint ein = identityRegistry.getEIN(delegatedAddress);
        return ein;
    }
}
