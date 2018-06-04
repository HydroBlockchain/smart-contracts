pragma solidity ^0.4.23;


library uint8Set {
    struct _uint8Set {
        uint8[] members;
        mapping(uint8 => uint) memberIndices;
    }

    function insert(_uint8Set storage self, uint8 other) public {
        if (!contains(self, other)) {
            assert(length(self) < 2**256-1);
            self.members.push(other);
            self.memberIndices[other] = length(self);
        }
    }

    function remove(_uint8Set storage self, uint8 other) public {
        if (contains(self, other)) {
            uint replaceIndex = self.memberIndices[other];
            uint8 lastMember = self.members[length(self)-1];
            // overwrite other with the last member and remove last member
            self.members[replaceIndex-1] = lastMember;
            self.members.length--;
            // reflect this change in the indices
            self.memberIndices[lastMember] = replaceIndex;
            delete self.memberIndices[other];
        }
    }

    function contains(_uint8Set storage self, uint8 other) public view returns (bool) {
        return self.memberIndices[other] > 0;
    }

    function length(_uint8Set storage self) public view returns (uint) {
        return self.members.length;
    }
}