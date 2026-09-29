import { useState,useEffect } from "react";
import "./App.css";
import CharDetails from "./components/charDetails/CharDetails";
import Register from "./components/registeration/Register";
import Profiles from "./components/profilepicture/profiles";
import { useDispatch, useSelector } from "react-redux";
import AdminPanel from "./components/adminpanel/adminpanel";
import { updatescreen } from "./store/screen/screen";
import Loading from "./components/loading/LoadingScreen";
import { isBrowserDevelopment } from "./utils/browserDevelopment";

function App() {
  const browserDevelopment = isBrowserDevelopment();
  const [visible, setVisible] = useState(browserDevelopment);
  const dispatch = useDispatch();

  useEffect(() => {
    if (browserDevelopment) {
      dispatch(updatescreen("characterselection"));
      // No navegador não existe a cena do jogo por trás da NUI; usa uma imagem de cena no lugar.
      document.documentElement.style.setProperty("background", "url(/images/sinner.png) center/cover", "important");
    }
  }, [browserDevelopment, dispatch]);
  
      useEffect(() => {
  
        const handlemessage = (event) => {
   
          switch (event.data.action) {
            case 'visible':
              setVisible(event.data.data)
              dispatch(updatescreen('characterselection'))
              break
          }
        }
    
        window.addEventListener('message',handlemessage);
        return () => window.removeEventListener('message',handlemessage);
    
      }, [dispatch])

  return (
    <>
    {visible &&
      <div className="h-screen vignette ">
        <CharDetails />
        <Register />
      </div>
      }
      <Loading />
      <AdminPanel />
      <Profiles />
    </>
  );
}

export default App;
