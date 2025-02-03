import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Hash "mo:base/Hash";

actor {
    // Types
    private type HashType = Text;
    private type Timestamp = Int;
    private type CertifiedData = {
        hash: HashType;
        timestamp: Timestamp;
    };

    // Stable storage
    private stable var admin : ?Principal = null;
    private stable var treeEntries : [(Text, HashType)] = [];
    private stable var merkleRoots : [(HashType, CertifiedData)] = [];
    private stable var lastUpdateTime : Timestamp = 0;

    // In-memory storage
    private var trees = HashMap.HashMap<Text, HashType>(0, Text.equal, Text.hash);
    private var certifiedTrees = HashMap.HashMap<HashType, CertifiedData>(0, Text.equal, Text.hash);

    // System functions for upgrade management
    system func preupgrade() {
        treeEntries := Iter.toArray(trees.entries());
        merkleRoots := Iter.toArray(certifiedTrees.entries());
    };

    system func postupgrade() {
        trees := HashMap.fromIter<Text, HashType>(treeEntries.vals(), 0, Text.equal, Text.hash);
        certifiedTrees := HashMap.fromIter<HashType, CertifiedData>(merkleRoots.vals(), 0, Text.equal, Text.hash);
    };

    // Admin management
    public shared({caller}) func registerAdmin() : async Result.Result<Text, Text> {
        switch (admin) {
            case (?existing) { #err("Admin already registered") };
            case null {
                admin := ?caller;
                #ok("Admin registered successfully")
            }
        }
    };

    // Create a new Merkle tree with certification
    public shared({caller}) func createCertifiedMerkleTree(data: [Text]) : async Result.Result<CertifiedData, Text> {
        switch (admin) {
            case (?adminPrincipal) {
                if (caller != adminPrincipal) {
                    return #err("Only admin can create Certified Merkle Tree");
                };

                let leaves = Buffer.Buffer<HashType>(data.size());
                
                // Create and store leaf hashes
                for (item in data.vals()) {
                    let hash = makeHash(item);
                    leaves.add(hash);
                    trees.put(item, hash);
                };

                // Build the Merkle tree
                let root = buildMerkleRoot(leaves);
                
                // Create certification data
                let currentTime = Time.now();
                let certData : CertifiedData = {
                    hash = root;
                    timestamp = currentTime;
                };

                certifiedTrees.put(root, certData);
                lastUpdateTime := currentTime;

                #ok(certData)
            };
            case null { #err("Admin not registered") }
        }
    };

    // Query methods with certification
    public query func verifyCertifiedData(data: Text, rootHash: Text, timestamp: Timestamp) : async Bool {
        switch (trees.get(data)) {
            case (?hash) {
                switch (certifiedTrees.get(rootHash)) {
                    case (?certData) {
                        // Verify timestamp is not too old (e.g., within last 24 hours)
                        if (Time.now() - certData.timestamp > 24 * 60 * 60 * 1000000000) {
                            return false;
                        };
                        
                        // Verify the actual data
                        return verifyHash(hash, rootHash, certData);
                    };
                    case null { false };
                };
            };
            case null { false };
        }
    };

    // Get proof for data verification
    public query func getCertifiedProof(data: Text) : async ?{
        proof: [HashType];
        certData: CertifiedData;
    } {
        switch (trees.get(data)) {
            case (?hash) {
                for ((root, certData) in certifiedTrees.entries()) {
                    let proof = generateProof(hash, root);
                    switch(proof) {
                        case (?proofArray) {
                            return ?{
                                proof = proofArray;
                                certData = certData;
                            };
                        };
                        case null {};
                    };
                };
            };
            case null {};
        };
        null
    };

    // Internal helper functions
    private func buildMerkleRoot(leaves: Buffer.Buffer<HashType>) : HashType {
        var currentLevel = leaves;
        
        while (currentLevel.size() > 1) {
            let nextLevel = Buffer.Buffer<HashType>(0);
            var i = 0;
            while (i < currentLevel.size()) {
                let left = currentLevel.get(i);
                let right = if (i + 1 < currentLevel.size()) {
                    currentLevel.get(i + 1)
                } else {
                    left
                };
                nextLevel.add(hashPair(left, right));
                i += 2;
            };
            currentLevel := nextLevel;
        };

        if (currentLevel.size() > 0) {
            currentLevel.get(0)
        } else {
            makeHash("empty_tree")
        }
    };

    private func verifyHash(hash: HashType, rootHash: HashType, certData: CertifiedData) : Bool {
        // Add your custom verification logic here
        hash == rootHash and certData.hash == rootHash
    };

    private func generateProof(hash: HashType, rootHash: HashType) : ?[HashType] {
        // Implementation of proof generation
        // This would involve traversing the tree and collecting sibling nodes
        null // Placeholder - implement actual proof generation
    };

    private func hashPair(left: HashType, right: HashType) : HashType {
        if (left < right) {
            makeHash(left # right)
        } else {
            makeHash(right # left)
        }
    };

    private func makeHash(data: Text) : Text {
        Nat32.toText(Text.hash(data))
    };
}
