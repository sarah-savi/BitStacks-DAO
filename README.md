# BitStacks DAO - Decentralized Bitcoin Treasury Management



## Overview

BitStacks DAO is a next-generation decentralized autonomous organization contract enabling secure, compliant management of Bitcoin-based assets through on-chain governance. Combining Bitcoin's security with Stacks Layer 2 programmability, this solution provides institutional-grade treasury management capabilities for decentralized organizations.

### Key Features

- **Bitcoin-Native Asset Management**  
  Manage STX and other Bitcoin-secured assets with non-custodial controls

- **Stake-Based Governance**  
  Weighted voting system based on staked token amounts

- **Dynamic Quorum System**  
  Auto-adjusting participation thresholds based on total stake

- **Institutional Compliance**  
  Built-in proposal safeguards and regulatory checkpoints

- **Transparent Audit Trails**  
  Immutable record of all governance actions on Bitcoin

- **Cross-Chain Compatibility**  
  Designed for future integration with Bitcoin L2 solutions

## Architecture

### Data Structures

#### Core State

```clarity
(define-data-var total-staked uint u0)
(define-data-var proposal-count uint u0)
(define-data-var quorum-threshold uint u500) // 50% in basis points
(define-data-var proposal-duration uint u144) // ~24h in blocks
(define-data-var min-proposal-amount uint u1000000) // 1 STX in uSTX
```

#### Member Structure

```clarity
(define-map members
    principal
    {
        staked-amount: uint,
        last-reward-block: uint,
        rewards-claimed: uint
    }
)
```

#### Proposal Structure

```clarity
(define-map proposals
    uint
    {
        proposer: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        amount: uint,
        recipient: principal,
        start-block: uint,
        end-block: uint,
        yes-votes: uint,
        no-votes: uint,
        status: (string-ascii 20),
        executed: bool
    }
)
```

### Governance Process

1. **Stake Tokens**  
   Members deposit STX to gain voting power

2. **Proposal Creation**  
   Minimum 1 STX stake required to submit proposals

3. **Voting Period**  
   24-hour window for stake-weighted voting

4. **Proposal Execution**  
   Automated payout if quorum and majority reached

5. **Reward Distribution**  
   (Future implementation) Staking rewards

## Key Parameters

| Parameter              | Value             | Description                    |
| ---------------------- | ----------------- | ------------------------------ |
| Quorum Threshold       | 50%               | Minimum participation required |
| Voting Period          | 144 blocks (~24h) | Proposal duration              |
| Minimum Proposal Stake | 1 STX             | Required to create proposals   |
| STX Decimals           | 6                 | 1 STX = 1,000,000 uSTX         |

## Core Functions

### Membership Management

#### `stake-tokens`

```clarity
(define-public (stake-tokens (amount uint))
```

- Transfers STX from caller to DAO treasury
- Updates member's staked balance
- Resets reward accrual timer

**Example:**

```bash
clarinet call stake-tokens --amount 5000000  # Stakes 5 STX
```

#### `unstake-tokens`

```clarity
(define-public (unstake-tokens (amount uint))
```

- Withdraws specified STX amount
- Requires sufficient staked balance
- Updates total stake pool

### Proposal Lifecycle

#### `create-proposal`

```clarity
(define-public (create-proposal
    (title (string-ascii 100))
    (description (string-ascii 500))
    (amount uint)
    (recipient principal))
```

- Requires minimum 1 STX stake
- Validates recipient address
- Enforces title/description limits
- Returns new proposal ID

**Example:**

```bash
clarinet call create-proposal \
    --title "Upgrade Protocol" \
    --description "Implement new security features v2.1" \
    --amount 15000000 \  # 15 STX
    --recipient SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE
```

#### `vote`

```clarity
(define-public (vote (proposal-id uint) (vote-for bool))
```

- Weighted by caller's stake
- One vote per proposal
- Only during active period

#### `execute-proposal`

```clarity
(define-public (execute-proposal (proposal-id uint))
```

- Checks quorum: 50% of total stake
- Requires majority approval
- Auto-transfers funds if successful

### View Functions

| Function            | Description                       |
| ------------------- | --------------------------------- |
| `get-member-info`   | Returns stake balance and rewards |
| `get-proposal-info` | Full proposal details and status  |
| `get-vote-info`     | Individual voting records         |
| `get-dao-info`      | Global DAO statistics             |

## Security Features

### Input Validation

- Principal address checks
- String length limits (100/500 chars)
- STX transfer safeguards
- Proposal amount validation

### State Management

- Atomic transactions
- Proposal status transitions
- Vote non-repudiation
- Execution lock after completion

### Error Handling

| Error Code               | Description                 |
| ------------------------ | --------------------------- |
| ERR-NOT-AUTHORIZED       | Unauthorized access attempt |
| ERR-PROPOSAL-EXPIRED     | Voting period ended         |
| ERR-INSUFFICIENT-BALANCE | Invalid unstake amount      |
| ERR-INVALID-VOTE         | Non-boolean vote value      |

## Compliance Framework

1. **Proposal Screening**

   - Title/description requirements
   - Recipient address validation
   - Minimum stake threshold

2. **Voting Audit**

   - Immutable vote records
   - Stake-weighted transparency
   - Time-limited participation

3. **Execution Checks**
   - Quorum verification
   - Majority confirmation
   - Non-custodial asset transfer

## Testing & Verification

Recommended test scenarios:

```gherkin
Scenario: Successful proposal execution
  Given 100 STX total stake
  When Proposal receives 60 STX Yes votes
  Then Execute proposal transfers funds

Scenario: Failed quorum
  Given 100 STX total stake
  When Proposal receives 40 STX Yes votes
  Then Proposal status becomes REJECTED

Scenario: Voting after expiration
  When Trying to vote after end-block
  Then ERR-PROPOSAL-EXPIRED error
```

## Deployment

1. Install Clarinet:

```bash
curl -L https://raw.githubusercontent.com/hirosystems/clarinet/main/install.sh | bash
```

2. Initialize project:

```bash
clarinet new bitstacks-dao && cd bitstacks-dao
```

## Roadmap

- [ ] Staking rewards distribution
- [ ] Bitcoin Lightning integration
- [ ] Multi-asset support
- [ ] Delegated voting
- [ ] Compliance oracle integration

## Contributing

1. Fork repository
2. Create feature branch
3. Submit PR with tests
4. Security review process
