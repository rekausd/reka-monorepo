# ReKaUSD Ethereum-side Mocks

Mocks for integration tests to simulate USDT → USDe → sUSDe flow with yield.

## Components
- `MockUSDT` (6 decimals): mintable by owner.
- `MockUSDe` (18 decimals): mint/burn by owner.
- `MockSUSDe` (18 decimals): share token, mint/burn by designated vault.
- `MockSwapUSDTtoUSDe`: pulls USDT and mints USDe out at `rateBps`.
- `MockStakingUSDeToSUSDe`: staking vault issuing sUSDe shares; accrues ~11% APY via per-second index in ray precision and materializes yield on demand.
- `libs/YieldMath.sol`: ray math helpers including powRay.

## Decimals
- USDT: 6
- USDe: 18
- sUSDe: 18

## Yield Model
- APY in basis points, default 1100 (11%).
- Per-second rate in ray; index compounds at each state change; `harvest()` mints the gap so on-chain USDe balance matches virtual assets.

## Usage
```bash
forge install
forge build
forge test -vvvv
forge script script/DeployMocks.s.sol:DeployMocks --rpc-url <rpc> --private-key <pk> --broadcast -vvvv
```
