import { useState, useEffect } from 'react';
import { useNuiState } from '../../hooks/nuiState';
import { FaMars, FaVenus } from 'react-icons/fa';
import { FiChevronLeft, FiChevronRight } from 'react-icons/fi';

import Section from './components/Section';
import Item from './components/Item';
import Input from './components/Input';
import RangeInput from './components/RangeInput';

import { PedHeadBlend, HeadBlendSettings } from './interfaces';
import './HeadBlend.css';
import femaleImg from '../../img/female.png';
import maleImg from '../../img/male.png';

const MOTHER_IMAGES: { [key: number]: string } = {
  0: 'https://static.wikia.nocookie.net/gtawiki/images/b/b3/CharacterCreator-GTAO-Parent-Female-Amelia.png',
  1: 'https://static.wikia.nocookie.net/gtawiki/images/5/5b/CharacterCreator-GTAO-Parent-Female-Sophia.png',
  2: 'https://static.wikia.nocookie.net/gtawiki/images/e/e3/CharacterCreator-GTAO-Parent-Female-Nicole.png',
  3: 'https://static.wikia.nocookie.net/gtawiki/images/5/51/CharacterCreator-GTAO-Parent-Female-Ava.png',
  4: 'https://static.wikia.nocookie.net/gtawiki/images/9/97/CharacterCreator-GTAO-Parent-Female-Emma.png',
  5: 'https://static.wikia.nocookie.net/gtawiki/images/6/60/CharacterCreator-GTAO-Parent-Female-Ashley.png',
  6: 'https://static.wikia.nocookie.net/gtawiki/images/1/14/CharacterCreator-GTAO-Parent-Female-Audrey.png',
  7: 'https://static.wikia.nocookie.net/gtawiki/images/2/25/CharacterCreator-GTAO-Parent-Female-Natalie.png',
  8: 'https://static.wikia.nocookie.net/gtawiki/images/3/34/CharacterCreator-GTAO-Parent-Female-Zoe.png',
  9: 'https://static.wikia.nocookie.net/gtawiki/images/5/5c/CharacterCreator-GTAO-Parent-Female-Isabella.png',
  10: 'https://static.wikia.nocookie.net/gtawiki/images/5/51/CharacterCreator-GTAO-Parent-Female-Brianna.png',
  11: 'https://static.wikia.nocookie.net/gtawiki/images/1/15/CharacterCreator-GTAO-Parent-Female-Olivia.png',
  12: 'https://static.wikia.nocookie.net/gtawiki/images/a/a6/CharacterCreator-GTAO-Parent-Female-Misty.png',
};

