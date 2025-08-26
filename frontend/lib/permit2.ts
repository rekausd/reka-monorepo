import { ethers } from "ethers";
import { PERMIT2_ADDR } from "@/lib/contracts";

// EIP-712 types for Permit2 PermitSingle (AllowanceTransfer.PermitSingle)
const EIP712Domain = [
  { name: "name", type: "string" },
  { name: "chainId", type: "uint256" },
  { name: "verifyingContract", type: "address" }
];

const PermitDetails = [
  { name: "token", type: "address" },
  { name: "amount", type: "uint160" },
  { name: "expiration", type: "uint48" },
  { name: "nonce", type: "uint48" }
];

const PermitSingle = [
  { name: "details", type: "PermitDetails" },
  { name: "spender", type: "address" },
  { name: "sigDeadline", type: "uint256" }
];

/**
 * Sign a Permit2 PermitSingle message for AllowanceTransfer
 * @param signer - The ethers signer to sign with
 * @param owner - The token owner address
 * @param token - The token address to permit
 * @param spender - The spender address (e.g., vault)
 * @param amount - The amount to permit (uint160 max)
 * @param expirationSec - Unix timestamp when permit expires (uint48 max)
 * @param sigDeadline - Unix timestamp when signature expires
 * @returns The signed permit data including domain, types, message, and signature
 */
export async function signPermit2(
  signer: ethers.Signer,
  owner: string,
  token: string,
  spender: string,
  amount: bigint,
  expirationSec: number,
  sigDeadline: number
) {
  const net = await signer.provider!.getNetwork();
  const domain = {
    name: "Permit2",
    chainId: Number(net.chainId),
    verifyingContract: PERMIT2_ADDR
  };

  // In production, fetch real nonce via Permit2.allowance(owner, token, spender).nonce
  // For POC, using nonce: 0 with fresh signatures each time
  const message = {
    details: {
      token,
      amount: amount.toString(),
      expiration: expirationSec,
      nonce: 0
    },
    spender,
    sigDeadline
  };

  const types = {
    PermitDetails,
    PermitSingle
  };

  try {
    // Sign the EIP-712 typed data
    const signature = await signer.signTypedData(
      domain,
      types,
      message
    );

    return {
      domain,
      types,
      message,
      signature
    };
  } catch (error) {
    console.error("Error signing Permit2:", error);
    throw error;
  }
}

/**
 * Format permit details for the Permit2 contract call
 * @param token - Token address
 * @param amount - Amount to permit
 * @param expiration - Expiration timestamp
 * @param nonce - Nonce value (usually 0 for new permits)
 */
export function formatPermitDetails(
  token: string,
  amount: bigint,
  expiration: number,
  nonce: number = 0
) {
  return {
    token,
    amount,
    expiration,
    nonce
  };
}

/**
 * Format transfer details for Permit2.transferFrom
 * @param from - Source address
 * @param to - Destination address
 * @param amount - Amount to transfer
 * @param token - Token address
 */
export function formatTransferDetails(
  from: string,
  to: string,
  amount: bigint,
  token: string
) {
  return {
    from,
    to,
    amount,
    token
  };
}