"use client";

import { Bell, Settings, ChevronDown } from "lucide-react";

export function TopHeader({ title }: { title: string }) {
  return (
    <div className="flex items-center justify-between px-5 pb-2 pt-5">
      <button type="button" aria-label="Settings">
        <Settings className="h-5 w-5 text-ink-muted" />
      </button>
      <button type="button" className="flex items-center gap-1">
        <span className="font-display text-[15px] font-semibold text-ink">{title}</span>
        <ChevronDown className="h-4 w-4 text-ink-muted" />
      </button>
      <button type="button" aria-label="Notifications">
        <Bell className="h-5 w-5 text-ink-muted" />
      </button>
    </div>
  );
}
