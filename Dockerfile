# =============================================================================
# Dockerfile — HotLink Cache (flat repo, Railway)
# next.config.js and package.json are at repo root.
# `next build` runs from WORKDIR /app — same directory as next.config.js.
# No monorepo, no workspaces, no filter flags, no cd.
# =============================================================================

FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./
RUN npm install

COPY . .

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

RUN npm run build

# ── Runner ────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0

RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static     ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public           ./public

USER nextjs
EXPOSE 3000
CMD ["node", "server.js"]
