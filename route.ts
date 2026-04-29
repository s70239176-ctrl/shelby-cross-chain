// apps/web/app/api/health/route.ts
// Railway health check endpoint.
// Railway pings GET /api/health every 30s (configured in railway.toml).
// Must return 200 within healthcheckTimeout seconds or the service restarts.
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic"; // never cache this route

export async function GET() {
  const shelbyRpc = process.env.SHELBY_RPC_URL
    ?? "https://api.shelbynet.shelby.xyz/shelby";

  // Check that required secrets are present (don't expose values)
  const configStatus = {
    shelby_api_key:     Boolean(process.env.SHELBY_API_KEY),
    aptos_private_key:  Boolean(process.env.APTOS_PRIVATE_KEY),
    module_address:     Boolean(process.env.HOTLINK_MODULE_ADDRESS),
    shelby_rpc:         shelbyRpc,
    network:            process.env.SHELBY_NETWORK ?? "shelbynet",
  };

  // Probe the Shelby RPC — non-blocking, 3s timeout
  let shelbyReachable = false;
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 3_000);
    const res   = await fetch(`${shelbyRpc}/health`, { signal: ctrl.signal });
    clearTimeout(timer);
    shelbyReachable = res.ok;
  } catch {
    // Shelby may be temporarily down — don't fail the health check for this
    // (Railway would restart the container, which won't fix an upstream issue)
    shelbyReachable = false;
  }

  return NextResponse.json(
    {
      status:  "ok",
      version: process.env.RAILWAY_GIT_COMMIT_SHA?.slice(0, 7) ?? "local",
      uptime:  Math.floor(process.uptime()),
      config:  configStatus,
      shelby:  { reachable: shelbyReachable, rpc: shelbyRpc },
      ts:      new Date().toISOString(),
    },
    { status: 200 },
  );
}
