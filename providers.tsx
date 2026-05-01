"use client";
// Minimal providers wrapper — no wallet adapter dependencies.
// Wallet connect is handled via manual address input in wallet-bar.tsx.
export function Providers({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
