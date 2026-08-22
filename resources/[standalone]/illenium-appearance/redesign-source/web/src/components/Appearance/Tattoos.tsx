import { useState, useCallback, useEffect } from 'react';
import { useNuiState } from '../../hooks/nuiState';
import RangeInput from './components/RangeInput';
import Button from './components/Button';
import { TattoosSettings, TattooList, Tattoo } from './interfaces';
import './Components.css';
import './Tattoos.css';

interface TattoosProps {
  settings: TattoosSettings;
  data: TattooList;
  storedData: TattooList;
  handleApplyTattoo: (value: Tattoo, opacity: number) => void;
  handlePreviewTattoo: (value: Tattoo, opacity: number) => void;
  handleDeleteTattoo: (value: Tattoo) => void;
  handleClearTattoos: () => void;
}

const Tattoos = ({ settings, data, storedData, handleApplyTattoo, handlePreviewTattoo, handleDeleteTattoo, handleClearTattoos }: TattoosProps) => {
  const { locales } = useNuiState();

  if (!locales || !settings) {
    return null;
  }

  const { items } = settings;
  const keys = Object.keys(items || {}).filter(key => key !== 'ZONE_HAIR');

  // Her zone için current tattoo index'ini tutmak için state
  const [currentTattooIndices, setCurrentTattooIndices] = useState<{ [key: string]: number }>({});
  const [opacities, setOpacities] = useState<{ [key: string]: number }>({});

  // Her zone için mevcut tattoo'yu al
  const getCurrentTattoo = useCallback((zone: string): Tattoo | null => {
    const zoneItems = items[zone] || [];
    if (zoneItems.length === 0) return null;
    const index = currentTattooIndices[zone] ?? 0;
    return zoneItems[index] || null;
  }, [items, currentTattooIndices]);

  // Her zone için opacity'yi al
  const getOpacity = useCallback((zone: string): number => {
    const currentTattoo = getCurrentTattoo(zone);
    if (!currentTattoo) return settings.opacity.min;

    const appliedTattoos = data[zone] || [];
    const appliedTattoo = appliedTattoos.find(t => t.name === currentTattoo.name);
    
    if (opacities[zone] !== undefined) {
      return opacities[zone];
    }
    
    return appliedTattoo?.opacity ?? settings.opacity.min;
  }, [data, getCurrentTattoo, opacities, settings.opacity.min]);

  // Tattoo değiştiğinde opacity'yi güncelle ve ilk tattoo'yu preview et
  useEffect(() => {
    keys.forEach(zone => {
      const zoneItems = items[zone] || [];
      if (zoneItems.length === 0) return;

      // İlk kez yükleniyorsa index'i 0 yap
      if (currentTattooIndices[zone] === undefined) {
        setCurrentTattooIndices(prev => ({ ...prev, [zone]: 0 }));
        const firstTattoo = zoneItems[0];
        if (firstTattoo) {
          const appliedTattoos = data[zone] || [];
          const appliedTattoo = appliedTattoos.find(t => t.name === firstTattoo.name);
          const initialOpacity = appliedTattoo?.opacity ?? settings.opacity.min;
          setOpacities(prev => ({ ...prev, [zone]: initialOpacity }));
          handlePreviewTattoo(firstTattoo, initialOpacity);
        }
        return;
      }

      const currentTattoo = getCurrentTattoo(zone);
      if (currentTattoo) {
        const appliedTattoos = data[zone] || [];
        const appliedTattoo = appliedTattoos.find(t => t.name === currentTattoo.name);
        if (appliedTattoo && opacities[zone] === undefined) {
          setOpacities(prev => ({ ...prev, [zone]: appliedTattoo.opacity }));
        }
      }
    });
  }, [keys, items, data, settings.opacity.min, getCurrentTattoo, currentTattooIndices, opacities, handlePreviewTattoo]);

  // Tattoo seçimi değiştirme
  const handleTattooChange = useCallback((zone: string, factor: number) => {
    const zoneItems = items[zone] || [];
    if (zoneItems.length === 0) return;

    const currentIndex = currentTattooIndices[zone] ?? 0;
    let newIndex = currentIndex + factor;

    if (newIndex < 0) {
      newIndex = zoneItems.length - 1;
    } else if (newIndex >= zoneItems.length) {
      newIndex = 0;
    }

    setCurrentTattooIndices(prev => ({ ...prev, [zone]: newIndex }));
    
    const newTattoo = zoneItems[newIndex];
    if (newTattoo) {
      const opacity = getOpacity(zone);
      handlePreviewTattoo(newTattoo, opacity);
    }
  }, [items, currentTattooIndices, getOpacity, handlePreviewTattoo]);

  // Opacity değiştirme
  const handleOpacityChange = useCallback((zone: string, value: number) => {
    setOpacities(prev => ({ ...prev, [zone]: value }));
    const currentTattoo = getCurrentTattoo(zone);
    if (currentTattoo) {
      handlePreviewTattoo(currentTattoo, value);
    }
  }, [getCurrentTattoo, handlePreviewTattoo]);

  // Tattoo uygula/sil
  const handleTattooAction = useCallback((zone: string) => {
    const currentTattoo = getCurrentTattoo(zone);
    if (!currentTattoo) return;

    const appliedTattoos = data[zone] || [];
    const isApplied = appliedTattoos.some(t => t.name === currentTattoo.name);

    const opacity = getOpacity(zone);

    if (isApplied) {
      handleDeleteTattoo(currentTattoo);
    } else {
      handleApplyTattoo(currentTattoo, opacity);
    }
  }, [getCurrentTattoo, data, getOpacity, handleApplyTattoo, handleDeleteTattoo]);

  const isTattooApplied = useCallback((zone: string): boolean => {
    const currentTattoo = getCurrentTattoo(zone);
    if (!currentTattoo) return false;

    const appliedTattoos = data[zone] || [];
    return appliedTattoos.some(t => t.name === currentTattoo.name);
  }, [getCurrentTattoo, data]);

  if (keys.length === 0) {
    return (
      <div className="components-container">
        <div className="components-item">
          <span style={{ color: 'rgba(255, 255, 255, 0.5)', fontSize: '1.296vh' }}>
            No tattoos available
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="components-container">
      {keys.map(zone => {
        const zoneItems = items[zone] || [];
        const currentTattoo = getCurrentTattoo(zone);
        const currentIndex = currentTattooIndices[zone] ?? 0;
        const opacity = getOpacity(zone);
        const applied = isTattooApplied(zone);

        if (zoneItems.length === 0) return null;

        return (
          <div key={zone} className="components-item">
            <h1>{locales.tattoos.items[zone] || zone}</h1>
            
            {/* Tattoo Selection */}
            <div className="component-selector">
              <span>{currentTattoo?.label ? currentTattoo?.label : 'Tattoo'}</span>
              <div>
                <button 
                  className="arrow-button" 
                  onClick={() => handleTattooChange(zone, -1)}
                >
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
                <span className="component-value">
                  {currentTattoo ? `${currentIndex + 1} / ${zoneItems.length}` : '0 / 0'}
                </span>
                <button 
                  className="arrow-button" 
                  onClick={() => handleTattooChange(zone, 1)}
                >
                  <svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </button>
              </div>
            </div>

            {/* Tattoo Name Display */}
            {/* {currentTattoo && (
              <div style={{ 
                marginTop: '0.556vh', 
                color: 'rgba(255, 255, 255, 0.7)', 
                fontSize: '1.111vh',
                fontFamily: 'Inter',
                marginBottom: '0.926vh'
              }}>
                {currentTattoo.label}
              </div>
            )} */}

            {/* Opacity */}
            <div style={{ marginTop: '0.926vh', width: '37.037vh' }}>
              <RangeInput
                title={locales.tattoos.opacity}
                min={settings.opacity.min}
                max={settings.opacity.max}
                factor={settings.opacity.factor}
                defaultValue={opacity}
                clientValue={opacity}
                onChange={(value) => handleOpacityChange(zone, value)}
              />
            </div>

            {/* Apply/Delete Button */}
            <div style={{ marginTop: '1.111vh', width: '37.037vh' }}>
              <Button 
                onClick={() => handleTattooAction(zone)} 
                width="100%"
              >
                {applied ? locales.tattoos.delete : locales.tattoos.apply}
              </Button>
            </div>
          </div>
        );
      })}

      {/* Clear All Button */}
      <div className="components-item" style={{ marginTop: '1.852vh' }}>
        <Button onClick={handleClearTattoos} width="37.037vh">
          {locales.tattoos.deleteAll}
        </Button>
      </div>
    </div>
  );
};

export default Tattoos;
