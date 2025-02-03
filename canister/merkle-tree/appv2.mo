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
import Int "mo:base/Int";
import Order "mo:base/Order";
import Bool "mo:base/Bool";

actor {
    // Types
    private type HashType = Text;
    private type Timestamp = Int;
    private type SensorReading = {
        sensorHash: HashType;
        timestamp: Timestamp;
    };
    private type MerkleTreeRecord = {
        rootHash: HashType;
        readings: [SensorReading];
        timestamp: Timestamp;
        totalReadings: Nat;
    };

    // Stable storage
    private stable var admin : ?Principal = null;
    private stable var treeRecords : [MerkleTreeRecord] = [];
    private stable var lastUpdateTime : Timestamp = 0;

    // In-memory storage
    private var trees = HashMap.HashMap<Text, HashType>(0, Text.equal, Text.hash);
    private var certifiedTrees = HashMap.HashMap<HashType, MerkleTreeRecord>(0, Text.equal, Text.hash);

    // System functions for upgrade management
    system func preupgrade() {
        treeRecords := Iter.toArray(certifiedTrees.vals());
    };

    system func postupgrade() {
        for (record in treeRecords.vals()) {
            certifiedTrees.put(record.rootHash, record);
        };
    };

    // Create a new Merkle tree from an array of sensor readings
    public shared({caller}) func createSensorMerkleTree(readings: [Text]) : async Result.Result<MerkleTreeRecord, Text> {
        // Validate input
        if (readings.size() == 0) {
            return #err("No readings provided");
        };
        
        let currentTime = Time.now();
        
        // Create sensor readings with timestamps
        let sensorReadings = Array.map<Text, SensorReading>(
            readings,
            func(reading: Text) : SensorReading = {
                sensorHash = reading;
                timestamp = currentTime;
            }
        );
        
        // Create leaf hashes
        let leaves = Buffer.Buffer<HashType>(readings.size());
        for (reading in sensorReadings.vals()) {
            let hash = makeHash(reading.sensorHash # Int.toText(reading.timestamp));
            leaves.add(hash);
            trees.put(reading.sensorHash, hash);
        };

        // Build Merkle tree and get root hash
        let rootHash = buildMerkleRoot(leaves);
        
        // Create tree record
        let treeRecord : MerkleTreeRecord = {
            rootHash = rootHash;
            readings = sensorReadings;
            timestamp = currentTime;
            totalReadings = readings.size();
        };

        // Store the record
        certifiedTrees.put(rootHash, treeRecord);
        lastUpdateTime := currentTime;

        #ok(treeRecord)
    };

    // Get all Merkle trees (most recent first)
    public query func getAllTrees() : async [MerkleTreeRecord] {
        let allTrees = Iter.toArray(certifiedTrees.vals());
        Array.sort(allTrees, func(a: MerkleTreeRecord, b: MerkleTreeRecord) : Order.Order {
            if (a.timestamp == b.timestamp) { #equal }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #less }
        })
    };

    // Get specific tree by root hash
    public query func getTree(rootHash: HashType) : async ?MerkleTreeRecord {
        certifiedTrees.get(rootHash)
    };

    // Verify if a sensor reading exists in a specific tree
    public query func verifySensorReading(rootHash: HashType, sensorHash: Text) : async Bool {
        switch (certifiedTrees.get(rootHash)) {
            case (null) { false };
            case (?record) {
                for (reading in record.readings.vals()) {
                    if (reading.sensorHash == sensorHash) {
                        return true;
                    };
                };
                false
            };
        }
    };

    // Get proof for data verification
    public query func getMerkleProof(rootHash: HashType, dataHash: Text) : async ?{
        proof: [HashType];
        index: Nat;
    } {
        switch (certifiedTrees.get(rootHash)) {
            case (null) { null };
            case (?record) {
                // Create leaf hashes
                let leaves = Buffer.Buffer<HashType>(record.readings.size());
                for (reading in record.readings.vals()) {
                    let hash = makeHash(reading.sensorHash # Int.toText(reading.timestamp));
                    leaves.add(hash);
                };

                // Find the index of our target hash
                var targetIndex : ?Nat = null;
                label l for (i in Iter.range(0, leaves.size() - 1)) {
                    if (leaves.get(i) == makeHash(dataHash # Int.toText(record.timestamp))) {
                        targetIndex := ?i;
                        break l;
                    };
                };

                switch(targetIndex) {
                    case (null) { null };
                    case (?index) {
                        let proof = generateMerkleProof(leaves, index);
                        ?{ proof = proof; index = index }
                    };
                };
            };
        }
    };

    // Verify Merkle proof
    public query func verifyMerkleProof(rootHash: HashType, dataHash: Text, proof: [HashType], index: Nat) : async Bool {
        switch (certifiedTrees.get(rootHash)) {
            case (null) { false };
            case (?record) {
                let targetHash = makeHash(dataHash # Int.toText(record.timestamp));
                verifyProof(targetHash, rootHash, proof, index)
            };
        }
    };

    // Get latest tree
    public query func getLatestTree() : async ?MerkleTreeRecord {
        var latest : ?MerkleTreeRecord = null;
        var latestTime : Int = 0;
        
        for (record in certifiedTrees.vals()) {
            if (record.timestamp > latestTime) {
                latest := ?record;
                latestTime := record.timestamp;
            };
        };
        
        latest
    };

    // Get tree statistics
    public query func getTreeStats() : async Text {
        var stats = "\n=== Merkle Tree Statistics ===\n";
        var totalTrees = 0;
        var totalReadings = 0;
        var maxReadings = 0;
        var minReadings = 999999;
        
        for (tree in certifiedTrees.vals()) {
            totalTrees += 1;
            totalReadings += tree.totalReadings;
            if (tree.totalReadings > maxReadings) maxReadings := tree.totalReadings;
            if (tree.totalReadings < minReadings) minReadings := tree.totalReadings;
        };

        stats #= "Total Trees: " # Int.toText(totalTrees) # "\n";
        stats #= "Total Readings: " # Int.toText(totalReadings) # "\n";
        if (totalTrees > 0) {
            stats #= "Average Readings per Tree: " # Int.toText(totalReadings / totalTrees) # "\n";
            stats #= "Max Readings in a Tree: " # Int.toText(maxReadings) # "\n";
            stats #= "Min Readings in a Tree: " # Int.toText(minReadings) # "\n";
        };
        stats #= "Last Update: " # Int.toText(lastUpdateTime) # "\n";
        stats #= "========================\n";
        
        stats
    };

    // Test Merkle tree verification
    public func testMerkleVerification() : async Text {
        var result = "\n=== Merkle Tree Verification Test ===\n";

        // Create test data
        let testReadings = [
            "sensor1_reading_123",
            "sensor2_reading_456",
            "sensor3_reading_789",
            "sensor4_reading_012"
        ];

        // Create Merkle tree
        let treeResult = await createSensorMerkleTree(testReadings);
        switch(treeResult) {
            case (#err(e)) { 
                return result # "Failed to create tree: " # e # "\n"; 
            };
            case (#ok(tree)) {
                result #= "Created Merkle tree with root hash: " # tree.rootHash # "\n";
                result #= "Number of readings: " # Int.toText(tree.totalReadings) # "\n\n";

                // Test verification for each reading
                label proof_loop for (i in Iter.range(0, testReadings.size() - 1)) {
                    let reading = testReadings[i];
                    
                    // Get Merkle proof
                    let proofResult = await getMerkleProof(tree.rootHash, reading);
                    switch(proofResult) {
                        case (null) {
                            result #= "Failed to get proof for reading " # reading # "\n";
                            continue proof_loop;
                        };
                        case (?merkleProof) {
                            // Verify the proof
                            let isValid = await verifyMerkleProof(
                                tree.rootHash,
                                reading,
                                merkleProof.proof,
                                merkleProof.index
                            );

                            result #= "Reading " # reading # ":\n";
                            result #= "  Index: " # Int.toText(merkleProof.index) # "\n";
                            result #= "  Proof Length: " # Int.toText(merkleProof.proof.size()) # "\n";
                            result #= "  Verification: " # Bool.toText(isValid) # "\n\n";
                        };
                    };
                };

                // Test with invalid data
                let invalidResult = await verifyMerkleProof(
                    tree.rootHash,
                    "invalid_reading",
                    [],
                    0
                );
                result #= "Invalid data verification test: " # Bool.toText(invalidResult) # "\n";
            };
        };

        result #= "========================\n";
        result
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

    // Helper function to generate Merkle proof
    private func generateMerkleProof(leaves: Buffer.Buffer<HashType>, index: Nat) : [HashType] {
        let proof = Buffer.Buffer<HashType>(0);
        var currentLevel = leaves;
        var currentIndex = index;

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

                // If this is the pair containing our target index
                if (i == currentIndex - (currentIndex % 2) or i == currentIndex + (1 - currentIndex % 2)) {
                    if (i == currentIndex) {
                        proof.add(right);
                    } else {
                        proof.add(left);
                    };
                };

                nextLevel.add(hashPair(left, right));
                i += 2;
            };

            currentLevel := nextLevel;
            currentIndex := currentIndex / 2;
        };

        Buffer.toArray(proof)
    };

    // Helper function to verify proof
    private func verifyProof(targetHash: HashType, rootHash: HashType, proof: [HashType], index: Nat) : Bool {
        var currentHash = targetHash;
        var currentIndex = index;

        for (siblingHash in proof.vals()) {
            currentHash := if (currentIndex % 2 == 0) {
                hashPair(currentHash, siblingHash)
            } else {
                hashPair(siblingHash, currentHash)
            };
            currentIndex := currentIndex / 2;
        };

        currentHash == rootHash
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
