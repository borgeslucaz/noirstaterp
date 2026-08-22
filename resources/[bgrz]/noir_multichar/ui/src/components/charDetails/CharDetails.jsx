import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import DeleteConfirm from "../confirmpage/deleteconfirm";
import { formatNumberToCurrency } from "../../utils/formatNumbersToCurrency";
import { nuicallback } from "../../utils/nuicallback";
import { updatescreen } from "../../store/screen/screen";
import "./charDetails.css";

const upper = (value, fallback = "DESCONHECIDO") => String(value || fallback).toUpperCase();
const padSlot = (value) => String(value || 0).padStart(2, "0");

function NoirIcon({ name }) {
  const paths = {
    cash: <path d="M3 6.5h18v11H3zM7 10h.01M17 14h.01M12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5Z" />,
    job: <path d="M9 6V4h6v2m-12 4h18v9H3zm0 0 7 4h4l7-4" />,
    location: <path d="M12 21s6-5.1 6-11a6 6 0 1 0-12 0c0 5.9 6 11 6 11Zm0-8.5A2.5 2.5 0 1 0 12 7a2.5 2.5 0 0 0 0 5.5Z" />,
    settings: <path d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm7-3.5 2-1-2-3-2.2.3-1.2-1L15 5h-3.5l-.8 2.3-1.3.8L7 8 5 11l1.7 1.5v1.2L5 15l2 3 2.4-.2 1.2.8.9 2.4H15l.7-2.4 1.2-.8 2.1.2 2-3-2-1Z" />,
    delete: <path d="M5 7h14M9 7V4h6v3m2 0-1 14H8L7 7m4 4v6m3-6v6" />,
  };
  return <svg viewBox="0 0 24 24" aria-hidden="true">{paths[name]}</svg>;
}

function CharacterInfo({ info }) {
  const rows = [
    ["cash", "DINHEIRO", formatNumberToCurrency(Number(info.cash) || 0, "$")],
    ["job", "EMPREGO", upper(info.job, "DESEMPREGADO")],
    ["location", "ÚLTIMA LOCALIZAÇÃO", upper(info.lastSeen)],
  ];

  return <div className="noir-info">{rows.map(([icon, label, value]) => (
    <div className="noir-info__row" key={label}>
      <NoirIcon name={icon} />
      <div><span>{label}</span><strong>{value}</strong></div>
    </div>
  ))}</div>;
}

function CharacterCard({ character, index, selected, onSelect }) {
  const name = character.emptyslot
    ? "NOVO PERSONAGEM"
    : upper(`${character.firstname || ""} ${character.lastname || ""}`.trim());
  const subtitle = character.emptyslot
    ? "CRIE UMA NOVA HISTÓRIA"
    : upper(character.additionalInfo?.job, "DESEMPREGADO");

  return <button
    type="button"
    className={"noir-card" + (selected ? " noir-card--selected" : "")}
    data-character-index={index}
    aria-label={`Selecionar ${name}`}
    aria-current={selected ? "true" : undefined}
    onMouseEnter={() => !selected && nuicallback("hover").catch(() => {})}
    onClick={() => onSelect(index)}
  >
    <span className="noir-card__number">{character.emptyslot ? "+" : padSlot(character.id)}</span>
    <span className="noir-card__copy"><strong>{name}</strong><small>{subtitle}</small></span>
  </button>;
}

