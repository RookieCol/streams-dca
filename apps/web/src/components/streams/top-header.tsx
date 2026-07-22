"use client";

import { Bell } from "lucide-react";

export function TopHeader({
  title,
  onNotificationsClick,
}: {
  title: string;
  onNotificationsClick?: () => void;
}) {
  return (
    <div className="flex items-center justify-between px-5 pb-5 pt-5">
      <span className="font-display text-[15px] font-semibold text-ink">{title}</span>
      <button type="button" aria-label="Notifications" onClick={onNotificationsClick} className="relative">
        <Bell className="h-5 w-5 text-ink-muted" />
        <span className="absolute -right-0.5 -top-0.5 h-2 w-2 rounded-full bg-loss ring-2 ring-white" />
      </button>
    </div>
  );
}
