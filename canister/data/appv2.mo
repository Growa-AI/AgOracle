import Principal "mo:base/Principal";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import Int "mo:base/Int";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

actor SmartContract {
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

    // Get first n characters of a text
    private func textSlice(t: Text, from: Nat, to: Nat) : Text {
        let chars = t.chars();
        var i = 0;
        var text = "";
        label l loop {
            switch(chars.next()) {
                case null break l;
                case (?c) {
                    if (i >= from and i < to) {
                        text := text # Text.fromChar(c);
                    };
                    i += 1;
                };
            };
        };
        return text;
    };

    // Types
    type DeviceType = {
        #Physical;
        #Virtual;
    };

    type Reading = {
        device_id: Text;
        device_type: DeviceType;
        parameter: Text;
        value: Float;
        created_at: Int;
    };

    type ReadingWithHash = {
        device_id: Text;
        device_type: DeviceType;
        parameter: Text;
        value: Float;
        created_at: Int;
        hash: Text;
    };

    type Role = {
        #Admin;
        #Moderator;
        #User;
    };

    // State variables
    private stable var owner: ?Principal = null;
    private var authorizedUsers = HashMap.HashMap<Principal, Role>(0, Principal.equal, Principal.hash);
    private var readings = HashMap.HashMap<Text, [Reading]>(0, Text.equal, Text.hash);
    private var readingsByHash = HashMap.HashMap<Text, Reading>(0, Text.equal, Text.hash);
    private stable var nonce: Nat = 0;

    // Generate unique hash for reading
    private func generateReadingHash(reading: Reading) : Text {
        // Increment nonce for additional uniqueness
        nonce += 1;
        
        // Create a buffer for the data to hash
        let messageBuffer = Buffer.Buffer<Nat8>(100);
        
        // Add device_id bytes
        let deviceIdBytes = Blob.toArray(Text.encodeUtf8(reading.device_id));
        for (b in deviceIdBytes.vals()) {
            messageBuffer.add(b);
        };
        
        // Add separator
        messageBuffer.add(0x7c); // "|" byte
        
        // Add device_type
        let deviceTypeBytes = Blob.toArray(Text.encodeUtf8(debug_show(reading.device_type)));
        for (b in deviceTypeBytes.vals()) {
            messageBuffer.add(b);
        };
        
        // Add separator
        messageBuffer.add(0x7c);
        
        // Add parameter
        let parameterBytes = Blob.toArray(Text.encodeUtf8(reading.parameter));
        for (b in parameterBytes.vals()) {
            messageBuffer.add(b);
        };
        
        // Add separator
        messageBuffer.add(0x7c);
        
        // Add value
        let valueBytes = Blob.toArray(Text.encodeUtf8(Float.toText(reading.value)));
        for (b in valueBytes.vals()) {
            messageBuffer.add(b);
        };
        
        // Add separator
        messageBuffer.add(0x7c);
        
        // Add timestamp
        let timestampBytes = Blob.toArray(Text.encodeUtf8(Int.toText(reading.created_at)));
        for (b in timestampBytes.vals()) {
            messageBuffer.add(b);
        };
        
        // Add separator
        messageBuffer.add(0x7c);
        
        // Add nonce
        let nonceBytes = Blob.toArray(Text.encodeUtf8(Nat.toText(nonce)));
        for (b in nonceBytes.vals()) {
            messageBuffer.add(b);
        };

        // Calculate SHA256
        let hash = sha256(Buffer.toArray(messageBuffer));
        
        // Convert to hex string
        let hashHex = bytesToHex(hash);
        
        // Take first 8 chars for prefix from device_id hash
        let deviceHash = sha256(deviceIdBytes);
        let prefix = textSlice(bytesToHex(deviceHash), 0, 8);
        
        // Get timestamp
        let timestamp = Int.abs(Time.now()) % 1_000_000;
        
        // Combine all parts
        prefix # "-" # hashHex # "-" # Nat.toText(timestamp)
    };

    // Admin assignment function - can only be called once if no owner exists
    public shared(msg) func assignAdmin() : async Text {
        switch(owner) {
            case null {
                owner := ?msg.caller;
                authorizedUsers.put(msg.caller, #Admin);
                return "Admin rights assigned successfully";
            };
            case (?_) {
                throw Error.reject("Admin already assigned");
            };
        };
    };

    // Transfer ownership to a new admin
    public shared(msg) func transferOwnership(newOwner: Principal) : async Text {
        switch(owner) {
            case null {
                throw Error.reject("No admin assigned yet");
            };
            case (?currentOwner) {
                if (Principal.equal(msg.caller, currentOwner)) {
                    owner := ?newOwner;
                    authorizedUsers.delete(currentOwner);
                    authorizedUsers.put(newOwner, #Admin);
                    return "Ownership transferred successfully to new admin";
                } else {
                    throw Error.reject("Only current admin can transfer ownership");
                };
            };
        };
    };

    // Check caller's role
    private func getCallerRole(caller: Principal) : Role {
        switch(authorizedUsers.get(caller)) {
            case null { #User };
            case (?role) { role };
        };
    };

    // Check if caller is admin
    private func isAdmin(caller: Principal) : Bool {
        switch(getCallerRole(caller)) {
            case (#Admin) { true };
            case (_) { false };
        };
    };

    // Check if caller is moderator or admin
    private func isModeratorOrAdmin(caller: Principal) : Bool {
        switch(getCallerRole(caller)) {
            case (#Admin) { true };
            case (#Moderator) { true };
            case (_) { false };
        };
    };

    // Add authorized user with role
    public shared(msg) func addAuthorizedUser(user: Principal, role: Role) : async Text {
        if (not isAdmin(msg.caller)) {
            throw Error.reject("Only admin can add authorized users");
        };
        
        switch(role) {
            case (#Admin) {
                throw Error.reject("Cannot add another admin. Use transferOwnership instead.");
            };
            case (_) {
                authorizedUsers.put(user, role);
                return "User authorized successfully with role: " # debug_show(role);
            };
        };
    };

    // Remove authorized user
    public shared(msg) func removeAuthorizedUser(user: Principal) : async Text {
        if (not isModeratorOrAdmin(msg.caller)) {
            throw Error.reject("Only admin or moderator can remove authorized users");
        };

        switch(getCallerRole(user)) {
            case (#Admin) {
                throw Error.reject("Cannot remove admin user");
            };
            case (_) {
                authorizedUsers.delete(user);
                return "User removed successfully";
            };
        };
    };

    // Insert reading with optional timestamp
    public shared(msg) func insertReading(
        device_id: Text,
        device_type: DeviceType,
        parameter: Text,
        value: Float,
        timestamp: ?Int
    ) : async Text {
        switch(authorizedUsers.get(msg.caller)) {
            case null {
                throw Error.reject("Unauthorized user");
            };
            case (?role) {
                if (role == #User) {
                    throw Error.reject("Unauthorized user");
                };
                
                let current_time = switch(timestamp) {
                    case null { Time.now() };
                    case (?t) { 
                        if (t == 0) { Time.now() } 
                        else { t }
                    };
                };

                let reading: Reading = {
                    device_id;
                    device_type;
                    parameter;
                    value;
                    created_at = current_time;
                };

                // Generate hash before storing
                let readingHash = generateReadingHash(reading);
                
                // Store in both maps
                switch(readings.get(device_id)) {
                    case null {
                        readings.put(device_id, [reading]);
                    };
                    case (?existingReadings) {
                        let newReadings = Array.append(existingReadings, [reading]);
                        readings.put(device_id, newReadings);
                    };
                };
                
                readingsByHash.put(readingHash, reading);

                return "Reading inserted successfully. Hash: " # readingHash;
            };
        };
    };

    // Get readings by time range
    public query func getReadings(device_id: Text, start_time: Int, end_time: Int) : async [ReadingWithHash] {
        switch(readings.get(device_id)) {
            case null { return []; };
            case (?deviceReadings) {
                let filteredReadings = Array.filter(deviceReadings, func (reading: Reading) : Bool {
                    reading.created_at >= start_time and reading.created_at <= end_time
                });
                Array.map(filteredReadings, func (reading: Reading) : ReadingWithHash {
                    {
                        device_id = reading.device_id;
                        device_type = reading.device_type;
                        parameter = reading.parameter;
                        value = reading.value;
                        created_at = reading.created_at;
                        hash = generateReadingHash(reading);
                    }
                })
            };
        };
    };

    // Get reading by hash
    public query func getReadingByHash(hash: Text) : async ?ReadingWithHash {
        switch(readingsByHash.get(hash)) {
            case null { null };
            case (?reading) {
                ?{
                    device_id = reading.device_id;
                    device_type = reading.device_type;
                    parameter = reading.parameter;
                    value = reading.value;
                    created_at = reading.created_at;
                    hash = hash;
                }
            };
        };
    };

    // Get all readings for a specific device
    public query func getAllReadingsForDevice(device_id: Text) : async [ReadingWithHash] {
        switch(readings.get(device_id)) {
            case null { return []; };
            case (?deviceReadings) {
                Array.map(deviceReadings, func (reading: Reading) : ReadingWithHash {
                    {
                        device_id = reading.device_id;
                        device_type = reading.device_type;
                        parameter = reading.parameter;
                        value = reading.value;
                        created_at = reading.created_at;
                        hash = generateReadingHash(reading);
                    }
                })
            };
        };
    };

    // Get readings for multiple devices with filtering
    public query func getFilteredReadings(
        device_ids: [Text],
        parameter: ?Text,
        device_type: ?DeviceType,
        start_time: Int,
        end_time: Int
    ) : async [(Text, [ReadingWithHash])] {
        Array.map<Text, (Text, [ReadingWithHash])>(
            device_ids,
            func (device_id: Text) : (Text, [ReadingWithHash]) {
                let deviceReadings = switch(readings.get(device_id)) {
                    case null { []; };
                    case (?readings) {
                        let filtered = Array.filter<Reading>(
                            readings,
                            func (reading: Reading) : Bool {
                                let timeMatch = reading.created_at >= start_time and reading.created_at <= end_time;
                                let paramMatch = switch(parameter) {
                                    case null { true };
                                    case (?p) { reading.parameter == p };
                                };
                                let typeMatch = switch(device_type) {
                                    case null { true };
                                    case (?t) { reading.device_type == t };
                                };
                                timeMatch and paramMatch and typeMatch
                            }
                        );
                        Array.map(filtered, func (reading: Reading) : ReadingWithHash {
                            {
                                device_id = reading.device_id;
                                device_type = reading.device_type;
                                parameter = reading.parameter;
                                value = reading.value;
                                created_at = reading.created_at;
                                hash = generateReadingHash(reading);
                            }
                        })
                    };
                };
                (device_id, deviceReadings)
            }
        );
    };

    // Get current admin
    public query func getAdmin() : async ?Principal {
        return owner;
    };

    // Get user role
    public query func getUserRole(user: Principal) : async Role {
        return getCallerRole(user);
    };
};
