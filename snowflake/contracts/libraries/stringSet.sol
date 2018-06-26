pragma solidity ^0.4.23;


library stringSet {
    struct _stringSet {
        string[] members;
        mapping(string => uint) memberIndices;
    }

    function insert(_stringSet storage self, string other) public {
        if (!contains(self, other)) {
            assert(length(self) < 2**256-1);
            self.members.push(other);
            self.memberIndices[other] = length(self);
        }
    }

    function remove(_stringSet storage self, string other) public {
        if (contains(self, other)) {
            uint replaceIndex = self.memberIndices[other];
            string memory lastMember = self.members[length(self)-1];
            // overwrite other with the last member and remove last member
            self.members[replaceIndex-1] = lastMember;
            self.members.length--;
            // reflect this change in the indices
            self.memberIndices[lastMember] = replaceIndex;
            delete self.memberIndices[other];
        }
    }

    function contains(_stringSet storage self, string other) public view returns (bool) {
        return self.memberIndices[other] > 0;
    }

    function length(_stringSet storage self) public view returns (uint) {
        return self.members.length;
    }
}
