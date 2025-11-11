import { HumanResponseWithEdits, SubmitType } from "../types";
import {
  KeyboardEvent,
  Dispatch,
  SetStateAction,
  MutableRefObject,
  useState,
  useRef,
  useEffect,
} from "react";
import { createDefaultHumanResponse } from "../utils";
import { toast } from "sonner";
import { HumanInterrupt, HumanResponse } from "@langchain/langgraph/prebuilt";
import { END } from "@langchain/langgraph/web";
import { useStreamContext } from "@/providers/Stream";

interface UseInterruptedActionsInput {
  interrupt: HumanInterrupt;
}

interface UseInterruptedActionsValue {
  // Actions
  handleSubmit: (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent> | KeyboardEvent,
  ) => Promise<void>;
  handleIgnore: (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent>,
  ) => Promise<void>;
  handleResolve: (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent>,
  ) => Promise<void>;

  // State values
  streaming: boolean;
  streamFinished: boolean;
  loading: boolean;
  supportsMultipleMethods: boolean;
  hasEdited: boolean;
  hasAddedResponse: boolean;
  acceptAllowed: boolean;
  humanResponse: HumanResponseWithEdits[];

  // State setters
  setSelectedSubmitType: Dispatch<SetStateAction<SubmitType | undefined>>;
  setHumanResponse: Dispatch<SetStateAction<HumanResponseWithEdits[]>>;
  setHasAddedResponse: Dispatch<SetStateAction<boolean>>;
  setHasEdited: Dispatch<SetStateAction<boolean>>;

  // Refs
  initialHumanInterruptEditValue: MutableRefObject<Record<string, string>>;
}

