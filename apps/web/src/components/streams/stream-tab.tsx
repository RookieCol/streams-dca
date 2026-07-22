"use client";

import { useState } from "react";
import { Infinity as InfinityIcon, ShieldAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { flowRatePerDay, streamCycle } from "@/lib/mock-data";

const SIZE = 168;
const STROKE = 3;
const RADIUS = (SIZE - STROKE) / 2;
const CIRC = 2 * Math.PI * RADIUS;

export function StreamTab() {
  const [active, setActive] = useState(true);

  return (
    <div className="flex flex-1 flex-col items-center px-6 pb-4 pt-8">
      <span className="rounded-full bg-flow-soft px-3 py-1 text-xs font-semibold text-flow">
        {active ? "Stream active" : "Stream paused"}
      </span>

      <div className="relative mt-8 flex items-center justify-center">
        <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} className="-rotate-90">
          <circle cx={SIZE / 2} cy={SIZE / 2} r={RADIUS} fill="none" stroke="#F0F0F1" strokeWidth={STROKE} />
          {active && (
            <circle
              cx={SIZE / 2}
              cy={SIZE / 2}
              r={RADIUS}
              fill="none"
              stroke="#00C2A8"
              strokeWidth={STROKE}
              strokeLinecap="round"
              strokeDasharray="10 14"
              className="motion-safe:animate-[flow-dash_2.2s_linear_infinite]"
            />
          )}
        </svg>
        <div className="absolute flex h-24 w-24 items-center justify-center rounded-full bg-ink text-white">
          <InfinityIcon className="h-9 w-9" strokeWidth={1.75} />
        </div>
      </div>

      <p className="font-display mt-6 text-3xl font-semibold tabular-nums text-ink">
        ${flowRatePerDay.toFixed(2)}
        <span className="text-lg font-medium text-ink-muted">/day</span>
      </p>
      <p className="mt-1 text-sm text-ink-muted">
        ${streamCycle.streamedUsd.toFixed(2)} streamed this cycle
      </p>

      <div className="mt-10 w-full space-y-3">
        <Button
          onClick={() => setActive((a) => !a)}
          className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
        >
          {active ? "Pause stream" : "Resume stream"}
        </Button>
        <button
          type="button"
          className="flex w-full items-center justify-center gap-1.5 py-2 text-sm font-medium text-loss"
        >
          <ShieldAlert className="h-4 w-4" />
          Kill switch — revoke permissions
        </button>
      </div>
    </div>
  );
}
