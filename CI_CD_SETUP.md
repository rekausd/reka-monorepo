# CI/CD Setup Guide - KAIA Contracts to Vercel

This guide explains how to set up automated deployment of KAIA contracts with Vercel frontend synchronization.

## Architecture Overview

```
Push to main → GitHub Actions → Deploy Contracts → Sync to Vercel → Redeploy Frontend
```

## Prerequisites

1. **GitHub Repository**: Your code should be pushed to GitHub
2. **Vercel Account**: Create an account at [vercel.com](https://vercel.com)
3. **KAIA Testnet Wallet**: With KAIA tokens for gas fees
4. **Vercel CLI**: Install globally with `npm i -g vercel`

## Step 1: Create Vercel Project

1. Navigate to your frontend directory:
   ```bash
   cd frontend
   ```

2. Link to Vercel (first time only):
   ```bash
   vercel
   ```
   - Choose "Link to existing project" or create new
   - Set root directory to `frontend`
   - Framework preset: Next.js
   - Build settings will be auto-detected

3. Get your Vercel IDs:
   ```bash
   # Get org/team ID
   vercel teams ls
   
   # Get project ID (after linking)
   vercel project ls
   ```

## Step 2: Generate Vercel Token

1. Go to [Vercel Account Settings](https://vercel.com/account/tokens)
2. Click "Create Token"
3. Name it (e.g., "GitHub Actions Deploy")
4. Copy the token (you won't see it again)

## Step 3: Configure GitHub Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions

Add these repository secrets:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `KAIA_RPC_URL` | KAIA Kairos RPC endpoint | `https://public-en-kairos.node.kaia.io` |
| `PRIVATE_KEY` | Deployer wallet private key | `0x...` (without 0x prefix) |
| `VERCEL_TOKEN` | Token from Step 2 | `...` |
| `VERCEL_ORG_ID` | Your Vercel org/team ID | `team_...` |
| `VERCEL_PROJECT_ID` | Your Vercel project ID | `prj_...` |

## Step 4: Test Deployment

### Manual Trigger
1. Go to Actions tab in GitHub
2. Select "Deploy KAIA & Sync Vercel"
3. Click "Run workflow" → "Run workflow"

### Automatic Trigger
Simply push to the `main` branch:
```bash
git push origin main
```

## Step 5: Verify Deployment

1. **Check GitHub Actions**:
   - Go to Actions tab
   - Click on the running/completed workflow
   - View logs and summary

2. **Check Contract Deployment**:
   - View `deployments/kaia-kairos-all.json` in repo
   - Addresses will be shown in workflow summary

3. **Check Vercel**:
   - Go to your Vercel project dashboard
   - Environment variables should be updated
   - New deployment should be triggered

4. **Test Frontend**:
   - Visit your Vercel URL
   - Connect KAIA wallet (Kairos testnet)
   - Contract addresses should be loaded

## Files Created

```
.github/workflows/kaia-vercel.yml    # GitHub Actions workflow
frontend/vercel.json                  # Vercel configuration
scripts/deploy-kaia-all.sh           # Unified deployment script
scripts/vercel-sync-env.sh           # Vercel env sync script
contracts/script/kaia/DeployAllKaia.s.sol  # Foundry deploy script
```

## Environment Variables

The following are automatically synced to Vercel:

- `NEXT_PUBLIC_KAIA_RPC_URL` - KAIA RPC endpoint
- `NEXT_PUBLIC_KAIA_PERMIT2` - Permit2 contract address
- `NEXT_PUBLIC_KAIA_USDT` - Mock USDT token address
- `NEXT_PUBLIC_KAIA_RKUSDT` - rkUSDT receipt token address
- `NEXT_PUBLIC_KAIA_VAULT` - Vault contract address

## Local Development

For local development, create `frontend/.env.local`:

```env
NEXT_PUBLIC_KAIA_RPC_URL=https://public-en-kairos.node.kaia.io
NEXT_PUBLIC_KAIA_PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
NEXT_PUBLIC_KAIA_USDT=<deployed_address>
NEXT_PUBLIC_KAIA_RKUSDT=<deployed_address>
NEXT_PUBLIC_KAIA_VAULT=<deployed_address>
```

Run the deployment script locally:
```bash
export KAIA_RPC_URL="https://public-en-kairos.node.kaia.io"
export PRIVATE_KEY="your_private_key"
export UPDATE_LOCAL_ENV=true
./scripts/deploy-kaia-all.sh
```

## Workflow Features

### Skip Deployment
If you only want to sync existing addresses without redeploying:
1. Go to Actions → "Deploy KAIA & Sync Vercel"
2. Click "Run workflow"
3. Check "Skip contract deployment"

### Deployment Artifacts
Each deployment creates artifacts that are retained for 30 days:
- View in Actions → Workflow run → Artifacts
- Contains `kaia-kairos-all.json` with all addresses

### PR Comments
If triggered from a pull request, the bot will comment with deployed addresses.

## Troubleshooting

### Vercel CLI Not Found
```bash
npm install -g vercel
```

### Permission Denied on Scripts
```bash
chmod +x scripts/*.sh
```

### Deployment Fails
- Check you have KAIA tokens for gas
- Verify RPC URL is correct
- Check private key format (no 0x prefix in secret)

### Vercel Sync Fails
- Verify token permissions
- Check org/team ID is correct
- Ensure project is linked to correct repo

## Security Notes

⚠️ **IMPORTANT**:
- Never commit private keys or tokens to the repository
- Use GitHub Secrets for all sensitive values
- The `NEXT_PUBLIC_*` variables are exposed to the browser (only use for public data)
- Rotate tokens periodically
- Use separate wallets for testnet and mainnet

## Customization

### Change Deployment Network
Edit `.github/workflows/kaia-vercel.yml`:
```yaml
env:
  KAIA_RPC_URL: ${{ secrets.MAINNET_RPC_URL }}  # Change to mainnet
```

### Add More Environment Variables
1. Update `scripts/vercel-sync-env.sh` to include new variables
2. Update `frontend/vercel.json` env section
3. Add to GitHub Secrets if needed

### Deploy to Multiple Environments
Create separate workflows for staging/production with different secret sets.

## Support

For issues with:
- **Contracts**: Check Foundry documentation
- **Vercel**: Check Vercel documentation or support
- **GitHub Actions**: Check workflow logs and GitHub docs
- **KAIA**: Check KAIA documentation