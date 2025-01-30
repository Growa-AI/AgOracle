# AgOracle

![Growa IoT Gateway](oracle.png)

# Decentralized Insurance System on Internet Computer

A comprehensive decentralized insurance system built on the Internet Computer platform, consisting of a central registry smart contract for service management and specialized service canisters, with the initial implementation focusing on crop insurance.

## System Architecture

### Core Components

1. **Main Registry Contract**
   - Central service management
   - Canister registration and tracking
   - Administrative controls
   - Service type coordination

2. **Insurance Service Canister**
   - Crop insurance implementation
   - Policy management
   - Claims processing
   - User credit system
   - Analytics and reporting

## Main Registry Contract

### Service Types
The system supports various service categories:
- Insurance (currently implemented)
- Banking (future expansion)
- Vendor (future expansion)
- Research (future expansion)
- Developer (future expansion)
- Subscriptions (future expansion)

### Registry Features

1. **Service Registry**
   - Maps service types to canister IDs
   - Prevents cross-service canister usage
   - Maintains service isolation

2. **Storage Registry**
   - Manages storage canisters
   - Automatic ID assignment
   - Centralized storage tracking

### Administrative Functions

```motoko
// Admin Management
func becomeAdmin() : async Bool
func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text>

// Service Registration
func registerServiceCanister(serviceType : ServiceType, canisterId : Principal)
func deregisterServiceCanister(serviceType : ServiceType, canisterId : Principal)

// Storage Management
func addStorageCanister(canisterId : Principal)
func removeStorageCanister(storageId : Nat)
```

## Insurance Service Implementation

### Core Features

1. **User Management**
   - Registration system
   - Credit-based operations
   - Profile management

2. **Policy System**
   - Create and manage insurance policies
   - Track insured assets
   - Policy validation

3. **Claims Processing**
   - Submit insurance claims
   - Process and verify claims
   - Track claim status

4. **Credit System**
   - Two types of credits:
     * Onboarding Credits (for policy creation)
     * Claim Credits (for claim submission)
   - Bundle-based purchasing
   - Credit management

### Insurance Types and Coverage

#### Supported Claim Reasons
- Hail damage
- Drought effects
- Flood damage
- Frost impact
- Pest infestation
- Disease outbreaks
- Fire damage
- Wind damage
- Other verified damages

#### Claim Verification Levels
- Limited verification
- Accurate verification
- Partial verification

### Key Functions

```motoko
// User Operations
func registerUser(): async Result.Result<Text, Text>
func purchaseOnboardingCredits(bundles: Nat): async Result.Result<Text, Text>
func purchaseClaimCredits(amount: Nat): async Result.Result<Text, Text>

// Policy Management
func createPolicy(
    policyId: Text,
    country: Text,
    insuredAmount: Float,
    crop: Text,
    landPolygon: Text
): async Result.Result<Text, Text>

// Claims Processing
func createClaim(
    policyId: Text,
    locationPoint: Text,
    claimReason: ClaimReason,
    claimAmount: Float,
    damagePertentage: Float,
    claimId: Text
): async Result.Result<Text, Text>
```

## System Integration and Flow

### Registration Process
1. Administrator deploys main registry contract
2. Insurance service canister is deployed
3. Admin registers insurance service in registry
4. Users can begin registering and using the insurance service

### Insurance Usage Flow
1. User Registration
   ```motoko
   let registerResult = await insuranceSystem.registerUser();
   ```

2. Credit Purchase
   ```motoko
   let purchaseResult = await insuranceSystem.purchaseOnboardingCredits(2);
   ```

3. Policy Creation
   ```motoko
   let policyResult = await insuranceSystem.createPolicy(
       "GRAIN2024-001",
       "Italy",
       50000.00,
       "Wheat",
       "[[45.4642, 9.1900], [45.4643, 9.1901]]"
   );
   ```

4. Claim Submission
   ```motoko
   let claimResult = await insuranceSystem.createClaim(
       "GRAIN2024-001",
       "45.4643, 9.1901",
       #hail,
       15000.00,
       30.0,
       "CLAIM2024-001"
   );
   ```

## Analytics and Reporting

### System Analytics
- Total policies issued
- Total claims processed
- Claims by status
- Total insured value
- Total claims paid

### User Analytics
- Individual policy count
- Claim history
- Insurance coverage
- Payment history

## Security Considerations

1. **Administrative Security**
   - Protected admin functions
   - Secure admin transfer
   - Service isolation

2. **Operational Security**
   - Credit-based operation limits
   - Policy ownership verification
   - Claim validation

3. **Data Integrity**
   - Input validation
   - Cross-reference checks
   - Status tracking

## System Requirements

### Development Environment
- DFINITY SDK
- Motoko programming language
- Internet Computer network

### Deployment Steps
1. Deploy main registry:
   ```bash
   dfx deploy main_contract
   ```

2. Deploy insurance service:
   ```bash
   dfx deploy insurance_system
   ```

3. Register insurance service:
   ```bash
   dfx canister call main_contract registerServiceCanister '(#Insurance, principal "canister-id")'
   ```

## Future Extensions

1. **Additional Services**
   - Banking integration
   - Vendor services
   - Research capabilities
   - Developer tools
   - Subscription management

2. **Enhanced Features**
   - Multi-currency support
   - Automated claim verification
   - Advanced analytics
   - Risk assessment tools

## Best Practices

1. **System Administration**
   - Regular service audits
   - Proper registry maintenance
   - Backup procedures

2. **Insurance Operations**
   - Regular policy reviews
   - Claim verification procedures
   - Credit system monitoring

3. **User Management**
   - Clear documentation
   - Support procedures
   - Regular updates

## License

This project is licensed under the MIT License - see the LICENSE file for details.
