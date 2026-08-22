import React from "react";
import { useState, useEffect } from "react";
import { useDispatch, useSelector } from "react-redux";
import { updatescreen } from "../../store/screen/screen";
import { nuicallback } from "../../utils/nuicallback";
import { useConfig } from "../../providers/configprovider";
import ESCButton from "../registeration/inputFields/ESCButton";

function SceneSelector() {
  const { config } = useConfig();
  const [counter, setCounter] = useState('');
  
  const dispatch = useDispatch();

  const scene = useSelector((state) => state.screen);

  const handleclick = (id) => {
    setCounter(id);
    nuicallback("UpdateScene", id);
  };



  useEffect(() => {
    nuicallback('getcurrentscene').then((response) => {
      setCounter(response)
    })
  }, [])
  


    useEffect(() => {
  
      const handlekey = (e) => {
        if (e.key === 'Escape' && scene == 'settings') {
          dispatch(updatescreen('characterselection'))
          nuicallback('click')
        }
      }
    
  
      window.addEventListener('keydown',handlekey);
      return () => window.removeEventListener('keydown',handlekey);
    })
  

  return (

    scene == 'settings' &&
      <>
      <div className="absolute top-10 left-[50%] translate-x-[-50%] an">
        <div className="flex flex-row gap-[15px]">
          {config.Scenes.map(data => (
            <div
            onMouseEnter={() => {
              if (counter != data.id){
                nuicallback('hover')
              }
            }}
              onClick={() => handleclick(data.id)}
              style={{
                backgroundImage: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.8) 100%), url(../images/${data.id}.png)`,
                backgroundSize: 'cover',
                backgroundPosition: 'center',
                transform: counter == data.id ? "scale(1.1)" : "scale(1.0)",
              }}
              className="w-[150px] h-[80px] transition bg-[#00000086] border-[1px] border-[#C9C9C9]"
            >
              <div className="px-2 py-1 text-white">{data.label}</div>
            </div>
          ))}
        </div>
      </div>
      <ESCButton exitfunc={() => {
        dispatch(updatescreen('characterselection'))
        nuicallback('click')
      }} />
      </>
    
    
  );
}

export default SceneSelector;
