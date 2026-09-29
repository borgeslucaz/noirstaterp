/** Fora do jogo (`npm run dev`) não existe `invokeNative`. */
export const isBrowser = (): boolean => !('invokeNative' in window);

export async function fetchNui<T = unknown>(endpoint: string, data: unknown = {}): Promise<T | null> {
  if (isBrowser()) return null;

  const resource = (window as unknown as { GetParentResourceName?: () => string })
    .GetParentResourceName?.() ?? 'noir_skills';

  const response = await fetch(`https://${resource}/${endpoint}`, {
    method: 'post',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  });

  return response.json();
}

/** Escuta uma `action` vinda do SendNUIMessage. Devolve o cancelamento do listener. */
export function onNuiMessage<T>(action: string, handler: (data: T) => void): () => void {
  const listener = (event: MessageEvent) => {
    if (event.data?.action === action) handler(event.data.data as T);
  };

  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}
