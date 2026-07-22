"use client";

import { useAccount, useDisconnect } from "wagmi";
import { LogOut, Wallet } from "lucide-react";
import { ConnectMiniPayButton } from "./connect-gate";

function short(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function ProfileTab() {
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();

  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-6">
      <p className="font-display text-2xl font-semibold text-ink">Profile</p>

      <div className="mt-6 flex items-center gap-3 border-y border-line py-4">
        <span className="flex h-10 w-10 items-center justify-center rounded-full bg-surface">
          <Wallet className="h-5 w-5 text-ink" />
        </span>
        <div>
          <p className="text-[15px] font-medium text-ink">
            {isConnected && address ? short(address) : "Not connected"}
          </p>
          <p className="text-sm text-ink-muted">Celo mainnet</p>
        </div>
      </div>

      {isConnected ? (
        <button
          type="button"
          onClick={() => disconnect()}
          className="mt-4 flex items-center gap-2 py-2 text-sm font-medium text-loss"
        >
          <LogOut className="h-4 w-4" />
          Disconnect
        </button>
      ) : (
        <div className="mt-4">
          <ConnectMiniPayButton label="Connect MiniPay" />
        </div>
      )}
    </div>
  );
}
