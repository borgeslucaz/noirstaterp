import { useCallback, useEffect, useRef, useState } from "preact/hooks";
import type { ComponentChildren } from "preact";
import { isBrowser, postNui, type NuiMessage } from "./nui";

type Route = "pausemenu" | "photomode";
type Phase = "entering" | "visible" | "exiting";
type Locale = Record<string, string>;

interface PlayerData {
  firstName: string;
  lastName: string;
  serverId: number;
  cash: number;
}

interface ServerInfo {
  serverName: string;
}

interface FilterInfo {
  index: number;
  name: string;
  total: number;
}

const defaultPlayer: PlayerData = {
  firstName: "Jezzy",
  lastName: "OnDuty",
  serverId: 42,
  cash: 5200,
};

const defaultServer: ServerInfo = { serverName: "NOIR" };
const defaultFilter: FilterInfo = { index: 0, name: "Nenhum", total: 0 };
const SCRAMBLE_STAGGER_MS = 70;
const SCRAMBLE_FRAME_MS = 15;
const SCRAMBLE_FRAMES = 10;
const UPPERCASE_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const LOWERCASE_LETTERS = "abcdefghijklmnopqrstuvwxyz";

function Icon({ name }: { name: "resume" | "settings" | "map" | "camera" | "exit" }) {
  const paths: Record<typeof name, ComponentChildren> = {
    resume: <polygon points="6 4 20 12 6 20 6 4" />,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1-2.9 2.9-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5v.1h-4v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1-2.9-2.9.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3v-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1 2.9-2.9.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3h4v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1 2.9 2.9-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1h.1v4h-.1a1.7 1.7 0 0 0-1.5 1Z" /></>,
    map: <><path d="m4 6 6-2 6 2 4-1v14l-6 2-6-2-4 1V6Z" /><path d="M10 4v14M16 6v14" /></>,
    camera: <><path d="M4 7h4l2-2h4l2 2h4v11H4V7Z" /><circle cx="12" cy="12.5" r="3" /></>,
    exit: <><path d="M12 2v10M8.5 8.5 12 12l3.5-3.5M5 14v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5" /></>,
  };

  return <svg viewBox="0 0 24 24" aria-hidden="true">{paths[name]}</svg>;
}

function PlayerCard({ player, locale }: { player: PlayerData; locale: Locale }) {
  const name = [player.firstName, player.lastName].filter(Boolean).join(" ");
  return <section className="player-card">
    <h2><span>{name}</span><small>#{player.serverId}</small></h2>
    <div className="cash"><span>{locale.cash || "Dinheiro"}</span><strong>${new Intl.NumberFormat("pt-BR").format(player.cash ?? 0)}</strong></div>
  </section>;
}

function ServerCard({ server }: { server: ServerInfo }) {
  return <section className="server-card"><h2>{server.serverName}</h2></section>;
}

function randomLetter(character: string) {
  if (character === " ") return " ";
  const letters = character === character.toUpperCase() && character !== character.toLowerCase()
    ? UPPERCASE_LETTERS
    : LOWERCASE_LETTERS;
  return letters[Math.floor(Math.random() * letters.length)];
}

function ScrambleText({ text, active }: { text: string; active: boolean }) {
  const [displayText, setDisplayText] = useState(text);
  const timers = useRef<number[]>([]);

  useEffect(() => setDisplayText(text), [text]);
  useEffect(() => {
    const clearTimers = () => {
      timers.current.forEach((timer) => {
        window.clearTimeout(timer);
        window.clearInterval(timer);
      });
      timers.current = [];
    };

    if (!active) {
      clearTimers();
      setDisplayText(text);
      return clearTimers;
    }

    const characters = text.split("");
    if (!characters.length) return clearTimers;
    const resolved = [...characters];

    characters.forEach((character, index) => {
      const timeout = window.setTimeout(() => {
        let frame = 0;
        const interval = window.setInterval(() => {
          frame += 1;
          const next = [...resolved];
          if (frame >= SCRAMBLE_FRAMES) {
            next[index] = character;
            resolved[index] = character;
            setDisplayText(next.join(""));
            window.clearInterval(interval);
          } else {
            next[index] = randomLetter(character);
            setDisplayText(next.join(""));
          }
        }, SCRAMBLE_FRAME_MS);
        timers.current.push(interval);
      }, SCRAMBLE_STAGGER_MS * index);
      timers.current.push(timeout);
    });

    return clearTimers;
  }, [active, text]);

  return <span className="menu-label">{displayText}</span>;
}

