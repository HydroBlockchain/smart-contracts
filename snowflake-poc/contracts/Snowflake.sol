pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

import "./Withdrawable.sol";

import "./libraries/stringSet.sol";
import "./libraries/bytes32Set.sol";
import "./libraries/addressSet.sol";


contract RaindropClient {
    function getUserByAddress(address _address) external view returns (string userName);
}


contract Snowflake is Withdrawable {
    using stringSet for stringSet._stringSet;
    using bytes32Set for bytes32Set._bytes32Set;
    using addressSet for addressSet._addressSet;

    // Token lookup mappings
    mapping (uint256 => Identity) internal tokenIdentities;
    mapping (address => uint256) public ownerToToken;
    mapping (string => uint256) public hydroIdToToken;
    // approved validators
    addressSet._addressSet internal validators;
    // contract variables
    address public raindropClientAddress;
    uint internal nextTokenId = 1;

    struct Validation {
        address validator;
        bytes32 validationMessage;
    }

    struct Name {
        bytes32 givenName;
        bytes32 middleName;
        bytes32 surname;
        bytes32 preferredName;
        Validation[] validationList;
        addressSet._addressSet resolvers;
    }

    struct DateOfBirth {
        bytes32 day;
        bytes32 month;
        bytes32 year;
        Validation[] validationList;
        addressSet._addressSet resolvers;
    }

    struct Field {
        bytes32 fieldValue;
        Validation[] validationList;
        addressSet._addressSet resolvers;
    }

    struct ContactInformation {
        mapping (string => Field) emails; // todo: what is the best way to index this mapping?
        stringSet._stringSet emailsAttestedTo; // todo: is this necessary?
        mapping (string => Field) phoneNumbers; // todo: what is the best way to index this mapping?
        stringSet._stringSet phoneNumbersAttestedTo; // todo: is this necessary?
        mapping (string => Field) physicalAddresses; // todo: what is the best way to index this mapping?
        stringSet._stringSet physicalAddressesAttestedTo; // todo: is this necessary?
    }

    struct Miscellaneous {
        addressSet._addressSet resolvers; // todo: should this be a mapping?
    }

    struct Identity {
        address owner;
        string hydroId;
        Name name;
        DateOfBirth dateOfBirth;
        ContactInformation contactInformation;
        Miscellaneous miscellaneous;
    }

    modifier onlyValidator() {
        require(validators.contains(msg.sender), "The sender address is not a validator.");
        _;
    }

    modifier onlyTokenOwnerOrValidator(uint _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender || validators.contains(msg.sender),
            "You are not the token owner or a validator."
        );
        _;
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = tokenIdentities[_tokenId].owner;
        require(owner != address(0), "This token has not yet been minted.");
        return owner;
    }

    function tokenOfAddress(address _address) public view returns (uint256) {
        uint256 tokenId = ownerToToken[_address];
        require(tokenId != 0, "This address does not possess a token.");
        return tokenId;
    }

    function tokenOfHydroID(string hydroId) public view returns (uint256) {
        uint256 tokenId = hydroIdToToken[hydroId];
        require(tokenId != 0, "This address does not possess a token.");
        return tokenId;
    }

    function addValidator(address _validator) public onlyOwner {
        validators.insert(_validator);
    }

    function removeValidator(address _validator) public onlyOwner {
        validators.remove(_validator);
    }

    function setRaindropClientAddress(address _address) public onlyOwner {
        raindropClientAddress = _address;
    }

    function mintIdentityToken(bytes32[] names, bytes32[] dateOfBirth) public returns(uint tokenId) {
        require(names.length == 4, "The names parameter must contain four elements.");
        require(dateOfBirth.length == 3, "The dateOfBirth parameter must contain four elements.");
        require(ownerToToken[msg.sender] == 0, "This address is already associated with an identity.");

        RaindropClient raindropClient = RaindropClient(raindropClientAddress);
        string memory _hydroId = raindropClient.getUserByAddress(msg.sender);

        assert(hydroIdToToken[_hydroId] == 0);

        uint newTokenId = nextTokenId++;
        Identity storage identity = tokenIdentities[newTokenId];

        identity.owner = msg.sender;
        identity.hydroId = _hydroId;

        identity.name.givenName = names[0];
        identity.name.middleName = names[1];
        identity.name.surname = names[2];
        identity.name.preferredName = names[3];

        identity.dateOfBirth.day = dateOfBirth[0];
        identity.dateOfBirth.month = dateOfBirth[1];
        identity.dateOfBirth.year = dateOfBirth[2];

        ownerToToken[msg.sender] = newTokenId;
        hydroIdToToken[_hydroId] = newTokenId;

        return newTokenId;
    }

    function addNameValidation(uint tokenId, bytes32 validationMessage) public onlyValidator {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0x0), "This token does not exist.");
        identity.name.validationList.push(Validation(msg.sender, validationMessage));
    }

    function modifyNameResolver(address resolver, bool add) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        if (add) {
            identity.name.resolvers.insert(resolver);
        } else {
            identity.name.resolvers.remove(resolver);
        }
    }

    function modifyEmailInformation(
        string[] emailNames, bytes32[] emails, bool add
    ) public {
        uint tokenId = tokenOfAddress(msg.sender);

        require(emailNames.length == emails.length, "Malformed inputs.");
        require(emailNames.length < 6, "Too many inputs.");

        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < emailNames.length; i++) {
            require(
                identity.contactInformation.emailsAttestedTo.contains(emailNames[i]) != add,
                "Incorrect initialization status."
            );
            if (add) {
                identity.contactInformation.emails[emailNames[i]].fieldValue = emails[i];
                identity.contactInformation.emailsAttestedTo.insert(emailNames[i]);
            } else {
                delete identity.contactInformation.emails[emailNames[i]].fieldValue;
                identity.contactInformation.emailsAttestedTo.remove(emailNames[i]);
            }
            delete identity.contactInformation.emails[emailNames[i]].validationList;
        }
    }

    function modifyPhoneNumbersInformation(
        string[] phoneNumberNames, bytes32[] phoneNumbers, bool add
    ) public {
        uint tokenId = tokenOfAddress(msg.sender);

        require(phoneNumberNames.length == phoneNumbers.length, "Malformed inputs.");
        require(phoneNumberNames.length < 6, "Too many inputs.");

        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < phoneNumberNames.length; i++) {
            require(
                identity.contactInformation.phoneNumbersAttestedTo.contains(phoneNumberNames[i]) != add,
                "Incorrect initialization status."
            );
            if (add) {
                identity.contactInformation.phoneNumbers[phoneNumberNames[i]].fieldValue = phoneNumbers[i];
                identity.contactInformation.phoneNumbersAttestedTo.insert(phoneNumberNames[i]);
            } else {
                delete identity.contactInformation.phoneNumbers[phoneNumberNames[i]].fieldValue;
                identity.contactInformation.phoneNumbersAttestedTo.remove(phoneNumberNames[i]);
            }
            delete identity.contactInformation.phoneNumbers[phoneNumberNames[i]].validationList;
        }
    }

    function modifyPhysicalAddressesInformation(
        string[] physicalAddressNames, bytes32[] physicalAddresses, bool add
    ) public {
        uint tokenId = tokenOfAddress(msg.sender);

        require(physicalAddressNames.length == physicalAddresses.length, "Malformed inputs.");
        require(physicalAddressNames.length < 6, "Too many inputs.");

        Identity storage identity = tokenIdentities[tokenId];

        for (uint i; i < physicalAddressNames.length; i++) {
            require(
                identity.contactInformation.physicalAddressesAttestedTo.contains(physicalAddressNames[i]) != add,
                "Incorrect initialization status."
            );
            if (add) {
                identity.contactInformation.physicalAddresses[physicalAddressNames[i]].fieldValue =
                    physicalAddresses[i];
                identity.contactInformation.physicalAddressesAttestedTo.insert(physicalAddressNames[i]);
            } else {
                delete identity.contactInformation.physicalAddresses[physicalAddressNames[i]].fieldValue;
                identity.contactInformation.physicalAddressesAttestedTo.remove(physicalAddressNames[i]);
            }
            delete identity.contactInformation.physicalAddresses[physicalAddressNames[i]].validationList;
        }
    }

    function addEmailValidation(uint tokenId, string identifier, bytes32 message) public onlyValidator {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0x0), "This token does not exist.");
        require(identity.contactInformation.emailsAttestedTo.contains(identifier), "The field does not exist.");
        identity.contactInformation.email[identifier].validationList.push(Validation(msg.sender, message));
    }

    function addPhoneNumberValidation(uint tokenId, string identifier, bytes32 message) public onlyValidator {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0x0), "This token does not exist.");
        require(identity.contactInformation.phoneNumbersAttestedTo.contains(identifier), "The field does not exist.");
        identity.contactInformation.phoneNumbers[identifier].validationList.push(Validation(msg.sender, message));
    }

    function addPhysicalAddressValidation(uint tokenId, string identifier, bytes32 message) public onlyValidator {
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.owner != address(0x0), "This token does not exist.");
        require(
            identity.contactInformation.physicalAddressesAttestedTo.contains(identifier), "The field does not exist."
        );
        identity.contactInformation.physicalAddresses[identifier].validationList.push(Validation(msg.sender, message));
    }

    function modifyEmailResolver(string identifier, address resolver, bool add) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.contactInformation.emailsAttestedTo.contains(identifier), "The field does not exist.");
        if (add) {
            identity.contactInformation.emails[identifier].resolvers.insert(resolver);
        } else {
            identity.contactInformation.emails[identifier].resolvers.remove(resolver);
        }
    }

    function modifyPhoneNumberResolver(string identifier, address resolver, bool add) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        require(identity.contactInformation.phoneNumbersAttestedTo.contains(identifier), "The field does not exist.");
        if (add) {
            identity.contactInformation.phoneNumbers[identifier].resolvers.insert(resolver);
        } else {
            identity.contactInformation.phoneNumbers[identifier].resolvers.remove(resolver);
        }
    }

    function modifyPhysicalAddressesResolver(string identifier, address resolver, bool add) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        require(
            identity.contactInformation.physicalAddressesAttestedTo.contains(identifier), "The field does not exist."
        );
        if (add) {
            identity.contactInformation.physicalAddresses[identifier].resolvers.insert(resolver);
        } else {
            identity.contactInformation.physicalAddresses[identifier].resolvers.remove(resolver);
        }
    }

    function modifyMiscellaneousResolver(address resolver, bool add) public {
        uint tokenId = tokenOfAddress(msg.sender);
        Identity storage identity = tokenIdentities[tokenId];
        if (add) {
            identity.miscellaneous.resolvers.insert(resolver);
        } else {
            identity.miscellaneous.resolvers.remove(resolver);
        }
    }
}