export default function useInterruptedActions({
  interrupt,
}: UseInterruptedActionsInput): UseInterruptedActionsValue {
  const thread = useStreamContext();
  const [humanResponse, setHumanResponse] = useState<HumanResponseWithEdits[]>(
    [],
  );
  const [loading, setLoading] = useState(false);
  const [streaming, setStreaming] = useState(false);
  const [streamFinished, setStreamFinished] = useState(false);
  const initialHumanInterruptEditValue = useRef<Record<string, string>>({});
  const [selectedSubmitType, setSelectedSubmitType] = useState<SubmitType>();
  // Whether or not the user has edited any fields which allow editing.
  const [hasEdited, setHasEdited] = useState(false);
  // Whether or not the user has added a response.
  const [hasAddedResponse, setHasAddedResponse] = useState(false);
  const [acceptAllowed, setAcceptAllowed] = useState(false);

  useEffect(() => {
    try {
      const { responses, defaultSubmitType, hasAccept } =
        createDefaultHumanResponse(interrupt, initialHumanInterruptEditValue);
      setSelectedSubmitType(defaultSubmitType);
      setHumanResponse(responses);
      setAcceptAllowed(hasAccept);
    } catch (e) {
      console.error("Error formatting and setting human response state", e);
    }
  }, [interrupt]);

  const resumeRun = (response: HumanResponse[]): boolean => {
    try {
      thread.submit(
        {},
        {
          command: {
            resume: response,
          },
        },
      );
      return true;
    } catch (e: any) {
      console.error("Error sending human response", e);
      return false;
    }
  };

  const handleSubmit = async (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent> | KeyboardEvent,
  ) => {
    e.preventDefault();
    if (!humanResponse) {
      toast.error("提交失败", {
        description: "请先填写需要提交的内容。",
        duration: 5000,
        richColors: true,
        closeButton: true,
      });
      return;
    }

    let errorOccurred = false;
    initialHumanInterruptEditValue.current = {};

    if (
      humanResponse.some((r) => ["response", "edit", "accept"].includes(r.type))
    ) {
      setStreamFinished(false);

      try {
        const humanResponseInput: HumanResponse[] = humanResponse.flatMap(
          (r) => {
            if (r.type === "edit") {
              if (r.acceptAllowed && !r.editsMade) {
                return {
                  type: "accept",
                  args: r.args,
                };
              } else {
                return {
                  type: "edit",
                  args: r.args,
                };
              }
            }

            if (r.type === "response" && !r.args) {
              // If response was allowed but no response was given, do not include in the response
              return [];
            }
            return {
              type: r.type,
              args: r.args,
            };
          },
        );

        const input = humanResponseInput.find(
          (r) => r.type === selectedSubmitType,
        );
        if (!input) {
          toast.error("提交失败", {
            description: "未找到可提交的内容，请确认填写后再试。",
            richColors: true,
            closeButton: true,
            duration: 5000,
          });
          return;
        }

        setLoading(true);
        setStreaming(true);
        const resumedSuccessfully = resumeRun([input]);
        if (!resumedSuccessfully) {
          // This will only be undefined if the graph ID is not found
          // in this case, the method will trigger a toast for us.
          return;
        }

        toast("提交成功", {
          description: "已将内容发送至后台处理，请关注反馈。",
          duration: 5000,
        });

        if (!errorOccurred) {
          setStreamFinished(true);
        }
      } catch (e: any) {
        console.error("Error sending human response", e);

        if ("message" in e && e.message.includes("Invalid assistant ID")) {
          toast("助手配置错误", {
            description:
              "未找到对应的受理流程，请在设置中更新助手 ID 后重试。",
            richColors: true,
            closeButton: true,
            duration: 5000,
          });
        } else {
          toast.error("提交失败", {
            description: "发送至后台时出现问题，请稍后重试。",
            richColors: true,
            closeButton: true,
            duration: 5000,
          });
        }

        errorOccurred = true;
        setStreaming(false);
        setStreamFinished(false);
      }

      if (!errorOccurred) {
        setStreaming(false);
        setStreamFinished(false);
      }
  } else {
    setLoading(true);
    resumeRun(humanResponse);

    toast("提交成功", {
      description: "已将内容发送至后台处理，请关注反馈。",
      duration: 5000,
    });
  }

    setLoading(false);
  };

  const handleIgnore = async (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent>,
  ) => {
    e.preventDefault();

    const ignoreResponse = humanResponse.find((r) => r.type === "ignore");
    if (!ignoreResponse) {
      toast.error("无法忽略", {
        description: "当前诉求不支持忽略操作，请选择其他处理方式。",
        duration: 5000,
      });
      return;
    }

    setLoading(true);
    initialHumanInterruptEditValue.current = {};

    resumeRun([ignoreResponse]);

    setLoading(false);
    toast("已忽略该诉求", { duration: 5000 });
  };

  const handleResolve = async (
    e: React.MouseEvent<HTMLButtonElement, MouseEvent>,
  ) => {
    e.preventDefault();

    setLoading(true);
    initialHumanInterruptEditValue.current = {};

    try {
      thread.submit(
        {},
        {
          command: {
            goto: END,
          },
        },
      );

      toast("处理完成", {
        description: "已将诉求标记为办结。",
        duration: 3000,
      });
    } catch (e) {
      console.error("Error marking thread as resolved", e);
      toast.error("操作失败", {
        description: "办结操作未成功，请稍后重试。",
        richColors: true,
        closeButton: true,
        duration: 3000,
      });
    }

    setLoading(false);
  };

  const supportsMultipleMethods =
    humanResponse.filter(
      (r) => r.type === "edit" || r.type === "accept" || r.type === "response",
    ).length > 1;

  return {
    handleSubmit,
    handleIgnore,
    handleResolve,
    humanResponse,
    streaming,
    streamFinished,
    loading,
    supportsMultipleMethods,
    hasEdited,
    hasAddedResponse,
    acceptAllowed,
    setSelectedSubmitType,
    setHumanResponse,
    setHasAddedResponse,
    setHasEdited,
    initialHumanInterruptEditValue,
  };
}
