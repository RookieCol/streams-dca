"use client";

import { ChevronRight } from "lucide-react";
import { streamRules } from "@/lib/mock-data";

export function RulesTab() {
  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-6">
      <p className="font-display text-2xl font-semibold text-ink">Rules</p>
      <p className="mt-1 text-sm text-ink-muted">Controls that keep your stream inside the guardrails you set.</p>

      <div className="mt-6">
        {streamRules.map((r) => (
          <button
            key={r.label}
            type="button"
            className="flex w-full items-center justify-between border-t border-line py-4 text-left last:border-b"
          >
            <span className="text-[15px] text-ink">{r.label}</span>
            <span className="flex items-center gap-1 text-[15px] font-medium text-ink-muted">
              {r.value}
              <ChevronRight className="h-4 w-4 text-ink-faint" />
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
