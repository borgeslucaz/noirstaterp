import { React, useState, useEffect } from "react";
import profilepicture from "../../assets/profile.png";
import profilefemale from "../../assets/profile-female.png";
import banner from "../../assets/banner.png";
import job from '../../assets/job.png'
import cash from '../../assets/cash.png'
import bank from '../../assets/bank.png'
import dob from '../../assets/dob.png'
import leftarrow from '../../assets/arrow-left.png'
import rightarrow from '../../assets/arrow-right.png'
import { nuicallback } from "../../utils/nuicallback";


function Profile(data) {


  const [slots, setSlots] = useState(data.characterslots)

  const handleslotchange = (state) => {
    if (state){
      nuicallback('updateslot',{identifier: data.identifier,slot: slots + 1})
      setSlots(slots + 1)
    }else if (slots > 0){
      nuicallback('updateslot',{identifier: data.identifier,slot: slots - 1})
        setSlots(slots - 1)
    }
  }


  let character = data.character

  return (
    <>
      <div className="flex flex-col items-center  absolute top-[50%] left-[50%] translate-y-[-50%] translate-x-[-50%] w-[300px] h-[600px] bg-[rgba(0,0,0,0.6)]">
        <div
          className="w-[100%] h-[130px]"
          style={{
            background: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.65) 100%), url(${banner})`,
            backgroundSize: "cover",
          }}
        ></div>
        <div
          style={{
            backgroundImage: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.65) 100%), url(${character.sex ? profilepicture : profilefemale})`,
          }}
          className="w-[100px] relative bottom-10 h-[100px] rounded-[100%]   border-white border-[1px] flex justify-end items-end bgcenter"
        ></div>

        <div className="text-[#FFFFFF] relative bottom-8 font-bold uppercase flex justify-center items-center w-[100%] flex-col">
          <div className="relative top-2 text-[20px] opacity-60">{character.firstname}</div>
          <div className="text-[30px]">{character.lastname}</div>
        </div>


        <div className="flex flex-col gap-4 items-center justify-center relative bottom-6"> 
        <div className=" flex flex-row items-center justify-start w-[225px] h-[35px] bg-[rgba(0,0,0,0.6)] border-[1px] border-white">
                <div className="p-4">
                    <div className="w-2 h-2 rounded-[100%] bg-white"></div>
                </div>
                <div className="uppercase w-[170px] overflow-hidden">{character.identifier}</div>
            </div>
            <div className=" flex flex-row items-center justify-start w-[225px] h-[35px] bg-[rgba(0,0,0,0.6)] border-[1px] border-white">
                <img className="px-3" src={job} alt="" />
                <div className="uppercase">{character.job}</div>
            </div>
            <div className=" flex flex-row items-center justify-start w-[225px] h-[35px] bg-[rgba(0,0,0,0.6)] border-[1px] border-white">
                <img className="px-3" src={cash} alt="" />
                <div className="uppercase">{character.cash}</div>
            </div>
            <div className=" flex flex-row items-center justify-start w-[225px] h-[35px] bg-[rgba(0,0,0,0.6)] border-[1px] border-white">
                <img className="px-3" src={bank} alt="" />
                <div className="uppercase">{character.bank}</div>
            </div>
            <div className=" flex flex-row items-center justify-start w-[225px] h-[35px] bg-[rgba(0,0,0,0.6)] border-[1px] border-white">
                <img className="px-3" src={dob} alt="" />
                <div className="uppercase">{character.dob}</div>
            </div>
        </div>


        <div className="flex flex-col items-center gap-1 relative bottom-3">
            <div>ADICIONAR VAGAS</div>
            <div className="flex flex-row items-center gap-4">
        <img className="w-10 h-9 p-2 opacity-70 hover:opacity-100" onClick={() => handleslotchange(false)} onMouseEnter={() => nuicallback('hover')} src={leftarrow} alt="" />
            <div className="w-[70px] h-[40px] bg-[rgba(0,0,0,0.6)] flex items-center justify-center"><div>{slots}</div></div>
            <img  className="w-10 h-9 p-2 opacity-70 hover:opacity-100" onClick={() => handleslotchange(true)} onMouseEnter={() => nuicallback('hover')} src={rightarrow} alt="" />
        </div>
        </div>
      </div>
    </>
  );
}

export default Profile;
