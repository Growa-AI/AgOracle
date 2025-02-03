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

actor MainContract {
  // TYPES
  public type ServiceType = {
    #Insurance;
    #Banking;
    #Vendor;
    #Research;
    #Developer;
    #Subscriptions;
  };

  // STORAGE
  private stable var currentOwner : Principal = Principal.fromText("2vxsx-fae"); // Default owner
  private stable var currentAdmin : ?Principal = null;
  private stable var moderators : [Principal] = [];
  
  private let serviceRegistry = HashMap.HashMap<ServiceType, Buffer.Buffer<Principal>>(
    0,
    func(x : ServiceType, y : ServiceType) { debug_show (x) == debug_show (y) },
    func(x : ServiceType) { Text.hash(debug_show (x)) }
  );

  private let usedCanisters = HashMap.HashMap<Principal, ServiceType>(0, Principal.equal, Principal.hash);
  private let storageRegistry = HashMap.HashMap<Nat, Principal>(0, Nat.equal, Hash.hash);
  private stable var nextStorageId : Nat = 0;

  // INITIALIZATION
  private func initializeRegistries() {
    for (serviceType in [#Insurance, #Banking, #Vendor, #Research, #Developer, #Subscriptions].vals()) {
      serviceRegistry.put(serviceType, Buffer.Buffer<Principal>(0));
    };
  };
  initializeRegistries();

  // HELPER FUNCTIONS
  private func isOwnerOrAdmin(caller : Principal) : Bool {
    if (caller == currentOwner) return true;
    switch (currentAdmin) {
      case (?admin) if (caller == admin) return true;
      case (null) {};
    };
    return false;
  };

  private func isModerator(caller : Principal) : Bool {
    return Array.find<Principal>(moderators, func(mod) { mod == caller }) != null;
  };

  // OWNER-ONLY FUNCTIONS
  public shared(msg) func transferOwnership(newOwner : Principal) : async Result.Result<Text, Text> {
    if (msg.caller != currentOwner) {
      return #err("Only the owner can transfer ownership");
    };
    currentOwner := newOwner;
    return #ok("Ownership transferred successfully");
  };

  type Wallet = actor {
    wallet_receive : shared () -> async Nat;
  };

  public shared(msg) func withdrawCycles(amount: Nat) : async Result.Result<Text, Text> {
    if (msg.caller != currentOwner) {
      return #err("Only the owner can withdraw cycles");
    };

    let available = Cycles.balance();
    if (available < amount) {
      return #err("Insufficient cycles balance");
    };

    try {
      Cycles.add(amount);
      let wallet = actor(Principal.toText(msg.caller)) : Wallet;
      let _ = await wallet.wallet_receive();
      return #ok("Cycles withdrawn successfully");
    } catch (e) {
      return #err("Failed to withdraw cycles: " # Error.message(e));
    };
  };

  // ADMIN MANAGEMENT
  public shared(msg) func becomeAdmin() : async Bool {
    if (msg.caller != currentOwner) {
      return false;
    };
    switch (currentAdmin) {
      case (null) {
        currentAdmin := ?msg.caller;
        return true;
      };
      case (?_admin) {
        return false;
      };
    };
  };

  public shared(msg) func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text> {
    if (msg.caller != currentOwner) {
      return #err("Only owner can transfer admin privileges");
    };
    currentAdmin := ?newAdmin;
    return #ok("Admin transferred successfully");
  };

  // MODERATOR MANAGEMENT (OWNER/ADMIN ONLY)
  public shared(msg) func addModerator(moderator : Principal) : async Result.Result<Text, Text> {
    if (not isOwnerOrAdmin(msg.caller)) {
      return #err("Only owner or admin can add moderators");
    };
    
    // Check if moderator already exists
    switch (Array.find<Principal>(moderators, func(mod) { mod == moderator })) {
      case (?_) { return #err("Moderator already exists") };
      case (null) {
        moderators := Array.append(moderators, [moderator]);
        return #ok("Moderator added successfully");
      };
    };
  };

  public shared(msg) func removeModerator(moderator : Principal) : async Result.Result<Text, Text> {
    if (not isOwnerOrAdmin(msg.caller)) {
      return #err("Only owner or admin can remove moderators");
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

  // SERVICE REGISTRY MANAGEMENT
  public shared(msg) func registerServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
    if (not (isOwnerOrAdmin(msg.caller) or isModerator(msg.caller))) {
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

  public shared(msg) func deregisterServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
    if (not (isOwnerOrAdmin(msg.caller) or isModerator(msg.caller))) {
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

  // STORAGE REGISTRY MANAGEMENT
  public shared(msg) func addStorageCanister(canisterId : Principal) : async Result.Result<Text, Text> {
    if (not (isOwnerOrAdmin(msg.caller) or isModerator(msg.caller))) {
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

  public shared(msg) func removeStorageCanister(storageId : Nat) : async Result.Result<Text, Text> {
    if (not (isOwnerOrAdmin(msg.caller) or isModerator(msg.caller))) {
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

  // QUERY FUNCTIONS
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

  public query func getAllServiceCanisters() : async Result.Result<[(ServiceType, [Principal])], Text> {
    var canisters : [(ServiceType, [Principal])] = [];
    for ((typ, buffer) in serviceRegistry.entries()) {
      canisters := Array.append(canisters, [(typ, Buffer.toArray(buffer))]);
    };
    #ok(canisters);
  };

  public query func getAllStorageCanisters() : async Result.Result<[(Nat, Principal)], Text> {
    var canisters : [(Nat, Principal)] = [];
    for ((id, canisterId) in storageRegistry.entries()) {
      canisters := Array.append(canisters, [(id, canisterId)]);
    };
    #ok(canisters);
  };

  public query func getCurrentAdmin() : async ?Principal {
    return currentAdmin;
  };

  public query func getCurrentOwner() : async Principal {
    return currentOwner;
  };

  public query func getModerators() : async [Principal] {
    return moderators;
  };
}
