pragma solidity ^0.4.24;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20/ERC20.sol";
import "./zeppelin/math/SafeMath.sol";

import "./libraries/addressSet.sol";
import "./libraries/bytes32Set.sol";


interface ClientRaindrop {
    function getUserByAddress(address _address) external view returns (string userName);
}


contract Snowflake is Ownable {
    using SafeMath for uint;
    using addressSet for addressSet._addressSet;
    using bytes32Set for bytes32Set._bytes32Set;

    // hydro token wrapper variable
    mapping (address => uint) public deposits;

    // token lookup mappings -- accessible only by wrapper functions
    mapping (string => Identity) internal tokenDirectory;
    mapping (address => string) internal ownerToToken;

    // admin/contract variables
    address public clientRaindropAddress;
    address public hydroTokenAddress;

    addressSet._addressSet resolverWhitelist;
    uint public resolverWhitelistFee;

    // name and date of birth restriction variables
    string[6] public nameOrder = ["prefix", "givenName", "middleName", "surname", "suffix", "preferredName"];
    bytes32Set._bytes32Set allowedNames;
    string[3] public dateOrder = ["day", "month", "year"];
    bytes32Set._bytes32Set allowedDates;

    // identity structures
    struct Identity {
        address owner;
        mapping (bytes32 => SnowflakeField) fields; // mapping of AllowedSnowflakeFields to SnowflakeFields
        bytes32Set._bytes32Set fieldsAttestedTo; // required, field names that the user has attested to
        mapping(address => Resolver) resolvers;
        addressSet._addressSet resolversFor; // optional, set of third-party resolvers
    }

    struct SnowflakeField {
        mapping (bytes32 => Entry) entries; // required, mapping of entry names to encrypted plaintext data.
        bytes32Set._bytes32Set entriesAttestedTo; // required, entry names that the user has attested to
    }

    struct Entry {
        string entryName;
        bytes32 saltedHash; // data should be encoded as: keccak256(abi.encodePacked(data, salt))
        uint blockNumber;
    }

    struct Resolver {
        uint withdrawAllowance; // optional, allows resolvers to programatically extract hydro from users
    }

    // field restriction variables
    string[5] public fieldOrder = ["Name", "DateOfBirth", "Emails", "PhoneNumbers", "PhysicalAddresses"];
    bytes32Set._bytes32Set allowedFields;

    constructor () public {
        // initialize allowed snowflake fields
        for (uint i; i < fieldOrder.length; i++) {
            allowedFields.insert(keccak256(abi.encodePacked(fieldOrder[i])));
        }

        // initialize allowed name entries
        for (uint j; j < nameOrder.length; j++) {
            allowedNames.insert(keccak256(abi.encodePacked(nameOrder[j])));
        }

        // initialize allowed date entries
        for (uint k; k < dateOrder.length; k++) {
            allowedDates.insert(keccak256(abi.encodePacked(dateOrder[k])));
        }
    }

    // enforces that the given (cased) hydroId has a token
    modifier _tokenExists(string hydroId) {
        require(tokenDirectory[hydroId].owner != address(0), "This token has not yet been minted.");
        _;
    }

    // checks whether the given address has a token (does not throw)
    function hasToken(address _address) public view returns (bool) {
        return tokenDirectory[ownerToToken[_address]].owner == _address;
    }

    // enforces that a particular address has a token
    modifier _hasToken(address _address, bool check) {
        require(hasToken(_address) == check, "The transaction sender has not minted a Snowflake.");
        _;
    }

    // gets the hydro id for a particular address (throws if the address does not have a hydroId)
    function getHydroId(address _address) public view returns (string hydroId) {
        require(hasToken(_address), "The address does not have a hydroId");
        return ownerToToken[_address];
    }

    // set the fee to become a resolver
    function setResolverWhitelistFee(uint fee) public onlyOwner {
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(fee <= (hydro.totalSupply() / 100 / 10), "Fee is too high.");
        resolverWhitelistFee = fee;
    }

    // allows whitelisting of resolvers
    function whitelistResolver(address resolver) public {
        transferSnowflakeBalance(owner, resolverWhitelistFee);
        resolverWhitelist.insert(resolver);
        emit ResolverWhitelisted(resolver, msg.sender);
    }

    function isWhitelisted(address resolver) public view returns(bool) {
        return resolverWhitelist.contains(resolver);
    }

    // set the raindrop and hydro token addresses
    function setAddresses(address clientRaindrop, address hydroToken) public onlyOwner {
        clientRaindropAddress = clientRaindrop;
        hydroTokenAddress = hydroToken;
    }

    // token minter
    function mintIdentityToken(bytes32[6] names, bytes32[3] dateOfBirth) public _hasToken(msg.sender, false) {
        ClientRaindrop clientRaindrop = ClientRaindrop(clientRaindropAddress);
        string memory _hydroId = clientRaindrop.getUserByAddress(msg.sender);

        Identity storage identity = tokenDirectory[_hydroId];

        identity.owner = msg.sender;

        bytes32 nameFieldIndex = allowedFields.members[0];
        SnowflakeField storage nameField = identity.fields[nameFieldIndex];
        for (uint i; i < names.length; i++) {
            if (names[i] == bytes32(0x0)) {
                continue;
            }
            nameField.entries[allowedNames.members[i]].entryName = nameOrder[i];
            nameField.entries[allowedNames.members[i]].saltedHash = names[i];
            nameField.entries[allowedNames.members[i]].blockNumber = block.number;
            nameField.entriesAttestedTo.insert(allowedNames.members[i]);
            // putting this here creates some unnecessary checks, but it catches the case when all elements are 0x0
            identity.fieldsAttestedTo.insert(nameFieldIndex);
        }

        bytes32 dateFieldIndex = allowedFields.members[1];
        SnowflakeField storage dateField = identity.fields[dateFieldIndex];
        for (uint j; j < dateOfBirth.length; j++) {
            if (dateOfBirth[j] == bytes32(0x0)) {
                continue;
            }
            dateField.entries[allowedDates.members[j]].entryName = dateOrder[j];
            dateField.entries[allowedDates.members[j]].saltedHash = dateOfBirth[j];
            dateField.entries[allowedDates.members[j]].blockNumber = block.number;
            dateField.entriesAttestedTo.insert(allowedDates.members[j]);
            // putting this here creates some unnecessary checks, but it catches the case when all elements are 0x0
            identity.fieldsAttestedTo.insert(dateFieldIndex);
        }

        ownerToToken[msg.sender] = _hydroId;

        emit SnowflakeMinted(_hydroId, msg.sender);
    }

    // wrappers that allow easy access to modify resolvers
    function addResolvers(address[] resolvers, uint[] withdrawAllowances) public _hasToken(msg.sender, true) {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(resolverWhitelist.contains(resolvers[i]), "The given resolver is not on the whitelist.");
            require(!identity.resolversFor.contains(resolvers[i]), "This snowflake has already set this resolver.");
            identity.resolversFor.insert(resolvers[i]);
            identity.resolvers[resolvers[i]].withdrawAllowance = withdrawAllowances[i];
        }

        emit ResolversAdded(ownerToToken[msg.sender], resolvers, withdrawAllowances);
    }

    function changeResolverAllowances(address[] resolvers, uint[] withdrawAllowances)
        public _hasToken(msg.sender, true)
    {
        require(resolvers.length == withdrawAllowances.length, "Malformed inputs.");

        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(identity.resolversFor.contains(resolvers[i]), "This snowflake has not set this resolver");
            identity.resolvers[resolvers[i]].withdrawAllowance = withdrawAllowances[i];
        }

        emit ResolversAllowanceChanged(ownerToToken[msg.sender], resolvers, withdrawAllowances);
    }

    function removeResolvers(address[] resolvers) public _hasToken(msg.sender, true) {
        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];

        for (uint i; i < resolvers.length; i++) {
            require(identity.resolversFor.contains(resolvers[i]), "This snowflake has not set this resolver");
            identity.resolversFor.remove(resolvers[i]);
            delete identity.resolvers[resolvers[i]];
        }

        emit ResolversRemoved(ownerToToken[msg.sender], resolvers);
    }

    // add/remove field entries
    function addFieldEntry(string field, string entry, bytes32 saltedHash) public _hasToken(msg.sender, true) {
        bytes32 fieldLookup = keccak256(abi.encodePacked(field));
        bytes32 entryLookup = keccak256(abi.encodePacked(entry));

        require(allowedFields.contains(fieldLookup), "Invalid field.");
        if (fieldLookup == allowedNames.members[0]) require(allowedNames.contains(entryLookup), "Invalid entry.");
        if (fieldLookup == allowedNames.members[1]) require(allowedDates.contains(entryLookup), "Invalid entry.");

        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];
        require(!identity.fields[fieldLookup].entriesAttestedTo.contains(entryLookup), "Entry already exists");

        identity.fields[fieldLookup].entriesAttestedTo.insert(entryLookup);
        identity.fields[fieldLookup].entries[entryLookup].entryName = entry;
        identity.fields[fieldLookup].entries[entryLookup].saltedHash = saltedHash;
        identity.fields[fieldLookup].entries[entryLookup].blockNumber = block.number;

        identity.fieldsAttestedTo.insert(fieldLookup);
    }

    function removeFieldEntry(string field, string entry) public _hasToken(msg.sender, true) {
        bytes32 fieldLookup = keccak256(abi.encodePacked(field));
        bytes32 entryLookup = keccak256(abi.encodePacked(entry));

        Identity storage identity = tokenDirectory[ownerToToken[msg.sender]];
        require(identity.fields[fieldLookup].entriesAttestedTo.contains(entryLookup), "Entry does not exist");

        identity.fields[fieldLookup].entriesAttestedTo.remove(entryLookup);
        delete identity.fields[fieldLookup].entries[entryLookup];
        if (identity.fields[fieldLookup].entriesAttestedTo.length() == 0) {
            identity.fieldsAttestedTo.remove(fieldLookup);
        }
    }

    // check resolver membership
    function hasResolver(string hydroId, address resolver) public view _tokenExists(hydroId) returns (bool) {
        Identity storage identity = tokenDirectory[hydroId];
        return identity.resolversFor.contains(resolver);
    }

    // functions to read token values
    function getDetails(string hydroId) public view _tokenExists(hydroId) returns (
        address owner,
        bytes32[] fieldsAttestedTo,
        address[] resolversFor
    ) {
        Identity storage identity = tokenDirectory[hydroId];
        return (
            identity.owner,
            identity.fieldsAttestedTo.members,
            identity.resolversFor.members
        );
    }

    function getDetails(string hydroId, address resolver) public view _tokenExists(hydroId)
        returns (uint withdrawAllowance)
    {
        Identity storage identity = tokenDirectory[hydroId];
        require(identity.resolversFor.contains(resolver));

        return identity.resolvers[resolver].withdrawAllowance;
    }

    function getDetails(string hydroId, string field) public view _tokenExists(hydroId)
        returns (bytes32[] entriesAttestedTo)
    {
        Identity storage identity = tokenDirectory[hydroId];
        bytes32 fieldLookup = keccak256(abi.encodePacked(field));
        require(identity.fieldsAttestedTo.contains(fieldLookup));

        return identity.fields[fieldLookup].entriesAttestedTo.members;
    }

    function getDetails(string hydroId, string field, bytes32 entryLookup) public view _tokenExists(hydroId)
        returns (string entryName, bytes32 saltedHash, uint blockNumber)
    {
        Identity storage identity = tokenDirectory[hydroId];
        bytes32 fieldLookup = keccak256(abi.encodePacked(field));
        require(identity.fieldsAttestedTo.contains(fieldLookup));
        require(identity.fields[fieldLookup].entriesAttestedTo.contains(entryLookup));

        return (
            identity.fields[fieldLookup].entries[entryLookup].entryName,
            identity.fields[fieldLookup].entries[entryLookup].saltedHash,
            identity.fields[fieldLookup].entries[entryLookup].blockNumber
        );
    }

    // functions that enable HYDRO functionality
    function receiveApproval(address _sender, uint amount, address _tokenAddress, bytes) public {
        require(msg.sender == _tokenAddress);
        require(_tokenAddress == hydroTokenAddress);
        ERC20 hydro = ERC20(_tokenAddress);
        require(hydro.transferFrom(_sender, address(this), amount));
        deposits[_sender] = deposits[_sender].add(amount);
        emit SnowflakeDeposit(_sender, amount);
    }

    function transferSnowflakeBalance(address to, uint amount) public {
        _transferSnowflakeBalance(msg.sender, to, amount);
    }

    function withdrawSnowflakeBalance(uint amount) public {
        require(amount > 0);
        require(deposits[msg.sender] >= amount, "Your cannot withdraw more than you have deposited.");
        deposits[msg.sender] = deposits[msg.sender].sub(amount);
        ERC20 hydro = ERC20(hydroTokenAddress);
        require(hydro.transfer(msg.sender, amount));
        emit SnowflakeWithdraw(msg.sender, amount);
    }

    // only callable from resolvers with withdraw allowances
    function transferOnBehalfOf(address from, address to, uint amount) public _hasToken(from, true) {
        Identity storage identity = tokenDirectory[ownerToToken[from]];
        require(identity.resolversFor.contains(msg.sender), "This resolver has not been set by the from tokenholder.");
        
        if (identity.resolvers[msg.sender].withdrawAllowance < amount) {
            emit InsufficientAllowance(
                ownerToToken[from], msg.sender, identity.resolvers[msg.sender].withdrawAllowance, amount
            );
            require(false, "Resolver has inadequate allowance.");
        }

        identity.resolvers[msg.sender].withdrawAllowance = identity.resolvers[msg.sender].withdrawAllowance.sub(amount);
        _transferSnowflakeBalance(from, to,  amount);
    }

    function _transferSnowflakeBalance(address from, address to, uint amount) internal {
        require(to != address(this), "This contract cannot hold token balances on its own behalf.");
        require(amount > 0);
        require(deposits[from] >= amount, "Your balance is too low to transfer this amount.");
        deposits[from] = deposits[from].sub(amount);
        deposits[to] = deposits[to].add(amount);
        emit SnowflakeTransfer(from, to, amount);
    }

    // events
    event SnowflakeDeposit(address indexed depositor, uint amount);
    event SnowflakeTransfer(address indexed from, address indexed to, uint amount);
    event SnowflakeWithdraw(address indexed depositor, uint amount);

    event SnowflakeMinted(string hydroId, address minter);

    event ResolverWhitelisted(address indexed resolver, address sponsor);

    event ResolversAdded(string indexed hydroId, address[] resolvers, uint[] withdrawAllowances);
    event ResolversAllowanceChanged(string indexed hydroId, address[] resolvers, uint[] withdrawAllowances);
    event ResolversRemoved(string indexed hydroId, address[] resolvers);

    event InsufficientAllowance(string indexed hydroId, address resolver, uint currentAllowance, uint requestedWithdraw);
}