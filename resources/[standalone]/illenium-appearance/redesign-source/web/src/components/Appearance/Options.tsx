import { useState, useRef, useEffect, ReactElement, useCallback, ReactNode } from 'react';
import {
  FaVideo,
  FaStreetView,
  FaUndo,
  FaRedo,
  FaSmile,
  FaMale,
  FaShoePrints,
  FaSave,
  FaTimes,
  FaTshirt,
  FaHatCowboy,
  FaSocks,
} from 'react-icons/fa';
import { GiClothes } from 'react-icons/gi';

import { CameraState, ClothesState, RotateState } from './interfaces';
import './Options.css';

interface ToggleOptionProps {
  active: boolean;
  onClick: () => void;
  children?: ReactNode;
}

interface ExtendendOptionProps {
  icon: ReactElement;
  children?: ReactNode;
}

interface OptionsProps {
  camera: CameraState;
  rotate: RotateState;
  clothes: ClothesState;
  handleSetClothes: (key: keyof ClothesState) => void;
  handleSetCamera: (key: keyof CameraState) => void;
  handleTurnAround: () => void;
  handleRotateLeft: () => void;
  handleRotateRight: () => void;
  handleSave: () => void;
  handleExit: () => void;
  enableExit: boolean;
}

const ToggleOption: React.FC<ToggleOptionProps> = ({ children, active, onClick }) => {
  return (
    <button type="button" className={`options-toggle-button ${active ? 'active' : ''}`} onClick={onClick}>
      {children}
    </button>
  );
};

const ExtendedOption: React.FC<ExtendendOptionProps> = ({ children, icon }) => {
  const [extended, setExtended] = useState(true);

  const [width, setWidth] = useState(0);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const updateWidth = () => {
      if (ref.current) {
        setWidth(ref.current.offsetWidth);
      }
    };

    updateWidth();
    setExtended(false);

    window.addEventListener('resize', updateWidth);
    return () => window.removeEventListener('resize', updateWidth);
  }, []);

  const handleMouseEnter = useCallback(() => {
    setExtended(true);
  }, []);

  const handleMouseLeave = useCallback(() => {
    setExtended(false);
  }, []);

  return (
    <div 
      className="options-extended-container"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      <div className="options-extended-icon">{icon}</div>
      <div 
        className="options-extended-children" 
        ref={ref}
        style={{ 
          opacity: extended ? 1 : 0,
          transform: extended ? 'translateX(0)' : 'translateX(1.111vh)',
          pointerEvents: extended ? 'all' : 'none'
        }}
      >
        {children}
      </div>
    </div>
  );
};

const Options: React.FC<OptionsProps> = ({
  camera,
  rotate,
  clothes,
  handleSetClothes,
  handleSetCamera,
  handleTurnAround,
  handleRotateLeft,
  handleRotateRight,
  handleExit,
  handleSave,
  enableExit
}) => {
  return (
    <div className="options-container">
      <ExtendedOption icon={<FaVideo size={20} />}>
        <ToggleOption active={camera.head} onClick={() => handleSetCamera('head')}>
          <FaSmile size={20} />
        </ToggleOption>
        <ToggleOption active={camera.body} onClick={() => handleSetCamera('body')}>
          <FaMale size={20} />
        </ToggleOption>
        <ToggleOption active={camera.bottom} onClick={() => handleSetCamera('bottom')}>
          <FaShoePrints size={20} />
        </ToggleOption>
      </ExtendedOption>
      <ExtendedOption icon={<GiClothes size={20} />}>
        <ToggleOption active={clothes.head} onClick={() => handleSetClothes('head')}>
          <FaHatCowboy size={20} />
        </ToggleOption>
        <ToggleOption active={clothes.body} onClick={() => handleSetClothes('body')}>
          <FaTshirt size={20} />
        </ToggleOption>
        <ToggleOption active={clothes.bottom} onClick={() => handleSetClothes('bottom')}>
          <FaSocks size={20} />
        </ToggleOption>
      </ExtendedOption>
      <button className="options-option" onClick={handleTurnAround}>
        <FaStreetView size={20} />
      </button>
      <ToggleOption active={rotate.left} onClick={handleRotateLeft}>
        <FaRedo size={20} />
      </ToggleOption>
      <ToggleOption active={rotate.right} onClick={handleRotateRight}>
        <FaUndo size={20} />
      </ToggleOption>
      <button className="options-option" onClick={handleSave}>
        <FaSave size={20} />
      </button>
      {enableExit &&
      <button className="options-option" onClick={handleExit}>
        <FaTimes size={20} />
      </button>}
      
    </div>
  );
};

export default Options;
