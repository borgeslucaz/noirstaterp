import { useState,useEffect } from "react";
import "./App.css";
import CharDetails from "./components/charDetails/CharDetails";
import Register from "./components/registeration/Register";
import SceneSelector from "./components/sceneselector/scenesselector";
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
        <SceneSelector />
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
