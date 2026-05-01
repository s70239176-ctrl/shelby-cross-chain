/** @type {import('next').NextConfig} */
const nextConfig = {
  // Generates .next/standalone for Docker/Railway deployment
  output: "standalone",

  transpilePackages: [
    "@shelby-protocol/sdk",
    "@shelby-protocol/solana-kit",
    "@hotlink-cache/sdk-integration",
  ],

  env: {
    NEXT_PUBLIC_SHELBY_NETWORK:
      process.env.NEXT_PUBLIC_SHELBY_NETWORK ?? "shelbynet",
    NEXT_PUBLIC_SHELBY_RPC_URL:
      process.env.NEXT_PUBLIC_SHELBY_RPC_URL ??
      "https://api.shelbynet.shelby.xyz/shelby",
    NEXT_PUBLIC_SHELBY_EXPLORER_URL:
      process.env.NEXT_PUBLIC_SHELBY_EXPLORER_URL ??
      "https://explorer.shelby.xyz/shelbynet",
    NEXT_PUBLIC_APTOS_FULLNODE_URL:
      process.env.NEXT_PUBLIC_APTOS_FULLNODE_URL ??
      "https://api.shelbynet.shelby.xyz/v1",
    NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS:
      process.env.NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS ?? "",
    NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS:
      process.env.NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS ??
      "0xc63d6a5efb0080a6029403131715bd4971e1149f7cc099aac69bb0069b3ddbf5",
  },

  experimental: {
    serverActions: {
      allowedOrigins: [
        "localhost:3000",
        process.env.RAILWAY_PUBLIC_DOMAIN,
      ].filter(Boolean),
    },
  },

  images: {
    remotePatterns: [
      { protocol: "https", hostname: "explorer.shelby.xyz" },
      { protocol: "https", hostname: "*.up.railway.app" },
    ],
  },

  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Content-Security-Policy",
            value: [
              "default-src 'self'",
              "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
              "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
              "font-src 'self' https://fonts.gstatic.com",
              "connect-src 'self' https://*.shelby.xyz https://*.aptoslabs.com https://api.devnet.solana.com wss://*.solana.com",
              "img-src 'self' data: blob: https://explorer.shelby.xyz",
              "frame-ancestors 'none'",
            ].join("; "),
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