function MenuButton({ icon, label, danger, onClick, index }: {
  icon: Parameters<typeof Icon>[0]["name"];
  label: string;
  danger?: boolean;
  onClick: () => void;
  index: number;
}) {
  const [hovered, setHovered] = useState(false);

  return <button
    className={`menu-button${danger ? " danger" : ""}`}
    style={{ "--index": index } as never}
    aria-label={label}
    onClick={onClick}
    onMouseEnter={() => setHovered(true)}
    onMouseLeave={() => setHovered(false)}
  >
    <span className="menu-icon"><Icon name={icon} /></span><ScrambleText text={label} active={hovered} />
  </button>;
}

function PauseView({ player, server, locale, close }: {
  player: PlayerData;
  server: ServerInfo;
  locale: Locale;
  close: () => void;
}) {
  const [confirmExit, setConfirmExit] = useState(false);
  const items = [
    { icon: "resume" as const, label: locale.resume || "Continuar", action: close },
    { icon: "settings" as const, label: locale.settings || "Configurações", action: () => void postNui("openSettings") },
    { icon: "map" as const, label: locale.maps || "Mapa", action: () => void postNui("openMap") },
    { icon: "camera" as const, label: locale.photomode || "Modo Foto", action: () => void postNui("enterPhotomode") },
    { icon: "exit" as const, label: locale.exit_server || "Sair do Servidor", action: () => setConfirmExit(true), danger: true },
  ];

  return <main className="pause-view">
    <div className="shade shade-left" /><div className="shade shade-right" />
    <div className="top-left"><PlayerCard player={player} locale={locale} /></div>
    <div className="top-right"><ServerCard server={server} /></div>
    <nav>{items.map((item, index) => <MenuButton key={item.label} icon={item.icon} label={item.label} danger={item.danger} onClick={item.action} index={index} />)}</nav>
    {confirmExit && <div className="confirm-backdrop" onClick={() => setConfirmExit(false)}>
      <div className="confirm-box" onClick={(event) => event.stopPropagation()}>
        <p>{locale.exit_confirm || "Tem certeza de que deseja sair do servidor?"}</p>
        <div><button onClick={() => setConfirmExit(false)}>{locale.no || "Não"}</button><button className="confirm-yes" onClick={() => void postNui("exitServer")}>{locale.yes || "Sim"}</button></div>
      </div>
    </div>}
  </main>;
}

function CircleButton({ label, active, children, onClick }: { label: string; active?: boolean; children: ComponentChildren; onClick: () => void }) {
  return <button className={`circle-button${active ? " active" : ""}`} title={label} aria-label={label} onClick={onClick}>{children}</button>;
}

function PhotoView({ filter, blur, locale }: { filter: FilterInfo; blur: boolean; locale: Locale }) {
  const dragging = useRef(false);
  const pointer = useRef({ x: 0, y: 0 });
  const dragFrame = useRef<number>();
  const pendingDrag = useRef({ x: 0, y: 0 });
  const zoomFrame = useRef<number>();
  const pendingZoom = useRef(0);
  const [filterInput, setFilterInput] = useState(String(filter.index));

  useEffect(() => setFilterInput(String(filter.index)), [filter.index]);
  useEffect(() => {
    const move = (event: MouseEvent) => {
      if (!dragging.current) return;
      const deltaX = event.clientX - pointer.current.x;
      const deltaY = event.clientY - pointer.current.y;
      pointer.current = { x: event.clientX, y: event.clientY };
      pendingDrag.current.x += deltaX;
      pendingDrag.current.y += deltaY;
      if ((deltaX || deltaY) && !dragFrame.current) {
        dragFrame.current = window.requestAnimationFrame(() => {
          const delta = pendingDrag.current;
          pendingDrag.current = { x: 0, y: 0 };
          dragFrame.current = undefined;
          if (delta.x || delta.y) void postNui("photomodeDrag", { deltaX: delta.x, deltaY: delta.y });
        });
      }
    };
    const up = () => { dragging.current = false; };
    const wheel = (event: WheelEvent) => {
      event.preventDefault();
      pendingZoom.current += event.deltaY > 0 ? 1 : -1;
      if (!zoomFrame.current) {
        zoomFrame.current = window.requestAnimationFrame(() => {
          const delta = pendingZoom.current;
          pendingZoom.current = 0;
          zoomFrame.current = undefined;
          if (delta) void postNui("photomodeZoom", { delta });
        });
      }
    };
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", up);
    window.addEventListener("wheel", wheel, { passive: false });
    return () => {
      window.removeEventListener("mousemove", move);
      window.removeEventListener("mouseup", up);
      window.removeEventListener("wheel", wheel);
      if (dragFrame.current) window.cancelAnimationFrame(dragFrame.current);
      if (zoomFrame.current) window.cancelAnimationFrame(zoomFrame.current);
    };
  }, []);

  const applyFilter = () => {
    const index = Math.max(0, Math.min(Number.parseInt(filterInput, 10) || 0, filter.total));
    setFilterInput(String(index));
    void postNui("setFilterIndex", { index });
  };

  return <main className="photo-view">
    <div className="drag-zone" onMouseDown={(event) => { dragging.current = true; pointer.current = { x: event.clientX, y: event.clientY }; }} />
    <div className="filter-controls">
      <CircleButton label={locale.prev_filter || "Filtro anterior"} onClick={() => void postNui("cycleFilter", { direction: "prev" })}>←</CircleButton>
      <label><input value={filterInput} inputMode="numeric" onInput={(event) => setFilterInput(event.currentTarget.value.replace(/\D/g, ""))} onBlur={applyFilter} onKeyDown={(event) => event.key === "Enter" && applyFilter()} aria-label={locale.filter || "Filtro"} /><span>/{filter.total}</span></label>
      <CircleButton label={locale.next_filter || "Próximo filtro"} onClick={() => void postNui("cycleFilter", { direction: "next" })}>→</CircleButton>
    </div>
    <div className="camera-controls">
      <CircleButton label={locale.rotate_left || "Girar para a esquerda"} onClick={() => void postNui("rotateCamera", { direction: "left" })}>↶</CircleButton>
      <CircleButton label={locale.rotate_right || "Girar para a direita"} onClick={() => void postNui("rotateCamera", { direction: "right" })}>↷</CircleButton>
      <CircleButton label={locale.blur || "Desfoque de fundo"} active={blur} onClick={() => void postNui("toggleBlur")}>◉</CircleButton>
    </div>
  </main>;
}

