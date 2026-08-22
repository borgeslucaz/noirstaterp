import { useNuiState } from '../../hooks/nuiState';

import Section from './components/Section';
import './Components.css';

import { PropSettings, PedProp, PropConfig } from './interfaces';

interface PropsProps {
  settings: PropSettings[];
  data: PedProp[];
  storedData: PedProp[];
  handlePropDrawableChange: (prop_id: number, drawable: number) => void;
  handlePropTextureChange: (prop_id: number, texture: number) => void;
  propConfig: PropConfig;
}

interface DataById<T> {
  [key: number]: T;
}

const Props = ({ settings, data, storedData, handlePropDrawableChange, handlePropTextureChange, propConfig }: PropsProps) => {
  const { locales } = useNuiState();

  const settingsById = settings.reduce((object, { prop_id, drawable, texture, blacklist }) => {
    return { ...object, [prop_id]: { drawable, texture, blacklist } };
  }, {} as DataById<Omit<PropSettings, 'prop_id'>>);

  const propsById: any = data.reduce((object, { prop_id, drawable, texture }) => {
    return { ...object, [prop_id]: { drawable, texture } };
  }, {} as DataById<Omit<PedProp, 'prop_id'>>);

  const storedPropsById: any = storedData.reduce((object, { prop_id, drawable, texture }) => {
    return { ...object, [prop_id]: { drawable, texture } };
  }, {} as DataById<Omit<PedProp, 'prop_id'>>);

  if (!locales) {
    return null;
  }

  const isBlacklisted = (value: number, blacklisted: number[]) => {
    return blacklisted.includes(value);
  };

  const normalize = (value: number, min: number, max: number) => {
    if (value < min) return max;
    if (value > max) return min;
    return value;
  };

  const getSafeValue = (currentValue: number, min: number, max: number, blacklisted: number[], factor: number) => {
    let safeValue = normalize(currentValue + factor, min, max);
    let iterations = 0;
    const maxIterations = max - min + 1;
    
    // Eğer hedef değer blacklisted değilse direkt döndür
    if (!isBlacklisted(safeValue, blacklisted)) {
      return safeValue;
    }

    // Blacklisted ise, factor yönünde bir sonraki geçerli değeri bul
    do {
      safeValue = normalize(safeValue + factor, min, max);
      iterations++;
      if (iterations > maxIterations) {
        // Tüm değerler blacklisted ise mevcut değeri döndür
        return currentValue;
      }
    } while (isBlacklisted(safeValue, blacklisted));

    return safeValue;
  };

  const handleDrawableChange = (propId: number, factor: number) => {
    if (!settingsById[propId] || !propsById[propId]) {
      console.warn(`Prop ${propId} not found in settings or data`);
      return;
    }
    const currentValue = propsById[propId].drawable;
    const settings = settingsById[propId];
    const newValue = getSafeValue(
      currentValue,
      settings.drawable.min,
      settings.drawable.max,
      settings.blacklist.drawables || [],
      factor
    );
    handlePropDrawableChange(propId, newValue);
  };

  const handleTextureChange = (propId: number, factor: number) => {
    if (!settingsById[propId] || !propsById[propId]) {
      console.warn(`Prop ${propId} not found in settings or data`);
      return;
    }
    const currentValue = propsById[propId].texture;
    const settings = settingsById[propId];
    const newValue = getSafeValue(
      currentValue,
      settings.texture.min,
      settings.texture.max,
      settings.blacklist.textures || [],
      factor
    );
    handlePropTextureChange(propId, newValue);
  };

  return (
    <div className="props-container">
      {propConfig.hats && <div className="components-item">
        <h1>{locales.props.hats}</h1>
        <div className="component-selector">
          <span>{locales.props.drawable}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(0, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[0]?.drawable ?? storedPropsById[0]?.drawable ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(0, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div className="component-selector">
          <span>{locales.props.texture}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(0, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[0]?.texture ?? storedPropsById[0]?.texture ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(0, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>}
      {propConfig.glasses && <div className="components-item">
        <h1>{locales.props.glasses}</h1>
        <div className="component-selector">
          <span>{locales.props.drawable}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(1, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[1]?.drawable ?? storedPropsById[1]?.drawable ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(1, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div className="component-selector">
          <span>{locales.props.texture}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(1, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[1]?.texture ?? storedPropsById[1]?.texture ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(1, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>}
      {propConfig.ear && <div className="components-item">
        <h1>{locales.props.ear}</h1>
        <div className="component-selector">
          <span>{locales.props.drawable}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(2, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[2]?.drawable ?? storedPropsById[2]?.drawable ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(2, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div className="component-selector">
          <span>{locales.props.texture}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(2, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[2]?.texture ?? storedPropsById[2]?.texture ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(2, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>}
      {propConfig.watches && <div className="components-item">
        <h1>{locales.props.watches}</h1>
        <div className="component-selector">
          <span>{locales.props.drawable}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(6, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[6]?.drawable ?? storedPropsById[6]?.drawable ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(6, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div className="component-selector">
          <span>{locales.props.texture}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(6, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[6]?.texture ?? storedPropsById[6]?.texture ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(6, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>}
      {propConfig.bracelets && <div className="components-item">
        <h1>{locales.props.bracelets}</h1>
        <div className="component-selector">
          <span>{locales.props.drawable}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(7, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[7]?.drawable ?? storedPropsById[7]?.drawable ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleDrawableChange(7, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
        <div className="component-selector">
          <span>{locales.props.texture}</span>
          <div>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(7, -1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
            <span className="component-value">{propsById[7]?.texture ?? storedPropsById[7]?.texture ?? 0}</span>
            <button 
              className="arrow-button" 
              onClick={() => handleTextureChange(7, 1)}
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </button>
          </div>
        </div>
      </div>}
    </div>
  );
};

export default Props;
