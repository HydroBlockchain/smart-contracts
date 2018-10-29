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

interface IdentityRegistryInterface {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) external view returns (bool);

    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAddressFor(uint ein, address _address) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s
    )
        external returns (uint ein);
    function addAddress(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        external;
    function removeAddress(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) external;
    function addProviders(uint ein, address[] providers) external;
    function removeProviders(uint ein, address[] providers) external;
    function addResolvers(uint ein, address[] resolvers) external;
    function removeResolvers(uint ein, address[] resolvers) external;

    function initiateRecoveryAddressChange(uint ein, address newRecoveryAddress) external;
}

interface ClientRaindropInterface {
    function signUp(uint ein, string casedHydroID, address _address) external;
}

contract Snowflake is Ownable {
    using SafeMath for uint;

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
        require(identityRegistry.isAddressFor(ein, _address), "Address is not associated with EIN.");
        _;
    }

    // enforces signature timeouts
    modifier timestampIsValid(uint timestamp) {
        // solium-disable-next-line security/no-block-members
        require(timestamp.add(signatureTimeout) > block.timestamp, "Message was signed too long ago.");
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


    // wrap mintIdentityDelegated
    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] resolvers, uint8 v, bytes32 r, bytes32 s
    )
        public returns (uint ein)
    {
        return identityRegistry.mintIdentityDelegated(recoveryAddress, associatedAddress, resolvers, v, r, s);
    }

    // wrap mintIdentityDelegated and initialize the client raindrop resolver
    function mintIdentityDelegated(
        address recoveryAddress, address associatedAddress, string casedHydroId, uint8 v, bytes32 r, bytes32 s
    )
        public returns (uint ein)
    {
        address[] memory clientRaindropResolver = new address[](1);
        clientRaindropResolver[0] = clientRaindropAddress;
        uint _ein = identityRegistry.mintIdentityDelegated(
            recoveryAddress, associatedAddress, clientRaindropResolver, v, r, s
        );

        signUpClientRaindrop(_ein, casedHydroId, associatedAddress);

        return _ein;
    }

    function signUpClientRaindrop(uint ein, string casedHydroId, address associatedAddress) public onlyOwner() {
        clientRaindrop.signUp(ein, casedHydroId, associatedAddress);
    }

    // wrap addAddress
    function addAddress(
        address approvingAddress, address addressToAdd, uint8[2] v, bytes32[2] r, bytes32[2] s, uint[2] timestamp
    )
        public
    {
        identityRegistry.addAddress(approvingAddress, addressToAdd, v, r, s, timestamp);
    }

    // wrap removeAddress
    function removeAddress(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp) public {
        identityRegistry.removeAddress(addressToRemove, v, r, s, timestamp);
    }

    // delegated addProviders
    function addProviders(address approvingAddress, address[] providers, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        public timestampIsValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        "I authorize that these Providers be added to my Identity", ein, providers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.addProviders(ein, providers);
        emit ProvidersAddedFromSnowflake(ein, providers, approvingAddress);
    }

    // delegated removeProviders
    function removeProviders(
        address approvingAddress, address[] providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public timestampIsValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        "I authorize that these Providers be removed from my Identity", ein, providers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.removeProviders(ein, providers);
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
        public timestampIsValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(abi.encodePacked("Add Resolvers", ein, resolvers, withdrawAllowances, timestamp)),
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
            if (isSnowflake[i]) {
                resolverAllowances[ein][resolvers[i]] = withdrawAllowances[i];
                SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
                if (snowflakeResolver.callOnSignUp()) {
                    require(snowflakeResolver.onSignUp(ein, withdrawAllowances[i]), "Sign up failure.");
                }
                emit SnowflakeResolverAdded(ein, resolvers[i], withdrawAllowances[i]);
            }
        }

        identityRegistry.addResolvers(ein, resolvers);
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
        bytes32 messageHash = keccak256(
            abi.encodePacked("Change Allowance", ein, resolvers, withdrawAllowances, nonce)
        );
        require(identityRegistry.isSigned(approvingAddress, messageHash, v, r, s), "Permission denied.");

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
        public timestampIsValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);

        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        "I authorize that these Resolvers be removed from my Identity.", ein, resolvers, timestamp
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

        identityRegistry.removeResolvers(ein, resolvers);
    }

    // convert bytes to uint
    function bytesToUint(bytes memory _bytes) private pure returns (uint) {
        require(_bytes.length == 32, "Argument is not 32 bytes.");

        uint converted;
        assembly { converted := mload(add(add(_bytes, 32), 0)) } // solium-disable-line security/no-inline-assembly

        return converted;
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes _bytes) public {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        uint recipient;
        if (_bytes.length != 0) {
            recipient = bytesToUint(_bytes);
            require(identityRegistry.identityExists(recipient), "The recipient EIN does not exist.");
        } else {
            recipient = identityRegistry.getEIN(sender);
        }

        require(hydroToken.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");

        deposits[recipient] = deposits[recipient].add(amount);

        emit SnowflakeDeposit(sender, recipient, amount);
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
                    abi.encodePacked("I authorize this change of Recovery Address.", ein, newAddress, nonce)
                ),
                v, r, s
            ),
            "Permission denied."
        );

        initiateRecoveryAddressChange(identityRegistry.getEIN(msg.sender), newAddress);
    }

    function initiateRecoveryAddressChange(uint ein, address newAddress) public {
        require(newAddress != address(0), "Cannot set the recovery address to the zero address.");
        identityRegistry.initiateRecoveryAddressChange(ein, newAddress);
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
