#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Deploy and Publish to KAIA Kairos ===${NC}"

# Check required environment variables
: "${KAIA_RPC_URL:?KAIA_RPC_URL not set}"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"

# Default Permit2 address on most chains
KAIA_PERMIT2_DEFAULT="0x000000000022d473030f116ddee9f6b43ac78ba3"
KAIA_PERMIT2="${KAIA_PERMIT2:-$KAIA_PERMIT2_DEFAULT}"

# Get the root directory
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}"
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
fi

echo -e "${GREEN}Building contracts...${NC}"
cd contracts
forge build

echo -e "${GREEN}Deploying All (USDT + rkUSDT + Vault)...${NC}"
DEPLOY_OUTPUT=$(forge script script/kaia/DeployAllKaia.s.sol:DeployAllKaia \
  --rpc-url "$KAIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vvv 2>&1)

# Extract deployed addresses from output
echo "$DEPLOY_OUTPUT" | grep -E "(USDT:|rkUSDT:|Vault:)" || true

# Find the latest run file
RUN_FILE=$(find broadcast/DeployAllKaia.s.sol -name "run-latest.json" 2>/dev/null | head -n1)

if [ -z "$RUN_FILE" ] || [ ! -f "$RUN_FILE" ]; then
  echo -e "${RED}Error: Could not find deployment run file${NC}"
  echo "Looking for: broadcast/DeployAllKaia.s.sol/*/run-latest.json"
  exit 1
fi

echo -e "${GREEN}Reading deployment results from: $RUN_FILE${NC}"

# Extract addresses from the run file
# Try to get from environment first (for reuse), otherwise extract from deployment
USDT=${KAIA_USDT:-$(jq -r '.transactions[]?|select(.contractName=="MockUSDTMintableOpen")|.contractAddress' "$RUN_FILE" 2>/dev/null | tail -n1 || echo "")}
RKUSDT=${KAIA_RKUSDT:-$(jq -r '.transactions[]?|select(.contractName=="MockRKUSDTMintable")|.contractAddress' "$RUN_FILE" 2>/dev/null | tail -n1 || echo "")}

# For vault, check multiple possible names
VAULT=$(jq -r '.transactions[]?|select(.contractName=="SimpleRekaUSDVault" or .contractName=="RekaUSDVault")|.contractAddress' "$RUN_FILE" 2>/dev/null | tail -n1 || echo "")

# If not found by name, try getting the last deployed contract (usually the vault)
if [ -z "$VAULT" ]; then
  VAULT=$(jq -r '.receipts[-1].contractAddress // .transactions[-1].contractAddress' "$RUN_FILE" 2>/dev/null || echo "")
fi

# Validate we have all addresses
if [ -z "$USDT" ] || [ -z "$RKUSDT" ] || [ -z "$VAULT" ]; then
  echo -e "${RED}Error: Failed to extract all contract addresses${NC}"
  echo "USDT: $USDT"
  echo "rkUSDT: $RKUSDT"
  echo "Vault: $VAULT"
  echo ""
  echo "Run file contents:"
  jq '.transactions[]|{contractName,contractAddress}' "$RUN_FILE" 2>/dev/null || echo "Could not parse run file"
  exit 1
fi

cd "$ROOT"

# Create deployments directory
mkdir -p deployments

# Write deployment JSON for records
cat > deployments/kaia-kairos-all.json <<JSON
{
  "kaiaRpc": "$KAIA_RPC_URL",
  "permit2": "$KAIA_PERMIT2",
  "usdt": "$USDT",
  "rkUSDT": "$RKUSDT",
  "vault": "$VAULT",
  "ethRpc": "${NEXT_PUBLIC_ETH_RPC_URL:-}",
  "ethStrategy": "${NEXT_PUBLIC_ETH_STRATEGY:-}",
  "faucetToken": "$USDT",
  "faucetAmount": "10000",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON

echo -e "${GREEN}Saved deployment record to deployments/kaia-kairos-all.json${NC}"

# Check existing frontend config for differences
if [ -f frontend/public/reka-config.json ]; then
  echo -e "${YELLOW}=== Existing Frontend Config ===${NC}"
  cat frontend/public/reka-config.json | jq '.' 2>/dev/null || cat frontend/public/reka-config.json
  echo ""
  
  # Compare with what we're about to deploy
  OLD_USDT=$(jq -r '.usdt // empty' frontend/public/reka-config.json 2>/dev/null || true)
  OLD_VAULT=$(jq -r '.vault // empty' frontend/public/reka-config.json 2>/dev/null || true)
  OLD_RKUSDT=$(jq -r '.rkUSDT // empty' frontend/public/reka-config.json 2>/dev/null || true)
  
  if [ -n "$OLD_USDT" ] && [ "$OLD_USDT" != "$USDT" ]; then
    echo -e "${YELLOW}WARN: Frontend USDT changing from $OLD_USDT to $USDT${NC}"
  fi
  if [ -n "$OLD_VAULT" ] && [ "$OLD_VAULT" != "$VAULT" ]; then
    echo -e "${YELLOW}WARN: Frontend Vault changing from $OLD_VAULT to $VAULT${NC}"
  fi
  if [ -n "$OLD_RKUSDT" ] && [ "$OLD_RKUSDT" != "$RKUSDT" ]; then
    echo -e "${YELLOW}WARN: Frontend rkUSDT changing from $OLD_RKUSDT to $RKUSDT${NC}"
  fi
fi

echo -e "${GREEN}Writing new frontend config with:${NC}"
echo "  USDT=$USDT"
echo "  rkUSDT=$RKUSDT"
echo "  Vault=$VAULT"
echo "  faucetToken=$USDT"

# Write runtime config for the frontend (Vercel will serve this file)
cat > frontend/public/reka-config.json <<JSON
{
  "kaiaRpc": "$KAIA_RPC_URL",
  "permit2": "$KAIA_PERMIT2",
  "usdt": "$USDT",
  "rkUSDT": "$RKUSDT",
  "vault": "$VAULT",
  "ethRpc": "${NEXT_PUBLIC_ETH_RPC_URL:-}",
  "ethStrategy": "${NEXT_PUBLIC_ETH_STRATEGY:-}",
  "faucetToken": "$USDT",
  "faucetAmount": "10000"
}
JSON

echo -e "${GREEN}Updated frontend/public/reka-config.json${NC}"

# Optional: update local .env for development
if [ "${UPDATE_LOCAL_ENV:-true}" = "true" ]; then
  cat > frontend/.env.local <<ENV
# KAIA Contracts (auto-generated by deploy script)
NEXT_PUBLIC_KAIA_RPC_URL=$KAIA_RPC_URL
NEXT_PUBLIC_KAIA_PERMIT2=$KAIA_PERMIT2
NEXT_PUBLIC_KAIA_USDT=$USDT
NEXT_PUBLIC_KAIA_RKUSDT=$RKUSDT
NEXT_PUBLIC_KAIA_VAULT=$VAULT
NEXT_PUBLIC_ETH_RPC_URL=${NEXT_PUBLIC_ETH_RPC_URL:-}
NEXT_PUBLIC_ETH_STRATEGY=${NEXT_PUBLIC_ETH_STRATEGY:-}
ENV
  echo -e "${GREEN}Updated frontend/.env.local${NC}"
fi

echo -e "${GREEN}=== Deployment Summary ===${NC}"
echo "KAIA RPC: $KAIA_RPC_URL"
echo "Permit2:  $KAIA_PERMIT2"
echo "USDT:     $USDT"
echo "rkUSDT:   $RKUSDT"
echo "Vault:    $VAULT"

# Post-deploy faucet self-test
echo ""
echo -e "${YELLOW}=== Running Post-Deploy Faucet Self-Test ===${NC}"
export FAUCET_TOKEN="$USDT"
export FAUCET_TO="$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo 0x0000000000000000000000000000000000000000)"

echo "Testing faucet functionality on USDT: $FAUCET_TOKEN"
echo "Test recipient: $FAUCET_TO"

# Run the faucet probe script
cd contracts
forge script script/kaia/ProbeFaucet.s.sol:ProbeFaucet \
  --rpc-url "$KAIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vv || {
    echo -e "${RED}ERROR: Faucet self-test failed!${NC}"
    echo "Ensure Mock USDT exposes a working mint/faucet function."
    echo "Check that deployed addresses match frontend config."
    exit 1
}

cd "$ROOT"
echo -e "${GREEN}✓ Faucet self-test passed${NC}"

# Git commit and push (optional)
if [ "${AUTO_COMMIT:-true}" = "true" ]; then
  echo ""
  echo -e "${YELLOW}Committing and pushing to git...${NC}"
  
  # Add files to git
  git add deployments/kaia-kairos-all.json frontend/public/reka-config.json 2>/dev/null || true
  git add frontend/.env.local 2>/dev/null || true
  
  # Check if there are changes to commit
  if git diff --staged --quiet 2>/dev/null; then
    echo -e "${YELLOW}No changes to commit${NC}"
  else
    # Commit with descriptive message
    COMMIT_MSG="chore: deploy KAIA contracts & update runtime config

Deployed to KAIA Kairos:
- USDT: $USDT
- rkUSDT: $RKUSDT
- Vault: $VAULT
- Permit2: $KAIA_PERMIT2"
    
    git commit -m "$COMMIT_MSG" || true
    
    # Push to main branch
    if [ "${AUTO_PUSH:-true}" = "true" ]; then
      git push origin main || echo -e "${YELLOW}Warning: Could not push to remote${NC}"
      echo -e "${GREEN}Pushed to main branch - Vercel will auto-deploy${NC}"
    else
      echo -e "${YELLOW}Changes committed locally. Run 'git push origin main' to deploy${NC}"
    fi
  fi
else
  echo ""
  echo -e "${YELLOW}Auto-commit disabled. To deploy to Vercel:${NC}"
  echo "  git add deployments/kaia-kairos-all.json frontend/public/reka-config.json"
  echo "  git commit -m 'chore: update runtime config'"
  echo "  git push origin main"
fi

echo ""
echo -e "${GREEN}=== Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. If pushed, Vercel will auto-build with new config"
echo "2. Frontend will load config from /reka-config.json at runtime"
echo "3. Test at: http://localhost:5173 (local) or your Vercel URL"
echo ""
echo "To run locally:"
echo "  cd frontend && npm run dev"