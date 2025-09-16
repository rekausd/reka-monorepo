/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://static.line-scdn.net https://liff.line.me https://cdn.jsdelivr.net",
              "style-src 'self' 'unsafe-inline' https://static.line-scdn.net",
              "img-src 'self' data: blob: https: http:",
              "font-src 'self' data:",
              "connect-src 'self' https://api.line.me https://liff.line.me https://access.line.me https://*.line-scdn.net wss://*.line-apps.com https://*.line-apps.com https://kaikas.cypress.klaytn.net https://public-en.node.kaia.io https://public-en-kairos.node.kaia.io",
              "frame-src 'self' https://liff.line.me https://line.me",
              "media-src 'self'",
              "object-src 'none'",
              "base-uri 'self'",
              "form-action 'self'",
              "frame-ancestors 'self' https://liff.line.me https://line.me",
              "upgrade-insecure-requests"
            ].join('; ')
          },
          {
            key: 'X-Frame-Options',
            value: 'ALLOWALL' // Allow embedding in LINE app
          }
        ]
      }
    ]
  },
  // Allow images from LINE CDN
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**.line-scdn.net',
      },
      {
        protocol: 'https',
        hostname: 'profile.line-scdn.net',
      }
    ],
  },
}

module.exports = nextConfig