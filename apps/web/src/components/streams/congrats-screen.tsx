"use client";

import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";

export function CongratsScreen({
  budget,
  flowRate,
  asset,
  onDone,
}: {
  budget: number;
  flowRate: number;
  asset: string;
  onDone: () => void;
}) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center px-6 text-center">
      <span className="flex h-16 w-16 items-center justify-center rounded-full bg-flow-soft">
        <CheckCircle2 className="h-9 w-9 text-flow" strokeWidth={1.75} />
      </span>

      <p className="font-display mt-6 text-2xl font-semibold text-ink">Congrats — you&rsquo;re streaming!</p>
      <p className="mt-2 text-[15px] text-ink-muted">
        ${budget.toFixed(2)} is now streaming into {asset} at ${flowRate.toFixed(2)}/day.
      </p>
      <p className="mt-4 rounded-full bg-surface px-3 py-1 text-xs font-medium text-ink-muted">
        Mock preview — no on-chain transaction was sent
      </p>

      <div className="mt-10 w-full">
        <Button
          onClick={onDone}
          className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
        >
          Done
        </Button>
      </div>
    </div>
  );
}
