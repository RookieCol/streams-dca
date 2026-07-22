"use client";

import { useState } from "react";
import { TrendingUp, PieChart } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { BalanceChart } from "./balance-chart";
import { AllocationDonut } from "./allocation-donut";
import { StreamCycleCard } from "./stream-cycle-card";
import {
  TIME_RANGES,
  TimeRange,
  balanceSeries,
  balanceUsd,
  balanceChangeToday,
  balanceChangePctToday,
  flowRatePerDay,
  allocation,
  streamCycle,
} from "@/lib/mock-data";

type View = "chart" | "allocation";

export function HomeTab({
  onOpenProjection,
  onOpenActivity,
  onAddToStream,
}: {
  onOpenProjection: () => void;
  onOpenActivity: () => void;
  onAddToStream: () => void;
}) {
  const [view, setView] = useState<View>("chart");
  const [range, setRange] = useState<TimeRange>("1M");
  const positive = balanceChangeToday >= 0;

  return (
    <div className="flex flex-1 flex-col px-5 pb-4">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[15px] font-medium text-ink-muted">Stream Vault</p>
          <p className="font-display text-4xl font-semibold tabular-nums text-ink">
            ${balanceUsd.toFixed(2)}
          </p>
          {view === "chart" ? (
            <div className="mt-1 flex items-center gap-1.5 text-sm font-medium">
              <span className={positive ? "text-gain" : "text-loss"}>
                {positive ? "▲" : "▼"} ${Math.abs(balanceChangeToday).toFixed(2)} (
                {Math.abs(balanceChangePctToday).toFixed(2)}%) Today
              </span>
            </div>
          ) : (
            <p className="mt-1 text-sm text-ink-muted">Allocation as of today</p>
          )}
          <p className="mt-0.5 flex items-center gap-1.5 text-sm font-medium text-flow">
            <span className="h-1.5 w-1.5 rounded-full bg-flow motion-safe:animate-pulse" />
            Streaming ${flowRatePerDay.toFixed(2)}/day
          </p>
        </div>

        <div className="flex shrink-0 items-center gap-0.5 rounded-full border border-line bg-surface p-1">
          <button
            type="button"
            onClick={() => setView("chart")}
            aria-label="Show value chart"
            className={cn(
              "flex h-7 w-7 items-center justify-center rounded-full transition-colors",
              view === "chart" ? "bg-ink text-white" : "text-ink-faint"
            )}
          >
            <TrendingUp className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={() => setView("allocation")}
            aria-label="Show allocation"
            className={cn(
              "flex h-7 w-7 items-center justify-center rounded-full transition-colors",
              view === "allocation" ? "bg-ink text-white" : "text-ink-faint"
            )}
          >
            <PieChart className="h-4 w-4" />
          </button>
        </div>
      </div>

      <div className="mt-6">
        {view === "chart" ? (
          <BalanceChart series={balanceSeries} positive={positive} />
        ) : (
          <AllocationDonut segments={allocation} />
        )}
      </div>

      {view === "chart" && (
        <div className="mt-3 flex items-center gap-1 overflow-x-auto">
          {TIME_RANGES.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRange(r)}
              className={cn(
                "rounded-full px-3 py-1.5 text-[13px] font-medium transition-colors",
                range === r ? "bg-surface text-ink" : "text-ink-muted"
              )}
            >
              {r}
            </button>
          ))}
          <button
            type="button"
            onClick={onOpenProjection}
            className="ml-1 shrink-0 rounded-full border border-flow/30 px-3 py-1.5 text-[13px] font-semibold text-flow"
          >
            FUTURE
          </button>
        </div>
      )}

      <button
        type="button"
        onClick={onOpenActivity}
        className="mt-5 flex items-center gap-1 text-[15px] font-medium text-ink"
      >
        View swap history
        <span aria-hidden>›</span>
      </button>

      <StreamCycleCard
        streamedUsd={streamCycle.streamedUsd}
        budgetUsd={streamCycle.budgetUsd}
        pct={streamCycle.pct}
        label={streamCycle.label}
        onClick={onOpenActivity}
      />

      <div className="mt-auto pt-6">
        <Button
          onClick={onAddToStream}
          className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
        >
          Add to stream
        </Button>
      </div>
    </div>
  );
}
