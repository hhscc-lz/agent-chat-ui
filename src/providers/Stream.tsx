import React, {
  createContext,
  useContext,
  ReactNode,
  useState,
  useEffect,
} from "react";
import { useStream } from "@langchain/langgraph-sdk/react";
import { type Message } from "@langchain/langgraph-sdk";
import {
  uiMessageReducer,
  isUIMessage,
  isRemoveUIMessage,
  type UIMessage,
  type RemoveUIMessage,
} from "@langchain/langgraph-sdk/react-ui";
import { useQueryState } from "nuqs";
import { getApiKey } from "@/lib/api-key";
import { toast } from "sonner";

export type StateType = {
  messages: Message[];
  ui?: UIMessage[];
  task_reports?: Message[]; // 子智能体报告列表（后端 add_messages 自动转换为 Message 对象）
  progress_messages?: string[]; // 后端 writer 发送的进度消息列表
};

const useTypedStream = useStream<
  StateType,
  {
    UpdateType: {
      messages?: Message[] | Message | string;
      ui?: (UIMessage | RemoveUIMessage)[] | UIMessage | RemoveUIMessage;
      context?: Record<string, unknown>;
      progress_messages?: string[];
    };
    CustomEventType: UIMessage | RemoveUIMessage | string; // 添加 string 类型支持进度消息
  }
>;

type StreamContextType = ReturnType<typeof useTypedStream>;
const StreamContext = createContext<StreamContextType | undefined>(undefined);

async function checkGraphStatus(
  apiUrl: string,
  apiKey: string | null,
): Promise<boolean> {
  try {
    const res = await fetch(`${apiUrl}/info`, {
      ...(apiKey && {
        headers: {
          "X-Api-Key": apiKey,
        },
      }),
    });

    return res.ok;
  } catch (e) {
    console.error(e);
    return false;
  }
}

const StreamSession = ({
  children,
  apiKey,
  apiUrl,
  assistantId,
  onAssistantIdChange,
}: {
  children: ReactNode;
  apiKey: string | null;
  apiUrl: string;
  assistantId: string;
  onAssistantIdChange?: (newAssistantId: string) => void;
}) => {
  const [currentAssistantId, setCurrentAssistantId] = useState(assistantId);

  // 同步外部 assistantId 变化
  useEffect(() => {
    if (assistantId !== currentAssistantId) {
      setCurrentAssistantId(assistantId);
    }
  }, [assistantId]);

  const streamValue = useTypedStream({
    apiUrl,
    apiKey: apiKey ?? undefined,
    assistantId: currentAssistantId,
    threadId: null, // 每次都是新会话
    fetchStateHistory: false, // 不需要获取历史
    onCustomEvent: (event, options) => {
      // 处理 UI 消息
      if (isUIMessage(event) || isRemoveUIMessage(event)) {
        options.mutate((prev) => {
          const ui = uiMessageReducer(prev.ui ?? [], event);
          return { ...prev, ui };
        });
      }
      // 处理进度消息（后端 writer 发送的字符串）
      else if (typeof event === 'string') {
        options.mutate((prev) => {
          const newMessages = [...(prev.progress_messages ?? []), event];
          return { ...prev, progress_messages: newMessages };
        });
      }
    },
  });

  useEffect(() => {
    // checkGraphStatus(apiUrl, apiKey).then((ok) => {
    //   if (!ok) {
    //     toast.error("Failed to connect to LangGraph server", {
    //       description: () => (
    //         <p>
    //           Please ensure your graph is running at <code>{apiUrl}</code> and
    //           your API key is correctly set (if connecting to a deployed graph).
    //         </p>
    //       ),
    //       duration: 10000,
    //       richColors: true,
    //       closeButton: true,
    //     });
    //   }
    // });
  }, [apiKey, apiUrl]);

  return (
    <StreamContext.Provider value={streamValue}>
      {children}
    </StreamContext.Provider>
  );
};

// Default values for the form
const DEFAULT_API_URL = "http://localhost:2024";
const DEFAULT_ASSISTANT_ID = "agent";

export const StreamProvider: React.FC<{
  children: ReactNode;
  overrideAssistantId?: string;
}> = ({
  children,
  overrideAssistantId,
}) => {
  // Get environment variables
  const envApiUrl: string | undefined = process.env.NEXT_PUBLIC_API_URL;
  const envAssistantId: string | undefined =
    process.env.NEXT_PUBLIC_ASSISTANT_ID;

  // Use URL params with env var fallbacks
  const [apiUrl] = useQueryState("apiUrl", {
    defaultValue: envApiUrl || DEFAULT_API_URL,
  });
  const [assistantId] = useQueryState("assistantId", {
    defaultValue: envAssistantId || DEFAULT_ASSISTANT_ID,
  });

  // For API key, use localStorage with env var fallback
  const [apiKey] = useState(() => {
    const storedKey = getApiKey();
    return storedKey || "";
  });

  // Use overrideAssistantId if provided, otherwise use assistantId from URL/env
  const finalAssistantId = overrideAssistantId || assistantId;

  return (
    <StreamSession
      apiKey={apiKey}
      apiUrl={apiUrl}
      assistantId={finalAssistantId}
    >
      {children}
    </StreamSession>
  );
};

// Create a custom hook to use the context
export const useStreamContext = (): StreamContextType => {
  const context = useContext(StreamContext);
  if (context === undefined) {
    throw new Error("useStreamContext must be used within a StreamProvider");
  }
  return context;
};

export default StreamContext;
