// lib/shelby.ts — Shelby SDK helpers (inlined, no workspace dependency)
import { Aptos, AptosConfig, Network, Account, Ed25519PrivateKey } from "@aptos-labs/ts-sdk";

export function getAptosAccount(): Account {
  const key = process.env.APTOS_PRIVATE_KEY ?? "";
  if (!key || key.includes("REPLACE")) throw new Error("APTOS_PRIVATE_KEY not configured");
  return Account.fromPrivateKey({ privateKey: new Ed25519PrivateKey(key) });
}

export function makeAptos() {
  return new Aptos(new AptosConfig({
    network:  Network.CUSTOM,
    fullnode: process.env.APTOS_FULLNODE_URL ?? "https://api.shelbynet.shelby.xyz/v1",
  }));
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
      function: `${moduleAddr}::hotlink_metadata::get_blob_metadata`,
      typeArguments: [], functionArguments: [blobId],
    },
  });
  const d = result as Record<string, unknown>;
  return {
    blobId:            String(d.blob_id   ?? blobId),
    blobName:          String(d.blob_name ?? ""),
    owner:             String(d.owner     ?? ""),
    sizeBytes:         Number(d.size_bytes ?? 0),
    expirationMicros:  String(d.expiration_micros  ?? "0"),
    pricePerReadOctas: String(d.price_per_read_octas ?? "0"),
    accessMode:        String(d.access_mode ?? "public"),
    totalReads:        Number(d.total_reads ?? 0),
    commitmentHash:    String(d.commitment_hash ?? ""),
  };
}

export interface ShelbyClient {
  upload: (opts: { blobData: Uint8Array; signer: Account; blobName: string; expirationMicros: number }) => Promise<{ blobId: string; transactionHash?: string; commitmentHash?: string }>;
  read:   (opts: { blobId: string }) => Promise<{ data?: Uint8Array; blobData?: Uint8Array; proof?: Record<string,unknown> }>;
}

export function getShelbyClient(): ShelbyClient {
  // Dynamically require the Shelby SDK so missing packages don't crash the module
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { ShelbyNodeClient } = require("@shelby-protocol/sdk/node");
  return new ShelbyNodeClient({
    network: Network.CUSTOM,
    apiKey:  process.env.SHELBY_API_KEY ?? "",
    fullnodeUrl: process.env.APTOS_FULLNODE_URL ?? "https://api.shelbynet.shelby.xyz/v1",
    shelbyUrl:   process.env.SHELBY_RPC_URL    ?? "https://api.shelbynet.shelby.xyz/shelby",
  });
}
