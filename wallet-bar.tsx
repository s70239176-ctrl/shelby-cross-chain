"use client";
import { useState } from "react";

// Simple wallet address input — no wallet adapter deps.
// Users paste their Aptos/Solana address directly.
export function WalletBar() {
  const [addr, setAddr] = useState("");
  const [saved, setSaved] = useState(false);

  const save = () => {
    if (addr.trim()) {
      sessionStorage.setItem("wallet_address", addr.trim());
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    }
  };

  return (
    <div style={{ display: "flex", gap: "0.4rem", alignItems: "center" }}>
      <input
        className="input"
        style={{ width: 220, fontSize: 11 }}
        placeholder="Paste your Aptos/Solana address…"
        value={addr}
        onChange={(e) => setAddr(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && save()}
      />
      <button className="btn-ghost" onClick={save}>
        {saved ? "✓ Saved" : "Connect"}
      </button>
    </div>
  );
}
