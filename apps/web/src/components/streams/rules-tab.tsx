"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { ChevronRight } from "lucide-react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
  SheetFooter,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { cn, pressFeedback } from "@/lib/utils";
import {
  useRules,
  FREQUENCY_LABEL,
  FREQUENCY_OPTIONS,
  RISK_OPTIONS,
  RISK_TO_PCT,
  type Asset,
} from "./rules-context";

type RuleKey = "assets" | "amount" | "risk" | "minBuy" | null;

function short(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

function Row({
  label,
  value,
  onClick,
  flash,
}: {
  label: string;
  value: string;
  onClick?: () => void;
  flash?: boolean;
}) {
  const Comp = onClick ? "button" : "div";
  return (
    <Comp
      type={onClick ? "button" : undefined}
      onClick={onClick}
      className={cn(
        "flex w-full items-center justify-between rounded-lg border-t border-line px-2 -mx-2 py-4 text-left transition-colors duration-500 last:border-b",
        onClick && pressFeedback,
        flash && "bg-flow-soft"
      )}
    >
      <span className="text-[15px] text-ink">{label}</span>
      <span className="flex items-center gap-1 text-[15px] font-medium text-ink-muted">
        {value}
        {onClick && <ChevronRight className="h-4 w-4 text-ink-faint" />}
      </span>
    </Comp>
  );
}

export function RulesTab() {
  const rules = useRules();
  const { address } = useAccount();
  const [open, setOpen] = useState<RuleKey>(null);
  const [savedKey, setSavedKey] = useState<RuleKey>(null);

  // Draft values, only committed to context when "Save" is tapped.
  const [amountDraft, setAmountDraft] = useState(String(rules.flowRatePerDay));
  const [frequencyDraft, setFrequencyDraft] = useState(rules.frequency);
  const [buyDraft, setBuyDraft] = useState(String(rules.minBuyUsd));

  function openSheet(key: RuleKey) {
    setAmountDraft(String(rules.flowRatePerDay));
    setFrequencyDraft(rules.frequency);
    setBuyDraft(String(rules.minBuyUsd));
    setOpen(key);
  }

  function flashSaved(key: RuleKey) {
    setSavedKey(key);
    window.setTimeout(() => setSavedKey(null), 600);
  }

  function toggleAsset(asset: Asset) {
    const has = rules.assets.includes(asset);
    if (has && rules.assets.length === 1) return; // keep at least one asset
    rules.setAssets(has ? rules.assets.filter((a) => a !== asset) : [...rules.assets, asset]);
  }

  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-6">
      <p className="font-display text-2xl font-semibold text-ink">Rules</p>
      <p className="mt-1 text-sm text-ink-muted">The limits that keep your Auto-Invest on track.</p>

      <div className="mt-6">
        <Row
          label="What you buy"
          value={rules.assets.join(", ")}
          onClick={() => openSheet("assets")}
          flash={savedKey === "assets"}
        />
        <Row
          label="Amount"
          value={`$${rules.flowRatePerDay.toFixed(2)} / ${FREQUENCY_LABEL[rules.frequency]}`}
          onClick={() => openSheet("amount")}
          flash={savedKey === "amount"}
        />
        <Row
          label="Risk level"
          value={`${RISK_OPTIONS.find((r) => r.value === rules.riskLevel)?.label} (${RISK_TO_PCT[rules.riskLevel]}%)`}
          onClick={() => openSheet("risk")}
          flash={savedKey === "risk"}
        />
        <Row
          label="Smallest buy"
          value={`$${rules.minBuyUsd.toFixed(2)}`}
          onClick={() => openSheet("minBuy")}
          flash={savedKey === "minBuy"}
        />
        <Row label="Where it lands" value={address ? short(address) : "Your wallet"} />
      </div>

      <Sheet open={open === "assets"} onOpenChange={(v) => !v && setOpen(null)}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>What you buy</SheetTitle>
            <SheetDescription>Pick one or both — your amount splits evenly.</SheetDescription>
          </SheetHeader>
          <div className="mt-4 grid grid-cols-2 gap-2">
            {(["WETH", "WBTC"] as const).map((asset) => (
              <button
                key={asset}
                type="button"
                onClick={() => toggleAsset(asset)}
                aria-pressed={rules.assets.includes(asset)}
                className={cn(
                  "rounded-xl border px-3.5 py-3 text-[15px] font-medium transition-colors",
                  pressFeedback,
                  rules.assets.includes(asset)
                    ? "border-ink bg-ink text-white"
                    : "border-line bg-surface text-ink"
                )}
              >
                {asset}
              </button>
            ))}
          </div>
          <SheetFooter className="mt-6">
            <Button
              onClick={() => {
                setOpen(null);
                flashSaved("assets");
              }}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              Done
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>

      <Sheet open={open === "amount"} onOpenChange={(v) => !v && setOpen(null)}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>Amount</SheetTitle>
            <SheetDescription>Want to put in more? Raise it here — it applies right away.</SheetDescription>
          </SheetHeader>
          <div className="mt-4">
            <label htmlFor="amountDraft" className="text-sm font-medium text-ink">
              USDC
            </label>
            <input
              id="amountDraft"
              inputMode="decimal"
              value={amountDraft}
              onChange={(e) => setAmountDraft(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-line bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink outline-none focus:border-ink"
            />
          </div>
          <div className="mt-4">
            <p className="text-sm font-medium text-ink">How often</p>
            <div className="mt-1.5 grid grid-cols-4 gap-1.5">
              {FREQUENCY_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => setFrequencyDraft(opt.value)}
                  aria-pressed={frequencyDraft === opt.value}
                  className={cn(
                    "rounded-xl border px-2 py-3 text-[13px] font-medium transition-colors",
                    pressFeedback,
                    frequencyDraft === opt.value
                      ? "border-ink bg-ink text-white"
                      : "border-line bg-surface text-ink"
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>
          <SheetFooter className="mt-6">
            <Button
              onClick={() => {
                const v = Number(amountDraft);
                if (v > 0) rules.setFlowRatePerDay(v);
                rules.setFrequency(frequencyDraft);
                setOpen(null);
                flashSaved("amount");
              }}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              Save
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>

      <Sheet open={open === "risk"} onOpenChange={(v) => !v && setOpen(null)}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>Risk level</SheetTitle>
            <SheetDescription>Higher risk means a buy is less likely to be skipped when prices move.</SheetDescription>
          </SheetHeader>
          <div className="mt-4 grid grid-cols-3 gap-2">
            {RISK_OPTIONS.map((opt) => (
              <button
                key={opt.value}
                type="button"
                onClick={() => rules.setRiskLevel(opt.value)}
                aria-pressed={rules.riskLevel === opt.value}
                className={cn(
                  "rounded-xl border px-2 py-3 text-[13px] font-medium transition-colors",
                  pressFeedback,
                  rules.riskLevel === opt.value
                    ? "border-ink bg-ink text-white"
                    : "border-line bg-surface text-ink"
                )}
              >
                {opt.label}
                <span className="block text-[11px] font-normal opacity-70">{RISK_TO_PCT[opt.value]}%</span>
              </button>
            ))}
          </div>
          <SheetFooter className="mt-6">
            <Button
              onClick={() => {
                setOpen(null);
                flashSaved("risk");
              }}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              Done
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>

      <Sheet open={open === "minBuy"} onOpenChange={(v) => !v && setOpen(null)}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>Smallest buy</SheetTitle>
            <SheetDescription>Skip buys below this amount to save on fees.</SheetDescription>
          </SheetHeader>
          <div className="mt-4">
            <label htmlFor="buyDraft" className="text-sm font-medium text-ink">
              USDC
            </label>
            <input
              id="buyDraft"
              inputMode="decimal"
              value={buyDraft}
              onChange={(e) => setBuyDraft(e.target.value)}
              className="mt-1.5 w-full rounded-xl border border-line bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink outline-none focus:border-ink"
            />
          </div>
          <SheetFooter className="mt-6">
            <Button
              onClick={() => {
                const v = Number(buyDraft);
                if (v >= 0) rules.setMinBuyUsd(v);
                setOpen(null);
                flashSaved("minBuy");
              }}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90"
            >
              Save
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </div>
  );
}