const FATHER_IMAGES: { [key: number]: string } = {
  0: 'https://static.wikia.nocookie.net/gtawiki/images/a/ae/CharacterCreator-GTAO-Parent-Male-Niko.png',
  1: 'https://static.wikia.nocookie.net/gtawiki/images/3/36/CharacterCreator-GTAO-Parent-Male-Ethan.png',
  2: 'https://static.wikia.nocookie.net/gtawiki/images/2/21/CharacterCreator-GTAO-Parent-Male-Daniel.png',
  3: 'https://static.wikia.nocookie.net/gtawiki/images/3/33/CharacterCreator-GTAO-Parent-Male-Kevin.png',
  4: 'https://static.wikia.nocookie.net/gtawiki/images/2/27/CharacterCreator-GTAO-Parent-Male-Louis.png',
  5: 'https://static.wikia.nocookie.net/gtawiki/images/9/95/CharacterCreator-GTAO-Parent-Male-Isaac.png',
  6: 'https://static.wikia.nocookie.net/gtawiki/images/6/6c/CharacterCreator-GTAO-Parent-Male-Angel.png',
  7: 'https://static.wikia.nocookie.net/gtawiki/images/7/7d/CharacterCreator-GTAO-Parent-Male-Alex.png',
  8: 'https://static.wikia.nocookie.net/gtawiki/images/d/dd/CharacterCreator-GTAO-Parent-Male-Evan.png',
  9: 'https://static.wikia.nocookie.net/gtawiki/images/4/47/CharacterCreator-GTAO-Parent-Male-Andrew.png',
  10: 'https://static.wikia.nocookie.net/gtawiki/images/4/46/CharacterCreator-GTAO-Parent-Male-Noah.png',
  11: 'https://static.wikia.nocookie.net/gtawiki/images/0/0b/CharacterCreator-GTAO-Parent-Male-Benjamin.png',
  12: 'https://static.wikia.nocookie.net/gtawiki/images/6/65/CharacterCreator-GTAO-Parent-Male-John.png',
  13: 'https://static.wikia.nocookie.net/gtawiki/images/5/5f/CharacterCreator-GTAO-Parent-Male-Gabriel.png',
  14: 'https://static.wikia.nocookie.net/gtawiki/images/f/f0/CharacterCreator-GTAO-Parent-Male-Juan.png',
  15: 'https://static.wikia.nocookie.net/gtawiki/images/4/44/CharacterCreator-GTAO-Parent-Male-Michael.png',
  16: 'https://static.wikia.nocookie.net/gtawiki/images/7/74/CharacterCreator-GTAO-Parent-Male-Adrian.png',
  17: 'https://static.wikia.nocookie.net/gtawiki/images/d/df/CharacterCreator-GTAO-Parent-Male-Joshua.png',
  18: 'https://static.wikia.nocookie.net/gtawiki/images/2/2a/CharacterCreator-GTAO-Parent-Male-Claude.png',
  19: 'https://static.wikia.nocookie.net/gtawiki/images/8/80/CharacterCreator-GTAO-Parent-Male-Diego.png',
  20: 'https://static.wikia.nocookie.net/gtawiki/images/3/38/CharacterCreator-GTAO-Parent-Male-Samuel.png',
  21: 'https://static.wikia.nocookie.net/gtawiki/images/3/31/CharacterCreator-GTAO-Parent-Male-Anthony.png',
  22: 'https://static.wikia.nocookie.net/gtawiki/images/e/e3/CharacterCreator-GTAO-Parent-Male-Vincent.png',
  23: 'https://static.wikia.nocookie.net/gtawiki/images/b/b6/CharacterCreator-GTAO-Parent-Male-Santiago.png'
};

interface HeadBlendProps {
  settings: HeadBlendSettings;
  storedData: PedHeadBlend;
  data: PedHeadBlend;
  model: string;
  handleHeadBlendChange: (key: keyof PedHeadBlend, value: number) => void;
  handleModelChange?: (value: string) => void;
}

