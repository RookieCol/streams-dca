"use client";

import { ChevronRight } from "lucide-react";
import { cn, pressFeedback } from "@/lib/utils";

const SIZE = 40;
const STROKE = 5;
const RADIUS = (SIZE - STROKE) / 2;
const CIRC = 2 * Math.PI * RADIUS;

export function StreamCycleCard({
  streamedUsd,
  budgetUsd,
  pct,
  label,
  onClick,
}: {
  streamedUsd: number;
  budgetUsd: number;
  pct: number;
  label: string;
  onClick?: () => void;
}) {
  const dash = (pct / 100) * CIRC;

  return (
    <button
      type="button"
      onClick={onClick}
      className={cn("flex w-full items-center justify-between border-t border-line py-4 text-left", pressFeedback)}
    >
      <div>
        <div className="flex items-center gap-1 text-[15px] font-medium text-ink">
          This month
          <ChevronRight className="h-4 w-4 text-ink-faint" />
        </div>
        <p className="mt-0.5 text-sm text-ink-muted">
          ${streamedUsd.toFixed(2)} of ${budgetUsd.toFixed(2)} invested
        </p>
      </div>
      <div className="flex items-center gap-3">
        <span className="rounded-full bg-flow-soft px-2.5 py-1 text-xs font-semibold text-flow">
          {label}
        </span>
        <svg width={SIZE} height={SIZE} viewBox={`0 0 ${SIZE} ${SIZE}`} className="-rotate-90 shrink-0">
          <circle cx={SIZE / 2} cy={SIZE / 2} r={RADIUS} fill="none" stroke="#F0F0F1" strokeWidth={STROKE} />
          <circle
            cx={SIZE / 2}
            cy={SIZE / 2}
            r={RADIUS}
            fill="none"
            stroke="#16A34A"
            strokeWidth={STROKE}
            strokeLinecap="round"
            strokeDasharray={`${dash} ${CIRC - dash}`}
          />
        </svg>
      </div>
    </button>
  );
}
