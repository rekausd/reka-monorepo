# Runtime Configuration System

This monorepo now uses a runtime configuration system that loads contract addresses from a public JSON file, eliminating the need for environment variables at build time.

## Overview

Instead of baking contract addresses into the build via `NEXT_PUBLIC_*` environment variables, the frontend now:
1. Loads configuration from `/public/reka-config.json` at runtime
2. Falls back to environment variables for local development
3. Allows hot-swapping addresses without rebuilding

## How It Works

### 1. Configuration File
`frontend/public/reka-config.json` contains all contract addresses and RPC URLs:
```json
{
  "kaiaRpc": "https://public-en-kairos.node.kaia.io",
  "permit2": "0x000000000022d473030f116ddee9f6b43ac78ba3",
  "usdt": "0x...",
  "rkUSDT": "0x...",
  "vault": "0x...",
  "ethRpc": "",
  "ethStrategy": ""
}
```

### 2. Loading Configuration
Components use the `useAppConfig()` hook to load configuration:
```typescript
import { useAppConfig } from "@/hooks/useAppConfig";

function MyComponent() {
  const config = useAppConfig();
  if (!config) return <div>Loading...</div>;
  
  // Use config.usdt, config.vault, etc.
}
```

### 3. Deploy and Publish Workflow
The `deploy-and-publish.sh` script:
1. Deploys contracts to KAIA testnet
2. Updates `frontend/public/reka-config.json`
3. Commits and pushes to git
4. Vercel auto-deploys with new config

## Usage

### Local Development

1. **Set environment variables:**
```bash
export KAIA_RPC_URL="https://public-en-kairos.node.kaia.io"
export PRIVATE_KEY="your_testnet_private_key"
```

2. **Run deployment script:**
```bash
./scripts/deploy-and-publish.sh
```

This will:
- Deploy USDT, rkUSDT, and Vault contracts
- Update `frontend/public/reka-config.json`
- Update `frontend/.env.local` (for fallback)
- Commit and push to main branch
- Trigger Vercel deployment

3. **Test locally:**
```bash
cd frontend
npm run dev
```

### Manual Config Update

To update addresses without redeploying contracts:

1. Edit `frontend/public/reka-config.json`:
```json
{
  "kaiaRpc": "https://public-en-kairos.node.kaia.io",
  "permit2": "0x000000000022d473030f116ddee9f6b43ac78ba3",
  "usdt": "0xNEW_USDT_ADDRESS",
  "rkUSDT": "0xNEW_RKUSDT_ADDRESS",
  "vault": "0xNEW_VAULT_ADDRESS"
}
```

2. Commit and push:
```bash
git add frontend/public/reka-config.json
git commit -m "chore: update contract addresses"
git push origin main
```

### Disable Auto-commit/Push

To deploy without auto-committing:
```bash
AUTO_COMMIT=false ./scripts/deploy-and-publish.sh
```

To commit but not push:
```bash
AUTO_PUSH=false ./scripts/deploy-and-publish.sh
```

## Configuration Options

### Script Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `KAIA_RPC_URL` | KAIA network RPC endpoint | Required |
| `PRIVATE_KEY` | Deployer private key | Required |
| `KAIA_PERMIT2` | Permit2 contract address | `0x000000000022d473030f116ddee9f6b43ac78ba3` |
| `KAIA_USDT` | Reuse existing USDT | Deploy new |
| `KAIA_RKUSDT` | Reuse existing rkUSDT | Deploy new |
| `KAIA_VAULT` | Reuse existing Vault | Deploy new |
| `UPDATE_LOCAL_ENV` | Update .env.local | `true` |
| `AUTO_COMMIT` | Auto-commit changes | `true` |
| `AUTO_PUSH` | Auto-push to remote | `true` |

### Runtime Config Fields

| Field | Description | Required |
|-------|-------------|----------|
| `kaiaRpc` | KAIA RPC endpoint | Yes |
| `permit2` | Permit2 address | Yes |
| `usdt` | USDT token address | Yes |
| `rkUSDT` | rkUSDT token address | Yes |
| `vault` | Vault contract address | Yes |
| `ethRpc` | Ethereum RPC (optional) | No |
| `ethStrategy` | ETH strategy address | No |

## Benefits

1. **No rebuild required**: Update addresses without rebuilding the frontend
2. **Hot-swappable**: Changes take effect immediately after deployment
3. **Environment-agnostic**: Same build works across dev/staging/prod
4. **Git-tracked**: Config changes are versioned in git
5. **Vercel-friendly**: Auto-deploys on push to main

## Migration from Environment Variables

The system maintains backward compatibility. Components still work with environment variables as fallback:

1. **Runtime config** (preferred): `/reka-config.json`
2. **Build-time env** (fallback): `NEXT_PUBLIC_*` variables

## Troubleshooting

### Config not loading
- Check browser console for fetch errors
- Verify `/reka-config.json` exists in public folder
- Check JSON syntax is valid

### Wrong addresses showing
- Clear browser cache
- Check which config source is being used (runtime vs env)
- Verify latest config is committed and deployed

### Deployment fails
- Ensure you have KAIA tokens for gas
- Check private key format (with or without 0x prefix)
- Verify RPC endpoint is accessible

### Git push fails
- Check you have push permissions
- Ensure you're on main branch
- Pull latest changes first

## Architecture

```
User runs deploy script
        ↓
Contracts deployed to KAIA
        ↓
Addresses extracted from forge output
        ↓
frontend/public/reka-config.json updated
        ↓
Git commit & push to main
        ↓
Vercel builds and deploys
        ↓
Frontend loads config at runtime
        ↓
Users see latest addresses
```

## Security Notes

⚠️ **Important**:
- `reka-config.json` is PUBLIC - never put secrets here
- Only contract addresses and public RPC URLs
- Private keys stay in environment variables
- Config file is served to all users

## Future Enhancements

Potential improvements:
- Config versioning with fallback
- Multi-network support in single file
- Dynamic network switching
- Config validation and schema
- Admin UI for config updates