"use client";

import { useState } from "react";
import { TrendingUp, PieChart, ArrowRight } from "lucide-react";
import { cn, pressFeedback } from "@/lib/utils";
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
  allocation,
  streamCycle,
  swapHistory,
} from "@/lib/mock-data";
import { useRules, FREQUENCY_LABEL } from "./rules-context";

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
  const { flowRatePerDay, frequency, active, cancelled } = useRules();

  return (
    <div className="flex flex-1 flex-col px-5 pb-4">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-[15px] font-medium text-ink-muted">Balance</p>
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
            <p className="mt-1 text-sm text-ink-muted">Where it's going</p>
          )}
          {cancelled ? (
            <p className="mt-0.5 text-sm font-medium text-ink-muted">Not investing right now</p>
          ) : (
            <p className={cn("mt-0.5 flex items-center gap-1.5 text-sm font-medium", active ? "text-flow" : "text-loss")}>
              <span
                className={cn("h-1.5 w-1.5 rounded-full", active ? "bg-flow motion-safe:animate-pulse" : "bg-loss")}
              />
              {active ? "Investing" : "Paused"} ${flowRatePerDay.toFixed(2)}/{FREQUENCY_LABEL[frequency]}
            </p>
          )}
        </div>

        <div className="flex shrink-0 items-center gap-0.5 rounded-full border border-line bg-surface p-1">
          <button
            type="button"
            onClick={() => setView("chart")}
            aria-label="Show value chart"
            className={cn(
              "flex h-7 w-7 items-center justify-center rounded-full transition-colors",
              pressFeedback,
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
              pressFeedback,
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
                pressFeedback,
                range === r ? "bg-surface text-ink" : "text-ink-muted"
              )}
            >
              {r}
            </button>
          ))}
          <button
            type="button"
            onClick={onOpenProjection}
            className={cn(
              "ml-1 shrink-0 rounded-full border border-flow/30 px-3 py-1.5 text-[13px] font-semibold text-flow",
              pressFeedback
            )}
          >
            FUTURE
          </button>
        </div>
      )}

      <button
        type="button"
        onClick={onOpenActivity}
        className={cn("mt-5 flex items-center gap-1 text-[15px] font-medium text-ink", pressFeedback)}
      >
        See your buys
        <span aria-hidden>›</span>
      </button>

      <StreamCycleCard
        streamedUsd={streamCycle.streamedUsd}
        budgetUsd={streamCycle.budgetUsd}
        pct={streamCycle.pct}
        label={streamCycle.label}
        onClick={onOpenActivity}
      />

      <div>
        {swapHistory.slice(0, 3).map((s) => (
          <button
            key={s.id}
            type="button"
            onClick={onOpenActivity}
            className={cn("flex w-full items-center justify-between border-b border-line py-3 text-left", pressFeedback)}
          >
            <div className="flex items-center gap-3">
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-surface">
                <ArrowRight className="h-3.5 w-3.5 text-flow" />
              </span>
              <div>
                <p className="text-sm font-medium text-ink">{s.pair}</p>
                <p className="text-xs text-ink-muted">{s.date}</p>
              </div>
            </div>
            <p className="text-sm font-medium tabular-nums text-ink">${s.amountUsd.toFixed(2)}</p>
          </button>
        ))}
      </div>

      <div className="sticky bottom-0 mt-auto -mx-5 bg-white px-5 pb-2 pt-4">
        <Button
          onClick={onAddToStream}
          className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
        >
          Add money
        </Button>
      </div>
    </div>
  );
}
