#!/usr/bin/env node
import { ethers } from "ethers";
import "@kaiachain/ethers-ext";

const REQUIRED_ENV = [
  "NEXT_PUBLIC_MINIAPP_APP_ID",
  "NEXT_PUBLIC_KAIA_RPC_URL",
  "NEXT_PUBLIC_KAIA_USDT",
  "NEXT_PUBLIC_KAIA_RKUSDT",
  "NEXT_PUBLIC_KAIA_VAULT",
  "NEXT_PUBLIC_KAIA_CHAIN_ID"
];

async function smokeTest() {
  console.log("🚀 Mini Dapp Smoke Test");
  console.log("=======================\n");
  
  // Check environment
  console.log("1. Checking environment variables...");
  const missing = REQUIRED_ENV.filter(key => !process.env[key]);
  if (missing.length > 0) {
    console.error("❌ Missing environment variables:", missing.join(", "));
    process.exit(1);
  }
  console.log("✅ All required environment variables present\n");
  
  // Test RPC connection
  console.log("2. Testing Kaia RPC connection...");
  const provider = new ethers.JsonRpcProvider(process.env.NEXT_PUBLIC_KAIA_RPC_URL);
  try {
    const chainId = await provider.getNetwork();
    const blockNumber = await provider.getBlockNumber();
    console.log(`✅ Connected to chain ${chainId.chainId} at block ${blockNumber}\n`);
  } catch (err) {
    console.error("❌ Failed to connect to RPC:", err);
    process.exit(1);
  }
  
  // Test contract reads
  console.log("3. Testing contract reads...");
  const vaultABI = ["function totalStakedUSDT() view returns (uint256)"];
  const vault = new ethers.Contract(
    process.env.NEXT_PUBLIC_KAIA_VAULT!,
    vaultABI,
    provider
  );
  
  try {
    const totalStaked = await vault.totalStakedUSDT();
    console.log(`✅ Vault totalStakedUSDT: ${ethers.formatUnits(totalStaked, 6)} USDT\n`);
  } catch (err) {
    console.error("❌ Failed to read from vault:", err);
    process.exit(1);
  }
  
  // Simulate Mini Dapp environment
  console.log("4. Mini Dapp environment simulation...");
  console.log("   To test in real Mini Dapp:");
  console.log("   - Set NEXT_PUBLIC_MINIAPP_ENABLED=true");
  console.log("   - Deploy to HTTPS endpoint");
  console.log("   - Register with LINE Developers Console");
  console.log("   - Test in LINE app\n");
  
  // Dev mode test
  console.log("5. Local dev mode test:");
  console.log("   Run: npm run dev");
  console.log("   Open: http://localhost:5173");
  console.log("   - Check Mini Dapp guard loads");
  console.log("   - Connect Kaia wallet");
  console.log("   - Test deposit/withdraw flows\n");
  
  console.log("✅ Smoke test complete!");
}

// Run if executed directly
if (require.main === module) {
  smokeTest().catch(console.error);
}

export { smokeTest };