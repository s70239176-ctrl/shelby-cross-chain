import type { NextConfig } from "next";

// Derive the public deployment URL from Railway's injected env var.
const deploymentUrl = process.env.RAILWAY_PUBLIC_DOMAIN
  ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`
  : process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:3000";

const nextConfig: NextConfig = {
  // ── REQUIRED for Railway Docker deployment ────────────────────────────────
  // Generates .next/standalone — a self-contained server.js + minimal deps.
  // Without this, the runner stage has no server to start.
  output: "standalone",

  // ── Monorepo workspace package transpilation ──────────────────────────────
  transpilePackages: [
    "@shelby-protocol/sdk",
    "@shelby-protocol/solana-kit",
    "@hotlink-cache/sdk-integration",
  ],

  // ── Public env vars (baked into client JS at build time) ─────────────────
  env: {
    NEXT_PUBLIC_SHELBY_NETWORK:
      process.env.NEXT_PUBLIC_SHELBY_NETWORK          ?? "shelbynet",
    NEXT_PUBLIC_SHELBY_RPC_URL:
      process.env.NEXT_PUBLIC_SHELBY_RPC_URL          ?? "https://api.shelbynet.shelby.xyz/shelby",
    NEXT_PUBLIC_SHELBY_EXPLORER_URL:
      process.env.NEXT_PUBLIC_SHELBY_EXPLORER_URL     ?? "https://explorer.shelby.xyz/shelbynet",
    NEXT_PUBLIC_APTOS_FULLNODE_URL:
      process.env.NEXT_PUBLIC_APTOS_FULLNODE_URL      ?? "https://api.shelbynet.shelby.xyz/v1",
    NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS:
      process.env.NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS  ?? "",
    NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS:
      process.env.NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS ??
      "0xc63d6a5efb0080a6029403131715bd4971e1149f7cc099aac69bb0069b3ddbf5",
    NEXT_PUBLIC_APP_URL: deploymentUrl,
  },

  // ── Server actions: allow Railway domain + localhost ──────────────────────
  experimental: {
    serverActions: {
      allowedOrigins: [
        "localhost:3000",
        ...(process.env.RAILWAY_PUBLIC_DOMAIN
          ? [process.env.RAILWAY_PUBLIC_DOMAIN]
          : []),
        ...(process.env.NEXT_PUBLIC_APP_URL
          ? [process.env.NEXT_PUBLIC_APP_URL.replace(/^https?:\/\//, "")]
          : []),
      ],
    },
  },

  // ── Image domains ─────────────────────────────────────────────────────────
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "explorer.shelby.xyz" },
      { protocol: "https", hostname: "*.up.railway.app" },
    ],
  },

  // ── Security headers ──────────────────────────────────────────────────────
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options",  value: "nosniff" },
          { key: "X-Frame-Options",          value: "DENY" },
          { key: "X-XSS-Protection",         value: "1; mode=block" },
          { key: "Referrer-Policy",           value: "strict-origin-when-cross-origin" },
          {
            key:   "Content-Security-Policy",
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

export default nextConfig;
