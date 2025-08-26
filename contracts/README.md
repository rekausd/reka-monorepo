# ReKaUSD Contracts

Smart contracts for the ReKaUSD protocol, enabling cross-chain yield optimization between KAIA and Ethereum.

## Overview

This repository contains the core smart contracts for ReKaUSD:
- **KAIA Contracts**: Vault for deposits/withdrawals, rkUSDT receipt token
- **Ethereum Contracts**: Yield strategy integration with Ethena
- **Common**: Shared interfaces and utilities

## Permit2 Deposits

The KAIA Vault supports single-transaction deposits via Uniswap **Permit2**, enabling gasless token approvals.

### Features
- **Function**: `depositWithPermit2(owner, token, amount, sigDeadline, signature)`
- **Flow**: 
  1. User signs EIP-712 permit message off-chain
  2. `permit(owner, PermitSingle(spender=vault))` sets allowance via signature
  3. `transferFrom(owner→vault)` pulls USDT to vault
  4. Mints rkUSDT 1:1 to depositor
- **Configuration**: Set Permit2 address via `KAIA_PERMIT2` environment variable
- **Kairos Testnet**: `0x000000000022d473030f116ddee9f6b43ac78ba3`

### Benefits
- Single transaction for users (no separate approve tx)
- Gasless approval via signature
- Maintains compatibility with legacy `deposit(uint256)` for standard flow

## Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js 16+ (for frontend integration)

### Installation
```bash
forge install
```

### Build
```bash
forge build
```

### Test
```bash
forge test -vv
```

### Deploy

Set environment variables:
```bash
export USDT_ADDR=0x...          # KAIA USDT address
export FEE_RECIPIENT=0x...      # Fee recipient address
export KAIA_PERMIT2=0x000000000022d473030f116ddee9f6b43ac78ba3  # Permit2 (optional)
```

Deploy to KAIA:
```bash
forge script script/kaia/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## Contract Addresses

### KAIA Kairos Testnet
- Permit2: `0x000000000022d473030f116ddee9f6b43ac78ba3`
- USDT: (deployment specific)
- rkUSDT: (deployment specific)
- Vault: (deployment specific)

## Security

- All deposits are protected by reentrancy guards
- Permit2 signatures are validated on-chain
- Epoch-based accounting ensures fair withdrawals
- Admin functions are protected by ownership controls

## License

MIT