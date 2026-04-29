# HotLink Cache — Railway Deployment Guide

Deploy the full HotLink Cache stack to Railway as a public web service in
under 10 minutes.

---

## How it works

```
GitHub repo push
       ↓
Railway detects Dockerfile at repo root
       ↓
Stage 1: pnpm install (monorepo workspace)
Stage 2: build sdk-integration → build apps/web (Next.js standalone)
Stage 3: 400 MB runtime image, node apps/web/server.js
       ↓
Railway assigns public URL: https://hotlink-cache-xxx.up.railway.app
```

The health check endpoint (`GET /api/health`) is polled every 30 seconds.
Railway restarts the service automatically on failure.

---

## Step 1 — Push to GitHub

```bash
git init
git add .
git commit -m "HotLink Cache v0.1.0"
gh repo create hotlink-cache --public --source=. --push
# or: git remote add origin git@github.com:YOU/hotlink-cache.git && git push -u origin main
```

---

## Step 2 — Create Railway project

1. Go to https://railway.app → **New Project**
2. Choose **Deploy from GitHub repo**
3. Select your `hotlink-cache` repository
4. Railway detects the `Dockerfile` and `railway.toml` automatically
5. Click **Deploy** — the first build starts immediately (takes ~3–5 min)

---

## Step 3 — Set environment variables

In the Railway dashboard → your service → **Variables** tab, add:

### Required (service won't function without these)

| Variable | Value | Notes |
|----------|-------|-------|
| `SHELBY_API_KEY` | `AG-xxxxxxxxxxxx` | From https://developers.aptoslabs.com/ |
| `APTOS_PRIVATE_KEY` | `ed25519-priv-0x…` | Run `shelby account create` locally first |
| `APTOS_ACCOUNT_ADDRESS` | `0x…` | Derived from your private key |
| `HOTLINK_MODULE_ADDRESS` | `0x…` | After running `pnpm run deploy:move` locally |

### Network (defaults work for shelbynet)

| Variable | Default value |
|----------|--------------|
| `SHELBY_NETWORK` | `shelbynet` |
| `SHELBY_RPC_URL` | `https://api.shelbynet.shelby.xyz/shelby` |
| `APTOS_FULLNODE_URL` | `https://api.shelbynet.shelby.xyz/v1` |
| `APTOS_INDEXER_URL` | `https://api.shelbynet.shelby.xyz/v1/graphql` |
| `SHELBY_CONTRACT_ADDRESS` | `0xc63d6a5efb…ddbf5` |
| `SHELBY_FAUCET_URL` | `https://faucet.shelbynet.shelby.xyz` |

### Public vars (baked into client JS at build time — set as build args too)

| Variable | Default value |
|----------|--------------|
| `NEXT_PUBLIC_SHELBY_NETWORK` | `shelbynet` |
| `NEXT_PUBLIC_SHELBY_RPC_URL` | `https://api.shelbynet.shelby.xyz/shelby` |
| `NEXT_PUBLIC_APTOS_FULLNODE_URL` | `https://api.shelbynet.shelby.xyz/v1` |
| `NEXT_PUBLIC_SHELBY_EXPLORER_URL` | `https://explorer.shelby.xyz/shelbynet` |
| `NEXT_PUBLIC_SHELBY_CONTRACT_ADDRESS` | `0xc63d6a5efb…ddbf5` |
| `NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS` | `0x…` (same as HOTLINK_MODULE_ADDRESS) |

### Optional

| Variable | Purpose |
|----------|---------|
| `SOLANA_RPC_URL` | Solana devnet RPC (defaults to public endpoint) |
| `HOTLINK_APP_DOMAIN` | Domain for Solana storage account scoping |
| `NEXT_PUBLIC_APP_URL` | Your custom domain (e.g. `https://hotlink.yourdomain.com`) |

---

## Step 4 — Trigger a redeploy

After setting variables in Railway:

