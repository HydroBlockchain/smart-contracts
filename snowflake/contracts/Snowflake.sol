pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20.sol";
import "./zeppelin/math/SafeMath.sol";

import "./libraries/addressSet.sol";

contract SnowflakeResolver {
    function onSignUp(string hydroId, uint allowance) public returns (bool);
}

contract ClientRaindrop {
    function getUserByAddress(address _address) external view returns (string userName);
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (bool);
}

contract Snowflake is Ownable {
    using SafeMath for uint;
    using addressSet for addressSet._addressSet;

    // hydro token wrapper variable
    mapping (string => uint) internal deposits;

    // lookup mappings -- accessible only by wrapper functions
    mapping (string => Identity) internal directory;
    mapping (address => string) internal addressDirectory;
    mapping (bytes32 => string) internal initiatedAddressClaims;

    // admin/contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;

    uint public resolverWhitelistFee;
    addressSet._addressSet resolverWhitelist;

    // identity structures
    struct Identity {
        address owner;
        addressSet._addressSet addresses;
        addressSet._addressSet resolvers;
        mapping(address => uint) resolverAllowances;
    }

    // checks whether the given address is owned by a token (does not throw)
    function hasToken(address _address) public view returns (bool) {
        return bytes(addressDirectory[_address]).length != 0;
    }

    // enforces that a particular address has a token
    modifier _hasToken(address _address, bool check) {
        require(hasToken(_address) == check, "The transaction sender does not have a Snowflake.");
        _;
    }

    // gets the HydroID for an address (throws if address doesn't have a HydroID or doesn't have a snowflake)
    function getHydroId(address _address) public view returns (string hydroId) {
        require(hasToken(_address), "The address does not have a hydroId");
        return addressDirectory[_address];
    }

    // set the fee to become a resolver
    function setResolverWhitelistFee(uint fee) public onlyOwner {
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(fee <= (hydro.totalSupply() / 100 / 10), "Fee is too high.");
        resolverWhitelistFee = fee;
    }

    // allows whitelisting of resolvers
    // TODO add additional requirements to become a resolver here?
    function whitelistResolver(address resolver) public _hasToken(msg.sender, true) {
        if (resolverWhitelistFee > 0) {
            require(_withdraw(addressDirectory[msg.sender], owner, resolverWhitelistFee), "Fee was not paid.");
        }
        resolverWhitelist.insert(resolver);
        emit ResolverWhitelisted(resolver, msg.sender);
    }

    function isWhitelisted(address resolver) public view returns(bool) {
        return resolverWhitelist.contains(resolver);
    }

    function getWhitelistedResolvers() public view returns(address[]) {
        return resolverWhitelist.members;
    }

    // set the raindrop and hydro token addresses
    function setAddresses(address clientRaindrop, address hydroToken) public onlyOwner {
        clientRaindropAddress = clientRaindrop;
        hydroTokenAddress = hydroToken;
    }

    // token minting
    function mintIdentityToken() public _hasToken(msg.sender, false) {
        _mintIdentityToken(msg.sender);
    }

    function mintIdentityTokenDelegated(address _address, uint8 v, bytes32 r, bytes32 s)
        public _hasToken(_address, false)
    {
        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        require(
            clientRaindrop.isSigned(
                _address, keccak256(abi.encodePacked("Create Snowflake", _address)), v, r, s
            ),
            "Permission denied."
        );
        _mintIdentityToken(_address);
    }

    function _mintIdentityToken(address _address) internal {
        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        string memory hydroId = clientRaindrop.getUserByAddress(_address);

        Identity storage identity = directory[hydroId];

        identity.owner = _address;
        identity.addresses.insert(_address);

        addressDirectory[_address] = hydroId;

        emit SnowflakeMinted(hydroId);
    }

    // wrappers that enable modifying resolvers
    function addResolvers(address[] resolvers, uint[] withdrawAllowances) public _hasToken(msg.sender, true) {
        require(resolvers.length == withdrawAllowances.length && resolvers.length < 10, "Malformed inputs.");

        Identity storage identity = directory[addressDirectory[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(resolverWhitelist.contains(resolvers[i]), "The given resolver is not on the whitelist.");
            require(!identity.resolvers.contains(resolvers[i]), "Snowflake has already set this resolver.");
            SnowflakeResolver snowflakeResolver = SnowflakeResolver(resolvers[i]);
            identity.resolvers.insert(resolvers[i]);
            identity.resolverAllowances[resolvers[i]] = withdrawAllowances[i];
            require(
                snowflakeResolver.onSignUp(addressDirectory[msg.sender], withdrawAllowances[i]),
                "Sign up failure."
            );
            emit ResolverAdded(addressDirectory[msg.sender], resolvers[i], withdrawAllowances[i]);
        }
    }

    function changeResolverAllowances(address[] resolvers, uint[] withdrawAllowances)
        public _hasToken(msg.sender, true)
    {
        require(resolvers.length == withdrawAllowances.length && resolvers.length < 10, "Malformed inputs.");

        Identity storage identity = directory[addressDirectory[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(identity.resolvers.contains(resolvers[i]), "Snowflake has not set this resolver.");
            identity.resolverAllowances[resolvers[i]] = withdrawAllowances[i];
            emit ResolverAllowanceChanged(addressDirectory[msg.sender], resolvers[i], withdrawAllowances[i]);
        }
    }

    function removeResolvers(address[] resolvers) public _hasToken(msg.sender, true) {
        Identity storage identity = directory[addressDirectory[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(identity.resolvers.contains(resolvers[i]), "Snowflake has not set this resolver.");
            identity.resolvers.remove(resolvers[i]);
            delete identity.resolverAllowances[resolvers[i]];
            emit ResolverRemoved(addressDirectory[msg.sender], resolvers[i]);
        }
    }

    // functions to read token values (does not throw)
    function getDetails(string hydroId) public view returns (
        address owner,
        address[] resolvers,
        address[] ownedAddresses
    ) {
        Identity storage identity = directory[hydroId];
        return (
            identity.owner,
            identity.resolvers.members,
            identity.addresses.members
        );
    }

    // check resolver membership (does not throw)
    function hasResolver(string hydroId, address resolver) public view returns (bool) {
        Identity storage identity = directory[hydroId];
        return identity.resolvers.contains(resolver);
    }

    // check address ownership (does not throw)
    function ownsAddress(string hydroId, address _address) public view returns (bool) {
        Identity storage identity = directory[hydroId];
        return identity.addresses.contains(_address);
    }

    // check resolver allowances (does not throw)
    function getResolverAllowance(string hydroId, address resolver) public view returns (uint withdrawAllowance) {
        Identity storage identity = directory[hydroId];
        return identity.resolverAllowances[resolver];
    }

    // allow contract to receive HYDRO tokens
    function receiveApproval(address sender, uint amount, address _tokenAddress, bytes) public _hasToken(sender, true) {
        require(msg.sender == _tokenAddress, "Malformed inputs.");
        require(_tokenAddress == hydroTokenAddress, "Sender is not the HYDRO token smart contract.");

        ERC20 hydro = ERC20(_tokenAddress);
        require(hydro.transferFrom(sender, address(this), amount), "Unable to transfer token ownership.");

        deposits[addressDirectory[sender]] = deposits[addressDirectory[sender]].add(amount);

        emit SnowflakeDeposit(addressDirectory[sender], amount);
    }

    function snowflakeBalance(string hydroId) public view returns (uint) {
        return deposits[hydroId];
    }

    // transfer snowflake balance to another Snowflake holder (throws if unsuccessful)
    function transferSnowflakeBalance(string hydroIdTo, uint amount) public _hasToken(msg.sender, true) {
        require(directory[hydroIdTo].owner != address(0), "Must transfer to an HydroID with a Snowflake");
        require(amount > 0, "Amount cannot be 0.");

        string storage hydroIdFrom = addressDirectory[msg.sender];
        require(deposits[hydroIdFrom] >= amount, "Your balance is too low to transfer this amount.");
        deposits[hydroIdFrom] = deposits[hydroIdFrom].sub(amount);
        deposits[hydroIdTo] = deposits[hydroIdTo].add(amount);
        emit SnowflakeTransfer(hydroIdFrom, hydroIdTo, amount);
    }

    // withdraw Snowflake balance to an external address
    function withdrawSnowflakeBalanceTo(address to, uint amount) public _hasToken(msg.sender, true) {
        require(_withdraw(addressDirectory[msg.sender], to, amount), "Transfer was unsuccessful.");
    }

    // allows resolvers to withdraw to an external address from snowflakes that have approved them
    function withdrawFrom(string hydroIdFrom, address to, uint amount) public returns (bool) {
        Identity storage identity = directory[hydroIdFrom];
        require(identity.owner != address(0), "Must withdraw from a HydroID with a Snowflake");
        require(identity.resolvers.contains(msg.sender), "Resolver has not been set by from tokenholder.");
        
        if (identity.resolverAllowances[msg.sender] < amount) {
            emit InsufficientAllowance(hydroIdFrom, msg.sender, identity.resolverAllowances[msg.sender], amount);
            return false;
        } else {
            if (_withdraw(hydroIdFrom, to, amount)) {
                identity.resolverAllowances[msg.sender] = identity.resolverAllowances[msg.sender].sub(amount);
                return true;
            } else {
                return false;
            }
        }
    }

    function _withdraw(string hydroIdFrom, address to, uint amount) internal returns (bool) {
        require(to != address(this), "Cannot transfer to the Snowflake smart contract itself.");
        require(amount > 0, "Amount cannot be 0.");

        require(deposits[hydroIdFrom] >= amount, "Cannot withdraw more than the current deposit balance.");
        deposits[hydroIdFrom] = deposits[hydroIdFrom].sub(amount);
        ERC20 hydro = ERC20(hydroTokenAddress);
        if (hydro.transfer(to, amount)) {
            emit SnowflakeWithdraw(to, amount);
            return true;
        } else {
            return false;
        }
    }

    // address ownership functions
    // to claim an address, users need to send a transaction from their snowflake address containing a sealed claim
    // sealedClaims are: keccak256(abi.encodePacked(<address>, <secret>, <hydroId>)),
    // where <address> is the address you'd like to claim, and <secret> is a SECRET bytes32 value.
    function initiateClaimFor(string hydroId, bytes32 sealedClaim, uint8 v, bytes32 r, bytes32 s) public {
        require(directory[hydroId].owner != address(0), "Must initiate claim for a HydroID with a Snowflake");

        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        require(
            clientRaindrop.isSigned(
                directory[hydroId].owner, keccak256(abi.encodePacked("Initiate Claim", sealedClaim)), v, r, s
            ),
            "Permission denied."
        );

        _initiateClaim(hydroId, sealedClaim);
    }

    function initiateClaim(bytes32 sealedClaim) public _hasToken(msg.sender, true) {
        _initiateClaim(addressDirectory[msg.sender], sealedClaim);
    }

    function _initiateClaim(string hydroId, bytes32 sealedClaim) internal {
        require(bytes(initiatedAddressClaims[sealedClaim]).length == 0, "This sealed claim has been submitted.");
        initiatedAddressClaims[sealedClaim] = hydroId;
    }

    function finalizeClaim(bytes32 secret, string hydroId) public {
        bytes32 possibleSealedClaim = keccak256(abi.encodePacked(msg.sender, secret, hydroId));
        require(
            bytes(initiatedAddressClaims[possibleSealedClaim]).length != 0, "This sealed claim hasn't been submitted."
        );

        // ensure that the claim wasn't stolen by another HydroID during initialization
        require(
            keccak256(abi.encodePacked(initiatedAddressClaims[possibleSealedClaim])) ==
            keccak256(abi.encodePacked(hydroId)),
            "Invalid signature."
        );

        directory[hydroId].addresses.insert(msg.sender);
        addressDirectory[msg.sender] = hydroId;

        emit AddressClaimed(msg.sender, hydroId);
    }

    function unclaim(address _address) public _hasToken(msg.sender, true) {
        require(_address != directory[addressDirectory[msg.sender]].owner, "Cannot unclaim owner address.");
        directory[addressDirectory[msg.sender]].addresses.remove(_address);
        delete addressDirectory[_address];
        emit AddressUnclaimed(_address, addressDirectory[msg.sender]);
    }

    // events
    event SnowflakeMinted(string hydroId);

    event ResolverWhitelisted(address indexed resolver, address sponsor);

    event ResolverAdded(string hydroId, address resolver, uint withdrawAllowance);
    event ResolverAllowanceChanged(string hydroId, address resolver, uint withdrawAllowance);
    event ResolverRemoved(string hydroId, address resolver);

    event SnowflakeDeposit(string hydroId, uint amount);
    event SnowflakeTransfer(string hydroIdFrom, string hydroIdTo, uint amount);
    event SnowflakeWithdraw(address indexed hydroId, uint amount);
    event InsufficientAllowance(
        string hydroId, address indexed resolver, uint currentAllowance, uint requestedWithdraw
    );

    event AddressClaimed(address indexed _address, string hydroId);
    event AddressUnclaimed(address indexed _address, string hydroId);
}