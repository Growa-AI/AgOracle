import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Int "mo:base/Int";
import Order "mo:base/Order";
import Bool "mo:base/Bool";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

actor {
    // SHA256 Implementation
    private let K : [Nat32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
        0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
        0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
        0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
        0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
        0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    private let S : [Nat32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];

    private let rot : (Nat32, Nat32) -> Nat32 = Nat32.bitrotRight;

    private class Digest() {
        private let s = Array.thaw<Nat32>(S);
        private let x = Array.init<Nat8>(64, 0);
        private var nx = 0;
        private var len : Nat64 = 0;

        public func reset() {
            for (i in Iter.range(0, 7)) {
                s[i] := S[i];
            };
            nx := 0;
            len := 0;
        };

        public func write(data : [Nat8]) {
            var p = data;
            len +%= Nat64.fromIntWrap(p.size());
            if (nx > 0) {
                let n = Nat.min(p.size(), 64 - nx);
                for (i in Iter.range(0, n - 1)) {
                    x[nx + i] := p[i];
                };
                nx += n;
                if (nx == 64) {
                    let buf = Array.freeze<Nat8>(x);
                    block(buf);
                    nx := 0;
                };
                p := Array.tabulate<Nat8>(p.size() - n, func (i) {
                    return p[n + i];
                });
            };
            if (p.size() >= 64) {
                let n = Nat64.toNat(Nat64.fromIntWrap(p.size()) & (^ 63));
                let buf = Array.tabulate<Nat8>(n, func (i) {
                    return p[i];
                });
                block(buf);
                p := Array.tabulate<Nat8>(p.size() - n, func (i) {
                    return p[n + i];
                });
            };
            if (p.size() > 0) {
                for (i in Iter.range(0, p.size() - 1)) {
                    x[i] := p[i];
                };
                nx := p.size();
            };
        };

        public func sum() : [Nat8] {
            var m = 0;
            var n = len;
            var t = Nat64.toNat(n) % 64;
            var buf : [var Nat8] = [var];
            if (56 > t) {
                m := 56 - t;
            } else {
                m := 120 - t;
            };
            n := n << 3;
            buf := Array.init<Nat8>(m, 0);
            if (m > 0) {
                buf[0] := 0x80;
            };
            write(Array.freeze<Nat8>(buf));
            buf := Array.init<Nat8>(8, 0);
            for (i in Iter.range(0, 7)) {
                let j : Nat64 = 56 -% 8 *% Nat64.fromIntWrap(i);
                buf[i] := Nat8.fromIntWrap(Nat64.toNat(n >> j));
            };
            write(Array.freeze<Nat8>(buf));
            let hash = Array.init<Nat8>(32, 0);
            for (i in Iter.range(0, 7)) {
                for (j in Iter.range(0, 3)) {
                    let k : Nat32 = 24 -% 8 *% Nat32.fromIntWrap(j);
                    hash[4 * i + j] := Nat8.fromIntWrap(Nat32.toNat(s[i] >> k));
                };
            };
            return Array.freeze<Nat8>(hash);
        };

        private func block(data : [Nat8]) {
            var p = data;
            var w = Array.init<Nat32>(64, 0);
            while (p.size() >= 64) {
                var j = 0;
                for (i in Iter.range(0, 15)) {
                    j := i * 4;
                    w[i] :=
                        Nat32.fromIntWrap(Nat8.toNat(p[j + 0])) << 24 |
                        Nat32.fromIntWrap(Nat8.toNat(p[j + 1])) << 16 |
                        Nat32.fromIntWrap(Nat8.toNat(p[j + 2])) << 08 |
                        Nat32.fromIntWrap(Nat8.toNat(p[j + 3])) << 00;
                };
                var v1 : Nat32 = 0;
                var v2 : Nat32 = 0;
                var t1 : Nat32 = 0;
                var t2 : Nat32 = 0;
                for (i in Iter.range(16, 63)) {
                    v1 := w[i - 02];
                    v2 := w[i - 15];
                    t1 := rot(v1, 17) ^ rot(v1, 19) ^ (v1 >> 10);
                    t2 := rot(v2, 07) ^ rot(v2, 18) ^ (v2 >> 03);
                    w[i] :=
                        t1 +% w[i - 07] +%
                        t2 +% w[i - 16];
                };
                var a = s[0];
                var b = s[1];
                var c = s[2];
                var d = s[3];
                var e = s[4];
                var f = s[5];
                var g = s[6];
                var h = s[7];
                for (i in Iter.range(0, 63)) {
                    t1 := rot(e, 06) ^ rot(e, 11) ^ rot(e, 25);
                    t1 +%= (e & f) ^ (^ e & g) +% h +% K[i] +% w[i];
                    t2 := rot(a, 02) ^ rot(a, 13) ^ rot(a, 22);
                    t2 +%= (a & b) ^ (a & c) ^ (b & c);
                    h := g;
                    g := f;
                    f := e;
                    e := d +% t1;
                    d := c;
                    c := b;
                    b := a;
                    a := t1 +% t2;
                };
                s[0] +%= a;
                s[1] +%= b;
                s[2] +%= c;
                s[3] +%= d;
                s[4] +%= e;
                s[5] +%= f;
                s[6] +%= g;
                s[7] +%= h;
                p := Array.tabulate<Nat8>(p.size() - 64, func (i) {
                    return p[i + 64];
                });
            };
        };
    };

    private func sha256(data : [Nat8]) : [Nat8] {
        let digest = Digest();
        digest.write(data);
        digest.sum()
    };

    // Convert bytes to hex string
    private func bytesToHex(bytes: [Nat8]) : Text {
        let hexDigits = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];
        var text = "";
        for (byte in bytes.vals()) {
            text := text # hexDigits[Nat8.toNat(byte >> 4)] # hexDigits[Nat8.toNat(byte & 0x0f)];
        };
        text
    };

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
    private stable var lastUpdateTime : Timestamp = 0;
    private stable var treeRecords : [MerkleTreeRecord] = [];  // Added back for upgrades

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

    // Modified hash function using SHA256
    private func makeHash(data: Text) : Text {
        let dataBytes = Blob.toArray(Text.encodeUtf8(data));
        let hash = sha256(dataBytes);
        bytesToHex(hash)
    };

    // Create a new Merkle tree from an array of sensor readings
    public shared({caller = _}) func createSensorMerkleTree(readings: [Text]) : async Result.Result<MerkleTreeRecord, Text> {
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
        
        // Create leaf hashes using SHA256
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

    // Build Merkle root from leaves
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

    // Hash pair of nodes
    private func hashPair(left: HashType, right: HashType) : HashType {
        if (left < right) {
            makeHash(left # right)
        } else {
            makeHash(right # left)
        }
    };

    // Get all trees (most recent first)
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

    // Generate Merkle proof for data verification safely
    private func generateMerkleProof(leaves: Buffer.Buffer<HashType>, index: Nat) : [HashType] {
        let proof = Buffer.Buffer<HashType>(0);
        var currentLevel = leaves;
        var currentIndex = index;

        while (currentLevel.size() > 1) {
            let nextLevel = Buffer.Buffer<HashType>(0);
            var i = 0;
            let levelSize = currentLevel.size();
            
            while (i < levelSize) {
                let left = currentLevel.get(i);
                let right = if (i + 1 < levelSize) {
                    currentLevel.get(i + 1)
                } else {
                    left
                };

                // Handle sibling selection safely without subtraction
                if (i < levelSize and currentIndex < levelSize) {
                    let isLeftNode = currentIndex % 2 == 0;
                    if (isLeftNode and i == currentIndex) {
                        // For left nodes, add the right sibling if it exists
                        proof.add(right);
                    } else if (not isLeftNode and i + 1 == currentIndex) {
                        // For right nodes, add the left sibling
                        proof.add(left);
                    };
                };

                nextLevel.add(hashPair(left, right));
                i += 2;
            };

            currentLevel := nextLevel;
            currentIndex := if (currentIndex == 0) { 0 } else { currentIndex / 2 };
        };

        Buffer.toArray(proof)
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
                    let hash = makeHash(reading.sensorHash # Int.toText(record.timestamp));
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

    // Public function to verify Merkle proof
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
};
