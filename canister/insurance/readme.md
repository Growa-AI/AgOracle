# Crop Insurance Smart Contract

This smart contract implements a decentralized crop insurance system on the Internet Computer platform. It allows farmers to insure their crops against various natural disasters and weather events, manage policies, and handle insurance claims.

## Features

- User registration and credit management
- Policy creation and management
- Claim submission and processing
- Analytics and reporting
- Admin controls and system management

## System Architecture

### Core Types

#### ClaimReason
Supported reasons for insurance claims:
- Hail
- Drought
- Flood
- Frost
- Pest
- Disease
- Fire
- Wind
- Other

#### ClaimStatus
Possible states for a claim:
- Pending
- Approved
- Rejected

#### DataMatchType
Quality of data verification:
- Limited
- Accurate
- Partial

### Credit System

The system uses two types of credits:
1. **Onboarding Credits**: Used to create new policies
2. **Claim Credits**: Used to submit insurance claims

Credits can be purchased in the following ways:
- Onboarding credits are sold in bundles (configurable size and price)
- Claim credits are sold individually

### User Management

#### Registration
```motoko
public shared({ caller }) func registerUser(): async Result.Result<Text, Text>
```
- Creates a new user account
- Provides initial credits (200 onboarding + 5 claim credits)
- Returns registration confirmation or error

#### Credit Purchase
```motoko
public shared({ caller }) func purchaseOnboardingCredits(bundles: Nat): async Result.Result<Text, Text>
public shared({ caller }) func purchaseClaimCredits(amount: Nat): async Result.Result<Text, Text>
```
- Purchase additional credits
- Requires payment in cycles
- Returns purchase confirmation or error

### Policy Management

#### Create Policy
```motoko
public shared({ caller }) func createPolicy(
    policyId: Text,
    country: Text,
    insuredAmount: Float,
    crop: Text,
    landPolygon: Text
): async Result.Result<Text, Text>
```
- Creates a new insurance policy
- Requires onboarding credits
- Validates policy details
- Returns policy creation confirmation or error

#### Query Policies
```motoko
public query func getPolicy(userId: Principal, policyId: Text): async Result.Result<Policy, Text>
public query func getUserPolicies(userId: Principal): async Result.Result<[Policy], Text>
```
- Retrieve specific policy or all user policies
- Returns policy details or error

### Claim Management

#### Submit Claim
```motoko
public shared({ caller }) func createClaim(
    policyId: Text,
    locationPoint: Text,
    claimReason: ClaimReason,
    claimAmount: Float,
    damagePertentage: Float,
    claimId: Text
): async Result.Result<Text, Text>
```
- Creates a new insurance claim
- Requires claim credits
- Validates claim details and policy ownership
- Returns claim creation confirmation or error

#### Query Claims
```motoko
public query func getAllPendingClaims(): async Result.Result<[Claim], Text>
public query func getUserClaims(userId: Principal): async Result.Result<[Claim], Text>
public query func getClaim(userId: Principal, claimId: Text): async Result.Result<Claim, Text>
```
- Get pending claims, user claims, or specific claim
- Returns claim details or error

#### Update Claim Status
```motoko
public shared({ caller }) func updateClaimStatus(
    userId: Principal,
    claimId: Text,
    newStatus: ClaimStatus,
    dataMatchType: ?DataMatchType,
    report: ?Text
): async Result.Result<Text, Text>
```
- Admin function to process claims
- Updates claim status and adds verification data
- Returns update confirmation or error

### Analytics

#### User Analytics
```motoko
public query func getUserAnalytics(userId: Principal): async Result.Result<AnalyticsStats, Text>
```
Returns:
- Total policies
- Total claims (by status)
- Total insured amount
- Total claim amount
- Total paid amount

#### System Analytics
```motoko
public query({ caller }) func getSystemAnalytics(): async Result.Result<AnalyticsStats, Text>
```
Returns system-wide statistics (admin only)

## Usage Example

```motoko
// 1. Register user
let registerResult = await insuranceSystem.registerUser();

// 2. Create policy
let createPolicyResult = await insuranceSystem.createPolicy(
    "GRAIN2024-001",
    "Italy",
    50000.00,
    "Wheat",
    "[[45.4642, 9.1900], [45.4643, 9.1901]]"
);

// 3. Submit claim
let createClaimResult = await insuranceSystem.createClaim(
    "GRAIN2024-001",
    "45.4643, 9.1901",
    #hail,
    15000.00,
    30.0,
    "CLAIM2024-001"
);

// 4. Process claim (admin only)
let updateClaimResult = await insuranceSystem.updateClaimStatus(
    userId,
    "CLAIM2024-001",
    #approved,
    ?#accurate,
    ?"Damage verified through satellite imagery"
);
```

## Security Considerations

1. **Principal Validation**: All functions validate caller principals
2. **Ownership Verification**: Claims can only be created for owned policies
3. **Credit System**: Prevents abuse through credit requirements
4. **Admin Controls**: Sensitive operations restricted to admin
5. **Data Validation**: All inputs are validated before processing

## Installation and Deployment

1. Clone the repository
2. Install the DFINITY SDK
3. Deploy using:
```bash
dfx deploy insurance_system
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
