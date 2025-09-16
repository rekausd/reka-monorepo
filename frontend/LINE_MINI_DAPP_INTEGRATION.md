# LINE Mini Dapp Integration Guide

This frontend has been fully integrated with LINE Mini Dapp SDK and LIFF. The integration replaces the standard KAIA wallet connector with the LINE Mini Dapp SDK wallet provider when running inside the LINE app.

## Integration Overview

### Key Components

1. **LIFF Client** (`lib/line/liffClient.ts`)
   - Initializes LIFF SDK
   - Manages LINE authentication
   - Must be initialized before Mini Dapp SDK

2. **Mini Dapp SDK** (`lib/line/dappSdk.ts`)
   - Provides EIP-1193 compatible wallet provider
   - Handles blockchain transactions through LINE wallet
   - Initialized as singleton after LIFF

3. **Unified Wallet Service** (`lib/wallet/unified-wallet.ts`)
   - Automatically detects environment (LINE Mini Dapp vs regular browser)
   - Switches between Mini Dapp SDK and standard KAIA wallet
   - Provides consistent interface for wallet operations

4. **Bootstrap Component** (`components/Bootstrap.tsx`)
   - Initializes LIFF and Mini Dapp SDK on app load
   - Ensures proper initialization sequence
   - Shows loading state during initialization

5. **LIFF Actions Bar** (`components/LiffActions.tsx`)
   - Floating action buttons for LINE-specific features
   - Share, minimize, and refresh functions
   - Only visible when running in LINE app

## Setup Instructions

### 1. Configure Environment Variables

Copy `.env.local.example` to `.env.local` and configure:

```bash
# Required for LINE Mini Dapp
NEXT_PUBLIC_LIFF_ID=your_liff_id_here
NEXT_PUBLIC_DAPP_CLIENT_ID=your_dapp_client_id_here
NEXT_PUBLIC_KAIA_CHAIN_ID=1001  # or 8217 for mainnet
```

### 2. LIFF App Configuration

In LINE Developers Console:

1. Create a LIFF app in your LINE channel
2. Configure LIFF settings:
   - **Module mode**: OFF (required for Action Button)
   - **LIFF Action Button**: ON
   - **Minimization**: ON
   - **Scopes**: openid, profile

### 3. Mini Dapp SDK Authorization

1. Contact Dapp Portal team for SDK access
2. Sign contract and Terms & Conditions
3. Receive clientId via email
4. **IMPORTANT**: Never expose clientSecret in frontend

## Key Features

### Wallet Connection Flow

1. **No Auto-Connect**: Wallet connection only triggers on user action (buy, claim, etc.)
2. **Environment Detection**: Automatically uses Mini Dapp SDK in LINE app, KAIA wallet in browser
3. **Error Handling**: Proper handling of wallet errors with user-friendly messages

### Supported Wallet Operations

- `kaia_requestAccounts`: Connect wallet
- `personal_sign`: Sign messages
- `kaia_sendTransaction`: Send transactions
- All standard EIP-1193 methods

### LIFF Actions

When running in LINE app, users can:
- **Share**: Share content to LINE chats
- **Minimize**: Minimize the Mini Dapp
- **Refresh**: Reload the app

## Testing

### Local Development

```bash
cd frontend
npm install
npm run dev
```

Access at `http://localhost:5173`

### Testing in LINE App

1. Deploy your app to a public URL
2. Update LIFF endpoint URL in LINE Developers Console
3. Open in LINE app: `https://liff.line.me/{YOUR_LIFF_ID}`

### Verification Checklist

- [ ] LIFF initializes successfully
- [ ] Mini Dapp SDK initializes after LIFF
- [ ] No auto-wallet connection on page load
- [ ] Wallet connects only on user action
- [ ] Transactions work through Mini Dapp SDK
- [ ] LIFF actions (share/minimize) work
- [ ] Unsupported browser guide shows when needed
- [ ] Error messages are user-friendly

## Error Handling

The integration handles these specific error codes:

- `-32001`: User cancelled/rejected
- `-32004`: Invalid from address
- `-32005`: Wrong password (triggers logout)
- `-32006`: Wallet not connected

On errors `-32004` to `-32006`, the wallet automatically disconnects and prompts reconnection.

## Security Notes

1. **Never expose clientSecret** in frontend code
2. **Server-side only**: Keep clientSecret on backend for payment operations
3. **Immediate rotation**: If clientSecret leaks, contact Dapp Portal team
4. **Environment variables**: Never commit actual values to version control

## Integration Architecture

```
User opens app in LINE
    ↓
Bootstrap.tsx initializes
    ↓
LIFF SDK initialized first
    ↓
Mini Dapp SDK initialized
    ↓
Wallet service detects LINE environment
    ↓
Uses Mini Dapp SDK wallet provider
    ↓
All wallet operations go through LINE
```

## Troubleshooting

### LIFF not initializing
- Check LIFF_ID is correct
- Verify LIFF app is properly configured
- Check console for error messages

### Mini Dapp SDK not working
- Ensure LIFF initialized first
- Verify clientId is correct
- Check browser compatibility

### Wallet connection issues
- Ensure not auto-connecting on load
- Check error handling for specific codes
- Verify chain ID configuration

## Support

For LINE-specific issues:
- LIFF documentation: https://developers.line.biz/en/docs/liff/
- Mini Dapp SDK: Contact Dapp Portal team

For app-specific issues:
- Check console logs for detailed error messages
- Verify environment variables are set correctly
- Test in actual LINE app, not just browser