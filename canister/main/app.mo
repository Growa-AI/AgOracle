import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Buffer "mo:base/Buffer";

actor MainContract {
  // TYPES
  public type ServiceType = {
    #Insurance; // Insurance service
    #Banking; // Banking service
    #Vendor; // Vendor service
    #Research; // Research service
    #Developer; // Developer service
    #Subscriptions; // Subscription management
  };

  // STORAGE
  private stable var currentAdmin : ?Principal = null;
  private let serviceRegistry = HashMap.HashMap<ServiceType, Buffer.Buffer<Principal>>(
    0,
    func(x : ServiceType, y : ServiceType) {
      debug_show (x) == debug_show (y)
    },
    func(x : ServiceType) {
      Text.hash(debug_show (x))
    }
  );

  // Used canisters registry to prevent cross-service usage
  private let usedCanisters = HashMap.HashMap<Principal, ServiceType>(0, Principal.equal, Principal.hash);

  // Storage canisters registry
  private let storageRegistry = HashMap.HashMap<Nat, Principal>(0, Nat.equal, Hash.hash);
  private stable var nextStorageId : Nat = 0;

  // INITIALIZATION
  private func initializeRegistries() {
    for (serviceType in [#Insurance, #Banking, #Vendor, #Research, #Developer, #Subscriptions].vals()) {
      serviceRegistry.put(serviceType, Buffer.Buffer<Principal>(0))
    }
  };
  initializeRegistries();

  // ADMIN MANAGEMENT
  public shared (msg) func becomeAdmin() : async Bool {
    switch (currentAdmin) {
      case (null) {
        currentAdmin := ?msg.caller;
        return true
      };
      case (?_admin) {
        return false
      }
    }
  };

  public shared (msg) func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can transfer privileges")
        };
        currentAdmin := ?newAdmin;
        return #ok("Admin transferred successfully")
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  // SERVICE REGISTRY MANAGEMENT
  public shared (msg) func registerServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can register canisters")
        };

        // Check if canister is already used in another service
        switch (usedCanisters.get(canisterId)) {
          case (?_existingService) {
            return #err("Canister is already used in another service")
          };
          case (null) {
            switch (serviceRegistry.get(serviceType)) {
              case (?canisters) {
                canisters.add(canisterId);
                usedCanisters.put(canisterId, serviceType);
                return #ok("Service canister registered successfully")
              };
              case (null) {
                let newBuffer = Buffer.Buffer<Principal>(1);
                newBuffer.add(canisterId);
                serviceRegistry.put(serviceType, newBuffer);
                usedCanisters.put(canisterId, serviceType);
                return #ok("Service canister registered successfully")
              }
            }
          }
        }
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  public shared (msg) func deregisterServiceCanister(serviceType : ServiceType, canisterId : Principal) : async Result.Result<Text, Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can deregister canisters")
        };

        switch (serviceRegistry.get(serviceType)) {
          case (?canisters) {
            let index = Buffer.indexOf<Principal>(canisterId, canisters, Principal.equal);
            switch (index) {
              case (?i) {
                let _ = canisters.remove(i);
                usedCanisters.delete(canisterId);
                return #ok("Service canister deregistered successfully")
              };
              case (null) {
                return #err("Canister not found in this service")
              }
            }
          };
          case (null) {
            return #err("Service type not found")
          }
        }
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  // STORAGE REGISTRY MANAGEMENT
  public shared (msg) func addStorageCanister(canisterId : Principal) : async Result.Result<Text, Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can add storage canisters")
        };

        // Check if canister is already registered
        for ((_, existingId) in storageRegistry.entries()) {
          if (Principal.equal(existingId, canisterId)) {
            return #err("Storage canister already registered")
          }
        };

        let id = nextStorageId;
        nextStorageId += 1;
        storageRegistry.put(id, canisterId);
        return #ok("Storage canister added successfully. ID: " # Nat.toText(id))
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  public shared (msg) func removeStorageCanister(storageId : Nat) : async Result.Result<Text, Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can remove storage canisters")
        };

        switch (storageRegistry.get(storageId)) {
          case (?_) {
            storageRegistry.delete(storageId);
            return #ok("Storage canister removed successfully")
          };
          case (null) {
            return #err("Storage canister not found")
          }
        }
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  // QUERY FUNCTIONS
  public query (msg) func getServiceCanisters(serviceType : ServiceType) : async Result.Result<[Principal], Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can query service canisters")
        };

        switch (serviceRegistry.get(serviceType)) {
          case (?canisters) {
            #ok(Buffer.toArray(canisters))
          };
          case (null) {
            #err("Service type not found")
          }
        }
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  public query (msg) func getAllServiceCanisters() : async Result.Result<[(ServiceType, [Principal])], Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can query all service canisters")
        };

        var canisters : [(ServiceType, [Principal])] = [];
        for ((typ, buffer) in serviceRegistry.entries()) {
          canisters := Array.append(canisters, [(typ, Buffer.toArray(buffer))])
        };
        #ok(canisters)
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  public query (msg) func getAllStorageCanisters() : async Result.Result<[(Nat, Principal)], Text> {
    switch (currentAdmin) {
      case (?admin) {
        if (msg.caller != admin) {
          return #err("Only admin can query storage canisters")
        };

        var canisters : [(Nat, Principal)] = [];
        for ((id, canisterId) in storageRegistry.entries()) {
          canisters := Array.append(canisters, [(id, canisterId)])
        };
        #ok(canisters)
      };
      case (null) {
        return #err("No admin set")
      }
    }
  };

  public query func getCurrentAdmin() : async ?Principal {
    return currentAdmin
  }
}
