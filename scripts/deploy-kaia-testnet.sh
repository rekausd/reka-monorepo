#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== KAIA Testnet Deployment Script ===${NC}"

# Check required environment variables
if [ -z "${KAIA_RPC_URL:-}" ]; then
    echo -e "${RED}Error: KAIA_RPC_URL not set${NC}"
    echo "Please set KAIA_RPC_URL to your Kaia testnet RPC endpoint"
    exit 1
fi

if [ -z "${PRIVATE_KEY:-}" ]; then
    echo -e "${RED}Error: PRIVATE_KEY not set${NC}"
    echo "Please set PRIVATE_KEY to your deployment wallet private key"
    exit 1
fi

# Optional: Use existing Permit2 address or deploy new
KAIA_PERMIT2=${KAIA_PERMIT2:-"0x000000000022D473030F116dDEE9F6B43aC78BA3"}
echo -e "${YELLOW}Using Permit2 at: ${KAIA_PERMIT2}${NC}"

# Navigate to contracts directory
cd "$(dirname "$0")/../contracts"

echo -e "${GREEN}Building contracts...${NC}"
forge build

# Create deployments directory if it doesn't exist
mkdir -p ../deployments

# Deploy tokens (or use existing)
echo -e "${GREEN}Deploying tokens...${NC}"
TOKENS_OUTPUT=$(forge script script/kaia/DeployTokensKaia.s.sol:DeployTokensKaia \
    --rpc-url "$KAIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --json 2>&1)

# Extract token addresses from output
USDT_ADDR=$(echo "$TOKENS_OUTPUT" | grep "USDT:" | tail -1 | awk '{print $NF}')
RKUSDT_ADDR=$(echo "$TOKENS_OUTPUT" | grep "rkUSDT:" | tail -1 | awk '{print $NF}')

if [ -z "$USDT_ADDR" ] || [ -z "$RKUSDT_ADDR" ]; then
    echo -e "${RED}Failed to extract token addresses${NC}"
    echo "Output was:"
    echo "$TOKENS_OUTPUT"
    exit 1
fi

echo -e "${GREEN}Token addresses:${NC}"
echo "  USDT: $USDT_ADDR"
echo "  rkUSDT: $RKUSDT_ADDR"

# Export for vault deployment
export KAIA_USDT="$USDT_ADDR"
export KAIA_RKUSDT="$RKUSDT_ADDR"
export KAIA_PERMIT2

# Deploy vault
echo -e "${GREEN}Deploying vault...${NC}"
VAULT_OUTPUT=$(forge script script/kaia/DeployVaultKaia.s.sol:DeployVaultKaia \
    --rpc-url "$KAIA_RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --broadcast \
    --json 2>&1)

# Extract vault address
VAULT_ADDR=$(echo "$VAULT_OUTPUT" | grep "Vault Address:" | tail -1 | awk '{print $NF}')

if [ -z "$VAULT_ADDR" ]; then
    echo -e "${RED}Failed to extract vault address${NC}"
    echo "Output was:"
    echo "$VAULT_OUTPUT"
    exit 1
fi

echo -e "${GREEN}Vault deployed at: $VAULT_ADDR${NC}"

# Create deployment JSON
DEPLOYMENT_FILE="../deployments/kaia-testnet.json"
cat > "$DEPLOYMENT_FILE" <<EOF
{
  "chainId": 1001,
  "network": "kaia-testnet",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "contracts": {
    "USDT": "$USDT_ADDR",
    "rkUSDT": "$RKUSDT_ADDR",
    "SimpleRekaUSDVault": "$VAULT_ADDR",
    "Permit2": "$KAIA_PERMIT2"
  }
}
EOF

echo -e "${GREEN}Deployment info saved to $DEPLOYMENT_FILE${NC}"

# Update frontend .env.local
ENV_FILE="../frontend/.env.local"
if [ -f "$ENV_FILE" ]; then
    # Update existing env file
    if grep -q "NEXT_PUBLIC_KAIA_USDT" "$ENV_FILE"; then
        # Update existing entries
        sed -i.bak "s/^NEXT_PUBLIC_KAIA_USDT=.*/NEXT_PUBLIC_KAIA_USDT=$USDT_ADDR/" "$ENV_FILE"
        sed -i.bak "s/^NEXT_PUBLIC_KAIA_RKUSDT=.*/NEXT_PUBLIC_KAIA_RKUSDT=$RKUSDT_ADDR/" "$ENV_FILE"
        sed -i.bak "s/^NEXT_PUBLIC_KAIA_VAULT=.*/NEXT_PUBLIC_KAIA_VAULT=$VAULT_ADDR/" "$ENV_FILE"
        sed -i.bak "s/^NEXT_PUBLIC_KAIA_PERMIT2=.*/NEXT_PUBLIC_KAIA_PERMIT2=$KAIA_PERMIT2/" "$ENV_FILE"
        rm "$ENV_FILE.bak"
    else
        # Append new entries
        echo "" >> "$ENV_FILE"
        echo "# KAIA Testnet Contracts" >> "$ENV_FILE"
        echo "NEXT_PUBLIC_KAIA_USDT=$USDT_ADDR" >> "$ENV_FILE"
        echo "NEXT_PUBLIC_KAIA_RKUSDT=$RKUSDT_ADDR" >> "$ENV_FILE"
        echo "NEXT_PUBLIC_KAIA_VAULT=$VAULT_ADDR" >> "$ENV_FILE"
        echo "NEXT_PUBLIC_KAIA_PERMIT2=$KAIA_PERMIT2" >> "$ENV_FILE"
    fi
else
    # Create new env file
    cat > "$ENV_FILE" <<EOF
# KAIA Testnet Contracts
NEXT_PUBLIC_KAIA_USDT=$USDT_ADDR
NEXT_PUBLIC_KAIA_RKUSDT=$RKUSDT_ADDR
NEXT_PUBLIC_KAIA_VAULT=$VAULT_ADDR
NEXT_PUBLIC_KAIA_PERMIT2=$KAIA_PERMIT2

# Add your KAIA RPC URL here for frontend
NEXT_PUBLIC_KAIA_RPC_URL=https://public-en-kairos.node.kaia.io
EOF
fi

echo -e "${GREEN}Frontend environment updated in $ENV_FILE${NC}"

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Deployed contracts:"
echo "  USDT:   $USDT_ADDR"
echo "  rkUSDT: $RKUSDT_ADDR"
echo "  Vault:  $VAULT_ADDR"
echo "  Permit2: $KAIA_PERMIT2"
echo ""
echo "To interact with the contracts:"
echo "  1. cd frontend && npm run dev"
echo "  2. Connect wallet to KAIA testnet"
echo "  3. Visit http://localhost:3000/app/stake"