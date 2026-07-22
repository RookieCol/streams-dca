"use client";

import { ArrowRight } from "lucide-react";
import { swapHistory } from "@/lib/mock-data";

export function ActivityTab() {
  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-6">
      <p className="font-display text-2xl font-semibold text-ink">Activity</p>
      <p className="mt-1 text-sm text-ink-muted">Every buy your Auto-Invest has made.</p>

      <div className="mt-6">
        {swapHistory.map((s) => (
          <div key={s.id} className="flex items-center justify-between border-t border-line py-4 last:border-b">
            <div className="flex items-center gap-3">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-surface">
                <ArrowRight className="h-4 w-4 text-flow" />
              </span>
              <div>
                <p className="text-[15px] font-medium text-ink">{s.pair}</p>
                <p className="text-sm text-ink-muted">{s.date}</p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-[15px] font-medium tabular-nums text-ink">${s.amountUsd.toFixed(2)}</p>
              <p className="text-sm capitalize text-gain">{s.status}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
