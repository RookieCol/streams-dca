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

const TAB_TITLE: Record<TabKey, string> = {
  home: "Stream Vault",
  rules: "Rules",
  stream: "Stream",
  activity: "Activity",
  profile: "Profile",
};

type PushedScreen = "none" | "projection" | "form" | "congrats";
type StreamSubmission = { budget: number; flowRate: number; asset: string; slippage: number };

export function AppShell() {
  const [tab, setTab] = useState<TabKey>("home");
  const [screen, setScreen] = useState<PushedScreen>("none");
  const [submission, setSubmission] = useState<StreamSubmission | null>(null);

  if (screen === "projection") {
    return (
      <div className="flex flex-1 flex-col">
        <ProjectionScreen onBack={() => setScreen("none")} />
      </div>
    );
  }

  if (screen === "form") {
    return (
      <div className="flex flex-1 flex-col">
        <StartStreamForm
          onBack={() => setScreen("none")}
          onSubmit={(values) => {
            setSubmission(values);
            setScreen("congrats");
          }}
        />
      </div>
    );
  }

  if (screen === "congrats" && submission) {
    return (
      <div className="flex flex-1 flex-col">
        <CongratsScreen
          budget={submission.budget}
          flowRate={submission.flowRate}
          asset={submission.asset}
          onDone={() => {
            setScreen("none");
            setTab("stream");
          }}
        />
      </div>
    );
  }

  return (
    <div className="flex flex-1 flex-col">
      <TopHeader title={TAB_TITLE[tab]} />
      <div className="flex flex-1 flex-col">
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
    </div>
  );
}