export default function CharDetails() {
  const [characters, setCharacters] = useState([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const cardsRef = useRef(null);
  const dispatch = useDispatch();
  const scene = useSelector((state) => state.screen);
  const selected = characters[selectedIndex] ?? null;

  const setCharacterList = useCallback((nextCharacters) => {
    const safeCharacters = Array.isArray(nextCharacters) ? nextCharacters : [];
    setCharacters(safeCharacters);
    setSelectedIndex((current) => Math.min(current, Math.max(safeCharacters.length - 1, 0)));
  }, []);

  useEffect(() => {
    if (scene !== "characterselection") return;
    nuicallback("GetCharacters").then(setCharacterList).catch(() => setCharacterList([]));
  }, [scene, setCharacterList]);

  useEffect(() => {
    const handleMessage = (event) => {
      if (event.data.action === "characterselection") {
        dispatch(updatescreen("characterselection"));
        setCharacterList(event.data.data);
      }
    };
    window.addEventListener("message", handleMessage);
    return () => window.removeEventListener("message", handleMessage);
  }, [dispatch, setCharacterList]);

  const selectCharacter = useCallback((index) => {
    const character = characters[index];
    if (!character || index === selectedIndex) return;
    setSelectedIndex(index);
    nuicallback("PreviewCharacter", { emptyslot: character.emptyslot, counter: index }).catch(() => {});
  }, [characters, selectedIndex]);

  const previous = useCallback(() => {
    if (selectedIndex > 0) {
      nuicallback("click", false).catch(() => {});
      selectCharacter(selectedIndex - 1);
    }
  }, [selectCharacter, selectedIndex]);

  const next = useCallback(() => {
    if (selectedIndex < characters.length - 1) {
      nuicallback("click", true).catch(() => {});
      selectCharacter(selectedIndex + 1);
    }
  }, [characters.length, selectCharacter, selectedIndex]);

  useEffect(() => {
    const container = cardsRef.current;
    const card = container?.querySelector('[data-character-index="' + selectedIndex + '"]');
    if (!container || !card) return;

    const centeredPosition = card.offsetLeft - (container.clientWidth - card.offsetWidth) / 2;
    container.scrollTo({ left: Math.max(0, centeredPosition), behavior: "smooth" });
  }, [characters.length, selectedIndex]);

  const play = useCallback(() => {
    if (!selected) return;
    dispatch(updatescreen(""));
    nuicallback("playcharacter", selected.id).catch(() => {});
  }, [dispatch, selected]);

  useEffect(() => {
    if (scene !== "characterselection") return undefined;
    const handleKey = (event) => {
      if (event.key === "ArrowLeft") previous();
      if (event.key === "ArrowRight") next();
      if (event.key === "Enter") play();
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [next, play, previous, scene]);

  const displayName = useMemo(() => selected?.emptyslot
    ? "NOVO PERSONAGEM"
    : upper(`${selected?.firstname || ""} ${selected?.lastname || ""}`.trim()), [selected]);

  if (scene === "deleteconfirm" && selected) {
    return <DeleteConfirm id={selected.id} characterName={displayName} />;
  }

  if (scene !== "characterselection") return null;

  return <div className="noir-character-select">
    <div className="noir-overlay noir-overlay--left" />
    <div className="noir-overlay noir-overlay--bottom" />
    <header className="noir-brand"><span className="noir-brand__mark">◇</span><div><strong>NOIR STATE</strong><small>ROLEPLAY</small></div></header>

    {selected ? <main className={`noir-panel${selected.emptyslot ? " noir-panel--empty" : ""}`}>
      <span className="noir-slot">{padSlot(selected.id)}</span>
      <h1>{displayName}</h1>
      <div className="noir-divider" />
      {selected.emptyslot ? <p className="noir-empty-copy">CRIE UMA NOVA HISTÓRIA</p> : <CharacterInfo info={selected.additionalInfo || {}} />}
      <button type="button" className="noir-primary" onMouseEnter={() => nuicallback("hover").catch(() => {})} onClick={play}>
        <span>{selected.emptyslot ? "CRIAR PERSONAGEM" : "JOGAR COM PERSONAGEM"}</span><span aria-hidden="true">→</span>
      </button>
    </main> : <main className="noir-panel"><p className="noir-empty-copy">NENHUM PERSONAGEM DISPONÍVEL</p></main>}

    <nav className="noir-carousel" aria-label="Personagens">
      <button type="button" className="noir-arrow" onClick={previous} disabled={selectedIndex === 0} aria-label="Personagem anterior">‹</button>
      <div className="noir-cards" ref={cardsRef}>{characters.map((character, index) => <CharacterCard key={character.citizenid !== "UNKNOWN" ? character.citizenid : `slot-${character.id}`} character={character} index={index} selected={index === selectedIndex} onSelect={selectCharacter} />)}</div>
      <button type="button" className="noir-arrow" onClick={next} disabled={selectedIndex >= characters.length - 1} aria-label="Próximo personagem">›</button>
    </nav>

    <div className="noir-utilities">
      <button type="button" onClick={() => { dispatch(updatescreen("settings")); nuicallback("click").catch(() => {}); }}><NoirIcon name="settings" />CONFIGURAÇÕES</button>
      {selected && !selected.emptyslot && <button type="button" className="noir-delete" onClick={() => { dispatch(updatescreen("deleteconfirm")); nuicallback("click").catch(() => {}); }}><NoirIcon name="delete" />EXCLUIR PERSONAGEM</button>}
    </div>

    <div className="noir-counter"><strong>{padSlot(selectedIndex + 1)}</strong><span>/ {padSlot(characters.length)}</span></div>
  </div>;
}
