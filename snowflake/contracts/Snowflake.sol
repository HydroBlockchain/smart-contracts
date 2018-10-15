pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/math/SafeMath.sol";

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
}

contract IdentityRegistry {
    function mintIdentityDelegated(address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s) public returns (uint ein);
    function identityExists(uint ein) public view returns (bool);
    function getEIN(address _address) public view returns (uint ein);
    function hasIdentity(address _address) public view returns (bool);

    function addProviders(uint ein, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function removeProviders(uint ein, address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function addResolvers(uint ein, address[] resolvers) public;
    function removeResolvers(uint ein, address[] resolvers) public;
    function isResolverFor(uint ein, address resolver) public view returns (bool);
    function addAddress(
        uint ein,
        address approvingAddress,
        address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt) public;
    function removeAddress(uint ein, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public;
    function initiateRecoveryAddressChange(uint ein, address newRecoveryAddress) public;
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s) public;
}

contract Snowflake is Ownable {
    using SafeMath for uint;

    // hydro token wrapper variable
    mapping (uint => uint) internal deposits;

    // signature variables
    uint signatureTimeout;
    mapping (bytes32 => bool) signatureLog;

    // lookup mappings -- accessible only by wrapper functions
    mapping (uint => mapping (address => uint)) internal resolverAllowances;

    // admin/contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;

    IdentityRegistry registry;
    ERC20 hydro;

    constructor (address _identityRegistryAddress, address _hydroTokenAddress) public {
        setSignatureTimeout(27000);
        registry = IdentityRegistry(_identityRegistryAddress);
        hydro = ERC20(_hydroTokenAddress);
    }

    // checks whether the given address is owned by a token (does not throw)
    function hasToken(address _address) public view returns (bool) {
        return registry.hasIdentity(msg.sender);
    }

    // enforces that a particular address has a token
    modifier _hasToken(address _address, bool check) {
        require(hasToken(_address) == check, "The transaction sender does not have an Identity token.");
        _;
    }

    // set the signature timeout
    function setSignatureTimeout(uint newTimeout) public {
        require(newTimeout >= 1800, "Timeout must be at least 30 minutes.");
        require(newTimeout <= 604800, "Timeout must be less than a week.");
        signatureTimeout = newTimeout;
    }

    // set the raindrop and hydro token addresses
    function setAddresses(address hydroToken) public onlyOwner {
        hydroTokenAddress = hydroToken;
        hydro = ERC20(hydroTokenAddress);
    }

    function mintIdentityDelegated(address mintIdentityDelegated, address identityAddress, uint8 v, bytes32 r, bytes32 s) public {
        registry.mintIdentityDelegated(mintIdentityDelegated, identityAddress, v, r, s);
    }

    function addResolvers(address[] resolvers, uint[] withdrawAllowances) public _hasToken(msg.sender, true) {
        _addResolvers(registry.getEIN(msg.sender), resolvers, withdrawAllowances);
    }

    function addResolversDelegated(
        address _address, address[] resolvers, uint[] withdrawAllowances, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) public
    {
        uint ein = registry.getEIN(_address);
        require(registry.identityExists(ein), "Must initiate claim for a valid identity");
        // solium-disable-next-line security/no-block-members
        require(timestamp.add(signatureTimeout) > block.timestamp, "Message was signed too long ago.");

        require(
            registry.isSigned(
                _address,
                keccak256(abi.encodePacked("Add Resolvers", resolvers, withdrawAllowances, timestamp)),
                v, r, s
            ),
            "Permission denied."
        );

        _addResolvers(ein, resolvers, withdrawAllowances);
    }

    function _addResolvers(
        uint ein, address[] resolvers, uint[] withdrawAllowances
    ) internal {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(!registry.isResolverFor(ein, resolvers[i]), "Identity has already set this resolver.");

            SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
            resolverAllowances[ein][resolvers[i]] = withdrawAllowances[i];
            if (snowflakeResolver.callOnSignUp()) {
                require(
                    snowflakeResolver.onSignUp(ein, withdrawAllowances[i]),
                    "Sign up failure."
                );
            }
            emit ResolverAdded(ein, resolvers[i], withdrawAllowances[i]);
        }

        registry.addResolvers(ein, resolvers);
    }

    function removeResolvers(address[] resolvers, bool force) public _hasToken(msg.sender, true) {
        uint ein = registry.getEIN(msg.sender)

        for (uint i; i < resolvers.length; i++) {
            require(registry.isResolverFor(ein, resolvers[i]), "Snowflake has not set this resolver.");

            delete resolverAllowances[ein][resolvers[i]];
            if (!force) {
                SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
                if (snowflakeResolver.callOnRemoval()) {
                    require(
                        snowflakeResolver.onRemoval(ein),
                        "Removal failure."
                    );
                }
            }
            emit ResolverRemoved(ein, resolvers[i]);
        }

        registry.removeResolvers(ein, resolvers);
    }

    function changeResolverAllowances(address[] resolvers, uint[] withdrawAllowances)
        public _hasToken(msg.sender, true)
    {
        _changeResolverAllowances(registry.getEIN(msg.sender), resolvers, withdrawAllowances);
    }

    function changeResolverAllowancesDelegated(
        address _address, address[] resolvers, uint[] withdrawAllowances, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) public
    {
        uint ein = registry.getEIN(_address);
        require(registry.identityExists(ein), "Must add Resolver for a valid identity");

        bytes32 _hash = keccak256(
            abi.encodePacked("Change Resolver Allowances", resolvers, withdrawAllowances, timestamp)
        );

        require(signatureLog[_hash] == false, "Signature was already submitted");
        signatureLog[_hash] = true;

        require(registry.isSigned(_address, _hash, v, r, s), "Permission denied.");

        _changeResolverAllowances(ein, resolvers, withdrawAllowances);
    }

    function _changeResolverAllowances(uint ein, address[] resolvers, uint[] withdrawAllowances) internal {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(registry.isResolverFor(ein, resolvers[i]), "Identity has not set this resolver.");
            resolverAllowances[ein][resolvers[i]] = withdrawAllowances[i];
            emit ResolverAllowanceChanged(ein, resolvers[i], withdrawAllowances[i]);
        }
    }

    // check resolver allowances (does not throw)
    function getResolverAllowance(uint ein, address resolver) public view returns (uint withdrawAllowance) {
        return resolverAllowances[ein][resolver];
    }

    function addAddress(
        uint ein,
        address approvingAddress,
        address addressToAdd,
        uint8[2] v, bytes32[2] r, bytes32[2] s, uint salt
    ) public {
        registry.addAddress(ein, approvingAddress, addressToAdd, v, r, s, salt);
    }

    function removeAddress(uint ein, address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        registry.removeAddress(ein, addressToRemove, v, r, s, salt);
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes _bytes) public {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        address recipient;
        if (_bytes.length == 20) {
            assembly { // solium-disable-line security/no-inline-assembly
                recipient := div(mload(add(add(_bytes, 0x20), 0)), 0x1000000000000000000000000)
            }
        } else {
            recipient = sender;
        }
        require(hasToken(recipient), "Invalid token recipient");

        require(hydro.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");

        uint recipientEIN = registry.getEIN(recipient);
        deposits[recipientEIN] = deposits[recipientEIN].add(amount);

        emit SnowflakeDeposit(recipientEIN, sender, amount);
    }

    function snowflakeBalance(uint ein) public view returns (uint) {
        return deposits[ein];
    }

    // transfer snowflake balance from one snowflake holder to another
    function transferSnowflakeBalance(uint einTo, uint amount) public _hasToken(msg.sender, true) {
        _transfer(registry.getEIN(msg.sender), einTo, amount);
    }

    // withdraw Snowflake balance to an external address
    function withdrawSnowflakeBalance(address to, uint amount) public _hasToken(msg.sender, true) {
        _withdraw(registry.getEIN(msg.sender), to, amount);
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

    // allows resolvers to send withdrawal amounts to arbitrary smart contracts 'to' identitys (throws if unsuccessful)
    function withdrawSnowflakeBalanceFromVia(
        uint einFrom, address via, uint einFrom, uint amount, bytes _bytes
    ) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, einFrom, einTo, amount, _bytes);
    }

    // allows resolvers to send withdrawal amounts 'to' addresses via arbitrary smart contracts
    function withdrawSnowflakeBalanceFromVia(
        uint einFrom, address via, address to, uint amount, bytes _bytes
    ) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        ViaContract viaContract = ViaContract(via);
        viaContract.snowflakeCall(msg.sender, einFrom, to, amount, _bytes);
    }

    function _transfer(uint einFrom, uint einTo, uint amount) internal returns (bool) {
        require(registry.identityExists(einTo), "Must transfer to a valid identity");

        require(deposits[einFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[einFrom] = deposits[einFrom].sub(amount);
        deposits[einTo] = deposits[einTo].add(amount);

        emit SnowflakeTransfer(einFrom, einTo, amount);
    }

    function _withdraw(uint einFrom, address to, uint amount) internal {
        require(to != address(this), "Cannot transfer to the Snowflake smart contract itself.");

        require(deposits[einFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[einFrom] = deposits[einFrom].sub(amount);
        require(hydro.transfer(to, amount), "Transfer was unsuccessful");
        emit SnowflakeWithdraw(to, amount);
    }

    function handleAllowance(uint einFrom, uint amount) internal {
        require(registry.identityExists(einFrom), "Must call alloance for a valid identity.");

        // check that resolver-related details are correct
        require(registry.isResolverFor(einFrom, msg.sender), "Resolver has not been set by from tokenholder.");

        if (resolverAllowances[einFrom][msg.sender] < amount) {
            emit InsufficientAllowance(einFrom, msg.sender, resolverAllowances[einFrom][msg.sender], amount);
            require(false, "Insufficient Allowance");
        }

        resolverAllowances[einFrom][msg.sender] = resolverAllowances[einFrom][msg.sender].sub(amount);
    }

    function initiateRecoveryAddressChange(address _newAddress) public {
        require(_newAddress != address(0));
        uint ein = registry.getEIN(_address);
        require(registry.identityExists(ein), "Must initiate change for a valid identity");

        registry.initiateRecoveryAddressChange(ein, _newAddress);
    }

    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s) public {
        registry.triggerRecovery(ein, newAssociatedAddress, v, r, s);
    }

    function addProvidersDelegated(address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        uint ein = registry.getEIN(approvingAddress);
        require(registry.identityExists(ein), "Must add Provider for a valid identity");

        registry.addProviders(ein, providers, approvingAddress, v, r, s, salt);
    }

    function removeProvidersDelegated(address[] providers, address approvingAddress, uint8 v, bytes32 r, bytes32 s, uint salt) public {
        uint ein = registry.getEIN(approvingAddress);
        require(registry.identityExists(ein), "Must remove Provider from a valid identity");

        registry.removeProviders(ein, providers, approvingAddress, v, r, s, salt);
    }


    // events
    event SnowflakeMinted(uint ein);

    event ResolverAdded(uint ein, address resolver, uint withdrawAllowance);
    event ResolverAllowanceChanged(uint ein, address resolver, uint withdrawAllowance);
    event ResolverRemoved(uint ein, address resolver);

    event SnowflakeDeposit(uint ein, address from, uint amount);
    event SnowflakeTransfer(uint einFrom, uint einTo, uint amount);
    event SnowflakeWithdraw(address to, uint amount);
    event InsufficientAllowance(
        uint ein, address indexed resolver, uint currentAllowance, uint requestedWithdraw
    );

    event AddressClaimed(address indexed _address, uint ein);
    event AddressUnclaimed(address indexed _address, uint ein);
}
