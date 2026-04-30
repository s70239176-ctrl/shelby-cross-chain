# =============================================================================
# Dockerfile — HotLink Cache  (Railway / BuildKit compatible)
#
# Why the previous version broke:
#   Splitting COPY into individual manifest files (COPY apps/web/package.json)
#   requires every source file to exist in the build context at that exact path.
#   Railway clones the GitHub repo as the build context. Any file not tracked
#   in git causes BuildKit's cache-key checksum to error with "not found".
#
# Fix: single COPY . . — copies the entire repo in one instruction.
#   Railway caches this layer by content hash. If nothing changed, the
#   pnpm install layer is reused. Simple, reliable, correct.
#
# Stages:
#   builder — install deps + compile sdk-integration + next build
#   runner  — Next.js standalone output only (~400 MB)
# =============================================================================

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

# Install pnpm via corepack — matches "packageManager": "pnpm@9.0.0" in package.json
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

# Copy entire repository in one instruction.
# .dockerignore excludes node_modules, .next, secrets, and other noise.
COPY . .

# Install all workspace dependencies
# No --frozen-lockfile: pnpm-lock.yaml may not exist on first deploy.
# Commit pnpm-lock.yaml after running `pnpm install` locally, then you
# can add --frozen-lockfile here for reproducible CI builds.
RUN pnpm install

# ── Build-time public env vars ────────────────────────────────────────────────
# NEXT_PUBLIC_* vars must be present at `next build` time — they are baked
# into the client JS bundle. Railway passes them as Docker build args
# (see railway.toml [build.args]).
# Secret vars (SHELBY_API_KEY, APTOS_PRIVATE_KEY) are NOT listed here.
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

ENV NEXT_TELEMETRY_DISABLED=1
# Prevents Next.js build from aborting when server-only secrets are absent
ENV SKIP_ENV_VALIDATION=1

# Build sdk-integration first (apps/web has a workspace:* dep on it)
RUN pnpm --filter @hotlink-cache/sdk-integration build

# Build Next.js app (output: standalone set in next.config.ts)
RUN pnpm --filter @hotlink-cache/web build

# ── Stage 2: minimal runtime ──────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Non-root user
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

# Copy only the standalone Next.js output — no node_modules needed at runtime
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static      ./apps/web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public            ./apps/web/public

USER nextjs

# Railway injects $PORT at runtime. Next.js standalone reads it automatically.
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

CMD ["node", "apps/web/server.js"]
