pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/math/SafeMath.sol";
import "./BytesLib.sol";

interface ERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface SnowflakeResolver {
    function callOnSignUp() external returns (bool);
    function onSignUp(uint ein, uint allowance) external returns (bool);
    function callOnRemoval() external returns (bool);
    function onRemoval(uint ein) external returns(bool);
}

interface ViaContract {
    function snowflakeCall(address resolver, uint einFrom, uint einTo, uint amount, bytes _bytes) external;
    function snowflakeCall(address resolver, uint einFrom, address to, uint amount, bytes _bytes) external;
    function snowflakeCall(address resolver, uint einTo, uint amount, bytes _bytes) external;
    function snowflakeCall(address resolver, address to, uint amount, bytes _bytes) external;
}

interface IdentityRegistryInterface {
    function isSigned(
        address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s
    ) external view returns (bool);

    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAssociatedAddressFor(uint ein, address _address) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAddressDelegated(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    ) external;
    function removeAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) external;
    function addProvidersFor(uint ein, address[] providers) external;
    function removeProvidersFor(uint ein, address[] providers) external;
    function addResolversFor(uint ein, address[] resolvers) external;
    function removeResolversFor(uint ein, address[] resolvers) external;

    function initiateRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
}

interface ClientRaindropInterface {
    function signUp(address _address, string casedHydroID) external;
}

