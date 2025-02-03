import Principal "mo:base/Principal";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";

actor SmartContract {
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

    // Generate hash for reading
    private func generateReadingHash(reading: Reading) : Text {
        let hashInput = reading.device_id # 
                       debug_show(reading.device_type) # 
                       reading.parameter #
                       Float.toText(reading.value) #
                       Int.toText(reading.created_at);
        
        let hashValue = Text.hash(hashInput);
        Nat32.toText(hashValue)
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

                switch(readings.get(device_id)) {
                    case null {
                        readings.put(device_id, [reading]);
                    };
                    case (?existingReadings) {
                        let newReadings = Array.append(existingReadings, [reading]);
                        readings.put(device_id, newReadings);
                    };
                };

                return "Reading inserted successfully";
            };
        };
    };

    // Convert Reading to ReadingWithHash
    private func addHashToReading(reading: Reading) : ReadingWithHash {
        {
            device_id = reading.device_id;
            device_type = reading.device_type;
            parameter = reading.parameter;
            value = reading.value;
            created_at = reading.created_at;
            hash = generateReadingHash(reading);
        }
    };

    // Get readings by time range
    public query func getReadings(device_id: Text, start_time: Int, end_time: Int) : async [ReadingWithHash] {
        switch(readings.get(device_id)) {
            case null { return []; };
            case (?deviceReadings) {
                let filteredReadings = Array.filter(deviceReadings, func (reading: Reading) : Bool {
                    reading.created_at >= start_time and reading.created_at <= end_time
                });
                Array.map(filteredReadings, addHashToReading)
            };
        };
    };

    // Get all readings for a specific device
    public query func getAllReadingsForDevice(device_id: Text) : async [ReadingWithHash] {
        switch(readings.get(device_id)) {
            case null { return []; };
            case (?deviceReadings) {
                Array.map(deviceReadings, addHashToReading)
            };
        };
    };

    // Get readings for multiple devices
    public query func getMultipleDeviceReadings(device_ids: [Text]) : async [(Text, [ReadingWithHash])] {
        Array.map<Text, (Text, [ReadingWithHash])>(
            device_ids,
            func (device_id: Text) : (Text, [ReadingWithHash]) {
                let deviceReadings = switch(readings.get(device_id)) {
                    case null { []; };
                    case (?readings) {
                        Array.map(readings, addHashToReading)
                    };
                };
                (device_id, deviceReadings)
            }
        );
    };

    // Get readings for multiple devices with time range and parameter filter
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
                        Array.map(filtered, addHashToReading)
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
}
