# ICP Device Readings Smart Contract

A Motoko smart contract for the Internet Computer Protocol (ICP) that manages device readings with role-based access control. The contract allows storing and retrieving readings from both physical and virtual devices with robust data integrity through SHA256 hashing.

## Features

- Role-based access control (Admin, Moderator, User)
- Support for both physical and virtual devices
- Flexible timestamp handling (automatic or manual)
- SHA256-based data integrity with unique hash generation
- Comprehensive query capabilities with filtering options
- Hash-based reading retrieval system

## Data Structures

### Device Types
```motoko
type DeviceType = {
    #Physical;
    #Virtual;
};
```

### Reading Structure
```motoko
type Reading = {
    device_id: Text;
    device_type: DeviceType;
    parameter: Text;
    value: Float;
    created_at: Int;
};
```

### Reading With Hash
```motoko
type ReadingWithHash = {
    device_id: Text;
    device_type: DeviceType;
    parameter: Text;
    value: Float;
    created_at: Int;
    hash: Text;
};
```

## Role Management

### Available Roles
```motoko
type Role = {
    #Admin;
    #Moderator;
    #User;
};
```

### Role Permissions

#### Admin
- Full system control
- Add/remove users
- Transfer ownership
- Manage all readings
- Access all queries

#### Moderator
- Insert readings
- Remove users (except admin)
- Access all queries

#### User
- Read-only access to queries

## Function Reference

### Admin Functions

```motoko
// Initialize admin (can only be called once)
public shared(msg) func assignAdmin() : async Text

// Transfer ownership to new admin
public shared(msg) func transferOwnership(newOwner: Principal) : async Text

// Add user with role
public shared(msg) func addAuthorizedUser(user: Principal, role: Role) : async Text

// Remove user
public shared(msg) func removeAuthorizedUser(user: Principal) : async Text
```

### Reading Management

```motoko
// Insert new reading
public shared(msg) func insertReading(
    device_id: Text,
    device_type: DeviceType,
    parameter: Text,
    value: Float,
    timestamp: ?Int
) : async Text

// Get reading by hash
public query func getReadingByHash(hash: Text) : async ?ReadingWithHash

// Get all readings for device
public query func getAllReadingsForDevice(device_id: Text) : async [ReadingWithHash]

// Get filtered readings
public query func getFilteredReadings(
    device_ids: [Text],
    parameter: ?Text,
    device_type: ?DeviceType,
    start_time: Int,
    end_time: Int
) : async [(Text, [ReadingWithHash])]
```

## Hash Generation

The contract uses a robust hash generation system that combines:
- SHA256 hashing
- Unique device prefix
- Timestamp
- Incremental nonce

Hash format: `[DEVICE_PREFIX]-[SHA256_HASH]-[TIMESTAMP]`

## Usage Examples

### Setting Up Admin
```motoko
// First deployment - assign admin
let result = await SmartContract.assignAdmin();

// Transfer ownership
let newAdminPrincipal = "...";
await SmartContract.transferOwnership(newAdminPrincipal);
```

### Managing Users
```motoko
// Add moderator
await SmartContract.addAuthorizedUser(principal, #Moderator);

// Remove user
await SmartContract.removeAuthorizedUser(userPrincipal);
```

### Inserting Readings
```motoko
// With automatic timestamp
await SmartContract.insertReading(
    "device123",
    #Physical,
    "temperature",
    25.5,
    null
);

// With manual timestamp
await SmartContract.insertReading(
    "device123",
    #Physical,
    "temperature",
    25.5,
    ?1645564800000000000
);
```

### Querying Readings
```motoko
// Get by hash
let reading = await SmartContract.getReadingByHash("ABC123-...");

// Get filtered readings
let readings = await SmartContract.getFilteredReadings(
    ["device123", "device456"],
    ?"temperature",
    ?#Physical,
    1645564800000000000,
    1645651200000000000
);
```

## Security Considerations

1. Role-based Access:
   - Only admin can add new users
   - Only admin can transfer ownership
   - Moderators can't modify admin
   - Users have read-only access

2. Data Integrity:
   - SHA256 hashing for all readings
   - Unique hash generation including device ID, timestamp, and nonce
   - Hash verification on retrieval

3. Timestamp Management:
   - Flexible timestamp input
   - Automatic timestamp if not provided
   - Validation of timestamp ranges

## Installation

1. Make sure you have [DFINITY SDK](https://sdk.dfinity.org) installed
2. Clone this repository
3. Deploy using:
```bash
dfx deploy
```

## Testing

Run the test suite:
```bash
dfx test
```

## Contributing

Feel free to open issues and submit pull requests to help improve this contract.

## License

[MIT License](LICENSE)

---

For more information about the Internet Computer Protocol and Motoko, visit [DFINITY Documentation](https://sdk.dfinity.org/docs/)
