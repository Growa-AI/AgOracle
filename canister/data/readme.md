# ICP Device Readings Smart Contract

A Motoko smart contract for the Internet Computer Protocol (ICP) that manages device readings with role-based access control. The contract allows storing and retrieving readings from both physical and virtual devices, with support for timestamps and data integrity through hashing.

## Features

- Role-based access control (Admin, Moderator, User)
- Support for physical and virtual devices
- Flexible timestamp management
- Reading hash generation for data integrity
- Comprehensive filtering and querying capabilities

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

### Reading with Hash
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
- **Admin**: Full control over the contract
- **Moderator**: Can insert readings and manage users (except admin)
- **User**: Basic access, cannot perform write operations

### Role-based Functions
- `assignAdmin()`: Initial admin assignment
- `transferOwnership(newOwner: Principal)`: Transfer admin rights
- `addAuthorizedUser(user: Principal, role: Role)`: Add new user with specific role
- `removeAuthorizedUser(user: Principal)`: Remove user access
- `getUserRole(user: Principal)`: Query user's role

## Reading Management

### Inserting Readings
```motoko
insertReading(
    device_id: Text,
    device_type: DeviceType,
    parameter: Text,
    value: Float,
    timestamp: ?Int
) : async Text
```

The timestamp parameter is optional:
- If null: current time is used
- If 0: current time is used
- If other value: provided timestamp is used

### Querying Readings

#### Get Readings by Time Range
```motoko
getReadings(device_id: Text, start_time: Int, end_time: Int) : async [ReadingWithHash]
```

#### Get All Readings for Device
```motoko
getAllReadingsForDevice(device_id: Text) : async [ReadingWithHash]
```

#### Get Multiple Device Readings
```motoko
getMultipleDeviceReadings(device_ids: [Text]) : async [(Text, [ReadingWithHash])]
```

#### Get Filtered Readings
```motoko
getFilteredReadings(
    device_ids: [Text],
    parameter: ?Text,
    device_type: ?DeviceType,
    start_time: Int,
    end_time: Int
) : async [(Text, [ReadingWithHash])]
```

## Hash Generation

The contract automatically generates a unique hash for each reading using the following fields:
- device_id
- device_type
- parameter
- value
- created_at

## Usage Examples

### Setting Up Admin
```motoko
// First deployment - assign admin
let result = await SmartContract.assignAdmin();

// Transfer ownership to new admin
let newAdminPrincipal = "...";
await SmartContract.transferOwnership(newAdminPrincipal);
```

### Managing Users
```motoko
// Add a moderator
let moderatorPrincipal = "...";
await SmartContract.addAuthorizedUser(moderatorPrincipal, #Moderator);

// Remove a user
await SmartContract.removeAuthorizedUser(userPrincipal);
```

### Inserting Readings
```motoko
// Insert reading with automatic timestamp
await SmartContract.insertReading(
    "device123",
    #Physical,
    "temperature",
    25.5,
    null
);

// Insert reading with specific timestamp
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
// Get all readings for a device
let readings = await SmartContract.getAllReadingsForDevice("device123");

// Get filtered readings
let filteredReadings = await SmartContract.getFilteredReadings(
    ["device123", "device456"],
    ?"temperature",
    ?#Physical,
    1645564800000000000,
    1645651200000000000
);
```

## Security Considerations

1. Only the admin can:
   - Add new users
   - Transfer ownership
   - Assign roles

2. Moderators can:
   - Insert readings
   - Remove users (except admin)
   - Insert readings

3. Regular users:
   - Can only perform read operations
   - Cannot modify any data

## Installation

1. Make sure you have the [DFINITY SDK](https://sdk.dfinity.org) installed
2. Clone this repository
3. Deploy the contract:
```bash
dfx deploy
```

## Testing

```bash
dfx test
```
