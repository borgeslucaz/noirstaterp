import { useNuiEvent } from "@/hooks/useNuiEvent.ts";
import { useEffect, useState, lazy, Suspense } from "react";
import CarHud from "./components/car-hud";
import Compass from "./components/compass";
import PlayerStatus from "./components/player-status";
import { useSetMinimapState, type MinimapStateInterface } from "./states/minimap";
import type { ConfigInterface } from "./types/config";
import { debug, setDebugMode } from "./utils/debug";
import { fetchNui } from "./utils/fetchNui";
import { isDevPreview } from "./utils/misc";
import { useCompassLocationStore, useCompassAlwaysStore } from "./states/compass-location";
import { useSkewedStyleStore, useSkewAmountStore } from "@/states/skewed-style";

const DevPreview = import.meta.env.DEV ? lazy(() => import("./components/dev-preview")) : null;

export function App() {
  const [visible, setVisible] = useState(isDevPreview());
  const setMinimapState = useSetMinimapState();
  const [compassLocation, setCompassLocation] = useCompassLocationStore();
  const [compassAlways, setCompassAlways] = useCompassAlwaysStore();
  const [skewedStyle, setSkewedStyle] = useSkewedStyleStore();
  const [skewAmount, setSkewAmount] = useSkewAmountStore();

  useNuiEvent("state::visibility::app::set", (state) => {
    const newState = state === "toggle" ? !visible : state;
    setVisible(newState);

    fetchNui("state::visibility::app::sync", newState);

    debug(`(App) NUI message received: setVisible ${state}`, `newState: ${newState}`);
  });

  useEffect(() => {
    fetchNui("APP_LOADED")
      .then((res: { config: ConfigInterface; minimap: MinimapStateInterface }) => {
        // APP_LOADED currently returns config directly; also accept the wrapped form.
        const config = "config" in res ? res.config : res as unknown as ConfigInterface;
        setDebugMode(config.debug ?? false);
        if (res.minimap) setMinimapState(res.minimap);
        setCompassLocation(config.compassLocation);
        setCompassAlways(config.compassAlways);
        setSkewedStyle(config.useSkewedStyle);
        setSkewAmount(config.skewAmount);
      })
      .catch((err) => {
        console.error(err);
      })
      .finally(() => {
        debug("(App) fetched uiLoaded callback");
      });
  }, []);

  if (!visible) {
    debug("(App) Returning with no children since the app is not visible.");
    return <></>;
  }

  return (
    <>
      {isDevPreview() && DevPreview && <Suspense fallback={null}><DevPreview /></Suspense>}
      <PlayerStatus />
      <CarHud />

      {compassLocation !== "hidden" && (
        <>
          <Compass />
        </>
      )}
    </>
  );
}
