"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { ChevronLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

type Asset = "WETH" | "WBTC";

type FormState = {
  budget: string;
  flowRate: string;
  asset: Asset | "";
  slippage: string;
};

type FormErrors = Partial<Record<keyof FormState, string>>;

const INITIAL: FormState = { budget: "", flowRate: "", asset: "", slippage: "0.5" };

function validate(form: FormState): FormErrors {
  const errors: FormErrors = {};
  const budget = Number(form.budget);
  const flowRate = Number(form.flowRate);
  const slippage = Number(form.slippage);

  if (!form.budget || !(budget > 0)) errors.budget = "Enter a budget greater than $0";
  if (!form.flowRate || !(flowRate > 0)) errors.flowRate = "Enter a flow rate greater than $0";
  else if (form.budget && flowRate > budget) errors.flowRate = "Flow rate can't exceed your budget";
  if (!form.asset) errors.asset = "Choose a target asset";
  if (form.slippage === "" || Number.isNaN(slippage) || slippage < 0 || slippage > 5)
    errors.slippage = "Slippage must be between 0% and 5%";

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
  onSubmit: (values: { budget: number; flowRate: number; asset: Asset; slippage: number }) => void;
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
        slippage: Number(form.slippage),
      });
    }, 900);
  }

  return (
    <div className="flex flex-1 flex-col px-5 pb-4 pt-5">
      <button type="button" onClick={onBack} aria-label="Back" className="mb-4 w-fit" disabled={submitting}>
        <ChevronLeft className="h-6 w-6 text-ink" />
      </button>

      <p className="font-display text-2xl font-semibold text-ink">Add to stream</p>
      <p className="mt-1 text-sm text-ink-muted">
        Set how much to stream and where it should flow. All fields are required.
      </p>

      <form onSubmit={handleSubmit} className="mt-6 flex flex-1 flex-col" noValidate>
          <div className="flex-1 space-y-5">
            <div>
              <label htmlFor="budget" className="text-sm font-medium text-ink">
                Total budget (USDC)
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
                Flow rate (USDC / day)
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
              <p className="text-sm font-medium text-ink">Target asset</p>
              <div className="mt-1.5 grid grid-cols-2 gap-2">
                {(["WETH", "WBTC"] as const).map((asset) => (
                  <button
                    key={asset}
                    type="button"
                    onClick={() => update("asset", asset)}
                    aria-pressed={form.asset === asset}
                    className={cn(
                      "rounded-xl border px-3.5 py-3 text-[15px] font-medium transition-colors",
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
              <label htmlFor="slippage" className="text-sm font-medium text-ink">
                Max slippage (%)
              </label>
              <input
                id="slippage"
                inputMode="decimal"
                value={form.slippage}
                onChange={(e) => update("slippage", e.target.value)}
                aria-required
                aria-invalid={Boolean(errors.slippage)}
                className={cn(
                  "mt-1.5 w-full rounded-xl border bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink outline-none focus:border-ink",
                  errors.slippage ? "border-loss" : "border-line"
                )}
              />
              <FieldError message={errors.slippage} />
            </div>

            <div>
              <p className="text-sm font-medium text-ink">Settlement address</p>
              <div className="mt-1.5 rounded-xl border border-line bg-surface px-3.5 py-3 text-[15px] tabular-nums text-ink-muted">
                {address ? short(address) : "demo.eth (0x1a2b…9f3c)"}
              </div>
              <p className="mt-1 text-xs text-ink-faint">
                {address
                  ? "Swapped assets settle to your connected wallet."
                  : "No wallet connected yet — using a demo address for this preview."}
              </p>
            </div>
          </div>

          <div className="mt-6">
            <Button
              type="submit"
              disabled={submitting}
              className="h-12 w-full rounded-full bg-ink text-[15px] font-semibold text-white hover:bg-ink/90 disabled:opacity-60"
            >
              {submitting ? "Starting stream…" : "Start streaming"}
            </Button>
          </div>
        </form>
    </div>
  );
}
