import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import DeleteConfirm from "../confirmpage/deleteconfirm";
import { nuicallback } from "../../utils/nuicallback";
import { updatescreen } from "../../store/screen/screen";
import "@fontsource/montserrat/latin-500.css";
import "@fontsource/montserrat/latin-600.css";
import "@fontsource/montserrat/latin-800.css";
import "./charDetails.css";

const upper = (value, fallback = "DESCONHECIDO") => String(value || fallback).toUpperCase();

function NoirIcon({ name }) {
  const paths = {
    scene: <path d="M21 3 3 10.5l7.5 3L14 21z" />,
    delete: <path d="M5 7h14M9 7V4h6v3m2 0-1 14H8L7 7m4 4v6m3-6v6" />,
  };
  return <svg viewBox="0 0 24 24" aria-hidden="true">{paths[name]}</svg>;
}

// Linhas retas finas no canto superior esquerdo, formando quadrados; puramente decorativas.
// Tamanho do nome em destaque sai do comprimento; "NOVO PERSONAGEM" é o teto.
const nameLength = (character) => character?.emptyslot
  ? "NOVO PERSONAGEM".length
  : Math.max(`${character?.firstname || ""} ${character?.lastname || ""}`.trim().length, "NOVO PERSONAGEM".length);

function CornerLines() {
  return <svg className="noir-corner" viewBox="0 0 220 220" aria-hidden="true">
    <path d="M0 56H180M0 132H110M56 0V190M132 0V120M92 56V170M0 96H70" />
  </svg>;
}

