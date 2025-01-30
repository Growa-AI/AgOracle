# Service Registry Smart Contract

A centralized registry system built on Internet Computer for managing different service canisters and storage solutions. This smart contract acts as a management hub for coordinating various service types and their associated canisters.

## System Overview

The system provides a centralized way to:
- Register and manage different types of service canisters
- Track storage canisters
- Prevent cross-service canister usage
- Maintain administrative control

## Service Types

The system supports the following service categories:
- Insurance
- Banking
- Vendor
- Research
- Developer
- Subscriptions

## Core Components

### Registry Systems

1. **Service Registry**
   - Maps service types to their associated canisters
   - Prevents duplicate registrations
   - Maintains service segregation

2. **Used Canisters Registry**
   - Prevents cross-service usage
   - Ensures each canister is used in only one service type

3. **Storage Registry**
   - Manages storage canisters
   - Maintains unique IDs for each storage canister
   - Provides easy access to storage resources

## Administrative Functions

### Admin Management

```motoko
public shared (msg) func becomeAdmin() : async Bool
public shared (msg) func transferAdmin(newAdmin : Principal) : async Result.Result<Text, Text>
public query func getCurrentAdmin() : async ?Principal
```

- Initial admin setup
- Admin privilege transfer
- Current admin query

### Service Management

```motoko
public shared (msg) func registerServiceCanister(
    serviceType : ServiceType, 
    canisterId : Principal
) : async Result.Result<Text, Text>

public shared (msg) func deregisterServiceCanister(
    serviceType : ServiceType, 
    canisterId : Principal
) : async Result.Result<Text, Text>
```

Features:
- Register new service canisters
- Deregister existing canisters
- Service type validation
- Cross-service usage prevention

### Storage Management

```motoko
public shared (msg) func addStorageCanister(
    canisterId : Principal
) : async Result.Result<Text, Text>

public shared (msg) func removeStorageCanister(
    storageId : Nat
) : async Result.Result<Text, Text>
```

Features:
- Add new storage canisters
- Remove existing storage canisters
- Automatic ID assignment
- Duplicate prevention

## Query Functions

```motoko
public query (msg) func getServiceCanisters(
    serviceType : ServiceType
) : async Result.Result<[Principal], Text>

public query (msg) func getAllServiceCanisters() 
    : async Result.Result<[(ServiceType, [Principal])], Text>

public query (msg) func getAllStorageCanisters() 
    : async Result.Result<[(Nat, Principal)], Text>
```

Features:
- Query canisters by service type
- Get complete service registry overview
- List all storage canisters

## Security Features

1. **Admin Control**
   - All management functions are admin-protected
   - Secure admin transfer mechanism
   - Initial admin setup protection

2. **Service Isolation**
   - Prevents canisters from being registered in multiple services
   - Maintains service boundary integrity

3. **Registry Protection**
   - Duplicate registration prevention
   - Safe deregistration process
   - Controlled storage management

## Usage Example

```motoko
// 1. Set up admin
let adminSetup = await mainContract.becomeAdmin();

// 2. Register a service canister
let registerResult = await mainContract.registerServiceCanister(
    #Insurance,
    Principal.fromText("aaaaa-aa")
);

// 3. Add storage canister
let storageResult = await mainContract.addStorageCanister(
    Principal.fromText("bbbbb-bb")
);

// 4. Query registered services
let services = await mainContract.getAllServiceCanisters();
```

## Installation and Deployment

1. Clone the repository
2. Install the DFINITY SDK
3. Deploy using:
```bash
dfx deploy main_contract
```

## Best Practices

1. **Admin Management**
   - Set up admin immediately after deployment
   - Use secure principal for admin account
   - Maintain backup admin procedures

2. **Service Registration**
   - Register services systematically
   - Document canister assignments
   - Regularly verify registry integrity

3. **Storage Management**
   - Monitor storage capacity
   - Maintain backup storage canisters
   - Regular registry cleanup

## Error Handling

The contract uses `Result.Result<T, Text>` for comprehensive error handling:
- Clear error messages
- Operation success confirmation
- Admin validation errors
- Registry state errors

## License

This project is licensed under the MIT License - see the LICENSE file for details.
