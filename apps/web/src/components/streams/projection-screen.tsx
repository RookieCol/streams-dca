"use client";

import { useMemo, useState } from "react";
import { ChevronLeft, Info } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  projectionBand,
  projectionHighlightYear,
  currentValueUsd,
} from "@/lib/mock-data";

const WIDTH = 320;
const HEIGHT = 160;
const PAD_L = 8;
const PAD_R = 8;
const PAD_T = 8;
const PAD_B = 20;
const TOPUP_STEPS = [0, 50, 100, 200, 300, 500];

export function ProjectionScreen({ onBack }: { onBack: () => void }) {
  const [topUpIdx, setTopUpIdx] = useState(0);
  const topUp = TOPUP_STEPS[topUpIdx];
  const scale = 1 + topUp / 1400;

  const scaled = useMemo(
    () => projectionBand.map((b) => ({ ...b, low: b.low * scale, high: b.high * scale, likely: b.likely * scale })),
    [scale]
  );

  const maxVal = Math.max(...scaled.map((b) => b.high)) * 1.05;
  const chartW = WIDTH - PAD_L - PAD_R;
  const chartH = HEIGHT - PAD_T - PAD_B;
  const barSlot = chartW / scaled.length;
  const barW = barSlot * 0.5;

  const yFor = (v: number) => PAD_T + chartH - (v / maxVal) * chartH;

  const likelyPath = scaled
    .map((b, i) => {
      const x = PAD_L + i * barSlot + barSlot / 2;
      const y = yFor(b.likely);
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const highlight = scaled.find((b) => b.year === projectionHighlightYear) ?? scaled[scaled.length - 1];
  const projectedValue = highlight.likely;
  const lowRange = Math.min(...scaled.map((b) => b.low));
  const highRange = Math.max(...scaled.map((b) => b.high));

  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-5">
      <button type="button" onClick={onBack} aria-label="Back" className="mb-4 w-fit">
        <ChevronLeft className="h-6 w-6 text-ink" />
      </button>

      <div className="flex items-center gap-1.5 text-[15px] font-medium text-ink-muted">
        Future projection
        <Info className="h-3.5 w-3.5" />
      </div>
      <p className="font-display mt-1 text-4xl font-semibold tabular-nums text-ink">
        ${projectedValue.toFixed(2)}
      </p>
      <p className="mt-1 text-sm text-ink-muted">
        Most likely stream value in <span className="font-medium text-ink">{projectionHighlightYear} years</span>
      </p>

      <div className="mt-4 flex items-center gap-4 text-xs text-ink-muted">
        <span className="flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-sm bg-flow-soft" /> Projection range
        </span>
        <span className="flex items-center gap-1.5">
          <span className="h-0.5 w-3 rounded-full bg-ink-faint" /> Current stream value
        </span>
      </div>

      <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} className="mt-4 h-40 w-full" preserveAspectRatio="none">
        {scaled.map((b, i) => {
          const x = PAD_L + i * barSlot + (barSlot - barW) / 2;
          const yHigh = yFor(b.high);
          const yLow = yFor(b.low);
          const isHighlight = b.year === projectionHighlightYear;
          return (
            <rect
              key={b.year}
              x={x}
              y={yHigh}
              width={barW}
              height={Math.max(yLow - yHigh, 2)}
              rx={3}
              fill={isHighlight ? "#00C2A8" : "#F0F0F1"}
              opacity={isHighlight ? 0.35 : 1}
            />
          );
        })}
        <line
          x1={PAD_L}
          y1={yFor(currentValueUsd)}
          x2={WIDTH - PAD_R}
          y2={yFor(currentValueUsd)}
          stroke="#C7CAD1"
          strokeWidth={1}
          strokeDasharray="3 3"
        />
        <path d={likelyPath} fill="none" stroke="#0B0C0E" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
        {scaled.map((b, i) => {
          if (b.year !== projectionHighlightYear) return null;
          const x = PAD_L + i * barSlot + barSlot / 2;
          return <circle key={b.year} cx={x} cy={yFor(b.likely)} r={4} fill="#00C2A8" />;
        })}
      </svg>

      <div className="flex justify-between text-[11px] text-ink-faint">
        <span>1Y</span>
        <span>{scaled.length}Y</span>
      </div>

      <p className="mt-1 text-[11px] text-ink-faint">
        Range ${lowRange.toFixed(0)} – ${highRange.toFixed(0)}
      </p>

      <div className="mt-8">
        <p className="text-sm font-medium text-ink">Simulate one-time top-up</p>
        <div className="relative mt-6">
          <div
            className="absolute -top-8 -translate-x-1/2 rounded-lg bg-ink px-2 py-1 text-xs font-semibold text-white"
            style={{ left: `${(topUpIdx / (TOPUP_STEPS.length - 1)) * 100}%` }}
          >
            ${topUp}
          </div>
          <input
            type="range"
            min={0}
            max={TOPUP_STEPS.length - 1}
            step={1}
            value={topUpIdx}
            onChange={(e) => setTopUpIdx(Number(e.target.value))}
            className="w-full accent-ink"
            aria-label="Simulate one-time top-up amount"
          />
        </div>
      </div>

      <div className="mt-auto pt-6">
        <Button className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90">
          Add funds
        </Button>
      </div>
    </div>
  );
}
