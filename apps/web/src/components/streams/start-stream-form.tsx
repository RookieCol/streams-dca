"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { ChevronLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn, pressFeedback } from "@/lib/utils";
import {
  FREQUENCY_OPTIONS,
  RISK_OPTIONS,
  RISK_TO_PCT,
  type Asset,
  type Frequency,
  type RiskLevel,
} from "./rules-context";

type FormState = {
  budget: string;
  flowRate: string;
  asset: Asset | "";
  frequency: Frequency;
  riskLevel: RiskLevel;
};

type FormErrors = Partial<Record<"budget" | "flowRate" | "asset", string>>;

const INITIAL: FormState = { budget: "", flowRate: "", asset: "", frequency: "daily", riskLevel: "medium" };

function validate(form: FormState): FormErrors {
  const errors: FormErrors = {};
  const budget = Number(form.budget);
  const flowRate = Number(form.flowRate);

  if (!form.budget || !(budget > 0)) errors.budget = "Enter an amount over $0";
  if (!form.flowRate || !(flowRate > 0)) errors.flowRate = "Enter an amount over $0";
  else if (form.budget && flowRate > budget) errors.flowRate = "Can't be more than your total";
  if (!form.asset) errors.asset = "Pick what to buy";

  return errors;
}

function short(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

function FieldError({ message }: { message?: string }) {
  if (!message) return null;
  return <p className="mt-1 text-xs font-medium text-loss">{message}</p>;
}

export function StartStreamForm({
  onBack,
  onSubmit,
}: {
  onBack: () => void;
  onSubmit: (values: {
    budget: number;
    flowRate: number;
    asset: Asset;
    frequency: Frequency;
    riskLevel: RiskLevel;
  }) => void;
}) {
  const { address } = useAccount();
  const [form, setForm] = useState<FormState>(INITIAL);
  const [errors, setErrors] = useState<FormErrors>({});
  const [submitting, setSubmitting] = useState(false);

  function update<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const nextErrors = validate(form);
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length > 0) return;

    setSubmitting(true);
    // Mock submission — no on-chain call in this spike, just a simulated round trip.
    window.setTimeout(() => {
      onSubmit({
        budget: Number(form.budget),
        flowRate: Number(form.flowRate),
        asset: form.asset as Asset,
        frequency: form.frequency,
        riskLevel: form.riskLevel,
      });
    }, 900);
  }

  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-5">
      <button
        type="button"
        onClick={onBack}
        aria-label="Back"
        className={cn("mb-4 w-fit", pressFeedback)}
        disabled={submitting}
      >
        <ChevronLeft className="h-6 w-6 text-ink" />
      </button>

      <p className="font-display text-2xl font-semibold text-ink">Add money</p>
      <p className="mt-1 text-sm text-ink-muted">
        A few quick details. All fields are required.
      </p>

      <form onSubmit={handleSubmit} className="mt-6 flex flex-1 flex-col" noValidate>
        <div className="flex-1 space-y-5">
          <div>
            <label htmlFor="budget" className="text-sm font-medium text-ink">
              Total amount (USDC)
            </label>
            <input
              id="budget"
              inputMode="decimal"
              placeholder="0.00"
              value={form.budget}
              onChange={(e) => update("budget", e.target.value)}
              aria-required
              aria-invalid={Boolean(errors.budget)}
              className={cn(
                "mt-1.5 w-full rounded-xl border bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink outline-none focus:border-ink",
                errors.budget ? "border-loss" : "border-line"
              )}
            />
            <FieldError message={errors.budget} />
          </div>

          <div>
            <label htmlFor="flowRate" className="text-sm font-medium text-ink">
              Amount (USDC)
            </label>
            <input
              id="flowRate"
              inputMode="decimal"
              placeholder="0.00"
              value={form.flowRate}
              onChange={(e) => update("flowRate", e.target.value)}
              aria-required
              aria-invalid={Boolean(errors.flowRate)}
              className={cn(
                "mt-1.5 w-full rounded-xl border bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink outline-none focus:border-ink",
                errors.flowRate ? "border-loss" : "border-line"
              )}
            />
            <FieldError message={errors.flowRate} />
          </div>

          <div>
            <p className="text-sm font-medium text-ink">How often</p>
            <div className="mt-1.5 grid grid-cols-4 gap-1.5">
              {FREQUENCY_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => update("frequency", opt.value)}
                  aria-pressed={form.frequency === opt.value}
                  className={cn(
                    "rounded-xl border px-2 py-3 text-[13px] font-medium transition-colors",
                    pressFeedback,
                    form.frequency === opt.value
                      ? "border-ink bg-ink text-white"
                      : "border-line bg-surface text-ink"
                  )}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="text-sm font-medium text-ink">Buy</p>
            <div className="mt-1.5 grid grid-cols-2 gap-2">
              {(["WETH", "WBTC"] as const).map((asset) => (
                <button
                  key={asset}
                  type="button"
                  onClick={() => update("asset", asset)}
                  aria-pressed={form.asset === asset}
                  className={cn(
                    "rounded-xl border px-3.5 py-3 text-[15px] font-medium transition-colors",
                    pressFeedback,
                    form.asset === asset
                      ? "border-ink bg-ink text-white"
                      : "border-line bg-surface text-ink"
                  )}
                >
                  {asset}
                </button>
              ))}
            </div>
            <FieldError message={errors.asset} />
          </div>

          <div>
            <p className="text-sm font-medium text-ink">Risk level</p>
            <div className="mt-1.5 grid grid-cols-3 gap-2">
              {RISK_OPTIONS.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  onClick={() => update("riskLevel", opt.value)}
                  aria-pressed={form.riskLevel === opt.value}
                  className={cn(
                    "rounded-xl border px-2 py-3 text-[13px] font-medium transition-colors",
                    pressFeedback,
                    form.riskLevel === opt.value
                      ? "border-ink bg-ink text-white"
                      : "border-line bg-surface text-ink"
                  )}
                >
                  {opt.label}
                  <span className="block text-[11px] font-normal opacity-70">
                    {RISK_TO_PCT[opt.value]}%
                  </span>
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="text-sm font-medium text-ink">Sent to</p>
            <div className="mt-1.5 rounded-xl border border-line bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink-muted">
              {address ? short(address) : "0x1a2b…9f3c"}
            </div>
            <p className="mt-1 text-xs text-ink-faint">Goes straight to your wallet.</p>
          </div>
        </div>

        <div className="mt-6">
          <Button
            type="submit"
            disabled={submitting}
            className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90 disabled:opacity-60"
          >
            {submitting ? "Starting…" : "Start"}
          </Button>
        </div>
      </form>
    </div>
  );
}
