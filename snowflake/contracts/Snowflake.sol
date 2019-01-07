pragma solidity ^0.5.0;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/math/SafeMath.sol";

import "./interfaces/HydroInterface.sol";
import "./interfaces/SnowflakeResolverInterface.sol";
import "./interfaces/SnowflakeViaInterface.sol";
import "./interfaces/IdentityRegistryInterface.sol";
import "./interfaces/ClientRaindropInterface.sol";

contract Snowflake is Ownable {
    using SafeMath for uint;

    // mapping of EIN to hydro token deposits
    mapping (uint => uint) public deposits;
    // mapping from EIN to resolver to allowance
    mapping (uint => mapping (address => uint)) public resolverAllowances;

    // SC variables
    address public identityRegistryAddress;
    IdentityRegistryInterface private identityRegistry;
    address public hydroTokenAddress;
    HydroInterface private hydroToken;
    address public clientRaindropAddress;
    ClientRaindropInterface private clientRaindrop;

    // signature variables
    uint public signatureTimeout = 1 days;
    mapping (uint => uint) public signatureNonce;

    constructor (address _identityRegistryAddress, address _hydroTokenAddress) public {
        setAddresses(_identityRegistryAddress, _hydroTokenAddress);
    }

    // enforces that a particular EIN exists
    modifier identityExists(uint ein, bool check) {
        require(identityRegistry.identityExists(ein) == check, "The EIN does not exist.");
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
        hydroToken = HydroInterface(hydroTokenAddress);
    }

    function setClientRaindropAddress(address _clientRaindropAddress) public onlyOwner {
        clientRaindropAddress = _clientRaindropAddress;
        clientRaindrop = ClientRaindropInterface(clientRaindropAddress);
    }

    // wrap createIdentityDelegated and initialize the client raindrop resolver
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] memory providers, string memory casedHydroId,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public returns (uint ein)
    {
        address[] memory _providers = new address[](providers.length + 1);
        _providers[0] = address(this);
        for (uint i; i < providers.length; i++) {
            _providers[i + 1] = providers[i];
        }

        uint _ein = identityRegistry.createIdentityDelegated(
            recoveryAddress, associatedAddress, _providers, new address[](0), v, r, s, timestamp
        );

        addResolver(_ein, clientRaindropAddress, true, 0, abi.encode(associatedAddress, casedHydroId));

        return _ein;
    }

    // permission addProvidersFor by signature
    function addProvidersFor(
        address approvingAddress, address[] memory providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
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
                        "I authorize that these Providers be added to my Identity.",
                        ein, providers, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.addProvidersFor(ein, providers);
    }

    // permission removeProvidersFor by signature
    function removeProvidersFor(
        address approvingAddress, address[] memory providers, uint8 v, bytes32 r, bytes32 s, uint timestamp
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
    }

    // permissioned addProvidersFor and removeProvidersFor by signature
    function upgradeProvidersFor(
        address approvingAddress, address[] memory newProviders, address[] memory oldProviders,
        uint8[2] memory v, bytes32[2] memory r, bytes32[2] memory s, uint[2] memory timestamp
    )
        public
    {
        addProvidersFor(approvingAddress, newProviders, v[0], r[0], s[0], timestamp[0]);
        removeProvidersFor(approvingAddress, oldProviders, v[1], r[1], s[1], timestamp[1]);
        uint ein = identityRegistry.getEIN(approvingAddress);
        emit SnowflakeProvidersUpgraded(ein, newProviders, oldProviders, approvingAddress);
    }

    // permission adding a resolver for identity of msg.sender
    function addResolver(address resolver, bool isSnowflake, uint withdrawAllowance, bytes memory extraData) public {
        addResolver(identityRegistry.getEIN(msg.sender), resolver, isSnowflake, withdrawAllowance, extraData);
    }

    // permission addResolversFor by signature
    function addResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, uint withdrawAllowance, bytes memory extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public
    {
        uint ein = identityRegistry.getEIN(approvingAddress);

        validateAddResolverForSignature(
            approvingAddress, ein, resolver, isSnowflake, withdrawAllowance, extraData, v, r, s, timestamp
        );

        addResolver(ein, resolver, isSnowflake, withdrawAllowance, extraData);
    }

    function validateAddResolverForSignature(
        address approvingAddress, uint ein,
        address resolver, bool isSnowflake, uint withdrawAllowance, bytes memory extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        private view ensureSignatureTimeValid(timestamp)
    {
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that this resolver be added to my Identity.",
                        ein, resolver, isSnowflake, withdrawAllowance, extraData, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );
    }

    // common logic for adding resolvers
    function addResolver(uint ein, address resolver, bool isSnowflake, uint withdrawAllowance, bytes memory extraData)
        private
    {
        require(!identityRegistry.isResolverFor(ein, resolver), "Identity has already set this resolver.");

        address[] memory resolvers = new address[](1);
        resolvers[0] = resolver;
        identityRegistry.addResolversFor(ein, resolvers);

        if (isSnowflake) {
            resolverAllowances[ein][resolver] = withdrawAllowance;
            SnowflakeResolverInterface snowflakeResolver = SnowflakeResolverInterface(resolver);
            if (snowflakeResolver.callOnAddition())
                require(snowflakeResolver.onAddition(ein, withdrawAllowance, extraData), "Sign up failure.");
            emit SnowflakeResolverAdded(ein, resolver, withdrawAllowance);
        }
    }

    // permission changing resolver allowances for identity of msg.sender
    function changeResolverAllowances(address[] memory resolvers, uint[] memory withdrawAllowances) public {
        changeResolverAllowances(identityRegistry.getEIN(msg.sender), resolvers, withdrawAllowances);
    }

    // change resolver allowances delegated
    function changeResolverAllowancesDelegated(
        address approvingAddress, address[] memory resolvers, uint[] memory withdrawAllowances,
        uint8 v, bytes32 r, bytes32 s
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
                        "I authorize this change in Resolver allowances.",
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
    function changeResolverAllowances(uint ein, address[] memory resolvers, uint[] memory withdrawAllowances) private {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        for (uint i; i < resolvers.length; i++) {
            require(identityRegistry.isResolverFor(ein, resolvers[i]), "Identity has not set this resolver.");
            require(resolverAllowances[ein][resolvers[i]] == 0, "Allowance is not 0.");
            resolverAllowances[ein][resolvers[i]] = withdrawAllowances[i];
            emit SnowflakeResolverAllowanceChanged(ein, resolvers[i], withdrawAllowances[i]);
        }
    }

    // permission removing a resolver for identity of msg.sender
    function removeResolver(address resolver, bool isSnowflake, bytes memory extraData) public {
        removeResolver(identityRegistry.getEIN(msg.sender), resolver, isSnowflake, extraData);
    }

    // permission removeResolverFor by signature
    function removeResolverFor(
        address approvingAddress, address resolver, bool isSnowflake, bytes memory extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        public ensureSignatureTimeValid(timestamp)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);

        validateRemoveResolverForSignature(approvingAddress, ein, resolver, isSnowflake, extraData, v, r, s, timestamp);

        removeResolver(ein, resolver, isSnowflake, extraData);
    }

    function validateRemoveResolverForSignature(
        address approvingAddress, uint ein, address resolver, bool isSnowflake, bytes memory extraData,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    )
        private view
    {
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize that these Resolvers be removed from my Identity.",
                        ein, resolver, isSnowflake, extraData, timestamp
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );
    }

    // common logic to remove resolvers
    function removeResolver(uint ein, address resolver, bool isSnowflake, bytes memory extraData) private {
        require(identityRegistry.isResolverFor(ein, resolver), "Identity has not yet set this resolver.");
    
        delete resolverAllowances[ein][resolver];
    
        if (isSnowflake) {
            SnowflakeResolverInterface snowflakeResolver = SnowflakeResolverInterface(resolver);
            if (snowflakeResolver.callOnRemoval())
                require(snowflakeResolver.onRemoval(ein, extraData), "Removal failure.");
            emit SnowflakeResolverRemoved(ein, resolver);
        }

        address[] memory resolvers = new address[](1);
        resolvers[0] = resolver;
        identityRegistry.removeResolversFor(ein, resolvers);
    }

    function triggerRecoveryAddressChangeFor(
        address approvingAddress, address newRecoveryAddress, uint8 v, bytes32 r, bytes32 s
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
                        "I authorize this change of Recovery Address.",
                        ein, newRecoveryAddress, nonce
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );

        identityRegistry.triggerRecoveryAddressChangeFor(ein, newRecoveryAddress);
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes memory _bytes) public {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        // depositing to an EIN
        if (_bytes.length <= 32) {
            require(hydroToken.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");
            uint recipient;
            if (_bytes.length < 32) {
                recipient = identityRegistry.getEIN(sender);
            }
            else {
                recipient = abi.decode(_bytes, (uint));
                require(identityRegistry.identityExists(recipient), "The recipient EIN does not exist.");
            }
            deposits[recipient] = deposits[recipient].add(amount);
            emit SnowflakeDeposit(sender, recipient, amount);
        }
        // transferring to a via
        else {
            (
                bool isTransfer, address resolver, address via, uint to, bytes memory snowflakeCallBytes
            ) = abi.decode(_bytes, (bool, address, address, uint, bytes));
            
            require(hydroToken.transferFrom(sender, via, amount), "Unable to transfer token ownership.");

            SnowflakeViaInterface viaContract = SnowflakeViaInterface(via);
            if (isTransfer) {
                viaContract.snowflakeCall(resolver, to, amount, snowflakeCallBytes);
                emit SnowflakeTransferToVia(resolver, via, to, amount);
            } else {
                address payable payableTo = address(to);
                viaContract.snowflakeCall(resolver, payableTo, amount, snowflakeCallBytes);
                emit SnowflakeWithdrawToVia(resolver, via, address(to), amount);
            }
        }
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
        emit SnowflakeTransferFrom(msg.sender);
    }

    // allows resolvers to withdraw allowance amounts to external addresses (throws if unsuccessful)
    function withdrawSnowflakeBalanceFrom(uint einFrom, address to, uint amount) public {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, to, amount);
        emit SnowflakeWithdrawFrom(msg.sender);
    }

    // allows resolvers to send withdrawal amounts to arbitrary smart contracts 'to' identities (throws if unsuccessful)
    function transferSnowflakeBalanceFromVia(uint einFrom, address via, uint einTo, uint amount, bytes memory _bytes)
        public
    {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        SnowflakeViaInterface viaContract = SnowflakeViaInterface(via);
        viaContract.snowflakeCall(msg.sender, einFrom, einTo, amount, _bytes);
        emit SnowflakeTransferFromVia(msg.sender, einTo);
    }

    // allows resolvers to send withdrawal amounts 'to' addresses via arbitrary smart contracts
    function withdrawSnowflakeBalanceFromVia(
        uint einFrom, address via, address payable to, uint amount, bytes memory _bytes
    )
        public
    {
        handleAllowance(einFrom, amount);
        _withdraw(einFrom, via, amount);
        SnowflakeViaInterface viaContract = SnowflakeViaInterface(via);
        viaContract.snowflakeCall(msg.sender, einFrom, to, amount, _bytes);
        emit SnowflakeWithdrawFromVia(msg.sender, to);
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
            emit SnowflakeInsufficientAllowance(einFrom, msg.sender, resolverAllowances[einFrom][msg.sender], amount);
            revert("Insufficient Allowance");
        }

        resolverAllowances[einFrom][msg.sender] = resolverAllowances[einFrom][msg.sender].sub(amount);
    }

    // allowAndCall from msg.sender
    function allowAndCall(address destination, uint amount, bytes memory data)
        public returns (bytes memory returnData)
    {
        return allowAndCall(identityRegistry.getEIN(msg.sender), amount, destination, data);
    }

    // allowAndCall from approvingAddress with meta-transaction
    function allowAndCallDelegated(
        address destination, uint amount, bytes memory data, address approvingAddress, uint8 v, bytes32 r, bytes32 s
    )
        public returns (bytes memory returnData)
    {
        uint ein = identityRegistry.getEIN(approvingAddress);
        uint nonce = signatureNonce[ein]++;
        validateAllowAndCallDelegatedSignature(approvingAddress, ein, destination, amount, data, nonce, v, r, s);

        return allowAndCall(ein, amount, destination, data);
    }

    function validateAllowAndCallDelegatedSignature(
        address approvingAddress, uint ein, address destination, uint amount, bytes memory data, uint nonce,
        uint8 v, bytes32 r, bytes32 s
    )
        private view
    {
        require(
            identityRegistry.isSigned(
                approvingAddress,
                keccak256(
                    abi.encodePacked(
                        byte(0x19), byte(0), address(this),
                        "I authorize this allow and call.", ein, destination, amount, data, nonce
                    )
                ),
                v, r, s
            ),
            "Permission denied."
        );
    }

    // internal logic for allowAndCall
    function allowAndCall(uint ein, uint amount, address destination, bytes memory data)
        private returns (bytes memory returnData)
    {
        // check that resolver-related details are correct
        require(identityRegistry.isResolverFor(ein, destination), "Destination has not been set by from tokenholder.");
        if (amount != 0) {
            resolverAllowances[ein][destination] = resolverAllowances[ein][destination].add(amount);
        }

        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory _returnData) = destination.call(data);
        require(success, "Call was not successful.");
        return _returnData;
    }

    // events
    event SnowflakeProvidersUpgraded(uint indexed ein, address[] newProviders, address[] oldProviders, address approvingAddress);

    event SnowflakeResolverAdded(uint indexed ein, address indexed resolver, uint withdrawAllowance);
    event SnowflakeResolverAllowanceChanged(uint indexed ein, address indexed resolver, uint withdrawAllowance);
    event SnowflakeResolverRemoved(uint indexed ein, address indexed resolver);

    event SnowflakeDeposit(address indexed from, uint indexed einTo, uint amount);
    event SnowflakeTransfer(uint indexed einFrom, uint indexed einTo, uint amount);
    event SnowflakeWithdraw(uint indexed einFrom, address indexed to, uint amount);

    event SnowflakeTransferFrom(address indexed resolverFrom);
    event SnowflakeWithdrawFrom(address indexed resolverFrom);
    event SnowflakeTransferFromVia(address indexed resolverFrom, uint indexed einTo);
    event SnowflakeWithdrawFromVia(address indexed resolverFrom, address indexed to);
    event SnowflakeTransferToVia(address indexed resolverFrom, address indexed via, uint indexed einTo, uint amount);
    event SnowflakeWithdrawToVia(address indexed resolverFrom, address indexed via, address indexed to, uint amount);

    event SnowflakeInsufficientAllowance(
        uint indexed ein, address indexed resolver, uint currentAllowance, uint requestedWithdraw
    );
}
