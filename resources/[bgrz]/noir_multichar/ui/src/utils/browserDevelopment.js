import { players } from "../components/charDetails/data/players";

export const isBrowserDevelopment = () =>
  import.meta.env.DEV && typeof window.GetParentResourceName !== "function";

const browserResponses = {
  GetCharacters: () => players,
  getcurrentscene: () => "casino",
  CreateCharacter: () => true,
  exitcharactercreator: () => true,
  DeleteCharacter: () => true,
  PreviewCharacter: () => true,
  UpdateScene: () => true,
  playcharacter: (slot) => { const character = players.find((item) => item.id === slot); if (character?.emptyslot) window.postMessage({ action: "charactercreator", data: slot }, "*"); return true; },
  click: () => true,
  hover: () => true,
};

export async function browserNuiCallback(eventName, data) {
  const response = browserResponses[eventName];

  // Unknown callbacks stay harmless in the browser so every screen can be
  // previewed without a running FiveM client.
  if (!response) {
    console.debug(`[NUI mock] ${eventName}`, data);
    return null;
  }

  return response(data);
}