const HeadBlend = ({ settings, storedData, data, model, handleHeadBlendChange, handleModelChange }: HeadBlendProps) => {
  const { locales } = useNuiState();
  const [motherImageError, setMotherImageError] = useState<number | null>(null);
  const [fatherImageError, setFatherImageError] = useState<number | null>(null);

  useEffect(() => {
    setMotherImageError(null);
  }, [data.shapeFirst]);

  useEffect(() => {
    setFatherImageError(null);
  }, [data.shapeSecond]);

  if (!locales) {
    return null;
  }

  const isMale = model === 'mp_m_freemode_01';

  const calculateSliderPercentage = (value: number, min: number, max: number) => {
    return ((value - min) / (max - min)) * 100;
  };

  const getMotherImage = (value: number): string | null => {
    if (motherImageError === value) {
      return null;
    }
    
    const imageKeys = Object.keys(MOTHER_IMAGES).map(Number).sort((a, b) => a - b);
    const maxIndex = Math.max(...imageKeys);
    
    let imageIndex = value;
    if (value > maxIndex) {
      imageIndex = value % (maxIndex + 1);
    }
    
    return MOTHER_IMAGES[imageIndex] || null;
  };

  const handleMotherImageError = (value: number) => {
    setMotherImageError(value);
    if (value !== 0 && MOTHER_IMAGES[value]) {
      handleHeadBlendChange('shapeFirst', 0);
    }
  };

  const getFatherImage = (value: number): string | null => {
    if (fatherImageError === value) {
      return null;
    }
    
    const imageKeys = Object.keys(FATHER_IMAGES).map(Number).sort((a, b) => a - b);
    const maxIndex = Math.max(...imageKeys);
    
    let imageIndex = value;
    if (value > maxIndex) {
      imageIndex = value % (maxIndex + 1);
    }
    
    return FATHER_IMAGES[imageIndex] || null;
  };

  const handleFatherImageError = (value: number) => {
    setFatherImageError(value);
    if (value !== 0 && FATHER_IMAGES[value]) {
      handleHeadBlendChange('shapeSecond', 0);
    }
  };

  return (
    <div className="head-blend-container">
      <div className="title">Escolha o gênero</div>
      <div className="gender-buttons-container">
        <div
          className={`gender-button ${isMale ? 'active' : ''}`}
          onClick={() => {
            if (handleModelChange) {
              handleModelChange('mp_m_freemode_01');
            }
          }}
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30" fill="none">
            <rect width="30" height="30" rx="5" fill="white" fillOpacity="0.06" />
            <path d="M10.5895 20.6785L13.9228 17.3447C15.1979 18.2999 16.7874 18.7365 18.3714 18.5666C19.9554 18.3967 21.4163 17.633 22.4599 16.4291C23.5035 15.2253 24.0524 13.6707 23.9961 12.0784C23.9397 10.4861 23.2823 8.97422 22.1563 7.84717C21.0302 6.72013 19.519 6.06158 17.9269 6.0041C16.3349 5.94663 14.7802 6.4945 13.5758 7.53741C12.3714 8.58033 11.6067 10.0409 11.4358 11.625C11.2648 13.2091 11.7002 14.7992 12.6543 16.0751L9.32009 19.4098L8.05069 18.1393C7.88224 17.971 7.65382 17.8765 7.41567 17.8765C7.17753 17.8766 6.94917 17.9713 6.78084 18.1398C6.61251 18.3083 6.51799 18.5367 6.51807 18.7749C6.51816 19.0131 6.61284 19.2415 6.78129 19.4098L8.05069 20.6803L6.27407 22.4563C6.18833 22.5391 6.11993 22.6382 6.07288 22.7477C6.02583 22.8573 6.00107 22.9751 6.00003 23.0943C5.999 23.2135 6.02171 23.3318 6.06685 23.4421C6.11199 23.5525 6.17865 23.6527 6.26294 23.737C6.34723 23.8213 6.44747 23.888 6.55779 23.9331C6.66812 23.9783 6.78634 24.001 6.90554 24C7.02474 23.9989 7.14254 23.9742 7.25207 23.9271C7.36159 23.88 7.46065 23.8116 7.54347 23.7259L9.32009 21.949L10.5895 23.2186C10.6723 23.3043 10.7714 23.3728 10.8809 23.4198C10.9904 23.4669 11.1082 23.4916 11.2274 23.4927C11.3466 23.4937 11.4648 23.471 11.5752 23.4258C11.6855 23.3807 11.7857 23.314 11.87 23.2297C11.9543 23.1454 12.021 23.0452 12.0661 22.9348C12.1112 22.8245 12.134 22.7062 12.1329 22.587C12.1319 22.4678 12.1071 22.35 12.0601 22.2404C12.013 22.1309 11.9446 22.0318 11.8589 21.949L10.5895 20.6785ZM17.6816 7.82731C18.5694 7.82731 19.4372 8.0906 20.1754 8.5839C20.9136 9.07719 21.4889 9.77833 21.8286 10.5987C22.1684 11.419 22.2572 12.3216 22.084 13.1925C21.9109 14.0633 21.4833 14.8633 20.8556 15.4911C20.2278 16.119 19.428 16.5465 18.5573 16.7197C17.6866 16.893 16.7841 16.8041 15.9639 16.4643C15.1437 16.1245 14.4426 15.5491 13.9494 14.8108C13.4562 14.0725 13.1929 13.2046 13.1929 12.3167C13.1929 11.126 13.6658 9.98412 14.5076 9.14221C15.3494 8.30029 16.4911 7.82731 17.6816 7.82731Z" fill="white" fill-opacity="0.5" />
          </svg>
          <span>Masculino</span>
        </div>
        <div
          className={`gender-button ${!isMale ? 'active' : ''}`}
          onClick={() => {
            if (handleModelChange) {
              handleModelChange('mp_f_freemode_01');
            }
          }}
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="30" height="30" viewBox="0 0 30 30" fill="none">
            <rect width="30" height="30" rx="5" fill="white" fill-opacity="0.06"/>
            <path d="M23.1017 6H18.6099C18.3717 6 18.1432 6.09465 17.9747 6.26312C17.8062 6.43159 17.7116 6.66009 17.7116 6.89834C17.7116 7.1366 17.8062 7.3651 17.9747 7.53357C18.1432 7.70204 18.3717 7.79669 18.6099 7.79669H20.9331L16.082 12.6477C14.8057 11.6926 13.2149 11.2564 11.6299 11.427C10.0449 11.5976 8.58342 12.3623 7.53958 13.5672C6.49573 14.772 5.94707 16.3276 6.00403 17.9207C6.06099 19.5138 6.71935 21.0262 7.84657 22.1534C8.9738 23.2807 10.4862 23.939 12.0793 23.996C13.6724 24.0529 15.228 23.5043 16.4328 22.4604C17.6377 21.4166 18.4024 19.9551 18.573 18.3701C18.7436 16.7851 18.3074 15.1943 17.3523 13.918L22.2033 9.06695V11.3901C22.2033 11.6283 22.298 11.8568 22.4664 12.0253C22.6349 12.1938 22.8634 12.2884 23.1017 12.2884C23.3399 12.2884 23.5684 12.1938 23.7369 12.0253C23.9054 11.8568 24 11.6283 24 11.3901V6.89834C24 6.66009 23.9054 6.43159 23.7369 6.26312C23.5684 6.09465 23.3399 6 23.1017 6ZM12.3215 22.1702C11.4331 22.1702 10.5647 21.9068 9.82606 21.4132C9.0874 20.9197 8.51168 20.2181 8.17171 19.3974C7.83174 18.5766 7.74279 17.6735 7.91611 16.8022C8.08942 15.9309 8.51722 15.1305 9.1454 14.5023C9.77357 13.8742 10.5739 13.4464 11.4452 13.2731C12.3165 13.0997 13.2197 13.1887 14.0404 13.5287C14.8612 13.8686 15.5627 14.4444 16.0563 15.183C16.5498 15.9217 16.8132 16.7901 16.8132 17.6785C16.8132 18.2683 16.6971 18.8524 16.4713 19.3974C16.2456 19.9423 15.9147 20.4375 15.4976 20.8546C15.0806 21.2717 14.5854 21.6026 14.0404 21.8283C13.4955 22.054 12.9114 22.1702 12.3215 22.1702Z" fill="white" fill-opacity="0.5"/>
          </svg>
          <span>Feminino</span>
        </div>
      </div>

      {/* <div className="title">Choose the Parents</div> */}

      <div className="parents-container">
        <img 
          className="parents-image" 
          src={getMotherImage(data.shapeFirst) || femaleImg} 
          alt="Female"
          onError={() => handleMotherImageError(data.shapeFirst)}
        />
        <img 
          className="parents-image" 
          src={getFatherImage(data.shapeSecond) || maleImg} 
          alt="Male"
          onError={() => handleFatherImageError(data.shapeSecond)}
        />
      </div>

      <div className="parent-selector">
        <span>Mãe</span>
        <div>
          <button className="arrow-button" onClick={() => handleHeadBlendChange('shapeFirst', Math.max(settings.shapeFirst.min, data.shapeFirst - 1))}>
            <FiChevronLeft />
          </button>
          <span className="parent-name">{data.shapeFirst}</span>
          <button className="arrow-button" onClick={() => handleHeadBlendChange('shapeFirst', Math.min(settings.shapeFirst.max, data.shapeFirst + 1))}>
            <FiChevronRight />
          </button>
        </div>
      </div>

      <div className="parent-selector">
        <span>Pai</span>
        <div>
          <button className="arrow-button" onClick={() => handleHeadBlendChange('shapeSecond', Math.max(settings.shapeSecond.min, data.shapeSecond - 1))}>
            <FiChevronLeft />
          </button>
          <span className="parent-name">{data.shapeSecond}</span>
          <button className="arrow-button" onClick={() => handleHeadBlendChange('shapeSecond', Math.min(settings.shapeSecond.max, data.shapeSecond + 1))}>
            <FiChevronRight />
          </button>
        </div>
      </div>

      <div 
        className="slider-container"
        style={{ '--slider-percentage': `${calculateSliderPercentage(data.shapeMix, settings.shapeMix.min, settings.shapeMix.max)}%` } as React.CSSProperties}
      >
        <span>Semelhança</span>
        <div>
          <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M2.54972 8.15473L4.40155 6.30263C5.10993 6.83327 5.99301 7.07582 6.87302 6.98144C7.75302 6.88706 8.5646 6.46276 9.14439 5.79396C9.72417 5.12516 10.0291 4.26152 9.99781 3.3769C9.96651 2.49227 9.6013 1.65235 8.9757 1.02621C8.35009 0.40007 7.51055 0.0342106 6.62608 0.00228033C5.74161 -0.0296499 4.87788 0.27472 4.20877 0.854117C3.53966 1.43351 3.11485 2.24492 3.01986 3.12498C2.92488 4.00505 3.16676 4.88843 3.69682 5.5973L1.84449 7.4499L1.13927 6.74408C1.04569 6.65055 0.918786 6.59803 0.786485 6.59807C0.654183 6.59812 0.527319 6.65073 0.433801 6.74433C0.340282 6.83793 0.287771 6.96485 0.287817 7.09717C0.287864 7.22949 0.340465 7.35637 0.43405 7.4499L1.13927 8.15573L0.15226 9.14239C0.104625 9.1884 0.0666299 9.24345 0.0404913 9.3043C0.0143527 9.36516 0.000594288 9.43062 1.88309e-05 9.49685C-0.000556627 9.56308 0.0120624 9.62876 0.0371397 9.69007C0.0622169 9.75137 0.09925 9.80706 0.146078 9.8539C0.192907 9.90073 0.248592 9.93777 0.309886 9.96285C0.37118 9.98794 0.436854 10.0006 0.503076 9.99998C0.569299 9.9994 0.634744 9.98564 0.695593 9.9595C0.756441 9.93336 0.811475 9.89536 0.857482 9.84772L1.84449 8.86056L2.54972 9.56589C2.59572 9.61353 2.65076 9.65153 2.71161 9.67767C2.77245 9.70381 2.8379 9.71757 2.90412 9.71815C2.97035 9.71872 3.03602 9.7061 3.09731 9.68102C3.15861 9.65594 3.21429 9.6189 3.26112 9.57207C3.30795 9.52523 3.34498 9.46954 3.37006 9.40824C3.39514 9.34693 3.40776 9.28125 3.40718 9.21502C3.4066 9.14878 3.39285 9.08333 3.36671 9.02247C3.34057 8.96161 3.30257 8.90657 3.25494 8.86056L2.54972 8.15473ZM6.48978 1.01517C6.98299 1.01517 7.46513 1.16145 7.87522 1.4355C8.28531 1.70955 8.60493 2.09907 8.79368 2.55481C8.98242 3.01054 9.0318 3.51202 8.93558 3.99582C8.83936 4.47963 8.60186 4.92403 8.25311 5.27284C7.90435 5.62164 7.46002 5.85918 6.97628 5.95541C6.49255 6.05165 5.99115 6.00226 5.53548 5.81349C5.07981 5.62471 4.69035 5.30504 4.41634 4.89489C4.14232 4.48474 3.99607 4.00254 3.99607 3.50925C3.99607 2.84778 4.2588 2.2134 4.72646 1.74567C5.19412 1.27794 5.82841 1.01517 6.48978 1.01517Z" fill="white" fill-opacity="0.5"/>
          </svg>
          <input
            type="range"
            min={settings.shapeMix.min}
            max={settings.shapeMix.max}
            step={settings.shapeMix.factor}
            value={data.shapeMix}
            onChange={(e) => {
              const newValue = Number(e.target.value);
              handleHeadBlendChange('shapeMix', newValue);
            }}
          />
          <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M9.50092 0H7.00552C6.87315 0 6.74621 0.0525816 6.65262 0.146177C6.55902 0.239773 6.50644 0.366716 6.50644 0.49908C6.50644 0.631445 6.55902 0.758387 6.65262 0.851983C6.74621 0.945579 6.87315 0.99816 7.00552 0.99816H8.29614L5.60111 3.69319C4.89204 3.16256 4.00828 2.92025 3.12773 3.01502C2.24719 3.10979 1.43523 3.53462 0.855321 4.20398C0.275408 4.87334 -0.0294062 5.73754 0.00223862 6.6226C0.0338834 7.50767 0.399637 8.34789 1.02587 8.97413C1.65211 9.60036 2.49233 9.96612 3.3774 9.99776C4.26246 10.0294 5.12666 9.72459 5.79602 9.14468C6.46538 8.56476 6.89021 7.75281 6.98498 6.87227C7.07975 5.99172 6.83743 5.10796 6.30681 4.39889L9.00184 1.70386V2.99448C9.00184 3.12685 9.05442 3.25379 9.14802 3.34738C9.24161 3.44098 9.36856 3.49356 9.50092 3.49356C9.63328 3.49356 9.76023 3.44098 9.85382 3.34738C9.94742 3.25379 10 3.12685 10 2.99448V0.49908C10 0.366716 9.94742 0.239773 9.85382 0.146177C9.76023 0.0525816 9.63328 0 9.50092 0ZM3.51196 8.98344C3.01841 8.98344 2.53595 8.83709 2.12559 8.56289C1.71522 8.2887 1.39538 7.89897 1.20651 7.44299C1.01764 6.98702 0.968218 6.48527 1.0645 6.00121C1.16079 5.51715 1.39845 5.07252 1.74744 4.72353C2.09643 4.37454 2.54107 4.13688 3.02513 4.04059C3.50919 3.9443 4.01093 3.99372 4.46691 4.18259C4.92288 4.37146 5.31261 4.69131 5.58681 5.10167C5.86101 5.51204 6.00736 5.9945 6.00736 6.48804C6.00736 6.81574 5.94281 7.14024 5.81741 7.44299C5.692 7.74575 5.50819 8.02084 5.27647 8.25256C5.04475 8.48428 4.76966 8.66809 4.46691 8.79349C4.16415 8.9189 3.83966 8.98344 3.51196 8.98344Z" fill="white" fill-opacity="0.5"/>
          </svg>
        </div>
      </div>

      <div 
        className="slider-container"
        style={{ '--slider-percentage': `${calculateSliderPercentage(data.skinMix, settings.skinMix.min, settings.skinMix.max)}%` } as React.CSSProperties}
      >
        <span>Cor da pele</span>
        <div>
          <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M2.54972 8.15473L4.40155 6.30263C5.10993 6.83327 5.99301 7.07582 6.87302 6.98144C7.75302 6.88706 8.5646 6.46276 9.14439 5.79396C9.72417 5.12516 10.0291 4.26152 9.99781 3.3769C9.96651 2.49227 9.6013 1.65235 8.9757 1.02621C8.35009 0.40007 7.51055 0.0342106 6.62608 0.00228033C5.74161 -0.0296499 4.87788 0.27472 4.20877 0.854117C3.53966 1.43351 3.11485 2.24492 3.01986 3.12498C2.92488 4.00505 3.16676 4.88843 3.69682 5.5973L1.84449 7.4499L1.13927 6.74408C1.04569 6.65055 0.918786 6.59803 0.786485 6.59807C0.654183 6.59812 0.527319 6.65073 0.433801 6.74433C0.340282 6.83793 0.287771 6.96485 0.287817 7.09717C0.287864 7.22949 0.340465 7.35637 0.43405 7.4499L1.13927 8.15573L0.15226 9.14239C0.104625 9.1884 0.0666299 9.24345 0.0404913 9.3043C0.0143527 9.36516 0.000594288 9.43062 1.88309e-05 9.49685C-0.000556627 9.56308 0.0120624 9.62876 0.0371397 9.69007C0.0622169 9.75137 0.09925 9.80706 0.146078 9.8539C0.192907 9.90073 0.248592 9.93777 0.309886 9.96285C0.37118 9.98794 0.436854 10.0006 0.503076 9.99998C0.569299 9.9994 0.634744 9.98564 0.695593 9.9595C0.756441 9.93336 0.811475 9.89536 0.857482 9.84772L1.84449 8.86056L2.54972 9.56589C2.59572 9.61353 2.65076 9.65153 2.71161 9.67767C2.77245 9.70381 2.8379 9.71757 2.90412 9.71815C2.97035 9.71872 3.03602 9.7061 3.09731 9.68102C3.15861 9.65594 3.21429 9.6189 3.26112 9.57207C3.30795 9.52523 3.34498 9.46954 3.37006 9.40824C3.39514 9.34693 3.40776 9.28125 3.40718 9.21502C3.4066 9.14878 3.39285 9.08333 3.36671 9.02247C3.34057 8.96161 3.30257 8.90657 3.25494 8.86056L2.54972 8.15473ZM6.48978 1.01517C6.98299 1.01517 7.46513 1.16145 7.87522 1.4355C8.28531 1.70955 8.60493 2.09907 8.79368 2.55481C8.98242 3.01054 9.0318 3.51202 8.93558 3.99582C8.83936 4.47963 8.60186 4.92403 8.25311 5.27284C7.90435 5.62164 7.46002 5.85918 6.97628 5.95541C6.49255 6.05165 5.99115 6.00226 5.53548 5.81349C5.07981 5.62471 4.69035 5.30504 4.41634 4.89489C4.14232 4.48474 3.99607 4.00254 3.99607 3.50925C3.99607 2.84778 4.2588 2.2134 4.72646 1.74567C5.19412 1.27794 5.82841 1.01517 6.48978 1.01517Z" fill="white" fill-opacity="0.5"/>
          </svg>
          <input
            type="range"
            min={settings.skinMix.min}
            max={settings.skinMix.max}
            step={settings.skinMix.factor}
            value={data.skinMix}
            onChange={(e) => {
              const newValue = Number(e.target.value);
              handleHeadBlendChange('skinMix', newValue);
            }}
          />
          <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10" fill="none">
            <path d="M9.50092 0H7.00552C6.87315 0 6.74621 0.0525816 6.65262 0.146177C6.55902 0.239773 6.50644 0.366716 6.50644 0.49908C6.50644 0.631445 6.55902 0.758387 6.65262 0.851983C6.74621 0.945579 6.87315 0.99816 7.00552 0.99816H8.29614L5.60111 3.69319C4.89204 3.16256 4.00828 2.92025 3.12773 3.01502C2.24719 3.10979 1.43523 3.53462 0.855321 4.20398C0.275408 4.87334 -0.0294062 5.73754 0.00223862 6.6226C0.0338834 7.50767 0.399637 8.34789 1.02587 8.97413C1.65211 9.60036 2.49233 9.96612 3.3774 9.99776C4.26246 10.0294 5.12666 9.72459 5.79602 9.14468C6.46538 8.56476 6.89021 7.75281 6.98498 6.87227C7.07975 5.99172 6.83743 5.10796 6.30681 4.39889L9.00184 1.70386V2.99448C9.00184 3.12685 9.05442 3.25379 9.14802 3.34738C9.24161 3.44098 9.36856 3.49356 9.50092 3.49356C9.63328 3.49356 9.76023 3.44098 9.85382 3.34738C9.94742 3.25379 10 3.12685 10 2.99448V0.49908C10 0.366716 9.94742 0.239773 9.85382 0.146177C9.76023 0.0525816 9.63328 0 9.50092 0ZM3.51196 8.98344C3.01841 8.98344 2.53595 8.83709 2.12559 8.56289C1.71522 8.2887 1.39538 7.89897 1.20651 7.44299C1.01764 6.98702 0.968218 6.48527 1.0645 6.00121C1.16079 5.51715 1.39845 5.07252 1.74744 4.72353C2.09643 4.37454 2.54107 4.13688 3.02513 4.04059C3.50919 3.9443 4.01093 3.99372 4.46691 4.18259C4.92288 4.37146 5.31261 4.69131 5.58681 5.10167C5.86101 5.51204 6.00736 5.9945 6.00736 6.48804C6.00736 6.81574 5.94281 7.14024 5.81741 7.44299C5.692 7.74575 5.50819 8.02084 5.27647 8.25256C5.04475 8.48428 4.76966 8.66809 4.46691 8.79349C4.16415 8.9189 3.83966 8.98344 3.51196 8.98344Z" fill="white" fill-opacity="0.5"/>
          </svg>
        </div>
      </div>
    </div>
  );
};

export default HeadBlend;
