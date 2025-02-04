/**
 * Main Registry Contract
 * 
 * This contract serves as a central registry for managing different types of services,
 * storage canisters, and access control. It implements a role-based access control
 * system with admins and moderators.
 */

import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Nat32 "mo:base/Nat32";

actor MainContract {
    /**
     * ServiceType defines the different categories of services that can be registered
     * in the system. Each service type represents a different domain or functionality.
     */
    public type ServiceType = {
        #Insurance;  // Insurance-related services
        #Banking;    // Banking and financial services
        #Vendor;     // Vendor and marketplace services
        #Research;   // Research and analysis services
        #Developer;  // Developer tools and services
        #Subscriptions;  // Subscription-based services
    };

    /**
     * Custom hash function for Nat values to ensure better distribution
     * and avoid potential collisions in the storage registry
     * @param n - The Nat value to hash
     * @return Hash.Hash - The computed hash value
     */
    private func natHash(n: Nat) : Hash.Hash {
        let hashValue = Nat32.fromNat(n);
        let rotated = Nat32.bitrotLeft(hashValue, 5);
        hashValue ^ rotated
    };

    // ===== STATE VARIABLES =====
    
    /**
     * Current admin of the contract. Can only be set once through becomeAdmin()
     * The admin has full control over the contract's functionality
     */
    private stable var currentAdmin : ?Principal = null;
    
    /**
     * List of moderators who have elevated privileges but less than admin
     * Moderators can manage service and storage canisters
     */
    private stable var moderators : [Principal] = [];
    
    /**
     * Registry mapping service types to their associated canisters
     * Each service type can have multiple canisters implementing it
     */
    private let serviceRegistry = HashMap.HashMap<ServiceType, Buffer.Buffer<Principal>>(
        0,
        func(x : ServiceType, y : ServiceType) { debug_show(x) == debug_show(y) },
        func(x : ServiceType) { Text.hash(debug_show(x)) }
    );

    /**
     * Tracks which canister belongs to which service to prevent duplicates
     * A canister can only be registered to one service type at a time
     */
    private let usedCanisters = HashMap.HashMap<Principal, ServiceType>(0, Principal.equal, Principal.hash);
    
    /**
     * Registry for storage canisters with numeric IDs for easy reference
     * Each storage canister gets a unique numeric identifier
     */
    private let storageRegistry = HashMap.HashMap<Nat, Principal>(0, Nat.equal, natHash);
    
    /**
     * Counter for generating unique IDs for storage canisters
     */
    private stable var nextStorageId : Nat = 0;

    // ===== INITIALIZATION =====
    
    /**
     * Initializes the service registry with empty buffers for each service type
     * Called during contract deployment
     */
    private func initializeRegistries() {
        for (serviceType in [#Insurance, #Banking, #Vendor, #Research, #Developer, #Subscriptions].vals()) {
            serviceRegistry.put(serviceType, Buffer.Buffer<Principal>(0));
        };
    };
    initializeRegistries();

    // ===== HELPER FUNCTIONS =====
    
    /**
     * Checks if the provided principal is the current admin
     * @param caller - Principal to check
     * @return Bool - True if caller is admin
     */
    private func isAdmin(caller : Principal) : Bool {
        switch (currentAdmin) {
            case (?admin) { caller == admin };
            case (null) { false };
        };
    };

    /**
     * Checks if the provided principal is a moderator
     * @param caller - Principal to check
     * @return Bool - True if caller is a moderator
     */
    private func isModerator(caller : Principal) : Bool {
        return Array.find<Principal>(moderators, func(mod) { mod == caller }) != null;
    };

    // ===== ADMIN MANAGEMENT =====
    
    /**
     * Allows the first caller to become the admin of the contract
     * Can only be called once - subsequent calls will fail
     * @return Result indicating success or failure
     */
    public shared(msg) func becomeAdmin() : async Result.Result<Text, Text> {
        switch (currentAdmin) {
            case (null) {
                currentAdmin := ?msg.caller;
                #ok("Admin rights assigned successfully");
            };
            case (?_) {
                #err("Admin already assigned");
            };
        };
    };

    /**
     * Allows current admin to transfer admin privileges to another principal
     * @param newAdmin - Principal to receive admin privileges
     * @return Result indicating success or failure
     */
    public shared(msg) func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text> {
        if (not isAdmin(msg.caller)) {
            return #err("Only current admin can transfer privileges");
        };
        currentAdmin := ?newAdmin;
        return #ok("Admin transferred successfully");
    };

    /**
     * Interface for interacting with cycles wallet
     */
    type Wallet = actor {
        wallet_receive : shared () -> async Nat;
    };

    /**
     * Allows admin to withdraw cycles from the contract
     * @param amount - Amount of cycles to withdraw
     * @return Result indicating success or failure
     */
    public shared(msg) func withdrawCycles(amount: Nat) : async Result.Result<Text, Text> {
        if (not isAdmin(msg.caller)) {
            return #err("Only admin can withdraw cycles");
        };

        let available = Cycles.balance();
        if (available < amount) {
            return #err("Insufficient cycles balance");
        };

        try {
            Cycles.add<system>(amount);
            let wallet = actor(Principal.toText(msg.caller)) : Wallet;
            let _ = await wallet.wallet_receive();
            return #ok("Cycles withdrawn successfully");
        } catch (e) {
            return #err("Failed to withdraw cycles: " # Error.message(e));
        };
    };

    // ===== MODERATOR MANAGEMENT =====
    
    /**
     * Adds a new moderator to the system
     * @param moderator - Principal to add as moderator
     * @return Result indicating success or failure
     */
    public shared(msg) func addModerator(moderator : Principal) : async Result.Result<Text, Text> {
        if (not isAdmin(msg.caller)) {
            return #err("Only admin can add moderators");
        };
        
        switch (Array.find<Principal>(moderators, func(mod) { mod == moderator })) {
            case (?_) { return #err("Moderator already exists") };
            case (null) {
                moderators := Array.append(moderators, [moderator]);
                return #ok("Moderator added successfully");
            };
        };
    };

    /**
     * Removes a moderator from the system
     * @param moderator - Principal to remove from moderators
     * @return Result indicating success or failure
     */
    public shared(msg) func removeModerator(moderator : Principal) : async Result.Result<Text, Text> {
        if (not isAdmin(msg.caller)) {
            return #err("Only admin can remove moderators");
        };
        
        let newModerators = Array.filter<Principal>(
            moderators,
            func(mod) { mod != moderator }
        );
        
        if (moderators.size() == newModerators.size()) {
            return #err("Moderator not found");
        };
        
        moderators := newModerators;
        return #ok("Moderator removed successfully");
    };

    // ===== SERVICE REGISTRY MANAGEMENT =====
    
    /**
     * Registers a canister for a specific service type
     * Can be called by admin or moderators
     * @param serviceType - Type of service to register
     * @param canisterId - Principal of the canister to register
     * @return Result indicating success or failure
     */
    public shared(msg) func registerServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
        if (not (isAdmin(msg.caller) or isModerator(msg.caller))) {
            return #err("Not authorized");
        };

        switch (usedCanisters.get(canisterId)) {
            case (?_existingService) {
                return #err("Canister is already used in another service");
            };
            case (null) {
                switch (serviceRegistry.get(serviceType)) {
                    case (?canisters) {
                        canisters.add(canisterId);
                        usedCanisters.put(canisterId, serviceType);
                        return #ok("Service canister registered successfully");
                    };
                    case (null) {
                        let newBuffer = Buffer.Buffer<Principal>(1);
                        newBuffer.add(canisterId);
                        serviceRegistry.put(serviceType, newBuffer);
                        usedCanisters.put(canisterId, serviceType);
                        return #ok("Service canister registered successfully");
                    };
                };
            };
        };
    };

    /**
     * Deregisters a canister from a service type
     * Can be called by admin or moderators
     * @param serviceType - Type of service to deregister from
     * @param canisterId - Principal of the canister to deregister
     * @return Result indicating success or failure
     */
    public shared(msg) func deregisterServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
        if (not (isAdmin(msg.caller) or isModerator(msg.caller))) {
            return #err("Not authorized");
        };

        switch (serviceRegistry.get(serviceType)) {
            case (?canisters) {
                let index = Buffer.indexOf<Principal>(canisterId, canisters, Principal.equal);
                switch (index) {
                    case (?i) {
                        let _ = canisters.remove(i);
                        usedCanisters.delete(canisterId);
                        return #ok("Service canister deregistered successfully");
                    };
                    case (null) {
                        return #err("Canister not found in this service");
                    };
                };
            };
            case (null) {
                return #err("Service type not found");
            };
        };
    };

    // ===== STORAGE REGISTRY MANAGEMENT =====
    
    /**
     * Adds a storage canister to the registry
     * Can be called by admin or moderators
     * @param canisterId - Principal of the storage canister to add
     * @return Result indicating success or failure
     */
    public shared(msg) func addStorageCanister(canisterId : Principal) : async Result.Result<Text, Text> {
        if (not (isAdmin(msg.caller) or isModerator(msg.caller))) {
            return #err("Not authorized");
        };

        for ((_, existingId) in storageRegistry.entries()) {
            if (Principal.equal(existingId, canisterId)) {
                return #err("Storage canister already registered");
            };
        };

        let id = nextStorageId;
        nextStorageId += 1;
        storageRegistry.put(id, canisterId);
        return #ok("Storage canister added successfully. ID: " # Nat.toText(id));
    };

    /**
     * Removes a storage canister from the registry
     * Can be called by admin or moderators
     * @param storageId - ID of the storage canister to remove
     * @return Result indicating success or failure
     */
    public shared(msg) func removeStorageCanister(storageId : Nat) : async Result.Result<Text, Text> {
        if (not (isAdmin(msg.caller) or isModerator(msg.caller))) {
            return #err("Not authorized");
        };

        switch (storageRegistry.get(storageId)) {
            case (?_) {
                storageRegistry.delete(storageId);
                return #ok("Storage canister removed successfully");
            };
            case (null) {
                return #err("Storage canister not found");
            };
        };
    };

    // ===== QUERY FUNCTIONS =====
    
    /**
     * Gets all canisters registered for a specific service type
     * @param serviceType - Service type to query
     * @return Result containing array of canister principals or error
     */
    public query func getServiceCanisters(serviceType : ServiceType) : async Result.Result<[Principal], Text> {
        switch (serviceRegistry.get(serviceType)) {
            case (?canisters) {
                #ok(Buffer.toArray(canisters));
            };
            case (null) {
                #err("Service type not found");
            };
        };
    };

    /**
     * Gets all registered service canisters grouped by service type
     * @return Result containing array of tuples (service type, canister principals)
     */
    public query func getAllServiceCanisters() : async Result.Result<[(ServiceType, [Principal])], Text> {
        var canisters : [(ServiceType, [Principal])] = [];
        for ((typ, buffer) in serviceRegistry.entries()) {
            canisters := Array.append(canisters, [(typ, Buffer.toArray(buffer))]);
        };
        #ok(canisters);
    };

    /**
     * Gets all registered storage canisters with their IDs
     * @return Result containing array of tuples (storage ID, canister principal)
     */
    public query func getAllStorageCanisters() : async Result.Result<[(Nat, Principal)], Text> {
        var canisters : [(Nat, Principal)] = [];
        for ((id, canisterId) in storageRegistry.entries()) {
            canisters := Array.append(canisters, [(id, canisterId)]);
        };
        #ok(canisters);
    };

    /**
     * Gets the current admin's principal
     * @return Optional principal of the current admin
     */
    public query func getCurrentAdmin() : async ?Principal {
        return currentAdmin;
    };

    /**
     * Gets the list of all moderators
     * @return Array of moderator principals
     */
    public query func getModerators() : async [Principal] {
        return moderators;
    };
};
