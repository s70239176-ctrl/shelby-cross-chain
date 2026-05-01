// lib/shelby.ts — Shelby + Aptos helpers
// Uses @aptos-labs/ts-sdk v5 API
import { Aptos, AptosConfig, Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";

const FULLNODE = process.env.APTOS_FULLNODE_URL ?? "https://api.shelbynet.shelby.xyz/v1";
const SHELBY_RPC = process.env.SHELBY_RPC_URL ?? "https://api.shelbynet.shelby.xyz/shelby";
const SHELBY_API_KEY = process.env.SHELBY_API_KEY ?? "";

export function getAptosAccount(): Account {
  const key = process.env.APTOS_PRIVATE_KEY ?? "";
  if (!key || key.includes("REPLACE")) throw new Error("APTOS_PRIVATE_KEY not configured");
  return Account.fromPrivateKey({ privateKey: new Ed25519PrivateKey(key) });
}

export function makeAptos() {
  // v5: AptosConfig accepts fullnode as a direct URL string
  return new Aptos(new AptosConfig({ fullnode: FULLNODE }));
}

export interface BlobMeta {
  blobId: string; blobName: string; owner: string; sizeBytes: number;
  expirationMicros: string; pricePerReadOctas: string;
  accessMode: string; totalReads: number; commitmentHash: string;
}

export async function getBlobMeta(blobId: string): Promise<BlobMeta> {
  const moduleAddr = process.env.HOTLINK_MODULE_ADDRESS ?? "";
  if (!moduleAddr) throw new Error("HOTLINK_MODULE_ADDRESS not set");
  const aptos = makeAptos();
  const [result] = await aptos.view({
    payload: {
      function: `${moduleAddr}::hotlink_metadata::get_blob_metadata` as `${string}::${string}::${string}`,
      typeArguments: [],
      functionArguments: [blobId],
    },
  });
  const d = result as Record<string, unknown>;
  return {
    blobId:            String(d.blob_id            ?? blobId),
    blobName:          String(d.blob_name          ?? ""),
    owner:             String(d.owner              ?? ""),
    sizeBytes:         Number(d.size_bytes         ?? 0),
    expirationMicros:  String(d.expiration_micros  ?? "0"),
    pricePerReadOctas: String(d.price_per_read_octas ?? "0"),
    accessMode:        String(d.access_mode        ?? "public"),
    totalReads:        Number(d.total_reads        ?? 0),
    commitmentHash:    String(d.commitment_hash    ?? ""),
  };
}

// Shelby SDK client — loaded at runtime only so a missing package
// doesn't crash the Next.js build.
export function getShelbyClient() {
  if (!SHELBY_API_KEY) throw new Error("SHELBY_API_KEY not configured");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { ShelbyNodeClient } = require("@shelby-protocol/sdk/node");
  return new ShelbyNodeClient({
    apiKey:     SHELBY_API_KEY,
    fullnode:   FULLNODE,
    shelbyUrl:  SHELBY_RPC,
  }) as {
    upload: (o: { blobData: Uint8Array; signer: Account; blobName: string; expirationMicros: number }) => Promise<{ blobId: string; transactionHash?: string; commitmentHash?: string }>;
    read:   (o: { blobId: string }) => Promise<Record<string, unknown>>;
  };
}
