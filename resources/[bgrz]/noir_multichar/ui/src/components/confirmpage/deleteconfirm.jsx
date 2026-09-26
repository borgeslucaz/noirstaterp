import React, { useCallback, useEffect, useRef, useState } from "react";
import { useDispatch } from "react-redux";
import { nuicallback } from "../../utils/nuicallback";
import { useConfig } from "../../providers/configprovider";
import { updatescreen } from "../../store/screen/screen";
import ESCButton from "../registeration/inputFields/ESCButton";
import { CURTAIN_MS } from "../registeration/curtain";
import "../registeration/registration.css";
import "./deleteconfirm.css";

// Mesmo padrão da criação: cortina preta, régua vertical e Montserrat. A confirmação continua
// sendo segurar ENTER (cada repetição de tecla enche a barra; soltar zera).
const DeleteConfirm = ({ id, characterName }) => {
  const dispatch = useDispatch();
  const { config } = useConfig();
  const [progress, setProgress] = useState(0);
  // Contagem e disparo fora do setState: o updater pode rodar duas vezes (StrictMode), e a
  // exclusão tem que sair uma vez só.
  const progressRef = useRef(0);
  const deletedRef = useRef(false);
  const [leaving, setLeaving] = useState(false);
  const leavingRef = useRef(false);

  // Voltar: o conteúdo some e a cortina sobe; a seleção aparece quando ela termina.
  const back = useCallback(() => {
    if (leavingRef.current || deletedRef.current) return;
    leavingRef.current = true;
    setLeaving(true);
    nuicallback("click");
    setTimeout(() => dispatch(updatescreen("characterselection")), CURTAIN_MS);
  }, [dispatch]);

  useEffect(() => {
    const handleDown = (event) => {
      if (event.key === "Escape") return back();
      if (event.key !== "Enter" || deletedRef.current || leavingRef.current) return;

      progressRef.current += 2;
      setProgress(progressRef.current);
      if (progressRef.current > 100) {
        deletedRef.current = true;
        dispatch(updatescreen(""));
        nuicallback("DeleteCharacter", id);
      }
    };
    const handleUp = () => {
      progressRef.current = 0;
      setProgress(0);
    };

    window.addEventListener("keydown", handleDown);
    window.addEventListener("keyup", handleUp);
    return () => {
      window.removeEventListener("keydown", handleDown);
      window.removeEventListener("keyup", handleUp);
    };
  }, [back, dispatch, id]);

  return (
    <section className={`noir-create noir-delete${leaving ? " is-leaving is-lifting" : ""}`} aria-label="Excluir personagem">
      <div className="noir-create__curtain" />

      <main className="noir-delete__panel">
        <div className="noir-create__heading noir-delete__heading">
          <span className="noir-delete__eyebrow">EXCLUIR PERSONAGEM</span>
          <h1>{characterName}</h1>
          <p>{config.Lang.deletedescription}</p>
        </div>

        <div className="noir-delete__hold">
          <div className="noir-delete__bar" aria-hidden="true">
            <span style={{ width: `${Math.min(progress, 100)}%` }} />
          </div>
          <div className="noir-delete__hint">
            Segure <kbd>ENTER</kbd> para excluir. Essa ação não pode ser desfeita.
          </div>
        </div>
      </main>

      <ESCButton exitfunc={back} />
    </section>
  );
};

export default DeleteConfirm;
