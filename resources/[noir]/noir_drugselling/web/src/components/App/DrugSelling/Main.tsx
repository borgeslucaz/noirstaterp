import React, { useMemo, useRef, useState } from "react";
import "./Main.scss";
import { useDealingData, Item } from "../../../data/DrugDealingData";
import { useLocaleState } from "../../../utils/locale";
import { fetchNui } from "../../../utils/fetchNui";
import { useFormatMoney } from "../../../utils/formatMoney";

// Negociação: uma faixa baixa embaixo e no centro, para o comprador e a cena continuarem à
// vista. A fala dele, as miniaturas do que o vendedor tem no bolso, o preço do produto
// escolhido e as duas saídas.
const WELCOME_LINES = 20;

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const Main: React.FC = () => {
  const Locale = useLocaleState();
  const dealingData = useDealingData();
  const formatMoney = useFormatMoney();
  const drugs = dealingData.playerDrugs;

  const lineIndex = useMemo(() => Math.floor(Math.random() * WELCOME_LINES) + 1, []);
  const [selected, setSelected] = useState(0);
  const drug: Item | undefined = drugs[selected];
  const [price, setPrice] = useState<number>(drug ? drug.normalPrice : 0);
  const [sending, setSending] = useState(false);
  const listRef = useRef<HTMLUListElement>(null);
  const dealRef = useRef<HTMLElement>(null);

  // O tooltip mora fora da grade (que rola e cortaria), posicionado sobre a miniatura.
  const [tip, setTip] = useState<{ index: number; left: number; top: number } | null>(null);
  const showTip = (index: number, el: HTMLElement) => {
    const box = dealRef.current?.getBoundingClientRect();
    const tile = el.getBoundingClientRect();
    if (!box) return;
    setTip({ index, left: tile.left - box.left, top: tile.top - box.top });
  };
  const tipDrug = tip ? drugs[tip.index] : undefined;

  const choose = (index: number) => {
    const next = clamp(index, 0, drugs.length - 1);
    setSelected(next);
    setPrice(drugs[next].normalPrice);
    listRef.current?.children[next]?.scrollIntoView({ block: "nearest", inline: "nearest" });
  };

  const close = () => fetchNui("hideFrame");

  const sell = () => {
    if (!drug || sending) return;
    setSending(true);
    fetchNui("drugSell", { name: drug.spawn_name, price });
  };

  const loyalty = Locale["loyality"]
    ? Locale["loyality"].replace("%a", String(dealingData.playerLevel)).replace("%b", String(dealingData.playerBoost)).replace(" | ", " · ")
    : "";
  const line = Locale["dealing_welcometext_" + lineIndex] || "";

  const range = drug ? drug.priceRangeMax - drug.priceRangeMin : 0;
  const fill = drug && range > 0 ? ((price - drug.priceRangeMin) / range) * 100 : 0;
  const ideal = drug && range > 0 ? ((drug.normalPrice - drug.priceRangeMin) / range) * 100 : 50;
  // O servidor paga preço × bônus do nível × grau (vende primeiro o melhor grau).
  const topGrade = drug && drug.grades && drug.grades.length > 0 ? drug.grades[0] : null;
  const gradeMult = topGrade ? topGrade.multiplier : 1;
  const receives = drug && (gradeMult !== 1 || dealingData.playerBoost > 0)
    ? Math.floor(price * (1 + dealingData.playerBoost / 100) * gradeMult)
    : null;
  const verdict = !drug ? "" : price > drug.normalPrice ? "above" : price < drug.normalPrice ? "below" : "ideal";

  return (
    <>
      <section className="deal" aria-labelledby="deal-name" ref={dealRef}>
        <header className="deal__head">
          <h1 id="deal-name" className="deal__name">{dealingData.pedName}</h1>
          <span className="deal__tag" style={{ "--tag": dealingData.pedBorder } as React.CSSProperties} title={loyalty}>
            {dealingData.pedType}
          </span>
          <button className="deal__close" aria-label="Fechar" onClick={close}>✕</button>
        </header>

        {tipDrug && tip && (
          <div className="deal__tip" role="tooltip" style={{ left: tip.left, top: tip.top }}>
            <b>{tipDrug.label}</b>
            <span>{tipDrug.amount} no bolso · {formatMoney(tipDrug.priceRangeMin)} a {formatMoney(tipDrug.priceRangeMax)}</span>
            <span>Ideal {formatMoney(tipDrug.normalPrice)}</span>
            {tipDrug.grades && tipDrug.grades.length > 0 && (
              <span className="deal__tip-grades">
                {tipDrug.grades.map((g) => `Grau ${g.grade} ×${g.amount}`).join(" · ")}
              </span>
            )}
          </div>
        )}

        {line && <p className="deal__line">“{line}”</p>}

        <div className="deal__body">
          <ul className="deal__list" role="listbox" aria-label="Produtos" ref={listRef} onScroll={() => setTip(null)}
            style={{ "--cols": Math.min(Math.max(drugs.length, 1), 4) } as React.CSSProperties}>
            {drugs.map((item, index) => (
              <li
                key={item.spawn_name}
                role="option"
                aria-selected={index === selected}
                aria-label={`${item.label}, ${item.amount} un.`}
                tabIndex={-1}
                className="deal__item"
                onClick={() => choose(index)}
                onMouseEnter={(e) => showTip(index, e.currentTarget)}
                onMouseLeave={() => setTip(null)}
              >
                <img src={item.icon} alt="" />
                {item.grades && item.grades.length > 0 && <span className="deal__grade">{item.grades[0].grade}</span>}
                <span className="deal__qty">{item.amount}</span>
              </li>
            ))}
          </ul>

          {drug && (
            <div className="deal__price">
              <div className="deal__price-line">
                <span className="deal__label">{drug.label}</span>
                <strong>{formatMoney(price)}</strong>
              </div>
              <div className="deal__range" style={{ "--fill": `${fill}%`, "--ideal": `${ideal}%` } as React.CSSProperties}>
                <input
                  type="range"
                  min={drug.priceRangeMin}
                  max={drug.priceRangeMax}
                  step={1}
                  value={price}
                  aria-label={(Locale["pricepergram"] || "Preço por unidade").replace(/:$/, "")}
                  onChange={(e) => setPrice(Number(e.target.value))}
                />
                <span className="deal__ideal" aria-hidden="true" />
              </div>
              <div className={`deal__verdict deal__verdict--${verdict}`}>
                {verdict === "ideal" && `Preço ideal`}
                {verdict === "above" && `Acima do ideal (${formatMoney(drug.normalPrice)}): vende menos`}
                {verdict === "below" && `Abaixo do ideal (${formatMoney(drug.normalPrice)}): vende mais`}
              </div>
              {receives !== null && (
                <div className="deal__receive">
                  Recebe {formatMoney(receives)}/un.
                  {topGrade && <> · grau {topGrade.grade} ×{String(topGrade.multiplier).replace(".", ",")}</>}
                  {dealingData.playerBoost > 0 && <> · +{dealingData.playerBoost}% do nível</>}
                </div>
              )}
            </div>
          )}
        </div>

        <footer className="deal__foot">
          <button className="btn btn--secondary" onClick={close}>{Locale["dealing_nvw"] || "Deixa pra lá"}</button>
          <button className="btn btn--confirm" onClick={sell} disabled={!drug || sending} aria-busy={sending}>
            {Locale["hereyougo"] || "Fechar negócio"}
          </button>
        </footer>
      </section>

      <div className="keys" aria-hidden="true">
        <span className="key"><kbd>Esc</kbd>Fechar</span>
      </div>
    </>
  );
};

export default Main;
