"use client";

import { useAccount } from "wagmi";
import { useConnectModal } from "@rainbow-me/rainbowkit";
import { Wallet } from "lucide-react";
import { Button } from "@/components/ui/button";

/** True inside the MiniPay in-app browser, where the wallet auto-connects. */
export function useIsMiniPay() {
  if (typeof window === "undefined") return false;
  return Boolean((window as unknown as { ethereum?: { isMiniPay?: boolean } }).ethereum?.isMiniPay);
}

export function ConnectMiniPayButton({ label = "Connect wallet" }: { label?: string }) {
  const { openConnectModal } = useConnectModal();

  return (
    <Button
      onClick={openConnectModal}
      className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
    >
      <Wallet className="mr-2 h-4 w-4" />
      {label}
    </Button>
  );
}

/**
 * Renders children only when a wallet is connected; otherwise shows a
 * connect prompt. Use to gate any action that needs an address (e.g. the
 * settlement address on the Add-to-stream form).
 */
export function RequireWallet({ children }: { children: React.ReactNode }) {
  const { isConnected } = useAccount();
  const isMiniPay = useIsMiniPay();

  if (isConnected) return <>{children}</>;

  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-4 px-6 text-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-full bg-surface">
        <Wallet className="h-6 w-6 text-ink" />
      </span>
      {isMiniPay ? (
        <p className="text-[15px] font-semibold text-ink">Connecting to MiniPay…</p>
      ) : (
        <>
          <div>
            <p className="text-[15px] font-semibold text-ink">Connect your wallet</p>
            <p className="mt-1 text-sm text-ink-muted">
              Open this app inside MiniPay, or connect a wallet to start streaming.
            </p>
          </div>
          <div className="w-full max-w-[220px]">
            <ConnectMiniPayButton />
          </div>
        </>
      )}
    </div>
  );
}