1. Go to **Deployments** tab
2. Click **Redeploy** on the latest deployment
3. Or push a new commit — Railway auto-deploys on every push to `main`

---

## Step 5 — Add a custom domain (optional)

1. Railway dashboard → your service → **Settings** → **Domains**
2. Click **Add Custom Domain**
3. Enter your domain (e.g. `hotlink.yourdomain.com`)
4. Add the CNAME record Railway shows to your DNS provider
5. Railway provisions a TLS certificate automatically (Let's Encrypt)
6. Update `NEXT_PUBLIC_APP_URL` to `https://hotlink.yourdomain.com`
7. Redeploy

---

## Step 6 — Verify deployment

```bash
# Health check
curl https://YOUR-APP.up.railway.app/api/health | jq .

# Expected:
# {
#   "status": "ok",
#   "version": "abc1234",
#   "uptime": 42,
#   "config": {
#     "shelby_api_key": true,
#     "aptos_private_key": true,
#     "module_address": true,
#     ...
#   },
#   "shelby": { "reachable": true, "rpc": "https://api.shelbynet.shelby.xyz/shelby" }
# }

# Test upload API
curl -X POST https://YOUR-APP.up.railway.app/api/blobs \
  -F "file=@/tmp/test.json" \
  -F "blobName=test/health-check.json" \
  -F "ttlSeconds=3600" \
  -F "pricePerReadOctas=0" \
  -F "accessMode=public"

# Analytics
curl https://YOUR-APP.up.railway.app/api/analytics | jq .stats
```

---

## Redeployment after shelbynet resets

shelbynet wipes ~weekly. After a reset:

1. Re-run locally: `pnpm run setup:shelby && pnpm run deploy:move && pnpm run fund`
2. Update Railway vars: `HOTLINK_MODULE_ADDRESS` and `NEXT_PUBLIC_HOTLINK_MODULE_ADDRESS`
3. Redeploy on Railway

Automate this with a Railway cron job or GitHub Action.

---

## Railway pricing

HotLink Cache runs comfortably on Railway's **Hobby plan** ($5/mo):
- Starter: 512 MB RAM, 0.5 vCPU — sufficient for shelbynet loads
- Pro: 8 GB RAM, 8 vCPU — recommended for production traffic

The Docker image is ~400 MB (Next.js standalone). Build time: ~3–5 min.

---

## Troubleshooting

### Build fails: `pnpm install` errors
Railway may not have pnpm available in the build environment.
The Dockerfile uses `corepack enable && corepack prepare pnpm@9.0.0 --activate`
which is the correct approach. If this still fails, add to railway.toml:
```toml
[build]
buildCommand = "npm install -g pnpm@9 && pnpm install && pnpm build"
```

### Health check fails immediately
The container starts but `/api/health` returns non-200.  
Check: **Deployments → Logs** in Railway. Common causes:
- `APTOS_PRIVATE_KEY` missing or still contains "REPLACE"
- Port mismatch — Railway injects `PORT` dynamically; the Dockerfile uses `ENV PORT=3000`
  which Next.js standalone respects. If using a custom CMD, ensure `--port $PORT`.

### `HOTLINK_MODULE_ADDRESS not set` in logs
You haven't run `deploy:move` yet. The app still works for public blob reads
(which don't need the module), but upload and analytics require it.

### `Module not found: @hotlink-cache/sdk-integration`
The workspace symlink isn't resolving in the Docker build.
Ensure `pnpm-workspace.yaml` is copied before `pnpm install` in the Dockerfile
(it is — check the COPY order in Stage 1).

### Next.js build error: `SHELBY_API_KEY not set`
The API key is a server-only secret — it must NOT be present at build time
(it would be baked into the client JS). The Dockerfile sets `SKIP_ENV_VALIDATION=1`
to suppress this. If you see this error, ensure your build does not call
`getServerConfig()` at module-import time (only inside route handlers).