export function App() {
  const [visible, setVisible] = useState(isBrowser());
  const [phase, setPhase] = useState<Phase>("entering");
  const [route, setRoute] = useState<Route>("pausemenu");
  const [player, setPlayer] = useState(defaultPlayer);
  const [server, setServer] = useState(defaultServer);
  const [locale, setLocale] = useState<Locale>({});
  const [filter, setFilter] = useState(defaultFilter);
  const [blur, setBlur] = useState(false);
  const closeTimer = useRef<number>();

  const hideImmediately = useCallback(() => {
    if (closeTimer.current) window.clearTimeout(closeTimer.current);
    setVisible(false);
    setPhase("entering");
  }, []);

  const beginClose = useCallback(() => {
    if (!visible || phase === "exiting" || route === "photomode") return;
    setPhase("exiting");
    closeTimer.current = window.setTimeout(() => {
      setVisible(false);
      setPhase("entering");
      void postNui("closeComplete");
    }, 650);
  }, [phase, route, visible]);

  const requestClose = useCallback(() => {
    if (route === "photomode") void postNui("exitPhotomode");
    else void postNui("close");
  }, [route]);

  useEffect(() => {
    const receive = (event: MessageEvent<NuiMessage>) => {
      const { action, data } = event.data ?? {};
      switch (action) {
        case "setLocale": case "language": setLocale((data as Locale) ?? {}); break;
        case "updatePlayerData": setPlayer((current) => ({ ...current, ...(data as Partial<PlayerData>) })); break;
        case "updateServerInfo": setServer((current) => ({ ...current, ...(data as Partial<ServerInfo>) })); break;
        case "updateFilter": setFilter(data as FilterInfo); break;
        case "updateBlur": setBlur(Boolean((data as { enabled?: boolean })?.enabled)); break;
        case "route": setRoute(data === "photomode" ? "photomode" : "pausemenu"); break;
        case "setVisible":
          if (data) { setVisible(true); setPhase("entering"); window.setTimeout(() => setPhase("visible"), 20); }
          else hideImmediately();
          break;
        case "requestClose": beginClose(); break;
        case "close": hideImmediately(); break;
      }
    };
    window.addEventListener("message", receive);
    return () => window.removeEventListener("message", receive);
  }, [beginClose, hideImmediately]);

  useEffect(() => {
    const keydown = (event: KeyboardEvent) => { if (event.key === "Escape" && visible) requestClose(); };
    window.addEventListener("keydown", keydown);
    return () => window.removeEventListener("keydown", keydown);
  }, [requestClose, visible]);

  useEffect(() => () => { if (closeTimer.current) window.clearTimeout(closeTimer.current); }, []);

  if (!visible) return null;
  return <div className={`nui phase-${phase}`}>
    {route === "photomode" ? <PhotoView filter={filter} blur={blur} locale={locale} /> : <PauseView player={player} server={server} locale={locale} close={requestClose} />}
  </div>;
}
