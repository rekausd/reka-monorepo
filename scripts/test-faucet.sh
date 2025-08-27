#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Faucet Diagnostic Test ===${NC}"

# Check required environment variables
if [ -z "${KAIA_RPC_URL:-}" ]; then
  echo -e "${RED}Error: KAIA_RPC_URL not set${NC}"
  echo "Example: export KAIA_RPC_URL=\"https://public-en-kairos.node.kaia.io\""
  exit 1
fi

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo -e "${RED}Error: PRIVATE_KEY not set${NC}"
  echo "Example: export PRIVATE_KEY=\"0xYOUR_PRIVATE_KEY\""
  exit 1
fi

# Get the root directory
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Read faucet token from frontend config
if [ -f frontend/public/reka-config.json ]; then
  FAUCET_TOKEN=$(jq -r '.faucetToken // .usdt' frontend/public/reka-config.json 2>/dev/null || echo "")
  FAUCET_AMOUNT=$(jq -r '.faucetAmount // "10000"' frontend/public/reka-config.json 2>/dev/null || echo "10000")
  
  echo -e "${GREEN}Reading from frontend/public/reka-config.json${NC}"
  echo "  Faucet Token: $FAUCET_TOKEN"
  echo "  Faucet Amount: $FAUCET_AMOUNT"
  echo ""
else
  echo -e "${YELLOW}Warning: frontend/public/reka-config.json not found${NC}"
  
  if [ -z "${FAUCET_TOKEN:-}" ]; then
    echo -e "${RED}Error: FAUCET_TOKEN not set and config not found${NC}"
    echo "Example: export FAUCET_TOKEN=\"0xYOUR_USDT_ADDRESS\""
    exit 1
  fi
fi

# Export for the Foundry script
export FAUCET_TOKEN="${FAUCET_TOKEN:-}"
export FAUCET_TO="${FAUCET_TO:-}" # Optional recipient

# Get wallet address for display
WALLET_ADDR=$(cast wallet address --private-key $PRIVATE_KEY 2>/dev/null || echo "unknown")
echo -e "${BLUE}Testing with wallet: $WALLET_ADDR${NC}"

# Check initial balance
echo -e "${YELLOW}Checking initial balance...${NC}"
INITIAL_BALANCE=$(cast call $FAUCET_TOKEN "balanceOf(address)(uint256)" $WALLET_ADDR --rpc-url $KAIA_RPC_URL 2>/dev/null || echo "0")
echo "Initial balance: $INITIAL_BALANCE wei"
echo ""

# Run the probe script
echo -e "${YELLOW}Running faucet probe...${NC}"
cd contracts

forge script script/kaia/ProbeFaucet.s.sol:ProbeFaucet \
  --rpc-url "$KAIA_RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vv || {
    echo -e "${RED}Faucet probe failed!${NC}"
    echo "This means the token at $FAUCET_TOKEN doesn't have a working mint/faucet function."
    exit 1
}

cd "$ROOT"

# Check final balance
echo ""
echo -e "${YELLOW}Checking final balance...${NC}"
FINAL_BALANCE=$(cast call $FAUCET_TOKEN "balanceOf(address)(uint256)" $WALLET_ADDR --rpc-url $KAIA_RPC_URL 2>/dev/null || echo "0")
echo "Final balance: $FINAL_BALANCE wei"

# Calculate minted amount
if command -v bc &> /dev/null; then
  MINTED=$(echo "$FINAL_BALANCE - $INITIAL_BALANCE" | bc 2>/dev/null || echo "unknown")
  if [ "$MINTED" != "unknown" ] && [ "$MINTED" != "0" ]; then
    echo -e "${GREEN}Successfully minted: $MINTED wei${NC}"
  fi
fi

echo ""
echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. If successful, the frontend faucet should work with the same token"
echo "2. Check http://localhost:5173/app/faucet to test the UI"
echo "3. The UI will show diagnostic info about which methods it tries"