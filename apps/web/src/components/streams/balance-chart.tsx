"use client";

import { useMemo, useRef, useState } from "react";

const WIDTH = 320;
const HEIGHT = 128;
const PAD = 6;

function buildPath(series: number[]) {
  const min = Math.min(...series);
  const max = Math.max(...series);
  const range = max - min || 1;
  const stepX = (WIDTH - PAD * 2) / (series.length - 1);

  const points = series.map((v, i) => {
    const x = PAD + i * stepX;
    const y = PAD + (1 - (v - min) / range) * (HEIGHT - PAD * 2);
    return [x, y] as const;
  });

  const line = points.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x.toFixed(2)},${y.toFixed(2)}`).join(" ");
  const area = `${line} L${points[points.length - 1][0].toFixed(2)},${HEIGHT} L${points[0][0].toFixed(2)},${HEIGHT} Z`;

  return { line, area, points };
}

function dayLabel(daysAgo: number) {
  if (daysAgo === 0) return "Today";
  if (daysAgo === 1) return "Yesterday";
  return `${daysAgo} days ago`;
}

export function BalanceChart({ series, positive }: { series: number[]; positive: boolean }) {
  const { line, area, points } = useMemo(() => buildPath(series), [series]);
  const strokeColor = positive ? "#16A34A" : "#E5484D";
  const last = points[points.length - 1];

  const containerRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState<number | null>(null);

  function updateFromClientX(clientX: number) {
    const el = containerRef.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const ratio = (clientX - rect.left) / rect.width;
    const idx = Math.round(ratio * (series.length - 1));
    setActiveIndex(Math.min(series.length - 1, Math.max(0, idx)));
  }

  const shown = activeIndex ?? points.length - 1;
  const shownPoint = points[shown];
  const leftPct = (shown / (points.length - 1)) * 100;

  return (
    <div
      ref={containerRef}
      className="relative touch-none select-none"
      onPointerMove={(e) => updateFromClientX(e.clientX)}
      onPointerDown={(e) => updateFromClientX(e.clientX)}
      onPointerLeave={() => setActiveIndex(null)}
      onPointerUp={() => setActiveIndex(null)}
    >
      {activeIndex !== null && (
        <div
          className="pointer-events-none absolute -top-9 z-10 -translate-x-1/2 whitespace-nowrap rounded-lg bg-ink px-2 py-1 text-xs font-semibold text-white shadow-sm"
          style={{ left: `${leftPct}%` }}
        >
          ${series[shown].toFixed(2)}
          <span className="ml-1.5 font-normal opacity-70">{dayLabel(points.length - 1 - shown)}</span>
        </div>
      )}

      <svg
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="h-32 w-full"
        preserveAspectRatio="none"
        role="img"
        aria-label="Portfolio value over time. Tap or drag to see values."
      >
        <defs>
          <linearGradient id="balanceFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={strokeColor} stopOpacity="0.16" />
            <stop offset="100%" stopColor={strokeColor} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={area} fill="url(#balanceFill)" />
        <path d={line} fill="none" stroke={strokeColor} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />

        {activeIndex !== null && (
          <line
            x1={shownPoint[0]}
            y1={PAD}
            x2={shownPoint[0]}
            y2={HEIGHT - PAD}
            stroke="#C7CAD1"
            strokeWidth={1}
            strokeDasharray="3 3"
          />
        )}

        {activeIndex === null && <circle cx={last[0]} cy={last[1]} r={3.5} fill={strokeColor} />}

        {activeIndex !== null && (
          <circle
            cx={shownPoint[0]}
            cy={shownPoint[1]}
            r={4}
            fill={strokeColor}
            stroke="white"
            strokeWidth={2}
          />
        )}
      </svg>
    </div>
  );
}
