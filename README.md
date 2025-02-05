# Growa Smart Contract for Internet Computer Protocol (ICP)

![Growa IoT Gateway](Cohort2024.jpg)

# Building a Decentralized Future: Insurance on the Internet Computer

## Canister Address

### Frontend:
https://tvbi5-ziaaa-aaaai-atdxa-cai.icp0.io/

### Management: 
https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=225eu-fyaaa-aaaad-qgghq-cai 

### Data: 
https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=v3bvf-3yaaa-aaaaj-az37a-cai 

### Merkle Tree: 
https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=gicre-hiaaa-aaaae-qakyq-cai 

### Insurance: 
https://a4gq6-oaaaa-aaaab-qaa4q-cai.raw.icp0.io/?id=7kroo-2aaaa-aaaai-atcyq-cai 

## Our technology:
https://support-138.gitbook.io/growa


## The Vision

Imagine a world where farmers can instantly protect their crops against natural disasters, where insurance claims are processed transparently, and where trust is built into the system itself. This is the vision behind our decentralized insurance system built on the Internet Computer platform.

Our system represents a bridge between traditional insurance and the future of decentralized finance, starting with crop insurance but designed to expand into a comprehensive suite of financial services.

## The Architecture: A Tale of Two Contracts

Our system is built on two fundamental pillars: a central registry that orchestrates all services, and specialized service contracts that handle specific business operations. Let's explore how these work together to create a seamless experience.

### The Guardian: Main Registry Contract

At the heart of our system lies the Main Registry Contract - think of it as the master conductor of an orchestra. This contract ensures that all services play in harmony by:

- Keeping track of all service canisters
- Ensuring each service operates within its designated boundaries
- Managing access control and administration
- Coordinating storage resources

The registry supports various types of services:
- 🌾 Insurance (our current focus)
- 🏦 Banking (future)
- 🏪 Vendor services (future)
- 🔬 Research capabilities (future)
- 💻 Developer tools (future)
- 📅 Subscription management (future)

### The Specialist: Insurance Service Contract

While the registry conducts, the Insurance Service Contract performs. This specialized contract handles the day-to-day operations of our crop insurance service. Here's what it brings to the table:

1. **Credit System**: A Novel Approach
   Think of credits as specialized tokens that enable specific actions:
   - Onboarding Credits: Your key to creating new policies
   - Claim Credits: Your ticket to filing claims
   
   Why two types? This dual-credit system helps prevent abuse while maintaining accessibility.

2. **Policy Management**: Your Shield Against Nature
   Create and manage insurance policies for:
   - Different types of crops
   - Various geographical locations
   - Multiple risk factors

3. **Claims Processing**: When Nature Strikes
   Our system handles claims for:
   - Hail damage
   - Drought effects
   - Flood impacts
   - Frost damage
   - Pest infestations
   - Disease outbreaks
   - Fire damage
   - Wind destruction
   - Other verified natural disasters

## Walking Through the System

### Step 1: Getting Started

Every journey begins with registration. When a user first joins our system:
1. They receive initial credits (200 onboarding + 5 claim credits)
2. These credits serve as their passport to our services
3. Additional credits can be purchased as needed

### Step 2: Creating Protection

Creating a policy is straightforward. Let's say you're a wheat farmer in Italy:

```motoko
let createPolicyResult = await insuranceSystem.createPolicy(
    "GRAIN2024-001",    // Your unique policy ID
    "Italy",            // Location
    50000.00,          // Value to insure (in USD)
    "Wheat",           // Crop type
    "[[45.4642, 9.1900], [45.4643, 9.1901]]" // Your field's coordinates
);
```

### Step 3: When Disaster Strikes

Imagine a hailstorm damages your crops. Here's how you'd file a claim:

```motoko
let createClaimResult = await insuranceSystem.createClaim(
    "GRAIN2024-001",     // Your policy ID
    "45.4643, 9.1901",   // Damage location
    #hail,               // Type of damage
    15000.00,           // Claim amount
    30.0,               // Damage percentage
    "CLAIM2024-001"     // Your claim ID
);
```

## Behind the Scenes: How It All Works

### The Registry's Role

1. **Service Management**
   - Each service (like our insurance system) is registered with a unique identifier
   - The registry ensures services don't interfere with each other
   - It maintains a clear hierarchy of permissions and access

2. **Storage Coordination**
   - All data storage is tracked and managed
   - Each storage canister has a unique ID
   - The system maintains data integrity across all services

### The Insurance Service's Magic

1. **Smart Validation**
   - Policies are validated before creation
   - Claims are cross-referenced with policies
   - Damage reports are verified through multiple data points

2. **Efficient Processing**
   - Claims go through a standardized process
   - Each step is recorded on the blockchain
   - Updates are immediate and transparent

## Future Horizons

Our system is designed to grow. Here's what's on the horizon:

1. **Expanding Services**
   - Banking integration for seamless payments
   - Vendor services for agricultural supplies
   - Research tools for risk assessment
   - Developer APIs for third-party integration

2. **Enhanced Features**
   - Automated satellite verification for claims
   - Weather data integration
   - Machine learning for risk assessment
   - Mobile apps for easy access

## In Conclusion

Our decentralized insurance system represents more than just code - it's a step toward a more transparent, efficient, and accessible insurance future. Whether you're a farmer protecting your livelihood, a developer building new features, or an administrator managing the system, you're part of this journey toward decentralized finance.

We invite you to explore, contribute, and help us build this future together.

---

*This project is licensed under the MIT License - see the LICENSE file for details.*
