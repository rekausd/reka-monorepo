# ReKaUSD (KAIA side)

Production-grade KAIA-side vault for a USDT restaking protocol named ReKaUSD that mints a receipt token rkUSDT on deposit. Ethereum-side logic is out of scope for this repo.

## Overview
- Users deposit KAIA-native USDT to `ReKaUSDVault` and receive `rkUSDT` 1:1 (6 decimals).
- Weekly epoch batching; at rollover the vault bridges available USDT via a bridge adapter (mocked).
- Withdrawals:
  - Instant within the same epoch up to user's `currentEpochDeposits` (fee applies).
  - Otherwise queued and becomes claimable next epoch after rollover (fee applies).
- Fees: deposit fee = 0; withdraw fee = 0.5% routed to `feeRecipient`.
- Safety bound: rollover reserves enough USDT to honor claimables, bridges only the remainder.

## Contracts
- `src/rkUSDT.sol`: ERC20 receipt token, decimals = 6. Only vault can mint/burn.
- `src/ReKaUSDVault.sol`: core vault, epoch management, deposits/withdrawals, bridging.
- `src/interfaces/IBridgeAdapter.sol`: adapter interface; mock emits events only.
- `src/MockStargateAdapter.sol`: test stub that emits `BridgeInitiated`.
- `src/utils/SafeERC20Compat.sol`: OZ SafeERC20 wrapper conveniences.

## Epoch model
```
Epoch N (deposits, instant-withdraw window) --> rollover --> Epoch N+1
- Queued withdrawals requested in Epoch N become claimable after rollover into N+1
- Bridged amount at rollover: vaultBalance - totalClaimable - reserveDust (not used yet)
```

## Fees
- Withdraw fee fixed at 50 bps.

## Run
```bash
forge install
forge build
forge test -vvvv
```

## Deploy
```bash
USDT_ADDR=0x... FEE_RECIPIENT=0x... EPOCH_DURATION=$((7*24*60*60)) \
  forge script script/Deploy.s.sol:Deploy --rpc-url $KAIA_RPC --broadcast -vvvv
```
