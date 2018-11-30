pragma solidity ^0.5.0;

/// @title An implementation of the set data structure for addresses.
/// @author Noah Zinsmeister
/// @dev O(1) insertion, removal, contains, and length functions.
library AddressSet {
    struct Set {
        address[] members;
        mapping(address => uint) memberIndices;
    }

    /// @dev Inserts an element into a set. If the element already exists in the set, the function is a no-op.
    /// @param self The set to insert into.
    /// @param other The element to insert.
    function insert(Set storage self, address other) public {
        if (!contains(self, other)) {
            self.memberIndices[other] = self.members.push(other);
        }
    }

    /// @dev Removes an element from a set. If the element does not exist in the set, the function is a no-op.
    /// @param self The set to remove from.
    /// @param other The element to remove.
    function remove(Set storage self, address other) public {
        if (contains(self, other)) {
            // replace other with the last element
            self.members[self.memberIndices[other] - 1] = self.members[length(self) - 1];
            // reflect this change in the indices
            self.memberIndices[self.members[self.memberIndices[other] - 1]] = self.memberIndices[other];
            delete self.memberIndices[other];
            // remove the last element
            self.members.pop();
        }
    }

    /// @dev Checks set membership.
    /// @param self The set to check membership in.
    /// @param other The element to check membership of.
    /// @return true if the element is in the set, false otherwise.
    function contains(Set storage self, address other) public view returns (bool) {
        return ( // solium-disable-line operator-whitespace
            self.memberIndices[other] > 0 && 
            self.members.length >= self.memberIndices[other] && 
            self.members[self.memberIndices[other] - 1] == other
        );
    }

    /// @dev Returns the number of elements in a set.
    /// @param self The set to check the length of.
    /// @return The number of elements in the set.
    function length(Set storage self) public view returns (uint) {
        return self.members.length;
    }
}
