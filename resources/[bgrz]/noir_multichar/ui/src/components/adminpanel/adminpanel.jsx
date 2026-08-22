import { React, useState, useEffect } from "react";
import { players } from "../charDetails/data/players";
import profilepicture from "../../assets/profile.png";
import profilefemale from "../../assets/profile-female.png";
import { nuicallback } from "../../utils/nuicallback";
import Profile from "./profile";

function AdminPanel() {
  const [visible, setVisible] = useState(false);
  const [characters, setCharacters] = useState(players);
  const [searchvalue, setSearchvalue] = useState('');
  const [editing, setEditing] = useState(false);
  const [editingid, setEditingid] = useState(0);
  const [slots, setSlots] = useState(0);

  const handleinput = (e) => {
    setSearchvalue(e.target.value)
  }

    useEffect(() => {
      const handlekey = (e) => {
        if (e.keyCode === 27 && visible) {
          nuicallback("click");
          if (editing){
            setEditing(false);
            nuicallback('GetAllCharacters').then((response) => {
              setCharacters(response)
            })
          }else{
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
          case 'adminpanel':
            setCharacters(event.data.data)
            setVisible(true)
            break
        }
      }
  
      window.addEventListener('message',handlemessage);
      return () => window.removeEventListener('message',handlemessage);
  
    }, [])
  


  return (
    visible &&
    <>
      {editing ? (
        <Profile character={characters[editingid]} characterslots={slots} />
      ) : (
        <div className="flex flex-col items-center justify-center gap-6 absolute top-[50%] left-[50%] translate-x-[-50%] translate-y-[-50%] w-[600px] h-[700px] bg-[rgba(0,0,0,0.6)]">
          <div className="text-5xl font-bold w-[100%] flex items-center justify-center h-[130px]"><div>PERFIS</div></div>

          <div>
            <svg
              className="w-4 fill-white absolute ml-[320px] mt-2"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 512 512"
            >
              <path d="M416 208c0 45.9-14.9 88.3-40 122.7L502.6 457.4c12.5 12.5 12.5 32.8 0 45.3s-32.8 12.5-45.3 0L330.7 376c-34.4 25.2-76.8 40-122.7 40C93.1 416 0 322.9 0 208S93.1 0 208 0S416 93.1 416 208zM208 352a144 144 0 1 0 0-288 144 144 0 1 0 0 288z" />
            </svg>
            <input
            onMouseEnter={() => nuicallback('hover')}
            onChange={handleinput}
              className=" outline-none px-2 w-[350px] h-[35px] bg-[rgba(0,0,0,0.6)] hover:bg-[rgba(0,0,0,0.8)] border-[1px] border-white"
              type="text"
              placeholder="Name"
            />
          </div>

          <div className="grid grid-cols-3 gap-3  h-[480px] overflow-y-scroll">
            {characters.filter(character => (character.firstname.toLowerCase().includes(searchvalue.toLowerCase()))).map((data,index) => (
              <div onClick={() => {
                nuicallback('GetSlots',data.identifier).then((response) => {
                  setSlots(response)
                  setEditingid(index);
                  setEditing(true);
                })
              }} onMouseEnter={() => nuicallback('hover')} style={{backgroundImage: `radial-gradient(circle, rgba(0,0,0,0) 0%, rgba(0,0,0,0.65) 100%), url(${data.sex ? profilepicture : profilefemale})`,backgroundPosition: 'center',backgroundRepeat: 'none'}} className="w-[125px] h-[150px] border-[1px] border-[#C9C9C9] flex flex-col justify-between p-2 duration-75 hover:bg-[length:130px] bg-[length:120px]">
                <div className="w-6 h-6 flex justify-center items-center border-white border-[1px] rounded-[100%] ">
                  <div>{data.id}</div>
                </div>

                <div className="text-[#FFFFFF] font-bold uppercase flex justify-center items-center w-[100%] flex-col">
                  <div className="relative top-2 text-[13px] opacity-60">
                  {data.lastname}
                  </div>
                  <div className="text-[20px]">{data.firstname}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </>
  );
}

export default AdminPanel;
