// Feature flags for optional integrations

// Enable Vercel Analytics/Speed Insights only when explicitly opted in.
// This avoids loading '/_vercel/insights/script.js' on non‑Vercel setups,
// which can return HTML and cause MIME errors.
export const ENABLE_VERCEL_INSIGHTS = (
  process.env.NEXT_PUBLIC_ENABLE_VERCEL_INSIGHTS === 'true'
);

