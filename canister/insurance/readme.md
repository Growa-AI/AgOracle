# Smart Agriculture Insurance System

A decentralized insurance system built on the Internet Computer Protocol (ICP) for managing agricultural insurance policies and claims. This system provides a comprehensive solution for farmers to insure their crops against various natural disasters and risks.

## Table of Contents
- [Features](#features)
- [System Architecture](#system-architecture)
- [Smart Contract Components](#smart-contract-components)
- [Data Types](#data-types)
- [User Roles](#user-roles)
- [Credit System](#credit-system)
- [API Reference](#api-reference)
- [Installation](#installation)
- [Usage Examples](#usage-examples)
- [Security](#security)
- [Analytics](#analytics)

## Features

- Role-based access control (Admin and Moderators)
- User registration and credit management
- Policy creation and management
- Claim processing with multi-stage verification
- Analytics and reporting
- USD-based pricing system
- Cycle management for transactions

## System Architecture

### Core Components
1. **User Management System**
   - User registration
   - Credit system
   - Role management

2. **Policy Management**
   - Policy creation
   - Policy validation
   - Policy querying

3. **Claims Processing**
   - Claim submission
   - Status tracking
   - Verification system

4. **Analytics Engine**
   - Real-time statistics
   - User analytics
   - System-wide analytics

## Data Types

### Claim Reasons
```motoko
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
```

### Decision States
```motoko
public type Decision = {
    #approved;
    #rejected
};
```

### Data Match Types
```motoko
public type DataMatchType = {
    #pending;
    #limited;
    #accurate;
    #partial
};
```

### Policy Structure
```motoko
public type Policy = {
    policyId: Text;
    userId: Principal;
    country: Text;
    insuredAmount: Float;
    crop: Text;
    landPolygon: Text;
    creationTime: Time.Time
};
```

## User Roles

### Admin
- System configuration
- Moderator management
- Cycle withdrawal
- USD rate management
- Analytics access

### Moderators
- Analytics access
- Claim verification
- System monitoring

### Users
- Policy creation
- Claim submission
- Credit purchase
- Personal analytics

## Credit System

### Types of Credits
1. **Onboarding Credits**
   - Used for creating policies
   - Initial allocation: 200 credits
   - Purchasable in bundles

2. **Claim Credits**
   - Used for submitting claims
   - Initial allocation: 5 credits
   - Individually purchasable

### Pricing Structure
```motoko
public type PriceUSD = {
    bundleSize: Nat;
    bundlePriceUSD: Float;
    claimPriceUSD: Float
};
```

## API Reference

### User Management
```motoko
public shared func registerUser() : async Result.Result<Text, Text>
public shared func addUserCredits(userId: Principal, onboardingCredits: Nat, claimCredits: Nat) : async Result.Result<Text, Text>
```

### Policy Management
```motoko
public shared func createPolicy(
    policyId: Text,
    country: Text,
    insuredAmount: Float,
    crop: Text,
    landPolygon: Text
) : async Result.Result<Text, Text>
```

### Claims Management
```motoko
public shared func createClaim(
    policyId: Text,
    locationPoint: Text,
    claimReason: ClaimReason,
    claimAmount: Float,
    damagePertentage: Float,
    claimId: Text,
    dataEvent: Text
) : async Result.Result<Text, Text>
```

### Analytics
```motoko
public shared func getSystemAnalytics() : async Result.Result<AnalyticsStats, Text>
public query func getUserAnalytics(userId: Principal) : async Result.Result<AnalyticsStats, Text>
public query func getTopInsurers(limit: Nat) : async Result.Result<[(Principal, Float)], Text>
```

## Installation

1. Install the DFINITY SDK:
```bash
sh -ci "$(curl -fsSL https://sdk.dfinity.org/install.sh)"
```

2. Clone the repository:
```bash
git clone https://github.com/your-repo/agriculture-insurance.git
cd agriculture-insurance
```

3. Deploy the canister:
```bash
dfx deploy
```

## Usage Examples

### Registering a User
```motoko
let result = await InsuranceSystem.registerUser();
switch (result) {
    case (#ok(message)) { /* Handle success */ };
    case (#err(error)) { /* Handle error */ };
};
```

### Creating a Policy
```motoko
let result = await InsuranceSystem.createPolicy(
    "POL-001",
    "USA",
    50000.0,
    "Corn",
    "POLYGON((...))"
);
```

### Submitting a Claim
```motoko
let result = await InsuranceSystem.createClaim(
    "POL-001",
    "POINT(latitude longitude)",
    #drought,
    25000.0,
    50.0,
    "CLM-001",
    "EVENT-001"
);
```

## Security

### Authentication
- Principal-based authentication
- Role-based access control
- Function-level authorization checks

### Data Validation
- Input validation for all functions
- Principal validation
- Amount validation for financial transactions

### Error Handling
- Comprehensive error messages
- Result type for all operations
- Exception handling for cycle operations

## Analytics

### System Analytics
```motoko
type AnalyticsStats = {
    totalPolicies: Nat;
    totalClaims: Nat;
    totalApprovedClaims: Nat;
    totalPendingClaims: Nat;
    totalRejectedClaims: Nat;
    totalInsuredAmount: Float;
    totalClaimAmount: Float;
    totalPaidAmount: Float;
};
```

### Available Metrics
- Total policies and claims
- Approval rates
- Financial metrics
- User statistics
- Top insurers

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Support

For support, please contact the development team or raise an issue in the GitHub repository.

---

For more information about the Internet Computer Protocol and Motoko, visit [DFINITY Documentation](https://sdk.dfinity.org/docs/).
