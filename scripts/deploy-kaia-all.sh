#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== KAIA All-in-One Deployment Script ===${NC}"

# Check required environment variables
if [ -z "${KAIA_RPC_URL:-}" ]; then
    echo -e "${RED}Error: KAIA_RPC_URL not set${NC}"
    exit 1
fi

if [ -z "${PRIVATE_KEY:-}" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set${NC}"
    exit 1
fi

# Use default Permit2 if not provided
KAIA_PERMIT2="${KAIA_PERMIT2:-0x000000000022D473030F116dDEE9F6B43aC78BA3}"

# Navigate to contracts directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../contracts"

echo -e "${GREEN}Building contracts...${NC}"
forge build

# Create deployments directory
mkdir -p ../deployments

# Deploy all contracts
echo -e "${GREEN}Deploying KAIA contracts...${NC}"
DEPLOY_OUTPUT=$(forge script script/kaia/DeployAllKaia.s.sol:DeployAllKaia \
    --rpc-url "$KAIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --json 2>&1)

# Extract addresses from deployment output
USDT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "USDT:" | tail -1 | awk '{print $NF}')
RKUSDT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "rkUSDT:" | tail -1 | awk '{print $NF}')
VAULT_ADDR=$(echo "$DEPLOY_OUTPUT" | grep "Vault:" | tail -1 | awk '{print $NF}')

# Validate we got all addresses
if [ -z "$USDT_ADDR" ] || [ -z "$RKUSDT_ADDR" ] || [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}Failed to extract contract addresses${NC}"
    echo "Deployment output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}Successfully deployed:${NC}"
echo "  USDT: $USDT_ADDR"
echo "  rkUSDT: $RKUSDT_ADDR"
echo "  Vault: $VAULT_ADDR"
echo "  Permit2: $KAIA_PERMIT2"

# Create unified deployment JSON for CI/CD
DEPLOYMENT_FILE="../deployments/kaia-kairos-all.json"
cat > "$DEPLOYMENT_FILE" <<EOF
{
  "chainId": 1001,
  "network": "kaia-kairos",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "kaiaRpc": "${KAIA_RPC_URL}",
  "permit2": "${KAIA_PERMIT2}",
  "usdt": "${USDT_ADDR}",
  "rkUSDT": "${RKUSDT_ADDR}",
  "vault": "${VAULT_ADDR}"
}
EOF

echo -e "${GREEN}Deployment info saved to $DEPLOYMENT_FILE${NC}"

# Optional: Update local frontend .env.local for development
ENV_FILE="../frontend/.env.local"
if [ "${UPDATE_LOCAL_ENV:-false}" = "true" ] && [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Updating local frontend/.env.local...${NC}"
    
    # Backup existing file
    cp "$ENV_FILE" "$ENV_FILE.bak"
    
    # Update or add KAIA contract addresses
    {
        grep -v "^NEXT_PUBLIC_KAIA_" "$ENV_FILE" || true
        echo "# KAIA Contracts (auto-updated by deploy script)"
        echo "NEXT_PUBLIC_KAIA_RPC_URL=$KAIA_RPC_URL"
        echo "NEXT_PUBLIC_KAIA_PERMIT2=$KAIA_PERMIT2"
        echo "NEXT_PUBLIC_KAIA_USDT=$USDT_ADDR"
        echo "NEXT_PUBLIC_KAIA_RKUSDT=$RKUSDT_ADDR"
        echo "NEXT_PUBLIC_KAIA_VAULT=$VAULT_ADDR"
    } > "$ENV_FILE.tmp"
    
    mv "$ENV_FILE.tmp" "$ENV_FILE"
    echo -e "${GREEN}Local env updated${NC}"
fi

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Deployed contracts on KAIA Kairos:"
echo "  USDT:    $USDT_ADDR"
echo "  rkUSDT:  $RKUSDT_ADDR"
echo "  Vault:   $VAULT_ADDR"
echo "  Permit2: $KAIA_PERMIT2"
echo ""
echo "Deployment data saved to: $DEPLOYMENT_FILE"