"use client";

import { useState } from "react";
import { TopHeader } from "./top-header";
import { BottomNav, TabKey } from "./bottom-nav";
import { HomeTab } from "./home-tab";
import { ProjectionScreen } from "./projection-screen";
import { StartStreamForm } from "./start-stream-form";
import { CongratsScreen } from "./congrats-screen";
import { StreamTab } from "./stream-tab";
import { RulesTab } from "./rules-tab";
import { ActivityTab } from "./activity-tab";
import { ProfileTab } from "./profile-tab";
import { NotificationsSheet } from "./notifications-sheet";
import { RulesProvider, useRules, type Asset, type Frequency, type RiskLevel, type InputCurrency } from "./rules-context";

const TAB_TITLE: Record<TabKey, string> = {
  home: "Portfolio",
  rules: "Rules",
  stream: "Auto-Invest",
  activity: "Activity",
  profile: "Profile",
};

type PushedScreen = "none" | "projection" | "form" | "congrats";
type StreamSubmission = {
  budget: number;
  flowRate: number;
  inputCurrency: InputCurrency;
  asset: Asset;
  frequency: Frequency;
  riskLevel: RiskLevel;
};

export function AppShell() {
  return (
    <RulesProvider>
      <AppShellInner />
    </RulesProvider>
  );
}

function AppShellInner() {
  const [tab, setTab] = useState<TabKey>("home");
  const [screen, setScreen] = useState<PushedScreen>("none");
  const [submission, setSubmission] = useState<StreamSubmission | null>(null);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const rules = useRules();

  if (screen === "projection") {
    return (
      <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
        <ProjectionScreen onBack={() => setScreen("none")} />
      </div>
    );
  }

  if (screen === "form") {
    return (
      <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
        <StartStreamForm
          onBack={() => setScreen("none")}
          onSubmit={(values) => {
            setSubmission(values);
            rules.setAssets([values.asset]);
            rules.setInputCurrency(values.inputCurrency);
            rules.setFlowRatePerDay(values.flowRate);
            rules.setFrequency(values.frequency);
            rules.setRiskLevel(values.riskLevel);
            setScreen("congrats");
          }}
        />
      </div>
    );
  }

  if (screen === "congrats" && submission) {
    return (
      <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
        <CongratsScreen
          budget={submission.budget}
          flowRate={submission.flowRate}
          asset={submission.asset}
          frequency={submission.frequency}
          onDone={() => {
            setScreen("none");
            setTab("stream");
          }}
        />
      </div>
    );
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <TopHeader title={TAB_TITLE[tab]} onNotificationsClick={() => setNotificationsOpen(true)} />
      <div key={tab} className="flex min-h-0 flex-1 flex-col overflow-y-auto animate-in fade-in duration-200">
        {tab === "home" && (
          <HomeTab
            onOpenProjection={() => setScreen("projection")}
            onOpenActivity={() => setTab("activity")}
            onAddToStream={() => setScreen("form")}
          />
        )}
        {tab === "rules" && <RulesTab />}
        {tab === "stream" && <StreamTab />}
        {tab === "activity" && <ActivityTab />}
        {tab === "profile" && <ProfileTab />}
      </div>
      <BottomNav active={tab} onChange={setTab} />
      <NotificationsSheet open={notificationsOpen} onOpenChange={setNotificationsOpen} />
    </div>
  );
}
