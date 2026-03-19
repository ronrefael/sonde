import { List, ActionPanel, Action } from "@raycast/api";
import { readFileSync, readdirSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

interface CacheEnvelope {
  data: Record<string, unknown>;
  created_at: number;
  expires_at: number;
}

function readSondeCache(name: string): Record<string, unknown> | null {
  const cacheDir = join(homedir(), "Library", "Caches", "sonde");
  const path = join(cacheDir, `${name}.json`);

  if (!existsSync(path)) return null;

  try {
    const content = readFileSync(path, "utf-8");
    const envelope: CacheEnvelope = JSON.parse(content);
    const now = Math.floor(Date.now() / 1000);
    if (now < envelope.expires_at) {
      return envelope.data;
    }
  } catch {
    // ignore
  }
  return null;
}

function readSessionData(): Record<string, unknown> | null {
  return readSondeCache("session_data");
}

function readUsageLimits(): Record<string, unknown> | null {
  return readSondeCache("usage_limits");
}

export default function Command() {
  const session = readSessionData();
  const usage = readUsageLimits();

  const items: { title: string; subtitle: string; icon: string }[] = [];

  if (session) {
    const model = (session.model_name as string) || "Unknown";
    items.push({ title: "Model", subtitle: model, icon: "🧠" });

    const cost = session.session_cost as number | undefined;
    if (cost !== undefined) {
      items.push({ title: "Session Cost", subtitle: `$${cost.toFixed(2)}`, icon: "💰" });
    }

    const ctx = session.context_used_pct as number | undefined;
    if (ctx !== undefined) {
      items.push({ title: "Context Usage", subtitle: `${ctx.toFixed(0)}%`, icon: "📊" });
    }
  }

  if (usage) {
    const fiveHour = (usage as Record<string, Record<string, unknown>>).five_hour;
    if (fiveHour?.utilization !== undefined) {
      items.push({
        title: "5h Usage",
        subtitle: `${(fiveHour.utilization as number).toFixed(0)}%`,
        icon: "⏱",
      });
    }
    const sevenDay = (usage as Record<string, Record<string, unknown>>).seven_day;
    if (sevenDay?.utilization !== undefined) {
      items.push({
        title: "7d Usage",
        subtitle: `${(sevenDay.utilization as number).toFixed(0)}%`,
        icon: "📅",
      });
    }
  }

  if (items.length === 0) {
    items.push({ title: "No data", subtitle: "Run sonde to generate data", icon: "❓" });
  }

  return (
    <List>
      {items.map((item, idx) => (
        <List.Item
          key={idx}
          title={item.title}
          subtitle={item.subtitle}
          icon={item.icon}
          actions={
            <ActionPanel>
              <Action.CopyToClipboard content={`${item.title}: ${item.subtitle}`} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
