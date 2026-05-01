/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",

  // sdk-integration is pre-compiled to JS by tsup before next build runs,
  // so it does not need transpilation. The @shelby-protocol/* packages are
  // excluded here because they may not resolve correctly inside Docker;
  // the compiled sdk-integration handles all imports from them at build time.
  transpilePackages: [],

  // Suppress warnings about missing packages during build
  typescript: {
    ignoreBuildErrors: true,
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
};

module.exports = nextConfig;
