# Proposal Submission System Smart Contract

## Overview

This repository contains a Clarity smart contract designed for decentralized governance through a proposal submission system. The contract enables token holders to create, vote on, and execute proposals, providing a robust foundation for on-chain governance.

## Features

- **Token-Based Governance**: Utilizes a fungible token to represent voting power
- **Complete Proposal Lifecycle**: Manage proposals from creation through execution
- **Weighted Voting**: Vote weight proportional to token holdings
- **Configurable Parameters**: Adjustable thresholds and voting periods
- **Security-First Design**: Comprehensive validation and error handling
- **Contract Execution**: Execute approved proposals on whitelisted contracts

## Contract Structure

### Constants

```clarity
;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
;; ... additional error codes
```

### Data Storage

The contract uses several data maps to track proposals and votes:

- `proposals`: Stores core proposal data
- `proposal-votes`: Tracks individual votes on each proposal
- `whitelisted-contracts`: Records contracts that can be called by proposals

### Public Functions

#### Proposal Management

- `submit-proposal`: Create a new proposal
- `vote`: Cast a vote on an active proposal
- `execute-proposal`: Execute an approved proposal
- `finalize-proposal`: Update proposal status after voting ends

#### Administrative Functions

- `mint-tokens`: Distribute governance tokens
- `set-contract-owner`: Update the contract administrator
- `set-whitelisted-contract`: Manage the whitelist of executable contracts
- `set-proposal-threshold`: Update the token threshold for creating proposals
- `set-voting-period`: Adjust the default voting period duration

#### Read-Only Functions

- `get-proposal`: Retrieve proposal details
- `get-vote`: Check a user's vote on a proposal
- `get-proposal-count`: Get the total number of proposals
- `get-token-balance`: Check a user's governance token balance
- `is-contract-whitelisted`: Verify if a contract is whitelisted
- `can-execute-proposal`: Check if a proposal is ready for execution

## Usage Guide


### Setting Up Governance

After deployment, the contract owner should:

1. Distribute governance tokens to community members
2. Add trusted contracts to the whitelist
3. Configure appropriate thresholds and voting periods

### Creating a Proposal

Any user with sufficient tokens can create a proposal:

```clarity
(contract-call? .proposal-system submit-proposal 
  "Upgrade Protocol" 
  u"This proposal upgrades our core protocol to version 2.0"
  (some 0x68656c6c6f20776f726c64) ;; Optional execution data
)
```

### Voting on Proposals

Token holders can vote on active proposals:

```clarity
;; Vote in favor
(contract-call? .proposal-system vote u1 true)

;; Vote against
(contract-call? .proposal-system vote u1 false)
```

### Executing Approved Proposals

After the voting period ends and a proposal is approved:

```clarity
(contract-call? .proposal-system execute-proposal u1)
```

## Proposal Lifecycle

1. **Creation**: A user submits a new proposal
2. **Active**: The proposal is open for voting
3. **Finalization**: After the voting period, the proposal is marked Approved or Rejected
4. **Execution**: If approved, the proposal can be executed

## Error Handling

The contract uses descriptive error codes to provide clear feedback:

| Error Code | Description |
|------------|-------------|
| u100 | Unauthorized operation |
| u101 | Proposal not found |
| u102 | Proposal already exists |
| u103 | Voting period has ended |
| u104 | Voting period has not ended |
| u105 | User has already voted |
| u106 | Insufficient tokens |
| u107 | Proposal already executed |
| u108 | Invalid vote |
| u109 | Execution failed |
| u110 | Invalid proposal data |
| u111 | Proposal rejected |

## Security Considerations

- **Token Thresholds**: Prevent spam proposals with minimum token requirements
- **Timelock Voting**: Fixed voting periods prevent rushed decisions
- **Contract Whitelist**: Only approved contracts can be executed
- **Permission Checks**: Authorization required for administrative functions
- **Vote Protection**: Each user can only vote once per proposal

## Advanced Use Cases

### Upgrading the System

The governance system can be used to approve and execute upgrades to itself or other protocol components.

### Treasury Management

By whitelisting a treasury contract, the governance system can manage community funds.

### Protocol Parameters

Governance can be used to update protocol parameters in other contracts.