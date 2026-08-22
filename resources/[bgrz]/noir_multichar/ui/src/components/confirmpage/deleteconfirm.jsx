import React from "react";
import { useState } from "react";
import { nuicallback } from "../../utils/nuicallback";
import { useEffect } from "react";
import { useConfig } from "../../providers/configprovider";
import { useDispatch } from "react-redux";
import { updatescreen } from "../../store/screen/screen";
import ESCButton from "../registeration/inputFields/ESCButton";

const DeleteConfirm = ({ id, characterName }) => {
  const [confirmvalue, setConfirmvalue] = useState(0);

  const dispatch = useDispatch();
  const { config } = useConfig();

  useEffect(() => {
    const handlekey = (e) => {
      if (e.keyCode === 27) {
        dispatch(updatescreen("characterselection"));
        nuicallback("click");
      } else if (e.keyCode === 13) {
        setConfirmvalue(confirmvalue + 2);
        if (confirmvalue > 99) {
          dispatch(updatescreen(""));
          nuicallback("DeleteCharacter", id);
        }
      }
    };

    window.addEventListener("keydown", handlekey);
    return () => window.removeEventListener("keydown", handlekey);
  });

  useEffect(() => {
    const handlekey = () => {
      setConfirmvalue(0);
    };

    window.addEventListener("keyup", handlekey);
    return () => window.removeEventListener("keyup", handlekey);
  });

  return (
    <>
      <div className="h-screen bg-neutral-950 bg-opacity-90 an">
        <div className="flex flex-col items-center gap-4 absolute center-abs">
          <div className="text-[100px] font-bold text-white relative top-7">
            CONFIRMAR
          </div>
          <div className="flex items-center justify-center gap-1">
            <span className="text-white">{config.Lang.deletedescription}</span>
          </div>
          <div className="text-sm tracking-[0.28em] text-white/60 uppercase">{characterName}</div>
          <div className="flex items-center justify-center">
            <div className="relative flex items-center justify-center border-2 border-white w-[clamp(16rem,40vw,24rem)] h-10 overflow-hidden text-white">
              <div
                style={{ width: `${Math.min(confirmvalue, 100)}%` }}
                className="absolute inset-y-0 left-0 bg-white tr2"
              ></div>
              <span className="relative z-10 whitespace-nowrap text-sm font-bold text-white mix-blend-difference">
                {config.Lang.enter}
              </span>
            </div>
          </div>
        </div>

        <ESCButton
          exitfunc={() => {
            dispatch(updatescreen("characterselection"));
            nuicallback("click");
          }}
        />
      </div>
    </>
  );
};

export default DeleteConfirm;
