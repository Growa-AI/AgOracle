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

actor {
    // Validate principal before using
    private func validatePrincipal(p : Principal) : Bool {
        not Principal.isAnonymous(p) and Text.size(Principal.toText(p)) > 0
    };

    // RATE MANAGEMENT
    private stable var currentUSDRate: Float = 7.5; // Default rate 1 ICP = $7.5

    public type PriceUSD = {
        bundleSize: Nat;      // Size of onboarding credit bundle
        bundlePriceUSD: Float;  // Price per bundle in USD
        claimPriceUSD: Float;   // Price per claim credit in USD
    };

    public type UserCredits = {
        onboardingCredits: Nat;
        claimCredits: Nat;
    };

    public type User = {
        id: Principal;
        registrationTime: Time.Time;
        credits: UserCredits;
    };

    // POLICY MANAGEMENT
    public type Policy = {
        policyId: Text;
        userId: Principal;
        country: Text;
        insuredAmount: Float;
        crop: Text;
        landPolygon: Text;
        creationTime: Time.Time;
    };

    // CONSTANTS
    private let INITIAL_ONBOARDING_CREDITS: Nat = 200;
    private let INITIAL_CLAIM_CREDITS: Nat = 5;

    // STORAGE
    private stable var currentAdmin: ?Principal = null;
    private let users = HashMap.HashMap<Principal, User>(0, Principal.equal, Principal.hash);
    private let policies = HashMap.HashMap<Text, Policy>(0, Text.equal, Text.hash);
    private stable var pricing: PriceUSD = {
        bundleSize = 50;       // Default bundle size
        bundlePriceUSD = 100.0;  // $100 per bundle
        claimPriceUSD = 10.0;    // $10 per claim
    };

    // UTILITY FUNCTIONS
    private func usdToCycles(usdAmount: Float) : Nat {
        let icpAmount = usdAmount / currentUSDRate;
        let cycles = Float.toInt(icpAmount * 1_000_000_000_000.0); // 1 ICP = 10^12 cycles
        Int.abs(cycles)
    };

    // ADMIN MANAGEMENT
    public shared({ caller }) func becomeAdmin() : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(currentAdmin) {
            case (null) {
                currentAdmin := ?caller;
                return #ok("Admin set successfully");
            };
            case (?admin) {
                return #err("Admin already set");
            };
        };
    };

    // Set USD Rate Function
    public shared({ caller }) func setUSDRate(newRate: Float) : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(currentAdmin) {
            case (?admin) {
                if (caller != admin) {
                    return #err("Only admin can set USD rate");
                };
                if (newRate <= 0) {
                    return #err("USD rate must be positive");
                };
                currentUSDRate := newRate;
                return #ok("USD rate updated successfully to " # Float.toText(newRate));
            };
            case (null) {
                return #err("No admin set");
            };
        };
    };

    public query func getCurrentRate() : async Float {
        currentUSDRate;
    };

    public query func getCurrentPricing() : async PriceUSD {
        pricing;
    };

    // USER MANAGEMENT
    public shared({ caller }) func registerUser() : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(users.get(caller)) {
            case (?_) {
                return #err("User already registered");
            };
            case (null) {
                let newUser: User = {
                    id = caller;
                    registrationTime = Time.now();
                    credits = {
                        onboardingCredits = INITIAL_ONBOARDING_CREDITS;
                        claimCredits = INITIAL_CLAIM_CREDITS;
                    };
                };
                users.put(caller, newUser);
                return #ok("User registered successfully with " # 
                    Int.toText(INITIAL_ONBOARDING_CREDITS) # " onboarding credits and " # 
                    Int.toText(INITIAL_CLAIM_CREDITS) # " claim credits");
            };
        };
    };

    // POLICY FUNCTIONS
    public shared({ caller }) func createPolicy(
        policyId: Text, 
        country: Text, 
        insuredAmount: Float, 
        crop: Text, 
        landPolygon: Text
    ) : async Result.Result<Text, Text> {
        // Validate inputs
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };

        // Check if user is registered
        switch(users.get(caller)) {
            case (null) {
                return #err("User must be registered before creating a policy");
            };
            case (?user) {
                // Check if user has enough onboarding credits
                if (user.credits.onboardingCredits == 0) {
                    return #err("Insufficient onboarding credits");
                };

                // Check if user already has a policy with this ID
                for ((_, policy) in policies.entries()) {
                    if (policy.userId == caller and policy.policyId == policyId) {
                        return #err("You already have a policy with this ID");
                    }
                };

                // Validate input parameters
                if (Text.size(policyId) == 0) {
                    return #err("Policy ID cannot be empty");
                };
                if (Text.size(country) == 0) {
                    return #err("Country cannot be empty");
                };
                if (insuredAmount <= 0) {
                    return #err("Insured amount must be positive");
                };
                if (Text.size(crop) == 0) {
                    return #err("Crop cannot be empty");
                };
                if (Text.size(landPolygon) == 0) {
                    return #err("Land polygon cannot be empty");
                };

                // Create new policy
                let newPolicy : Policy = {
                    policyId = policyId;
                    userId = caller;
                    country = country;
                    insuredAmount = insuredAmount;
                    crop = crop;
                    landPolygon = landPolygon;
                    creationTime = Time.now();
                };

                // Update user credits
                let updatedUser : User = {
                    id = user.id;
                    registrationTime = user.registrationTime;
                    credits = {
                        onboardingCredits = user.credits.onboardingCredits - 1;
                        claimCredits = user.credits.claimCredits;
                    };
                };

                // Store policy and update user
                let uniquePolicyKey = Text.concat(Principal.toText(caller), "_" # policyId);
                policies.put(uniquePolicyKey, newPolicy);
                users.put(caller, updatedUser);

                return #ok("Policy created successfully. Onboarding credit used.");
            };
        };
    };

    // Query policy by ID
    public query func getPolicy(userId: Principal, policyId: Text) : async Result.Result<Policy, Text> {
        for ((key, policy) in policies.entries()) {
            if (policy.userId == userId and policy.policyId == policyId) {
                return #ok(policy);
            };
        };
        return #err("Policy not found");
    };

    // Get all policies for a user
    public query func getUserPolicies(userId: Principal) : async Result.Result<[Policy], Text> {
        if (not validatePrincipal(userId)) {
            return #err("Invalid principal");
        };

        var userPolicies : [Policy] = [];
        for ((_, policy) in policies.entries()) {
            if (policy.userId == userId) {
                userPolicies := Array.append(userPolicies, [policy]);
            };
        };

        #ok(userPolicies);
    };

    // ADMIN FUNCTIONS
    public shared({ caller }) func updatePricing(newPricing: PriceUSD) : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(currentAdmin) {
            case (?admin) {
                if (caller != admin) {
                    return #err("Only admin can update pricing");
                };
                pricing := newPricing;
                return #ok("Pricing updated successfully");
            };
            case (null) {
                return #err("No admin set");
            };
        };
    };

    public shared({ caller }) func addUserCredits(userId: Principal, onboardingCredits: Nat, claimCredits: Nat) : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller) or not validatePrincipal(userId)) {
            return #err("Invalid principal");
        };
        
        switch(currentAdmin) {
            case (?admin) {
                if (caller != admin) {
                    return #err("Only admin can add credits");
                };
                
                switch(users.get(userId)) {
                    case (?user) {
                        let updatedUser: User = {
                            id = user.id;
                            registrationTime = user.registrationTime;
                            credits = {
                                onboardingCredits = user.credits.onboardingCredits + onboardingCredits;
                                claimCredits = user.credits.claimCredits + claimCredits;
                            };
                        };
                        users.put(userId, updatedUser);
                        return #ok("Credits added successfully");
                    };
                    case (null) {
                        return #err("User not found");
                    };
                };
            };
            case (null) {
                return #err("No admin set");
            };
        };
    };

    // PURCHASE FUNCTIONS
    public shared({ caller }) func purchaseOnboardingCredits() : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(users.get(caller)) {
            case (?user) {
                let icpCycles = usdToCycles(pricing.bundlePriceUSD);
                let icpAmount = pricing.bundlePriceUSD / currentUSDRate;

                let payment = ExperimentalCycles.available();
                if (payment < icpCycles) {
                    return #err("Insufficient payment. Required: " # Float.toText(icpAmount) # " ICP ($ " # Float.toText(pricing.bundlePriceUSD) # ")");
                };

                let accepted = ExperimentalCycles.accept(icpCycles);

                let updatedUser: User = {
                    id = user.id;
                    registrationTime = user.registrationTime;
                    credits = {
                        onboardingCredits = user.credits.onboardingCredits + pricing.bundleSize;
                        claimCredits = user.credits.claimCredits;
                    };
                };
                users.put(caller, updatedUser);
                return #ok("Successfully purchased " # Nat.toText(pricing.bundleSize) # 
                    " onboarding credits for $ " # Float.toText(pricing.bundlePriceUSD) # 
                    " (" # Float.toText(icpAmount) # " ICP)");
            };
            case (null) {
                return #err("User not registered");
            };
        };
    };

    public shared({ caller }) func purchaseClaimCredit() : async Result.Result<Text, Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(users.get(caller)) {
            case (?user) {
                let icpCycles = usdToCycles(pricing.claimPriceUSD);
                let icpAmount = pricing.claimPriceUSD / currentUSDRate;

                let payment = ExperimentalCycles.available();
                if (payment < icpCycles) {
                    return #err("Insufficient payment. Required: " # Float.toText(icpAmount) # " ICP ($ " # Float.toText(pricing.claimPriceUSD) # ")");
                };

                let accepted = ExperimentalCycles.accept(icpCycles);

                let updatedUser: User = {
                    id = user.id;
                    registrationTime = user.registrationTime;
                    credits = {
                        onboardingCredits = user.credits.onboardingCredits;
                        claimCredits = user.credits.claimCredits + 1;
                    };
                };
                users.put(caller, updatedUser);
                return #ok("Successfully purchased 1 claim credit for $ " # Float.toText(pricing.claimPriceUSD) # 
                    " (" # Float.toText(icpAmount) # " ICP)");
            };
            case (null) {
                return #err("User not registered");
            };
        };
    };

    // QUERY FUNCTIONS
    public query func getUserCredits(userId: Principal) : async Result.Result<UserCredits, Text> {
        if (not validatePrincipal(userId)) {
            return #err("Invalid principal");
        };
        
        switch(users.get(userId)) {
            case (?user) {
                #ok(user.credits);
            };
            case (null) {
                #err("User not found");
            };
        };
    };

    public query func isUserRegistered(userId: Principal) : async Bool {
        if (not validatePrincipal(userId)) {
            return false;
        };
        
        switch(users.get(userId)) {
            case (?_) { true };
            case (null) { false };
        };
    };

    public shared({ caller }) func getAllUsers() : async Result.Result<[User], Text> {
        if (not validatePrincipal(caller)) {
            return #err("Invalid principal");
        };
        
        switch(currentAdmin) {
            case (?admin) {
                if (caller != admin) {
                    return #err("Only admin can get all users");
                };
                var allUsers: [User] = [];
                for ((_, user) in users.entries()) {
                    allUsers := Array.append(allUsers, [user]);
                };
                #ok(allUsers);
            };
            case (null) {
                return #err("No admin set");
            };
        };
    };
};
