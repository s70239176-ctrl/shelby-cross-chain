# =============================================================================
# Dockerfile — HotLink Cache  (Railway / BuildKit compatible)
# =============================================================================

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

WORKDIR /app

COPY . .

RUN pnpm install

ARG NEXT_PUBLIC_SHELBY_NETWORK=shelbynet
ARG NEXT_PUBLIC_SHELBY_RPC_URL=https://api.shelbynet.shelby.xyz/shelby
ARG NEXT_PUBLIC_SHELBY_EXPLORER_URL=https://explorer.shelby.xyz/shelbynet
ARG NEXT_PUBLIC_APTOS_FULLNODE_URL=https://api.shelbynet.shelby.xyz/v1
ARG NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS=0xc63d6a5efb0080a6029403131715bd4971e1149f7cc099aac69bb0069b3ddbf5
ARG NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS=""

ENV NEXT_PUBLIC_SHELBY_NETWORK=$NEXT_PUBLIC_SHELBY_NETWORK \
    NEXT_PUBLIC_SHELBY_RPC_URL=$NEXT_PUBLIC_SHELBY_RPC_URL \
    NEXT_PUBLIC_SHELBY_EXPLORER_URL=$NEXT_PUBLIC_SHELBY_EXPLORER_URL \
    NEXT_PUBLIC_APTOS_FULLNODE_URL=$NEXT_PUBLIC_APTOS_FULLNODE_URL \
    NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS=$NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS \
    NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS=$NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS \
    NEXT_TELEMETRY_DISABLED=1 \
    SKIP_ENV_VALIDATION=1

RUN pnpm --filter @hotlink-cache/sdk-integration build

RUN pnpm --filter @hotlink-cache/web build

# Guarantee the directories the runner stage copies from always exist,
# even if Next.js didn't generate them (e.g. empty public/, missing static/).
RUN mkdir -p apps/web/.next/static apps/web/public

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static      ./apps/web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public            ./apps/web/public

USER nextjs

EXPOSE 3000

CMD ["node", "apps/web/server.js"]
