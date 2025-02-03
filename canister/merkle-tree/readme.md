# Certified Merkle Tree Canister

A Motoko-based Internet Computer canister that implements certified Merkle trees for secure data verification and querying. This canister provides a robust solution for maintaining verifiable data structures on the Internet Computer blockchain.

## Features

- **Certified Data Storage**: Implements secure data certification with timestamps
- **Merkle Tree Implementation**: Full Merkle tree implementation with proof generation and verification
- **Query Call Security**: Enhanced security for query calls using certified variables
- **Temporal Validation**: Built-in timestamp verification to prevent replay attacks
- **Upgradeable**: Maintains data consistency across canister upgrades
- **Admin Controls**: Secure admin-only operations for tree creation and management

## Prerequisites

- [dfx](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove) >= 0.9.0
- [Node.js](https://nodejs.org) >= 14.0.0
- [Internet Computer CLI](https://internetcomputer.org/docs/current/developer-docs/build/install-upgrade-remove)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/certified-merkle-canister.git
cd certified-merkle-canister
```

2. Install dependencies:
```bash
dfx start --background
npm install
```

3. Deploy the canister:
```bash
dfx deploy
```

## Usage

### 1. Register Admin

First, register an admin who will have permissions to create Merkle trees:

```motoko
// Using dfx
dfx canister call merkle_canister registerAdmin

// Using Motoko
let result = await canister.registerAdmin();
```

### 2. Create a Certified Merkle Tree

Create a new Merkle tree with certified data:

```motoko
let data = ["item1", "item2", "item3"];
let result = await canister.createCertifiedMerkleTree(data);
```

### 3. Verify Certified Data

Verify that data exists in a certified Merkle tree:

```motoko
let isValid = await canister.verifyCertifiedData(
    "item1",
    rootHash,
    timestamp
);
```

### 4. Get Certified Proof

Obtain a proof for data verification:

```motoko
let proofResult = await canister.getCertifiedProof("item1");
```

## API Reference

### Admin Management

#### `registerAdmin()`
- Registers the caller as the admin
- Returns: `Result<Text, Text>`

### Tree Operations

#### `createCertifiedMerkleTree(data: [Text])`
- Creates a new certified Merkle tree
- Parameters:
  - `data`: Array of text items to include in the tree
- Returns: `Result<CertifiedData, Text>`

### Query Operations

#### `verifyCertifiedData(data: Text, rootHash: Text, timestamp: Timestamp)`
- Verifies if data exists in a certified tree
- Parameters:
  - `data`: The data to verify
  - `rootHash`: The root hash of the tree
  - `timestamp`: The timestamp of certification
- Returns: `Bool`

#### `getCertifiedProof(data: Text)`
- Gets proof for data verification
- Parameters:
  - `data`: The data to get proof for
- Returns: `?{proof: [HashType]; certData: CertifiedData}`

## Data Structures

### CertifiedData
```motoko
type CertifiedData = {
    hash: HashType;
    timestamp: Timestamp;
};
```

### HashType
```motoko
type HashType = Text;
```

## Security Considerations

- Always verify timestamps when checking certified data
- Keep admin credentials secure
- Regular updates to maintain security
- Implement proper error handling in client applications

## Best Practices

1. **Data Validation**
   - Always validate input data before creating trees
   - Implement proper error handling
   - Check timestamp validity

2. **Performance**
   - Batch operations when possible
   - Use query calls for read operations
   - Implement proper caching strategies

3. **Security**
   - Regular security audits
   - Keep dependencies updated
   - Monitor canister cycles

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - see LICENSE file for details

## Development

### Local Development

1. Start the local network:
```bash
dfx start --background
```

2. Deploy locally:
```bash
dfx deploy
```

### Testing

Run the test suite:
```bash
dfx test
```

## Support

For support, please open an issue in the GitHub repository or contact the maintainers.

## Acknowledgments

- Internet Computer Protocol team
- Merkle tree implementation inspired by standard cryptographic practices

## Project Status

This project is under active development. Please report any issues or suggest improvements via GitHub issues.
