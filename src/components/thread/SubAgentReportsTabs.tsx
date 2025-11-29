import { useState } from "react";
import { cn } from "@/lib/utils";
import { MarkdownText } from "./markdown-text";
import { Button } from "@/components/ui/button";
import { Copy } from "lucide-react";
import { toast } from "sonner";

interface SubAgentReportsTabsProps {
  reports: string[];
}

export function SubAgentReportsTabs({ reports }: SubAgentReportsTabsProps) {
  const [activeTab, setActiveTab] = useState(0);

  if (!reports || reports.length === 0) {
    return null;
  }

  const handleCopy = () => {
    navigator.clipboard.writeText(reports[activeTab]);
    toast.success("报告已复制到剪贴板");
  };

  return (
    <div className="mt-6 border rounded-lg overflow-hidden bg-background">
      {/* 标签栏 */}
      <div className="flex items-center gap-1 border-b bg-muted/30 p-1">
        {reports.map((_, index) => (
          <button
            key={index}
            onClick={() => setActiveTab(index)}
            className={cn(
              "px-4 py-2 text-sm font-medium rounded-md transition-colors",
              activeTab === index
                ? "bg-background text-foreground shadow-sm"
                : "text-muted-foreground hover:text-foreground hover:bg-muted/50"
            )}
          >
            子智能体报告 {index + 1}
          </button>
        ))}
      </div>

      {/* 报告内容 */}
      <div className="p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold">
            子智能体报告 {activeTab + 1}
          </h3>
          <Button variant="outline" size="sm" onClick={handleCopy}>
            <Copy className="w-4 h-4 mr-2" />
            复制
          </Button>
        </div>

        <div className="prose prose-sm max-w-none dark:prose-invert">
          <MarkdownText>{reports[activeTab]}</MarkdownText>
        </div>
      </div>
    </div>
  );
}
