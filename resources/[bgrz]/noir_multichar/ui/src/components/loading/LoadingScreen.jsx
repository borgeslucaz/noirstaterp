import React from "react";
import { useEffect, useState } from "react";
const Loading = () => {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const handlemessage = (event) => {
      switch (event.data.action) {
        case "loadingscreen":
            setVisible(event.data.data);
          break;
      }
    };

    window.addEventListener("message", handlemessage);
    return () => window.removeEventListener("message", handlemessage);
  }, []);

  return (
    
      <>
        <div
        style={{opacity: visible ? 1.0 : 0.0}}
          className="flex items-center justify-center h-screen bg-black transition-opacity duration-300"
        >
        </div>
      </>
  );
};

export default Loading;
