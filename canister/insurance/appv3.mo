import Error "mo:base/Error";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Order "mo:base/Order";

actor class InsuranceSystem() {
  // Type definitions
  public type ClaimReason = {
    #hail;
    #drought;
    #flood;
    #frost;
    #pest;
    #disease;
    #fire;
    #wind;
    #other
  };

  public type Decision = {
    #approved;
    #rejected
  };

  public type DataMatchType = {
    #pending;
    #limited;
    #accurate;
    #partial
  };

  public type PriceUSD = {
    bundleSize : Nat;
    bundlePriceUSD : Float;
    claimPriceUSD : Float
  };

  public type UserCredits = {
    onboardingCredits : Nat;
    claimCredits : Nat
  };

  public type User = {
    id : Principal;
    registrationTime : Time.Time;
    credits : UserCredits
  };

  public type Policy = {
    policyId : Text;
    userId : Principal;
    country : Text;
    insuredAmount : Float;
    crop : Text;
    landPolygon : Text;
    creationTime : Time.Time
  };

  public type Claim = {
    claimId : Text;
    policyId : Text;
    userId : Principal;
    locationPoint : Text;
    claimReason : ClaimReason;
    claimAmount : Float;
    damagePertentage : Float;
    status : DataMatchType;
    decision : ?Decision;
    report : ?Text;
    dataEvent : Text;
    creationTime : Time.Time
  };

  public type AnalyticsStats = {
    totalPolicies : Nat;
    totalClaims : Nat;
    totalApprovedClaims : Nat;
    totalPendingClaims : Nat;
    totalRejectedClaims : Nat;
    totalInsuredAmount : Float;
    totalClaimAmount : Float;
    totalPaidAmount : Float
  };

  public type SimpleAnalytics = {
    var totalPolicies : Nat;
    var totalClaims : Nat;
    var totalApprovedClaims : Nat;
    var totalPendingClaims : Nat;
    var totalRejectedClaims : Nat;
    var totalInsuredAmount : Float;
    var totalClaimAmount : Float;
    var totalPaidAmount : Float
  };

  public type UserAnalytics = {
    var policies : Nat;
    var claims : Nat;
    var approvedClaims : Nat;
    var pendingClaims : Nat;
    var rejectedClaims : Nat;
    var totalInsuredAmount : Float;
    var totalClaimAmount : Float;
    var totalPaidAmount : Float
  };

  // Constants
  private let INITIAL_ONBOARDING_CREDITS : Nat = 200;
  private let INITIAL_CLAIM_CREDITS : Nat = 5;
  private let DEFAULT_USD_RATE : Float = 7.5;

  // State variables
  private stable var currentAdmin : ?Principal = null;
  private stable var moderators : [Principal] = [];
  private stable var currentUSDRate : Float = DEFAULT_USD_RATE;
  private stable var pricing : PriceUSD = {
    bundleSize = 50;
    bundlePriceUSD = 100.0;
    claimPriceUSD = 10.0
  };

  // Storage
  private let users = HashMap.HashMap<Principal, User>(0, Principal.equal, Principal.hash);
  private let policies = HashMap.HashMap<Text, Policy>(0, Text.equal, Text.hash);
  private let claims = HashMap.HashMap<Text, Claim>(0, Text.equal, Text.hash);

  // Authorization and validation functions
  private func isAdmin(caller : Principal) : Bool {
    switch (currentAdmin) {
      case (?admin) caller == admin;
      case (null) false
    }
  };

  private func isModerator(caller : Principal) : Bool {
    return Array.find<Principal>(moderators, func(mod) {mod == caller}) != null
  };

  private func validatePrincipal(p : Principal) : Bool {
    not Principal.isAnonymous(p) and Text.size(Principal.toText(p)) > 0
  };

  private func validatePolicy(
    policyId : Text,
    country : Text,
    insuredAmount : Float,
    crop : Text,
    landPolygon : Text
  ) : Result.Result<(), Text> {
    if (Text.size(policyId) == 0) return #err("Policy ID cannot be empty");
    if (Text.size(country) == 0) return #err("Country cannot be empty");
    if (insuredAmount <= 0) return #err("Insured amount must be positive");
    if (Text.size(crop) == 0) return #err("Crop cannot be empty");
    if (Text.size(landPolygon) == 0) return #err("Land polygon cannot be empty");
    #ok()
  };

  private func validateClaim(
    claimId : Text,
    locationPoint : Text,
    claimAmount : Float,
    damagePertentage : Float
  ) : Result.Result<(), Text> {
    if (Text.size(claimId) == 0) return #err("Claim ID cannot be empty");
    if (Text.size(locationPoint) == 0) return #err("Location point cannot be empty");
    if (claimAmount <= 0) return #err("Claim amount must be positive");
    if (damagePertentage < 0 or damagePertentage > 100) {
      return #err("Damage percentage must be between 0 and 100")
    };
    #ok()
  };

  // Core functionality
  public shared ({caller}) func becomeAdmin() : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    switch (currentAdmin) {
      case (null) {
        currentAdmin := ?caller;
        #ok("Admin set successfully")
      };
      case (?_) #err("Admin already set")
    }
  };

  public shared ({caller}) func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only current admin can transfer admin role")
    };

    if (not validatePrincipal(newAdmin)) {
      return #err("Invalid new admin principal")
    };

    currentAdmin := ?newAdmin;
    #ok("Admin transferred successfully")
  };

  public shared ({caller}) func addModerator(moderator : Principal) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can add moderators")
    };

    switch (Array.find<Principal>(moderators, func(mod) {mod == moderator})) {
      case (?_) {return #err("Moderator already exists")};
      case (null) {
        moderators := Array.append(moderators, [moderator]);
        return #ok("Moderator added successfully")
      }
    }
  };

  public shared ({caller}) func removeModerator(moderator : Principal) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can remove moderators")
    };

    let newModerators = Array.filter<Principal>(
      moderators,
      func(mod) {mod != moderator}
    );

    if (moderators.size() == newModerators.size()) {
      return #err("Moderator not found")
    };

    moderators := newModerators;
    return #ok("Moderator removed successfully")
  };

  public shared ({caller}) func registerUser() : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    switch (users.get(caller)) {
      case (?_) #err("User already registered");
      case (null) {
        let newUser : User = {
          id = caller;
          registrationTime = Time.now();
          credits = {
            onboardingCredits = INITIAL_ONBOARDING_CREDITS;
            claimCredits = INITIAL_CLAIM_CREDITS
          }
        };
        users.put(caller, newUser);
        #ok("User registered successfully")
      }
    }
  };

  public shared ({caller}) func addUserCredits(
    userId : Principal,
    onboardingCredits : Nat,
    claimCredits : Nat
  ) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can add credits")
    };

    switch (users.get(userId)) {
      case (?user) {
        let updatedUser : User = {
          id = user.id;
          registrationTime = user.registrationTime;
          credits = {
            onboardingCredits = user.credits.onboardingCredits + onboardingCredits;
            claimCredits = user.credits.claimCredits + claimCredits
          }
        };
        users.put(userId, updatedUser);
        #ok("Credits added successfully")
      };
      case (null) #err("User not found")
    }
  };

  // Policy and Claim Management
  public shared ({caller}) func createPolicy(
    policyId : Text,
    country : Text,
    insuredAmount : Float,
    crop : Text,
    landPolygon : Text
  ) : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    switch (users.get(caller)) {
      case (null) #err("User must be registered before creating a policy");
      case (?user) {
        if (user.credits.onboardingCredits == 0) {
          return #err("Insufficient onboarding credits")
        };

        switch (validatePolicy(policyId, country, insuredAmount, crop, landPolygon)) {
          case (#err(msg)) return #err(msg);
          case (#ok()) {
            let uniquePolicyKey = Text.concat(Principal.toText(caller), "_" # policyId);

            switch (policies.get(uniquePolicyKey)) {
              case (?_) return #err("Policy with this ID already exists");
              case (null) {
                let newPolicy : Policy = {
                  policyId = policyId;
                  userId = caller;
                  country = country;
                  insuredAmount = insuredAmount;
                  crop = crop;
                  landPolygon = landPolygon;
                  creationTime = Time.now()
                };

                let updatedUser : User = {
                  id = user.id;
                  registrationTime = user.registrationTime;
                  credits = {
                    onboardingCredits = user.credits.onboardingCredits - 1;
                    claimCredits = user.credits.claimCredits
                  }
                };

                policies.put(uniquePolicyKey, newPolicy);
                users.put(caller, updatedUser);
                #ok("Policy created successfully")
              }
            }
          }
        }
      }
    }
  };

  public shared ({caller}) func createClaim(
    policyId : Text,
    locationPoint : Text,
    claimReason : ClaimReason,
    claimAmount : Float,
    damagePertentage : Float,
    claimId : Text,
    dataEvent : Text
  ) : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    switch (users.get(caller)) {
      case (null) return #err("User must be registered before creating a claim");
      case (?user) {
        if (user.credits.claimCredits == 0) {
          return #err("Insufficient claim credits")
        };

        let policyKey = Text.concat(Principal.toText(caller), "_" # policyId);
        switch (policies.get(policyKey)) {
          case (null) return #err("Policy not found or does not belong to user");
          case (?policy) {
            if (policy.userId != caller) {
              return #err("Policy does not belong to user")
            };

            switch (validateClaim(claimId, locationPoint, claimAmount, damagePertentage)) {
              case (#err(msg)) return #err(msg);
              case (#ok()) {
                let uniqueClaimKey = Text.concat(Principal.toText(caller), "_" # claimId);

                switch (claims.get(uniqueClaimKey)) {
                  case (?_) return #err("Claim with this ID already exists");
                  case (null) {
                    let newClaim : Claim = {
                      claimId = claimId;
                      policyId = policyId;
                      userId = caller;
                      locationPoint = locationPoint;
                      claimReason = claimReason;
                      claimAmount = claimAmount;
                      damagePertentage = damagePertentage;
                      status = #pending;
                      decision = null;
                      report = null;
                      dataEvent = dataEvent;
                      creationTime = Time.now()
                    };

                    let updatedUser : User = {
                      id = user.id;
                      registrationTime = user.registrationTime;
                      credits = {
                        onboardingCredits = user.credits.onboardingCredits;
                        claimCredits = user.credits.claimCredits - 1
                      }
                    };

                    claims.put(uniqueClaimKey, newClaim);
                    users.put(caller, updatedUser);
                    #ok("Claim created successfully")
                  }
                }
              }
            }
          }
        }
      }
    }
  };

  public shared ({caller}) func updateClaimStatus(
    userId : Principal,
    claimId : Text,
    newDecision : ?Decision,
    newStatus : DataMatchType,
    report : ?Text
  ) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can update claim status")
    };

    let key = Text.concat(Principal.toText(userId), "_" # claimId);
    switch (claims.get(key)) {
      case (?claim) {
        let updatedClaim : Claim = {
          claimId = claim.claimId;
          policyId = claim.policyId;
          userId = claim.userId;
          locationPoint = claim.locationPoint;
          claimReason = claim.claimReason;
          claimAmount = claim.claimAmount;
          damagePertentage = claim.damagePertentage;
          status = newStatus;
          decision = newDecision;
          report = report;
          dataEvent = claim.dataEvent;
          creationTime = claim.creationTime
        };
        claims.put(key, updatedClaim);
        #ok("Claim status updated successfully")
      };
      case (null) #err("Claim not found")
    }
  };

  // Query functions
  public query func getCurrentRate() : async Float {
    currentUSDRate
  };

  public query func getCurrentPricing() : async PriceUSD {
    pricing
  };

  public query func getPolicy(userId : Principal, policyId : Text) : async Result.Result<Policy, Text> {
    let key = Text.concat(Principal.toText(userId), "_" # policyId);
    switch (policies.get(key)) {
      case (?policy) #ok(policy);
      case (null) #err("Policy not found")
    }
  };

  public query func getAllPendingClaims() : async Result.Result<[Claim], Text> {
    var pendingClaims : [Claim] = [];
    for ((_, claim) in claims.entries()) {
      if (claim.decision == null) {
        pendingClaims := Array.append(pendingClaims, [claim])
      }
    };
    #ok(pendingClaims)
  };

  public query func getUserPolicies(userId : Principal) : async Result.Result<[Policy], Text> {
    if (not validatePrincipal(userId)) return #err("Invalid principal");

    let userPolicies = Array.mapFilter<(Text, Policy), Policy>(
      Iter.toArray(policies.entries()),
      func((_, policy)) {
        if (policy.userId == userId) ?policy else null
      }
    );
    #ok(userPolicies)
  };

  public query func getUserClaims(userId : Principal) : async Result.Result<[Claim], Text> {
    if (not validatePrincipal(userId)) return #err("Invalid principal");

    var userClaims : [Claim] = [];
    for ((_, claim) in claims.entries()) {
      if (claim.userId == userId) {
        userClaims := Array.append(userClaims, [claim])
      }
    };
    #ok(userClaims)
  };

  public query func getUserAnalytics(userId : Principal) : async Result.Result<AnalyticsStats, Text> {
    if (not validatePrincipal(userId)) return #err("Invalid principal");

    switch (users.get(userId)) {
      case (null) #err("User not found");
      case (?_) {
        var stats = {
          var totalPolicies = 0;
          var totalClaims = 0;
          var totalApprovedClaims = 0;
          var totalPendingClaims = 0;
          var totalRejectedClaims = 0;
          var totalInsuredAmount = 0.0;
          var totalClaimAmount = 0.0;
          var totalPaidAmount = 0.0
        };

        // Calculate user statistics
        for ((_, policy) in policies.entries()) {
          if (policy.userId == userId) {
            stats.totalPolicies += 1;
            stats.totalInsuredAmount += policy.insuredAmount
          }
        };

        for ((_, claim) in claims.entries()) {
          if (claim.userId == userId) {
            stats.totalClaims += 1;
            stats.totalClaimAmount += claim.claimAmount;

            switch (claim.decision) {
              case (? #approved) {
                stats.totalApprovedClaims += 1;
                stats.totalPaidAmount += claim.claimAmount
              };
              case (? #rejected) stats.totalRejectedClaims += 1;
              case (null) stats.totalPendingClaims += 1
            }
          }
        };

        #ok({
          totalPolicies = stats.totalPolicies;
          totalClaims = stats.totalClaims;
          totalApprovedClaims = stats.totalApprovedClaims;
          totalPendingClaims = stats.totalPendingClaims;
          totalRejectedClaims = stats.totalRejectedClaims;
          totalInsuredAmount = stats.totalInsuredAmount;
          totalClaimAmount = stats.totalClaimAmount;
          totalPaidAmount = stats.totalPaidAmount
        })
      }
    }
  };

  public shared ({caller}) func getSystemAnalytics() : async Result.Result<AnalyticsStats, Text> {
    if (not (isAdmin(caller) or isModerator(caller))) {
      return #err("Only admin or moderators can view system analytics")
    };

    var stats = {
      var totalPolicies = 0;
      var totalClaims = 0;
      var totalApprovedClaims = 0;
      var totalPendingClaims = 0;
      var totalRejectedClaims = 0;
      var totalInsuredAmount = 0.0;
      var totalClaimAmount = 0.0;
      var totalPaidAmount = 0.0
    };

    for ((_, policy) in policies.entries()) {
      stats.totalPolicies += 1;
      stats.totalInsuredAmount += policy.insuredAmount
    };

    for ((_, claim) in claims.entries()) {
      stats.totalClaims += 1;
      stats.totalClaimAmount += claim.claimAmount;

      switch (claim.decision) {
        case (? #approved) {
          stats.totalApprovedClaims += 1;
          stats.totalPaidAmount += claim.claimAmount
        };
        case (? #rejected) stats.totalRejectedClaims += 1;
        case (null) stats.totalPendingClaims += 1
      }
    };

    #ok({
      totalPolicies = stats.totalPolicies;
      totalClaims = stats.totalClaims;
      totalApprovedClaims = stats.totalApprovedClaims;
      totalPendingClaims = stats.totalPendingClaims;
      totalRejectedClaims = stats.totalRejectedClaims;
      totalInsuredAmount = stats.totalInsuredAmount;
      totalClaimAmount = stats.totalClaimAmount;
      totalPaidAmount = stats.totalPaidAmount
    })
  };

  public query func getUserCredits(userId : Principal) : async Result.Result<UserCredits, Text> {
    if (not validatePrincipal(userId)) return #err("Invalid principal");

    switch (users.get(userId)) {
      case (?user) #ok(user.credits);
      case (null) #err("User not found")
    }
  };

  public query func isRegistered(userId : Principal) : async Result.Result<Bool, Text> {
    if (not validatePrincipal(userId)) return #err("Invalid principal");

    switch (users.get(userId)) {
      case (?_) #ok(true);
      case (null) #ok(false)
    }
  };

  public query func getCurrentAdmin() : async ?Principal {
    currentAdmin
  };

  public query func getModerators() : async [Principal] {
    moderators
  };

  // Utility functions
  private func usdToCycles(usdAmount : Float) : Nat {
    let icpAmount = usdAmount / currentUSDRate;
    let cycles = Float.toInt(icpAmount * 1_000_000_000_000.0);
    Int.abs(cycles)
  };

  public shared ({caller}) func withdraw(amount : Nat, recipient : Principal) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can withdraw cycles")
    };

    let available = ExperimentalCycles.balance();
    if (available < amount) {
      return #err("Insufficient cycles")
    };

    try {
      let recipient_actor = actor (Principal.toText(recipient)) : actor {
        wallet_receive : shared () -> async Nat
      };
      ExperimentalCycles.add(amount);
      let cycles_received = await recipient_actor.wallet_receive();

      if (cycles_received == amount) {
        #ok("Successfully transferred cycles")
      } else {
        #err("Transfer failed")
      }
    } catch (e) {
      #err("Error during transfer: " # Error.message(e))
    }
  };

  public query func getCyclesBalance() : async Nat {
    ExperimentalCycles.balance()
  };

  public shared ({caller}) func setUSDRate(newRate : Float) : async Result.Result<Text, Text> {
    if (not isAdmin(caller)) {
      return #err("Only admin can set USD rate")
    };
    if (newRate <= 0) return #err("USD rate must be positive");
    currentUSDRate := newRate;
    #ok("USD rate updated successfully")
  };

  // Credit purchase functions
  public shared ({caller}) func purchaseOnboardingCredits(bundles : Nat) : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    let totalCredits = bundles * pricing.bundleSize;
    let totalCostUSD = Float.fromInt(bundles) * pricing.bundlePriceUSD;
    let requiredCycles = usdToCycles(totalCostUSD);

    if (ExperimentalCycles.available() < requiredCycles) {
      return #err("Insufficient cycles sent with the call")
    };

    switch (users.get(caller)) {
      case (null) return #err("User not registered");
      case (?user) {
        let updatedUser : User = {
          id = user.id;
          registrationTime = user.registrationTime;
          credits = {
            onboardingCredits = user.credits.onboardingCredits + totalCredits;
            claimCredits = user.credits.claimCredits
          }
        };

        users.put(caller, updatedUser);
        #ok("Successfully purchased " # Nat.toText(totalCredits) # " credits")
      }
    }
  };

  public shared ({caller}) func purchaseClaimCredits(amount : Nat) : async Result.Result<Text, Text> {
    if (not validatePrincipal(caller)) return #err("Invalid principal");

    let requiredCycles = usdToCycles(Float.fromInt(amount) * pricing.claimPriceUSD);

    if (ExperimentalCycles.available() < requiredCycles) {
      return #err("Insufficient cycles sent with the call")
    };

    switch (users.get(caller)) {
      case (null) return #err("User not registered");
      case (?user) {
        let updatedUser : User = {
          id = user.id;
          registrationTime = user.registrationTime;
          credits = {
            onboardingCredits = user.credits.onboardingCredits;
            claimCredits = user.credits.claimCredits + amount
          }
        };

        users.put(caller, updatedUser);
        #ok("Successfully purchased " # Nat.toText(amount) # " claim credits")
      }
    }
  };

  // Analytics function
  public query func getTopInsurers(limit : Nat) : async Result.Result<[(Principal, Float)], Text> {
    let insurerAmounts = HashMap.HashMap<Principal, Float>(0, Principal.equal, Principal.hash);

    for ((_, policy) in policies.entries()) {
      switch (insurerAmounts.get(policy.userId)) {
        case (null) insurerAmounts.put(policy.userId, policy.insuredAmount);
        case (?amount) insurerAmounts.put(policy.userId, amount + policy.insuredAmount)
      }
    };

    var sortedInsurers = Iter.toArray(insurerAmounts.entries());
    sortedInsurers := Array.sort(
      sortedInsurers,
      func(a : (Principal, Float), b : (Principal, Float)) : Order.Order {
        if (a.1 > b.1) #less else if (a.1 < b.1) #greater else #equal
      }
    );

    #ok(Array.subArray(sortedInsurers, 0, Nat.min(limit, sortedInsurers.size())))
  };

  // Bundle price query
  public query func getBundlePrice() : async PriceUSD {
    pricing
  }
}
