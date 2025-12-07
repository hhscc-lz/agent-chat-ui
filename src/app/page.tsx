"use client";

import { Thread } from "@/components/thread";
import { StreamProvider } from "@/providers/Stream";
import { ThreadProvider } from "@/providers/Thread";
import { ArtifactProvider } from "@/components/thread/artifact";
import { Toaster } from "@/components/ui/sonner";
import React, { useState } from "react";

export default function DemoPage(): React.ReactNode {
  const [smartQueryEnabled, setSmartQueryEnabled] = useState(false);

  // 根据开关选择智能体:
  // - 智能问数开启: qa_agent (快速问答)
  // - 智能问数关闭: analysis_agent (深度分析)
  const selectedAssistant = smartQueryEnabled ? "qa_agent" : "analysis_agent";

  return (
    <React.Suspense fallback={<div>Loading (layout)...</div>}>
      <Toaster />
      <ThreadProvider>
        <StreamProvider overrideAssistantId={selectedAssistant}>
          <ArtifactProvider>
            <Thread
              smartQueryEnabled={smartQueryEnabled}
              onSmartQueryChange={setSmartQueryEnabled}
            />
          </ArtifactProvider>
        </StreamProvider>
      </ThreadProvider>
    </React.Suspense>
  );
}
