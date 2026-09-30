import React, { useState, useEffect } from "react";
import { isEnvBrowser } from "../../utils/misc";
import { fetchNui } from "../../utils/fetchNui";
import { useNuiEvent } from "../../hooks/useNuiEvent";
import { useLocale } from "../../utils/locale";
import { SetCurrencyData } from "../../data/CurrencyData";
import { CurrencyData } from "../../data/CurrencyData";
import Main from "./DrugSelling/Main";
import { DrugDealingData, SetDealingData } from "../../data/DrugDealingData";

import "./App.scss";
import { PRESETS, dealingFor } from "../../demo/demo"

const App: React.FC = () => {
  const [drugSellingVisible, setDrugSellingVisible] = useState(false);
  const [currencyData, setCurrencyData] = SetCurrencyData()
  const [dealingData, setDealingData] = SetDealingData()

  useNuiEvent<boolean>('setDrugSellingVisible', setDrugSellingVisible);
  useNuiEvent<CurrencyData>('setCurrency', ({ format, style, currency }) => {
    setCurrencyData({
      format: format,
      style: style,
      currency: currency
    })
  })

  useNuiEvent<DrugDealingData>("setDrugDealingData", (data) => {
    setDealingData(data);
  });

  const toggleVisibility = (setter: React.Dispatch<React.SetStateAction<boolean>>) => () => {
    setter((prev) => !prev);
  };

  useEffect(() => {
    if (drugSellingVisible) {
      const keyHandler = (e: KeyboardEvent) => {
        if (["Escape"].includes(e.code)) {
          if (!isEnvBrowser()) fetchNui("hideFrame");
          else setDrugSellingVisible(false);
        }
      };
      window.addEventListener("keydown", keyHandler);

      return () => window.removeEventListener("keydown", keyHandler);
    }
  }, [drugSellingVisible]);

  const [, setLocale] = useLocale()
  useNuiEvent<{
    locale: { [key: string]: string }
  }>('setLanguage', ({ locale }) => {
    setLocale((current) => ({ ...current, ...locale }))
    fetchNui('languageConfirmation', {})
  })

  return (
    <>
      {isEnvBrowser() && (
        <div className="preview">
          <button onClick={toggleVisibility(setDrugSellingVisible)}>
            {drugSellingVisible ? "Fechar negociação" : "Abrir negociação"}
          </button>
          {PRESETS.map((count) => (
            <button
              key={count}
              onClick={() => {
                setDrugSellingVisible(false);
                setDealingData(dealingFor(count));
                setTimeout(() => setDrugSellingVisible(true), 0);
              }}
            >
              {count} {count === 1 ? "droga" : "drogas"}
            </button>
          ))}
        </div>
      )}

      {drugSellingVisible && <Main />}
    </>
  );
};

export default App;
