#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Vercel Environment Sync ===${NC}"

# Validate required environment variables
: "${VERCEL_TOKEN:?VERCEL_TOKEN not set}"
: "${VERCEL_ORG_ID:?VERCEL_ORG_ID not set}"
: "${VERCEL_PROJECT_ID:?VERCEL_PROJECT_ID not set}"

# Get deployment JSON file path
JSON_FILE="${1:-deployments/kaia-kairos-all.json}"
if [ ! -f "$JSON_FILE" ]; then
  echo -e "${RED}Error: Missing $JSON_FILE${NC}"
  exit 1
fi

echo -e "${GREEN}Reading deployment data from: $JSON_FILE${NC}"

# Extract values from JSON
KAIA_RPC=$(jq -r '.kaiaRpc' "$JSON_FILE")
PERMIT2=$(jq -r '.permit2' "$JSON_FILE")
USDT=$(jq -r '.usdt' "$JSON_FILE")
RKUSDT=$(jq -r '.rkUSDT' "$JSON_FILE")
VAULT=$(jq -r '.vault' "$JSON_FILE")

# Optional ETH environment variables (can be empty)
ETH_RPC="${NEXT_PUBLIC_ETH_RPC_URL:-}"
ETH_STRAT="${NEXT_PUBLIC_ETH_STRATEGY:-}"

echo -e "${GREEN}Contract addresses to sync:${NC}"
echo "  KAIA_RPC_URL: $KAIA_RPC"
echo "  KAIA_PERMIT2: $PERMIT2"
echo "  KAIA_USDT: $USDT"
echo "  KAIA_RKUSDT: $RKUSDT"
echo "  KAIA_VAULT: $VAULT"
if [ -n "$ETH_RPC" ]; then
  echo "  ETH_RPC_URL: $ETH_RPC"
fi
if [ -n "$ETH_STRAT" ]; then
  echo "  ETH_STRATEGY: $ETH_STRAT"
fi

# Helper function to set or update Vercel environment variable
set_env() {
  local KEY="$1"
  local VAL="$2"
  
  echo -n "Setting $KEY... "
  
  # Remove existing variable (ignore errors if doesn't exist)
  npx vercel env rm "$KEY" production --yes \
    --token "$VERCEL_TOKEN" \
    --scope "$VERCEL_ORG_ID" \
    >/dev/null 2>&1 || true
  
  # Add new variable
  printf "%s" "$VAL" | npx vercel env add "$KEY" production \
    --token "$VERCEL_TOKEN" \
    --scope "$VERCEL_ORG_ID" \
    >/dev/null
  
  echo -e "${GREEN}✓${NC}"
}

# Navigate to frontend directory for Vercel CLI
cd "$(dirname "$0")/../frontend"

echo -e "${GREEN}Installing Vercel CLI...${NC}"
npm list vercel >/dev/null 2>&1 || npm install --no-save vercel >/dev/null

echo -e "${GREEN}Updating Vercel environment variables...${NC}"

# Set all environment variables
set_env "NEXT_PUBLIC_KAIA_RPC_URL" "$KAIA_RPC"
set_env "NEXT_PUBLIC_KAIA_PERMIT2" "$PERMIT2"
set_env "NEXT_PUBLIC_KAIA_USDT" "$USDT"
set_env "NEXT_PUBLIC_KAIA_RKUSDT" "$RKUSDT"
set_env "NEXT_PUBLIC_KAIA_VAULT" "$VAULT"

# Set optional ETH variables if provided
if [ -n "$ETH_RPC" ]; then
  set_env "NEXT_PUBLIC_ETH_RPC_URL" "$ETH_RPC"
fi
if [ -n "$ETH_STRAT" ]; then
  set_env "NEXT_PUBLIC_ETH_STRATEGY" "$ETH_STRAT"
fi

echo -e "${GREEN}Environment variables updated successfully!${NC}"

# Trigger production redeployment
echo -e "${GREEN}Triggering Vercel production redeployment...${NC}"

# Get the latest deployment URL
DEPLOYMENT_URL=$(npx vercel list --token "$VERCEL_TOKEN" --scope "$VERCEL_ORG_ID" --prod --json 2>/dev/null | jq -r '.[0].url' || echo "")

if [ -n "$DEPLOYMENT_URL" ]; then
  echo "Current production deployment: $DEPLOYMENT_URL"
  
  # Trigger redeploy of the latest production deployment
  echo "Redeploying..."
  REDEPLOY_OUTPUT=$(npx vercel redeploy "$DEPLOYMENT_URL" --prod \
    --token "$VERCEL_TOKEN" \
    --scope "$VERCEL_ORG_ID" \
    2>&1)
  
  # Extract new deployment URL from output
  NEW_URL=$(echo "$REDEPLOY_OUTPUT" | grep -oE 'https://[^ ]+' | tail -1)
  
  if [ -n "$NEW_URL" ]; then
    echo -e "${GREEN}=== Deployment Successful ===${NC}"
    echo -e "${GREEN}Production URL: $NEW_URL${NC}"
  else
    echo -e "${YELLOW}Redeploy command executed but couldn't extract URL${NC}"
    echo "Output: $REDEPLOY_OUTPUT"
  fi
else
  echo -e "${YELLOW}Warning: Could not find existing production deployment${NC}"
  echo "Please ensure the project is linked to Vercel and has at least one deployment"
  echo "You may need to run 'vercel --prod' manually first"
fi

echo -e "${GREEN}=== Vercel Sync Complete ===${NC}"