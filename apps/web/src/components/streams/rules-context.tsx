"use client";

import { createContext, useContext, useState, type ReactNode } from "react";
import { flowRatePerDay as initialAmount } from "@/lib/mock-data";
import {
  DEFAULT_ASSETS,
  DEFAULT_INPUT_CURRENCY,
  type Asset,
  type InputCurrency,
} from "@/lib/tokens";

export type { Asset, InputCurrency } from "@/lib/tokens";
export type Frequency = "daily" | "weekly" | "biweekly" | "monthly";
export type RiskLevel = "low" | "medium" | "high";

export const FREQUENCY_LABEL: Record<Frequency, string> = {
  daily: "day",
  weekly: "week",
  biweekly: "2 weeks",
  monthly: "month",
};

export const FREQUENCY_OPTIONS: { value: Frequency; label: string }[] = [
  { value: "daily", label: "Daily" },
  { value: "weekly", label: "Weekly" },
  { value: "biweekly", label: "Biweekly" },
  { value: "monthly", label: "Monthly" },
];

export const RISK_TO_PCT: Record<RiskLevel, number> = {
  low: 0.3,
  medium: 0.8,
  high: 2.0,
};

export const RISK_OPTIONS: { value: RiskLevel; label: string }[] = [
  { value: "low", label: "Low" },
  { value: "medium", label: "Medium" },
  { value: "high", label: "High" },
];

type RulesState = {
  assets: Asset[];
  inputCurrency: InputCurrency;
  flowRatePerDay: number;
  frequency: Frequency;
  riskLevel: RiskLevel;
  minBuyUsd: number;
  active: boolean;
  cancelled: boolean;
};

type RulesContextValue = RulesState & {
  setAssets: (assets: Asset[]) => void;
  setInputCurrency: (value: InputCurrency) => void;
  setFlowRatePerDay: (value: number) => void;
  setFrequency: (value: Frequency) => void;
  setRiskLevel: (value: RiskLevel) => void;
  setMinBuyUsd: (value: number) => void;
  setActive: (value: boolean) => void;
  setCancelled: (value: boolean) => void;
};

const RulesContext = createContext<RulesContextValue | null>(null);

export function RulesProvider({ children }: { children: ReactNode }) {
  const [assets, setAssets] = useState<Asset[]>(DEFAULT_ASSETS);
  const [inputCurrency, setInputCurrency] = useState<InputCurrency>(DEFAULT_INPUT_CURRENCY);
  const [flowRatePerDay, setFlowRatePerDay] = useState(initialAmount);
  const [frequency, setFrequency] = useState<Frequency>("daily");
  const [riskLevel, setRiskLevel] = useState<RiskLevel>("medium");
  const [minBuyUsd, setMinBuyUsd] = useState(5);
  const [active, setActive] = useState(true);
  const [cancelled, setCancelled] = useState(false);

  return (
    <RulesContext.Provider
      value={{
        assets,
        setAssets,
        inputCurrency,
        setInputCurrency,
        flowRatePerDay,
        setFlowRatePerDay,
        frequency,
        setFrequency,
        riskLevel,
        setRiskLevel,
        minBuyUsd,
        setMinBuyUsd,
        active,
        setActive,
        cancelled,
        setCancelled,
      }}
    >
      {children}
    </RulesContext.Provider>
  );
}

export function useRules() {
  const ctx = useContext(RulesContext);
  if (!ctx) throw new Error("useRules must be used within a RulesProvider");
  return ctx;
}