export default function CharDetails() {
  const [characters, setCharacters] = useState([]);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const dispatch = useDispatch();
  const scene = useSelector((state) => state.screen);
  // Offsets da roda no último render, para saber qual item deu a volta (e não animar a travessia).
  const wheelOffsets = useRef({});
  const pendingOffsets = useRef({});
  useEffect(() => { wheelOffsets.current = pendingOffsets.current; });
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

  // Ordem da lista embaixo do nome: personagens na ordem dos slots e um "novo personagem" no fim.
  // ↑/↓ (e ←/→) andam nessa ordem, com volta ao início.
  const cycle = useMemo(() => {
    const filled = characters.map((character, index) => (character.emptyslot ? -1 : index)).filter((index) => index >= 0);
    const empty = characters[selectedIndex]?.emptyslot ? selectedIndex : characters.findIndex((character) => character.emptyslot);
    return empty >= 0 ? [...filled, empty] : filled;
  }, [characters, selectedIndex]);

  const step = useCallback((direction) => {
    if (cycle.length < 2) return;
    const position = cycle.indexOf(selectedIndex);
    const target = cycle[(position + direction + cycle.length) % cycle.length];
    nuicallback("click", direction > 0).catch(() => {});
    selectCharacter(target);
  }, [cycle, selectCharacter, selectedIndex]);

  const play = useCallback(() => {
    if (!selected) return;
    dispatch(updatescreen(""));
    nuicallback("playcharacter", selected.id).catch(() => {});
  }, [dispatch, selected]);

  useEffect(() => {
    if (scene !== "characterselection") return undefined;
    const handleKey = (event) => {
      if (event.key === "ArrowUp" || event.key === "ArrowLeft") { event.preventDefault(); step(-1); }
      if (event.key === "ArrowDown" || event.key === "ArrowRight") { event.preventDefault(); step(1); }
      if (event.key === "Enter") play();
    };
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [play, scene, step]);

  const displayName = useMemo(() => selected?.emptyslot
    ? "NOVO PERSONAGEM"
    : upper(`${selected?.firstname || ""} ${selected?.lastname || ""}`.trim()), [selected]);

  if (scene === "deleteconfirm" && selected) {
    return <DeleteConfirm id={selected.id} characterName={displayName} />;
  }

  if (scene !== "characterselection") return null;

  const wheelPosition = Math.max(cycle.indexOf(selectedIndex), 0);
  pendingOffsets.current = {};
  const openScreen = (screen) => { dispatch(updatescreen(screen)); nuicallback("click").catch(() => {}); };

  return <div className="noir-character-select">
    <div className="noir-shade" />
    <CornerLines />

    <nav className="noir-toolbar" aria-label="Opções">
      {selected && !selected.emptyslot && <button type="button" className="noir-toolbar__danger" onClick={() => openScreen("deleteconfirm")} aria-label="Excluir personagem" title="Excluir personagem"><NoirIcon name="delete" /></button>}
      <span className="noir-toolbar__sep" />
      <button type="button" onClick={() => openScreen("settings")} aria-label="Trocar cena" title="Trocar cena"><NoirIcon name="scene" /></button>
    </nav>

    {selected ? <div className="noir-wheel-wrap">
      {cycle.length > 1 && <div className="noir-wheel__arrows">
        <button type="button" onClick={() => step(-1)} aria-label="Personagem anterior">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 15 6-6 6 6" /></svg>
        </button>
        <button type="button" className="noir-wheel__down" onClick={() => step(1)} aria-label="Próximo personagem">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg>
        </button>
      </div>}

      {/* Roda vertical circular: o selecionado fica parado no meio e os outros giram em volta.
          Cada item se posiciona pela distância circular (--off) até o selecionado; os pequenos
          têm altura fixa, então nada precisa ser medido. */}
      <ol className="noir-wheel" style={{ "--sel-len": nameLength(selected) }} aria-label="Personagens">
        {cycle.map((index, position) => {
          const character = characters[index];
          const isSelected = index === selectedIndex;
          const key = character.citizenid !== "UNKNOWN" ? character.citizenid : "novo";
          const name = character.emptyslot
            ? (isSelected ? "NOVO PERSONAGEM" : "+ NOVO PERSONAGEM")
            : upper(`${character.firstname || ""} ${character.lastname || ""}`.trim());
          let offset = (position - wheelPosition + cycle.length) % cycle.length;
          if (offset > Math.floor(cycle.length / 2)) offset -= cycle.length;
          const previous = wheelOffsets.current[key];
          const jumped = previous !== undefined && Math.abs(offset - previous) > 1;
          pendingOffsets.current[key] = offset;
          return <li
            key={key}
            className={"noir-wheel__item"
              + (offset === 0 ? " is-selected" : offset > 0 ? " is-below" : " is-above")
              + (character.emptyslot ? " is-new" : "")
              + (Math.abs(offset) > 2 ? " is-far" : "")
              + (jumped ? " is-jump" : "")}
            style={{ "--off": offset, "--len": nameLength(character) }}
            aria-current={isSelected ? "true" : undefined}
          >
            <button
              type="button"
              className="noir-wheel__name"
              tabIndex={isSelected ? -1 : 0}
              onMouseEnter={() => !isSelected && nuicallback("hover").catch(() => {})}
              onClick={() => { if (!isSelected) { nuicallback("click").catch(() => {}); selectCharacter(index); } }}
            >{name}</button>
          </li>;
        })}
      </ol>
    </div> : <div className="noir-wheel-wrap"><p className="noir-wheel__empty">SEM PERSONAGENS</p></div>}

    {selected?.emptyslot && <dl key={selectedIndex} className="noir-facts">
      <div>
        <dd>COMECE SUA NOVA HISTÓRIA</dd>
      </div>
    </dl>}

    {selected && !selected.emptyslot && <dl key={selectedIndex} className="noir-facts">
      <div>
        <dt>EMPREGO</dt>
        <dd>{upper(selected.additionalInfo?.job, "DESEMPREGADO")}</dd>
      </div>
      {selected.additionalInfo?.gang && <div>
        <dt>GANG</dt>
        <dd>{upper(selected.additionalInfo.gang)}{selected.additionalInfo.gangGrade ? <small> · {upper(selected.additionalInfo.gangGrade)}</small> : null}</dd>
      </div>}
    </dl>}

    {selected && <div className="noir-cta">
      <button type="button" className="noir-cta__action" onMouseEnter={() => nuicallback("hover").catch(() => {})} onClick={play}>
        {selected.emptyslot ? "CRIAR" : "JOGAR"}
      </button>
      <div className="noir-hint">
        ou pressione <kbd>ENTER</kbd> para {selected.emptyslot ? "criar" : "jogar"}
      </div>
    </div>}

    <span className="noir-mark" aria-hidden="true">◇</span>
  </div>;
}
