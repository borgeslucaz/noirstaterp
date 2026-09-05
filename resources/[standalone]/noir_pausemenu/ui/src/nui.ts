export interface NuiMessage<T = unknown> {
  action: string;
  data: T;
}

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export const isBrowser = () => typeof window.GetParentResourceName !== "function";

export async function postNui<T = unknown>(event: string, data?: unknown): Promise<T | undefined> {
  if (isBrowser()) return undefined;

  const resource = window.GetParentResourceName?.() ?? "noir_pausemenu";
  const response = await fetch(`https://${resource}/${event}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data ?? {}),
  });

  return response.json().catch(() => undefined) as Promise<T | undefined>;
}
