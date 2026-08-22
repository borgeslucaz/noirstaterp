import { React, useState, useEffect } from "react";
import profilepicture from "../../assets/profile.png";
import profilefemale from "../../assets/profile-female.png";
import { players } from "../charDetails/data/players";
import { nuicallback } from "../../utils/nuicallback";
import plus from '../../assets/plus.svg'

function Profiles() {
  const [playerdata, setPlayerData] = useState(players);
  const [counter, setCounter] = useState(0);
  const [edit, setEdit] = useState(false);
  const [visible, setVisible] = useState(false);
  const [previewimg, setPreviewimg] = useState('')

  useEffect(() => {
    const handlekey = (e) => {
      if (e.key === "Escape" && visible) {
        if (edit) {
          setEdit(false);
          setPreviewimg('')
          nuicallback('click')
        } else {
          setVisible(false);
          nuicallback('exit')
        }
      }
    };

    window.addEventListener("keydown", handlekey);
    return () => window.removeEventListener("keydown", handlekey);
  });

  useEffect(() => {
    const handlemessage = (event) => {
      switch (event.data.action) {
        case "profilepicture":
          setVisible(true);
          setPlayerData(event.data.data);
          break;
      }
    };

    window.addEventListener("message", handlemessage);
    return () => window.removeEventListener("message", handlemessage);
  }, []);


  return (
    <>
      {visible && (
        <div className="top-[50%] left-[50%] translate-y-[-50%] translate-x-[-50%] absolute">
          {edit ? (
            <div className="w-[300px] flex flex-col gap-4 items-center justify-center bg-[rgba(0,0,0,0.5)] p-6">
              <input
                type="text"
                defaultValue={playerdata[counter].img}
                placeholder={"URL"}
                onChange={() => setPreviewimg(event.target.value)}
                onMouseEnter={() => nuicallback("hover")}
                className=" border-[1px] w-[100%] border-white focus:outline-none hover:bg-[rgba(0,0,0,0.8)] bg-[rgba(0,0,0,0.5)] text-white placeholder:text-white p-[6px]"
              />

               <div
                  style={{
                    backgroundImage: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.65) 100%), url(${previewimg})`,
                    backgroundPosition: "center",
                  }}
                  className="w-[125px]  h-[150px]  border-white border-[1px] flex justify-end items-end hover:bg-[length:130px] bg-[length:120px]"
                >
                </div>

              <button
                type="submit"
                onMouseEnter={() => nuicallback("hover")}
                onClick={() => {
                    nuicallback('saveprofilepicture',{slot: playerdata[counter].id, img: previewimg}).then((response) => {
                      setPlayerData(response);
                    });

                    setEdit(false);
                    setPreviewimg('')
                }}
                className="border w-[110px] p-1 flex justify-center hover:bg-[rgba(255,255,255,0.8)] bg-[rgba(255,255,255,1.0)]"
              >
                <img src={plus} alt="plus" className="w-[25px] invert" />
              </button>

            </div>
          ) : (
            
            <div className="bg-[rgba(0,0,0,0.5)] p-3 flex flex-col items-center justify-center gap-3">
              <div className="text-[40px] font-bold">PERFIS</div> 
            <div className="  w-[fit-content] flex gap-5">
              {playerdata.map((data, index) => !data.emptyslot && (
                <div
                  onClick={() => {
                    if (!data.emptyslot) {
                      setEdit(true);
                      setCounter(index);
                      setPreviewimg(data.img);
                      nuicallback('click')
                    }
                  }}
                  onMouseEnter={() => nuicallback('hover')}
                  style={{
                    backgroundImage: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.65) 100%), url(${data.img}), url(${data.sex ? profilepicture : profilefemale})`,
                    backgroundPosition: "center",
                  }}
                  className="w-[125px]  h-[150px]  border-white border-[1px] flex justify-end items-end duration-75 hover:bg-[length:130px] bg-[length:120px]"
                >
                  <div className="text-[#FFFFFF] font-bold uppercase flex justify-center items-center w-[100%] flex-col p-1">
                    <div className="relative top-2 text-[13px] opacity-60">
                      {!data.emptyslot && data.lastname}
                    </div>
                    <div className="text-[20px]">
                      {data.emptyslot ? "NOVA VAGA" : data.firstname}
                    </div>
                  </div>
                </div>
              ))}
              </div>
            </div>
          )}
        </div>
      )}
    </>
  );
}

export default Profiles;
