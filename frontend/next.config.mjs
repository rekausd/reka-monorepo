/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: { optimizePackageImports: ["recharts"] },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://static.line-scdn.net https://liff.line.me",
              "style-src 'self' 'unsafe-inline'",
              "img-src 'self' data: https:",
              "font-src 'self' data:",
              "connect-src 'self' https://api.line.me https://liff.line.me https://public-en-kairos.node.kaia.io https://public-en.node.kaia.io wss://public-en.node.kaia.io",
              "frame-src https://liff.line.me",
              "object-src 'none'",
              "base-uri 'self'",
            ].join("; ")
          },
          {
            key: "X-Frame-Options",
            value: "ALLOWALL" // Required for Mini Dapp iframe
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff"
          }
        ]
      }
    ];
  }
};
export default nextConfig;