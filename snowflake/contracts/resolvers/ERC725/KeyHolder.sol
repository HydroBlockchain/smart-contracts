pragma solidity ^0.4.24;

import "./ERC725.sol";

contract KeyHolder is ERC725 {

    struct Key {
        uint256[] purposes; //e.g., MANAGEMENT_KEY = 1, ACTION_KEY = 2, etc.
        uint256 keyType; // e.g. 1 = ECDSA, 2 = RSA, etc.
        bytes32 key;
    }

    struct KeyHolderData {
        uint256 executionNonce;
        mapping (bytes32 => Key) keys;
        mapping (uint256 => bytes32[]) keysByPurpose;
        mapping (uint256 => Execution) executions;
    }

    KeyHolderData keyHolderData;

    struct Execution {
        address to;
        uint256 value;
        bytes data;
        bool approved;
        bool executed;
    }

    event ExecutionFailed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    constructor() public {
        bytes32 _key = keccak256(abi.encodePacked(msg.sender));
        keyHolderData.keys[_key].key = _key;
        keyHolderData.keys[_key].purposes.push(1);
        keyHolderData.keys[_key].keyType = 1;
        keyHolderData.keysByPurpose[1].push(_key);
        emit KeyAdded(_key, 1, 1);
    }

    function getKey(bytes32 _key)
        public
        view
        returns(uint256[] purposes, uint256 keyType, bytes32 key)
    {
        return (keyHolderData.keys[_key].purposes, keyHolderData.keys[_key].keyType, keyHolderData.keys[_key].key);
    }

    function getKeyPurpose(bytes32 _key)
        public
        view
        returns(uint256[] purposes)
    {
        return (keyHolderData.keys[_key].purposes);
    }

    function getKeysByPurpose(uint256 _purpose)
        public
        view
        returns(bytes32[] _keys)
    {
        return keyHolderData.keysByPurpose[_purpose];
    }

    function addKey(bytes32 _key, uint256 _purpose, uint256 _type)
        public
        returns (bool success)
    {
        if (msg.sender != address(this)) {
          require(keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), 1), "Sender does not have management key"); // Sender has MANAGEMENT_KEY
        }

        if(keyHolderData.keys[_key].key != _key) { //key doesn't exists yet
          keyHolderData.keys[_key].key = _key;
          keyHolderData.keys[_key].keyType = _type;
        }

        keyHolderData.keys[_key].purposes.push(_purpose);
        keyHolderData.keysByPurpose[_purpose].push(_key);

        emit KeyAdded(_key, _purpose, _type);

        return true;
    }

    function approve(uint256 _id, bool _approve)
        public
        returns (bool success)
    {
        require(keyHasPurpose(keccak256(abi.encodePacked(msg.sender)), 2), "Sender does not have action key");

        emit Approved(_id, _approve);

        if (_approve == true) {
            keyHolderData.executions[_id].approved = true;
            success = keyHolderData.executions[_id].to.call(keyHolderData.executions[_id].data, 0);
            if (success) {
                keyHolderData.executions[_id].executed = true;
                emit Executed(
                    _id,
                    keyHolderData.executions[_id].to,
                    keyHolderData.executions[_id].value,
                    keyHolderData.executions[_id].data
                );
                return;
            } else {
                emit ExecutionFailed(
                    _id,
                    keyHolderData.executions[_id].to,
                    keyHolderData.executions[_id].value,
                    keyHolderData.executions[_id].data
                );
                return;
            }
        } else {
            keyHolderData.executions[_id].approved = false;
        }
        return true;
    }

    function execute(address _to, uint256 _value, bytes _data)
        public
        returns (uint256 executionId)
    {
        require(!keyHolderData.executions[keyHolderData.executionNonce].executed, "Already executed");
        keyHolderData.executions[keyHolderData.executionNonce].to = _to;
        keyHolderData.executions[keyHolderData.executionNonce].value = _value;
        keyHolderData.executions[keyHolderData.executionNonce].data = _data;

        emit ExecutionRequested(keyHolderData.executionNonce, _to, _value, _data);

        if (keyHasPurpose(keccak256(abi.encodePacked(msg.sender)),1) || keyHasPurpose(keccak256(abi.encodePacked(msg.sender)),2)) {
            approve(keyHolderData.executionNonce, true);
        }

        keyHolderData.executionNonce++;
        return keyHolderData.executionNonce-1;
    }

    function removeKey(bytes32 _key, uint256 _purpose)
        public
        returns (bool success)
    {
        require(keyHolderData.keys[_key].key == _key, "No such key");
        emit KeyRemoved(keyHolderData.keys[_key].key, keyHolderData.keys[_key].purposes, keyHolderData.keys[_key].keyType);

        // Remove purpose from key
        uint256[] storage purposes = keyHolderData.keys[_key].purposes;
        for (uint i = 0; i < purposes.length; i++) {
            if (purposes[i] == _purpose) {
                purposes[i] = purposes[purposes.length - 1];
                delete purposes[purposes.length - 1];
                purposes.length--;
                break;
            }
        }

        // If no more purposes, delete key
        if (purposes.length == 0) {
            delete keyHolderData.keys[_key];
        }

        // Remove key from keysByPurpose
        bytes32[] storage keys = keyHolderData.keysByPurpose[_purpose];
        for (uint j = 0; j < keys.length; j++) {
            if (keys[j] == _key) {
                keys[j] = keys[keys.length - 1];
                delete keys[keys.length - 1];
                keys.length--;
                break;
            }
        }

        return true;
    }

    function keyHasPurpose(bytes32 _key, uint256 _purpose)
        public
        view
        returns(bool result)
    {
        bool isThere;
        if (keyHolderData.keys[_key].key == 0) {
            return false;
        }

        uint256[] storage purposes = keyHolderData.keys[_key].purposes;
        for (uint i = 0; i < purposes.length; i++) {
            if (purposes[i] <= _purpose) {
                isThere = true;
                break;
            }
        }
        return isThere;
    }

}
