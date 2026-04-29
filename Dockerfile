# =============================================================================
# Dockerfile — HotLink Cache  (Railway-compatible, pnpm monorepo)
#
# Root cause of the previous error:
#   COPY apps/web/package.json ./apps/web/
#   BuildKit resolves the destination relative to WORKDIR.
#   The directory ./apps/web/ must already exist before COPY writes into it.
#   When COPY creates it implicitly, BuildKit's cache-key checksum diverges
#   from what the build daemon expects → "not found" cache key failure.
#
# Fix: use explicit `mkdir -p` before every directory-targeted COPY,
#   OR copy each manifest with an explicit filename destination.
#   We use the explicit filename form — it is the most portable.
#
# Multi-stage layout:
#   deps    — pnpm install with manifest-only context (cache-friendly)
#   builder — full source copy + tsup build + next build
#   runner  — Next.js standalone output only (~400 MB final image)
# =============================================================================

# ── Stage 1: install dependencies ────────────────────────────────────────────
FROM node:20-alpine AS deps

# corepack ships with Node 20 — activate pnpm 9 exactly
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# ── Copy manifests ONLY (for layer cache) ────────────────────────────────────
# Rule: each COPY destination that ends in / must be a directory that already
# exists, OR we must name the file explicitly.
# We name every file explicitly to avoid BuildKit cache-key divergence.

# Root workspace files
COPY package.json             ./package.json
COPY pnpm-workspace.yaml      ./pnpm-workspace.yaml
COPY turbo.json               ./turbo.json

# sdk-integration workspace — create dir first, then copy manifest
RUN mkdir -p packages/sdk-integration
COPY packages/sdk-integration/package.json ./packages/sdk-integration/package.json

# web app workspace — create dir first, then copy manifest
RUN mkdir -p apps/web
COPY apps/web/package.json ./apps/web/package.json

# Install all deps (dev + prod — both needed for the build stage)
# Do NOT use --frozen-lockfile: there is no lockfile in the repo yet.
# Once you run `pnpm install` locally and commit pnpm-lock.yaml,
# change this to: RUN pnpm install --frozen-lockfile
RUN pnpm install

# ── Stage 2: build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Bring in installed node_modules from deps stage
COPY --from=deps /app/node_modules                          ./node_modules
COPY --from=deps /app/packages/sdk-integration/node_modules ./packages/sdk-integration/node_modules
COPY --from=deps /app/apps/web/node_modules                 ./apps/web/node_modules

# Copy all source (node_modules excluded via .dockerignore)
COPY . .

# ── Build-time NEXT_PUBLIC_ env vars ─────────────────────────────────────────
# These are baked into the client JS bundle at build time.
# Railway passes them as Docker build args (configured in railway.toml).
# Secret vars (SHELBY_API_KEY, APTOS_PRIVATE_KEY) are NOT listed here —
# they are injected at runtime only.
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

# Suppress Next.js telemetry and skip env validation at build time.
# SKIP_ENV_VALIDATION stops getServerConfig() from throwing when
# SHELBY_API_KEY is absent during the Docker build (it's runtime-only).
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_ENV_VALIDATION=1

# ── Step 1: compile sdk-integration (apps/web imports it via workspace:*) ────
RUN pnpm --filter @hotlink-cache/sdk-integration build

# ── Step 2: build Next.js app (output: standalone configured in next.config.ts)
RUN pnpm --filter @hotlink-cache/web build

# ── Stage 3: minimal production runtime ──────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Non-root user (Railway best practice)
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# ── Copy ONLY the standalone output ─────────────────────────────────────────
# next build with output:'standalone' produces:
#   apps/web/.next/standalone/   ← self-contained server + minimal node_modules
#   apps/web/.next/static/       ← client-side JS/CSS chunks
#   apps/web/public/             ← static assets
#
# The standalone dir already contains its own node_modules subset —
# we do NOT copy the full workspace node_modules into the runner.

COPY --from=builder --chown=nextjs:nodejs \
     /app/apps/web/.next/standalone       ./

COPY --from=builder --chown=nextjs:nodejs \
     /app/apps/web/.next/static           ./apps/web/.next/static

# public/ may be empty if no static assets — the COPY is safe either way
COPY --from=builder --chown=nextjs:nodejs \
     /app/apps/web/public                 ./apps/web/public

USER nextjs

# Railway injects PORT dynamically (usually 8080 in production).
# Next.js standalone server reads process.env.PORT automatically.
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

# Next.js standalone places server.js at the root of the standalone dir.
# In a monorepo the path is: <standalone_root>/apps/web/server.js
CMD ["node", "apps/web/server.js"]
