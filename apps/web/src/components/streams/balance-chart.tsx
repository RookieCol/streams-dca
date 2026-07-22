"use client";

import { useMemo } from "react";

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

export function BalanceChart({ series, positive }: { series: number[]; positive: boolean }) {
  const { line, area, points } = useMemo(() => buildPath(series), [series]);
  const strokeColor = positive ? "#16A34A" : "#E5484D";
  const last = points[points.length - 1];
  const prevLast = points[points.length - 4] ?? points[points.length - 2];
  const liveSegment = `M${prevLast[0].toFixed(2)},${prevLast[1].toFixed(2)} L${last[0].toFixed(2)},${last[1].toFixed(2)}`;

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      className="h-32 w-full"
      preserveAspectRatio="none"
      role="img"
      aria-label="Portfolio value over time"
    >
      <defs>
        <linearGradient id="balanceFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={strokeColor} stopOpacity="0.16" />
          <stop offset="100%" stopColor={strokeColor} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={area} fill="url(#balanceFill)" />
      <path d={line} fill="none" stroke={strokeColor} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
      {/* Signature: the trailing edge stays visibly "live" — a flowing dashed
          overlay plus a pulsing dot, echoing the product's continuous stream. */}
      <path
        d={liveSegment}
        fill="none"
        stroke="#00C2A8"
        strokeWidth={2}
        strokeLinecap="round"
        strokeDasharray="4 4"
        className="motion-safe:animate-[flow-dash_1s_linear_infinite]"
      />
      <circle cx={last[0]} cy={last[1]} r={3.5} fill="#00C2A8" />
      <circle cx={last[0]} cy={last[1]} r={3.5} fill="#00C2A8" className="motion-safe:animate-ping origin-center opacity-60" />
    </svg>
  );
}
