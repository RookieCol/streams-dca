"use client";

import { CheckCircle2, Info, ShieldCheck } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";

const NOTIFICATIONS = [
  {
    id: "1",
    icon: CheckCircle2,
    title: "Bought $12.50 of WETH",
    detail: "Today, as part of your Auto-Invest",
  },
  {
    id: "2",
    icon: CheckCircle2,
    title: "Bought $12.50 of WBTC",
    detail: "Yesterday, as part of your Auto-Invest",
  },
  {
    id: "3",
    icon: ShieldCheck,
    title: "Risk level set to Medium",
    detail: "2 days ago, from Rules",
  },
  {
    id: "4",
    icon: Info,
    title: "Welcome to Auto-Invest",
    detail: "Your first buy landed 5 days ago",
  },
] as const;

export function NotificationsSheet({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="rounded-t-2xl">
        <SheetHeader>
          <SheetTitle>Notifications</SheetTitle>
          <SheetDescription>What&rsquo;s happened with your Auto-Invest.</SheetDescription>
        </SheetHeader>
        <div className="mt-2">
          {NOTIFICATIONS.map((n) => (
            <div key={n.id} className="flex items-start gap-3 border-t border-line py-3 last:border-b">
              <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-surface">
                <n.icon className="h-4 w-4 text-flow" />
              </span>
              <div>
                <p className="text-[15px] font-medium text-ink">{n.title}</p>
                <p className="text-sm text-ink-muted">{n.detail}</p>
              </div>
            </div>
          ))}
        </div>
      </SheetContent>
    </Sheet>
  );
}
