"use client";

import { TrendingUp, Target, Infinity as InfinityIcon, Layers, User } from "lucide-react";
import { cn, pressFeedback } from "@/lib/utils";

export type TabKey = "home" | "rules" | "stream" | "activity" | "profile";

const TABS: { key: TabKey; label: string; icon: typeof TrendingUp }[] = [
  { key: "home", label: "Portfolio", icon: TrendingUp },
  { key: "rules", label: "Rules", icon: Target },
  { key: "stream", label: "Auto", icon: InfinityIcon },
  { key: "activity", label: "Activity", icon: Layers },
  { key: "profile", label: "Profile", icon: User },
];

export function BottomNav({
  active,
  onChange,
}: {
  active: TabKey;
  onChange: (tab: TabKey) => void;
}) {
  return (
    <nav className="sticky bottom-0 z-20 flex items-center justify-around border-t border-line bg-white/95 px-2 pb-[env(safe-area-inset-bottom)] pt-2 backdrop-blur">
      {TABS.map(({ key, label, icon: Icon }) => {
        const isActive = key === active;
        const isStream = key === "stream";
        return (
          <button
            key={key}
            type="button"
            onClick={() => onChange(key)}
            className={cn("flex flex-1 flex-col items-center gap-1 py-1.5", pressFeedback)}
            aria-current={isActive ? "page" : undefined}
            aria-label={label}
          >
            <span
              className={cn(
                "flex h-8 w-8 items-center justify-center rounded-full transition-all duration-200",
                isActive && "scale-110",
                isStream && isActive && "bg-ink text-white",
                isStream && !isActive && "text-ink",
                !isStream && isActive && "text-ink",
                !isStream && !isActive && "text-ink-faint"
              )}
            >
              <Icon className="h-5 w-5" strokeWidth={isActive ? 2.25 : 1.75} />
            </span>
          </button>
        );
      })}
    </nav>
  );
}