contract Snowflake is Ownable {
    using SafeMath for uint;
    using BytesLib for bytes;

    // mapping of EINs to hydro token deposits
    mapping (uint => uint) public deposits;
    // mapping from identity to resolver to allowance
    mapping (uint => mapping (address => uint)) public resolverAllowances;

    // SC variables
    address public identityRegistryAddress;
    IdentityRegistryInterface private identityRegistry;
    address public hydroTokenAddress;
    ERC20 private hydroToken;
    address public clientRaindropAddress;
    ClientRaindropInterface private clientRaindrop;

    // signature variables
    uint public signatureTimeout;
    mapping (uint => uint) public signatureNonce;

    constructor (address _identityRegistryAddress, address _hydroTokenAddress) public {
        setAddresses(_identityRegistryAddress, _hydroTokenAddress);
        setSignatureTimeout(5 hours);
    }

    // enforces that a particular address has an EIN
    modifier hasIdentity(address _address, bool check) {
        require(identityRegistry.hasIdentity(_address) == check, "The address does not have an EIN.");
        _;
    }

    // enforces that a particular EIN exists
    modifier identityExists(uint ein, bool check) {
        require(identityRegistry.identityExists(ein) == check, "The EIN does not exist.");
        _;
    }

    // enforces that a particular address is associated with an EIN
    modifier isAddressFor(uint ein, address _address) {
        require(identityRegistry.isAssociatedAddressFor(ein, _address), "Address is not associated with EIN.");
        _;
    }

    // enforces signature timeouts
    modifier ensureSignatureTimeValid(uint timestamp) {
        require(
            // solium-disable-next-line security/no-block-members
            block.timestamp >= timestamp && block.timestamp < timestamp + signatureTimeout, "Timestamp is not valid."
        );
        _;
    }


    // set the hydro token and identity registry addresses
    function setAddresses(address _identityRegistryAddress, address _hydroTokenAddress) public onlyOwner {
        identityRegistryAddress = _identityRegistryAddress;
        identityRegistry = IdentityRegistryInterface(identityRegistryAddress);

        hydroTokenAddress = _hydroTokenAddress;
        hydroToken = ERC20(hydroTokenAddress);
    }

    function setClientRaindropAddress(address _clientRaindropAddress) public onlyOwner {
        clientRaindropAddress = _clientRaindropAddress;
        clientRaindrop = ClientRaindropInterface(clientRaindropAddress);
    }

    // set the signature timeout
    function setSignatureTimeout(uint newTimeout) public {
        require(newTimeout >= 1800 && newTimeout <= 604800, "Timeout must be between 30 minutes and a week.");
        signatureTimeout = newTimeout;
    }


    // wrap createIdentityDelegated
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        return identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, resolvers, v, r, s, timestamp
        );
    }

    // wrap createIdentityDelegated and initialize the client raindrop resolver
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, string casedHydroId,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        address[] memory clientRaindropResolver = new address[](1);
        clientRaindropResolver[0] = clientRaindropAddress;
        uint _ein = identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, clientRaindropResolver, v, r, s, timestamp
        );

        signUpClientRaindrop(associatedAddress, casedHydroId);

        return _ein;
    }

    function signUpClientRaindrop(address associatedAddress, string casedHydroId) public onlyOwner() {
        clientRaindrop.signUp(associatedAddress, casedHydroId);
    }

    // wrap addAddress
    function addAddress(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public
    {
        identityRegistry.addAddressDelegated(approvingAddress, addressToAdd, v, r, s, timestamp);
    }

    // wrap removeAddress
    function removeAddress(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) public {
        identityRegistry.removeAddressDelegated(addressToRemove, v, r, s, timestamp);
    }

    // delegated addProviders
    function addProviders(address approvingAddress, address[] providers, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that these Providers be added to my Identity.",
                        ein, providers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.addProvidersFor(ein, providers);
        emit ProvidersAddedFromSnowflake(ein, providers, approvingAddress);
    }

    // delegated removeProviders
    function removeProviders(
        address approvingAddress, address[] providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that these Providers be removed from my Identity.",
                        ein, providers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.removeProvidersFor(ein, providers);
        emit ProvidersRemovedFromSnowflake(ein, providers, approvingAddress);
    }

    // delegated wrapper to add new providers and remove old ones
    function upgradeProviders(
        address approvingAddress, address[] newProviders, address[] oldProviders,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public
    {
        addProviders(approvingAddress, newProviders, v[0], r[0], s[0], timestamp[0]);
        removeProviders(approvingAddress, oldProviders, v[1], r[1], s[1], timestamp[1]);
        uint ein = identityRegistry.getEIN(approvingAddress);
        emit ProvidersUpgradedFromSnowflake(ein, newProviders, oldProviders, approvingAddress);
    }

    // add resolvers for identity of msg.sender
    function addResolvers(address[] resolvers, bool[] isSnowflake, uint[] withdrawAllowances) public {
        addResolvers(identityRegistry.getEIN(msg.sender), resolvers, isSnowflake, withdrawAllowances);
    }

    // add resolvers delegated
    function addResolvers(
        address approvingAddress, address[] resolvers, bool[] isSnowflake, uint[] withdrawAllowances,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that these Resolvers be added to my Identity.",
                        ein, resolvers, withdrawAllowances, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        addResolvers(ein, resolvers, isSnowflake, withdrawAllowances);
    }

    // common logic for adding resolvers
    function addResolvers(uint ein, address[] resolvers, bool[] isSnowflake, uint[] withdrawAllowances) private {
        require(resolvers.length == isSnowflake.length, "Malformed inputs.");
        require(isSnowflake.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(!identityRegistry.isResolverFor(ein, resolvers[i]), "Identity has already set this resolver.");
        }
        identityRegistry.addResolversFor(ein, resolvers);

        for (uint j; j < resolvers.length; j++) {
            if (isSnowflake[j]) {
                resolverAllowances[ein][resolvers[j]] = withdrawAllowances[j];
                SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[j]);
                if (snowflakeResolver.callOnSignUp()) {
                    require(snowflakeResolver.onSignUp(ein, withdrawAllowances[j]), "Sign up failure.");
                }
                emit SnowflakeResolverAdded(ein, resolvers[j], withdrawAllowances[j]);
            }
        }
    }

    // change resolver allowances for identity of msg.sender
    function changeResolverAllowances(address[] resolvers, uint[] withdrawAllowances) public {
        changeResolverAllowances(identityRegistry.getEIN(msg.sender), resolvers, withdrawAllowances);
    }

    // change resolver allowances delegated
    function changeResolverAllowances(
        address approvingAddress, address[] resolvers, uint[] withdrawAllowances, uint8 v, bytes32 r, bytes32 s
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);

        uint nonce = signatureNonce[ein]++;
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize this change in Resolver Allowances.",
                        ein, resolvers, withdrawAllowances, nonce
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        changeResolverAllowances(ein, resolvers, withdrawAllowances);
    }

    // common logic to change resolver allowances
    function changeResolverAllowances(uint ein, address[] resolvers, uint[] withdrawAllowances) internal {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(identityRegistry.isResolverFor(ein, resolvers[i]), "Identity has not set this resolver.");
            resolverAllowances[ein][resolvers[i]] = withdrawAllowances[i];
            emit SnowflakeResolverAllowanceChanged(ein, resolvers[i], withdrawAllowances[i]);
        }
    }

    // remove resolvers for identity of msg.sender
    function removeResolvers(address[] resolvers, bool[] isSnowflake, bool[] force) public {
        removeResolvers(identityRegistry.getEIN(msg.sender), resolvers, isSnowflake, force);
    }

    // add resolvers delegated
    function removeResolvers(
        address approvingAddress, address[] resolvers, bool[] isSnowflake, bool[] force,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);

        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that these Resolvers be removed from my Identity.",
                        ein, resolvers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        removeResolvers(ein, resolvers, isSnowflake, force);
    }

    // common logic to remove resolvers
    function removeResolvers(uint ein, address[] resolvers, bool[] isSnowflake, bool[] force) private {
        require(resolvers.length == isSnowflake.length, "Malformed inputs.");
        require(isSnowflake.length == force.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(identityRegistry.isResolverFor(ein, resolvers[i]), "Identity has already set this resolver.");
    
            delete resolverAllowances[ein][resolvers[i]];
    
            if (isSnowflake[i] && !force[i]) {
                SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
                if (snowflakeResolver.callOnRemoval()) {
                    require(snowflakeResolver.onRemoval(ein), "Removal failure.");
                }
                emit SnowflakeResolverRemoved(ein, resolvers[i]);
            }
        }

        identityRegistry.removeResolversFor(ein, resolvers);
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes _bytes) public {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        // depositing to an EIN
        if (_bytes.length <= 32) {
            require(hydroToken.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");

            uint recipient = interpretDepositBytes(sender, _bytes);
            deposits[recipient] = deposits[recipient].add(amount);

            emit SnowflakeDeposit(sender, recipient, amount);
        }
        else {
            // // decode arguments for transferToVia
            address resolver;
            address via;
            bytes memory _snowflakeCallBytes;
            ViaContract viaContract;
            if (_bytes[0] == byte(0x01)) {
                uint einTo;
                (resolver, via, einTo, _snowflakeCallBytes) = interpretTransferToViaBytes(_bytes);
                require(hydroToken.transferFrom(sender, via, amount), "Unable to transfer token ownership.");
                viaContract = ViaContract(via);
                viaContract.snowflakeCall(resolver, einTo, amount, _snowflakeCallBytes);
            }
            // decode arguments for withdrawToVia
            else {
                address to;
                (resolver, via, to, _snowflakeCallBytes) = interpretWithdrawToViaBytes(_bytes);
                require(hydroToken.transferFrom(sender, via, amount), "Unable to transfer token ownership.");
                viaContract = ViaContract(via);
                viaContract.snowflakeCall(resolver, to, amount, _snowflakeCallBytes);
            }
        }
    }

    function interpretDepositBytes(address sender, bytes _bytes) private view returns (uint) {
        uint recipient;
        if (_bytes.length != 32) {
            recipient = identityRegistry.getEIN(sender);
        } else {
            recipient = _bytes.toUint(0);
            require(identityRegistry.identityExists(recipient), "The recipient EIN does not exist.");
        }
        return recipient;
    }

    function interpretTransferToViaBytes(bytes _bytes) private pure returns (address, address, uint, bytes) {
        require(_bytes.length >= 73, "Incorrectly formatted bytes argument.");
        return(
            _bytes.toAddress(1),
            _bytes.toAddress(21),
            _bytes.toUint(41),
            _bytes.slice(73, _bytes.length.sub(73))
        );
    }

    function interpretWithdrawToViaBytes(bytes _bytes) private pure returns (address, address, address, bytes) {
        require(_bytes.length >= 61, "Incorrectly formatted bytes argument.");
        return(
            _bytes.toAddress(1),
            _bytes.toAddress(21),
            _bytes.toAddress(41),
            _bytes.slice(61, _bytes.length.sub(61))
        );
    }


    // transfer snowflake balance from one snowflake holder to another
    function transferSnowflakeBalance(uint einTo, uint amount) public {
        _transfer(identityRegistry.getEIN(msg.sender), einTo, amount);
    }

    // withdraw Snowflake balance to an external address
    function withdrawSnowflakeBalance(address to, uint amount) public {
        _withdraw(identityRegistry.getEIN(msg.sender), to, amount);
    }

    // allows resolvers to transfer allowance amounts to other snowflakes (throws if unsuccessful)
    function transferSnowflakeBalanceFrom(uint einFrom, uint einTo, uint amount) public {
        handleAllowance(einFrom, amount);
        _transfer(einFrom, einTo, amount);
    }

    // allows resolvers to withdraw allowance amounts to external addresses (throws if unsuccessful)
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, to, amount);
    }

    // allows resolvers to send withdrawal amounts to arbitrary smart contracts 'to' identities (throws if unsuccessful)
    function transferSnowflakeBalanceFromVia(uint einFrom, address via, uint einTo, uint amount, bytes _bytes) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, einFrom, einTo, amount, _bytes);
    }

    // allows resolvers to send withdrawal amounts 'to' addresses via arbitrary smart contracts
    function withdrawSnowflakeBalanceFromVia(uint einFrom, address via, address to, uint amount, bytes _bytes) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, einFrom, to, amount, _bytes);
    }

    function _transfer(uint einFrom, uint einTo, uint amount) private identityExists(einTo, true) returns (bool) {
        require(deposits[einFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[einFrom] = deposits[einFrom].sub(amount);
        deposits[einTo] = deposits[einTo].add(amount);

        emit SnowflakeTransfer(einFrom, einTo, amount);
    }

    function _withdraw(uint einFrom, address to, uint amount) internal {
        require(to != address(this), "Cannot transfer to the Snowflake smart contract itself.");

        require(deposits[einFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[einFrom] = deposits[einFrom].sub(amount);
        require(hydroToken.transfer(to, amount), "Transfer was unsuccessful");

        emit SnowflakeWithdraw(einFrom, to, amount);
    }

    function handleAllowance(uint einFrom, uint amount) internal {
        // check that resolver-related details are correct
        require(identityRegistry.isResolverFor(einFrom, msg.sender), "Resolver has not been set by from tokenholder.");

        if (resolverAllowances[einFrom][msg.sender] < amount) {
            emit InsufficientAllowance(einFrom, msg.sender, resolverAllowances[einFrom][msg.sender], amount);
            require(false, "Insufficient Allowance");
        }

        resolverAllowances[einFrom][msg.sender] = resolverAllowances[einFrom][msg.sender].sub(amount);
    }


    function initiateRecoveryAddressChange(address newAddress) public {
        initiateRecoveryAddressChange(identityRegistry.getEIN(msg.sender), newAddress);
    }

    function initiateRecoveryAddressChange(address approvingAddress, address newAddress, uint8 v, bytes32 r, bytes32 s)
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        uint nonce = signatureNonce[ein]++;
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize this change of Recovery Address.",
                        ein, newAddress, nonce
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        initiateRecoveryAddressChange(identityRegistry.getEIN(msg.sender), newAddress);
    }

    function initiateRecoveryAddressChange(uint ein, address newAddress) public {
        require(newAddress != address(0), "Cannot set the recovery address to the zero address.");
        identityRegistry.initiateRecoveryAddressChangeFor(ein, newAddress);
    }


    // events
    event ProvidersAddedFromSnowflake(uint ein, address[] providers, address approvingAddress);
    event ProvidersRemovedFromSnowflake(uint ein, address[] providers, address approvingAddress);
    event ProvidersUpgradedFromSnowflake(
        uint ein, address[] newProviders, address[] oldProviders, address approvingAddress
    );

    event SnowflakeResolverAdded(uint ein, address resolver, uint withdrawAllowance);
    event SnowflakeResolverAllowanceChanged(uint ein, address resolver, uint withdrawAllowance);
    event SnowflakeResolverRemoved(uint ein, address resolver);

    event SnowflakeDeposit(address indexed from, uint indexed einTo, uint amount);
    event SnowflakeTransfer(uint indexed einFrom, uint indexed einTo, uint amount);
    event SnowflakeWithdraw(uint indexed einFrom, address indexed to, uint amount);
    event InsufficientAllowance(uint indexed ein, address resolver, uint currentAllowance, uint requestedWithdraw);
}
