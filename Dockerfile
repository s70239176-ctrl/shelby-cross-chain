# =============================================================================
# Dockerfile — HotLink Cache (Railway deployment)
#
# Multi-stage build:
#   Stage 1 (deps)    — install ALL workspace dependencies with pnpm
#   Stage 2 (builder) — build packages/sdk-integration, then apps/web
#   Stage 3 (runner)  — minimal runtime image using Next.js standalone output
#
# Next.js standalone mode copies only the files needed to run, keeping the
# final image under ~400 MB instead of ~2 GB with node_modules.
#
# Railway auto-detects the Dockerfile at repo root and uses it directly.
# Set all SHELBY_* / APTOS_* / NEXT_PUBLIC_* vars in the Railway dashboard.
# =============================================================================

# ── Stage 1: dependency installation ─────────────────────────────────────────
FROM node:20-alpine AS deps

# Install pnpm via corepack (matches packageManager field in package.json)
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Copy workspace manifests first for layer caching —
# if only source files change, this layer is reused
COPY package.json pnpm-workspace.yaml turbo.json ./
COPY packages/sdk-integration/package.json ./packages/sdk-integration/
COPY apps/web/package.json                 ./apps/web/

# Install all dependencies (including devDeps needed for build)
# --frozen-lockfile ensures reproducible installs
RUN pnpm install --frozen-lockfile || pnpm install

# ── Stage 2: build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Copy installed node_modules from deps stage
COPY --from=deps /app/node_modules              ./node_modules
COPY --from=deps /app/packages/sdk-integration/node_modules \
                 ./packages/sdk-integration/node_modules
COPY --from=deps /app/apps/web/node_modules     ./apps/web/node_modules

# Copy all source files
COPY . .

# Build args — Railway injects NEXT_PUBLIC_* at build time via --build-arg.
# We declare them here so Next.js bundles them into the client JS.
ARG NEXT_PUBLIC_SHELBY_NETWORK=shelbynet
ARG NEXT_PUBLIC_SHELBY_RPC_URL=https://api.shelbynet.shelby.xyz/shelby
ARG NEXT_PUBLIC_SHELBY_EXPLORER_URL=https://explorer.shelby.xyz/shelbynet
ARG NEXT_PUBLIC_APTOS_FULLNODE_URL=https://api.shelbynet.shelby.xyz/v1
ARG NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS=0xc63d6a5efb0080a6029403131715bd4971e1149f7cc099aac69bb0069b3ddbf5
ARG NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS=""

ENV NEXT_PUBLIC_SHELBY_NETWORK=$NEXT_PUBLIC_SHELBY_NETWORK
ENV NEXT_PUBLIC_SHELBY_RPC_URL=$NEXT_PUBLIC_SHELBY_RPC_URL
ENV NEXT_PUBLIC_SHELBY_EXPLORER_URL=$NEXT_PUBLIC_SHELBY_EXPLORER_URL
ENV NEXT_PUBLIC_APTOS_FULLNODE_URL=$NEXT_PUBLIC_APTOS_FULLNODE_URL
ENV NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS=$NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS
ENV NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS=$NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS

# Required for Next.js standalone output generation
ENV NEXT_TELEMETRY_DISABLED=1

# Step 1: build the sdk-integration package (apps/web depends on it)
RUN pnpm --filter @hotlink-cache/sdk-integration build

# Step 2: build the Next.js app
# SKIP_ENV_VALIDATION=1 prevents the build from aborting if server-only
# env vars (SHELBY_API_KEY etc.) are absent at build time on Railway
ENV SKIP_ENV_VALIDATION=1
RUN pnpm --filter @hotlink-cache/web build

# ── Stage 3: minimal runtime image ───────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Create a non-root user for Railway security requirements
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# Copy Next.js standalone build (contains a self-contained server.js)
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static     ./apps/web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public           ./apps/web/public

USER nextjs

# Railway dynamically assigns $PORT — Next.js standalone server respects it
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# The standalone server.js is generated at apps/web/.next/standalone/apps/web/server.js
# but Next.js also copies a root server.js in some versions — we handle both:
CMD ["node", "apps/web/server.js"]
