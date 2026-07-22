"use client";

import { useState } from "react";
import { Infinity as InfinityIcon, ShieldAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
} from "@/components/ui/sheet";
import { streamCycle } from "@/lib/mock-data";
import { useRules, FREQUENCY_LABEL } from "./rules-context";
import { cn, pressFeedback } from "@/lib/utils";

const SIZE = 168;
const STROKE = 3;
const RADIUS = (SIZE - STROKE) / 2;

export function StreamTab() {
  const { flowRatePerDay, frequency, active, setActive, cancelled, setCancelled } = useRules();
  const [confirmOpen, setConfirmOpen] = useState(false);

  const badge = cancelled ? "Cancelled" : active ? "Active" : "Paused";

  return (
    <div className="flex flex-1 flex-col items-center px-6 pb-4 pt-8">
      <span
        className={cn(
          "rounded-full px-3 py-1 text-xs font-semibold",
          cancelled ? "bg-surface text-ink-muted" : active ? "bg-flow-soft text-flow" : "bg-loss/10 text-loss"
        )}
      >
        {badge}
      </span>

      <div className="relative mt-8 flex items-center justify-center">
        <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} className="-rotate-90">
          <circle cx={SIZE / 2} cy={SIZE / 2} r={RADIUS} fill="none" stroke="#F0F0F1" strokeWidth={STROKE} />
          {!cancelled && (
            <circle
              cx={SIZE / 2}
              cy={SIZE / 2}
              r={RADIUS}
              fill="none"
              stroke={active ? "#16A34A" : "#E5484D"}
              strokeWidth={STROKE}
              strokeLinecap="round"
              strokeDasharray="10 14"
              className="motion-safe:animate-[flow-dash_2.2s_linear_infinite] transition-[stroke] duration-300"
            />
          )}
        </svg>
        <div
          className={cn(
            "absolute flex h-24 w-24 items-center justify-center rounded-full text-white transition-colors",
            cancelled ? "bg-ink-faint" : "bg-ink"
          )}
        >
          <InfinityIcon className="h-9 w-9" strokeWidth={1.75} />
        </div>
      </div>

      <p className="font-display mt-6 text-3xl font-semibold tabular-nums text-ink">
        ${flowRatePerDay.toFixed(2)}
        <span className="text-lg font-medium text-ink-muted">/{FREQUENCY_LABEL[frequency]}</span>
      </p>
      <p className="mt-1 text-sm text-ink-muted">
        {cancelled ? "Not investing right now" : `$${streamCycle.streamedUsd.toFixed(2)} invested this month`}
      </p>

      <div className="mt-10 w-full space-y-3">
        {cancelled ? (
          <Button
            onClick={() => {
              setCancelled(false);
              setActive(true);
            }}
            className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
          >
            Restart Auto-Invest
          </Button>
        ) : (
          <>
            <Button
              onClick={() => setActive(!active)}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              {active ? "Pause" : "Resume"}
            </Button>
            <button
              type="button"
              onClick={() => setConfirmOpen(true)}
              className={cn(
                "flex w-full items-center justify-center gap-1.5 py-2 text-sm font-medium text-loss",
                pressFeedback
              )}
            >
              <ShieldAlert className="h-4 w-4" />
              Cancel Auto-Invest
            </button>
          </>
        )}
      </div>

      <Sheet open={confirmOpen} onOpenChange={setConfirmOpen}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader className="items-center text-center">
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-loss/10">
              <ShieldAlert className="h-6 w-6 text-loss" />
            </span>
            <SheetTitle>Cancel Auto-Invest?</SheetTitle>
            <SheetDescription>
              This stops your Auto-Invest completely — no more buys until you start a new one from Home.
            </SheetDescription>
          </SheetHeader>
          <SheetFooter className="mt-6">
            <Button
              onClick={() => setConfirmOpen(false)}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              Keep investing
            </Button>
            <button
              type="button"
              onClick={() => {
                setActive(false);
                setCancelled(true);
                setConfirmOpen(false);
              }}
              className={cn("py-2 text-sm font-medium text-loss", pressFeedback)}
            >
              Cancel Auto-Invest
            </button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </div>
  );
}
