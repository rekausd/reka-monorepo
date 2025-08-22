# ReKaUSD Bridge (mock burn→mint)

NestJS service that bridges USDT between KAIA testnet and Ethereum testnet using a **burn event on source → mint on destination** pattern.  
**Polling:** 5s, with configurable confirmations per chain.  
**Persistence:** SQLite (`bridge-state.sqlite`) stores cursors and processed event ids.

## Run
```bash
cp .env.example .env   # fill RPCs, token addresses, and owner PKs
npm i
npm run dev
# GET http://localhost:3000/healthz
```

ENV

See .env.example.

Notes

This is not a trustless bridge. It's a dev mock.

Owner keys mint on the destination chain. Keep them secure.


## 1) After writing files
1. Run:
   - `npm i`
   - `npm run dev`
2. Open `GET http://localhost:3000/healthz` and ensure it returns block heights and cursors.
3. Confirm logs: on `BridgeBurn` events emitted by your token, the service mints on the opposite chain once and marks the event processed.

**Done.**
