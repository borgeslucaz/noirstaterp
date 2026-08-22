import React, { useRef, useState } from "react";
import { credits } from "./data/credits";
import { useEffect } from "react";
import { nuicallback } from "../../../utils/nuicallback";
import { useConfig } from "../../../providers/configprovider";
const Credits = () => {

    const [visible, setVisible] = useState(false);
    const ref = useRef()
    const { config } = useConfig();


    useEffect(() => {
        const handlekey = (e) => {
            if (visible) {
                if (e.keyCode === 27) {
                    setVisible(false)
                    nuicallback('exitcredits')
                }
            }
        }
    
        window.addEventListener('keydown',handlekey);
        return () => window.removeEventListener('keydown',handlekey);
      })
    
    

    const handleUseRef = () => {
        ref.current.focus()
    }


    useEffect(() => {
        handleUseRef()
    }, [])

    window.addEventListener('message', event => {
        switch (event.data.action) {
            case 'visible-credits':
                setVisible(true)
                handleUseRef()
                break
        }
    })

    return (
        <div
            ref={ref}
            tabIndex='0'
            // onKeyDown={handlekey}
            onMouseMove={handleUseRef}
            onClick={handleUseRef}
            style={{ display: visible ? 'flex' : 'none' }}
            className="h-screen bg-neutral-950 bg-opacity-90 "
        >
            <div className="ANTON text-8xl text-gray-300 p-20">{config.Lang.CREDIT}</div>
            <div>
                <div className="flex flex-col gap-4 center-abs">
                    {config.credits.map((data) => (
                        <div className="flex flex-col gap-1 items-center">
                            <div className="ANTON text-3xl text-gray-100 opacity-50">{data.title}</div>
                            <div className="ANTON text-2xl text-gray-100">{data.description}</div>
                        </div>
                    ))}
                </div>
            </div>

            <div className="flex items-center justify-center gap-1 absolute bottom-[40px] right-[20px] ">
                <div className='border-[2px] border-white text-white py-[1px] px-[10px] rounded-[7px] bg-[rgba(0,0,0,0.5)]'>
                    {config.Lang.esc}
                </div>
                <span className='text-white'>{config.Lang.back}</span>
            </div>
            <div className="ANTON text-1xl text-gray-100 flex gap-1 absolute bottom-0 right-0 p-3">{config.Lang.dev} <p className="text-primary"> {config.Lang.afterlife}</p></div>
        </div>
    )
}

export default Credits;