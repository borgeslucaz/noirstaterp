import { useNuiState } from '../../hooks/nuiState';

import Item from './components/Item';
import Input from './components/Input';
import './Components.css';

import { ComponentConfig, ComponentSettings, PedComponent } from './interfaces';

interface ComponentsProps {
  settings: ComponentSettings[];
  data: PedComponent[];
  storedData: PedComponent[];
  handleComponentDrawableChange: (component_id: number, drawable: number) => void;
  handleComponentTextureChange: (component_id: number, texture: number) => void;
  componentConfig: ComponentConfig;
  hasTracker: boolean;
  isPedFreemodeModel: boolean | undefined;
}

interface DataById<T> {
  [key: number]: T;
}

const Components = ({
  settings,
  data,
  storedData,
  handleComponentDrawableChange,
  handleComponentTextureChange,
  componentConfig,
  hasTracker,
  isPedFreemodeModel
}: ComponentsProps) => {
  const { locales } = useNuiState();

  const settingsById = settings.reduce((object, { component_id, drawable, texture, blacklist }) => {
    return { ...object, [component_id]: { drawable, texture, blacklist } };
  }, {} as DataById<Omit<ComponentSettings, 'component_id'>>);

  const componentsById: any = data.reduce((object, { component_id, drawable, texture }) => {
    return { ...object, [component_id]: { drawable, texture } };
  }, {} as DataById<Omit<PedComponent, 'component_id'>>);

  const storedComponentsById: any = storedData.reduce((object, { component_id, drawable, texture }) => {
    return { ...object, [component_id]: { drawable, texture } };
  }, {} as DataById<Omit<PedComponent, 'component_id'>>);

  if (!locales || !componentConfig) {
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

  const handleDrawableChange = (componentId: number, factor: number) => {
    if (!settingsById[componentId] || !componentsById[componentId]) {
      console.warn(`Component ${componentId} not found in settings or data`);
      return;
    }
    const currentValue = componentsById[componentId].drawable;
    const settings = settingsById[componentId];
    const newValue = getSafeValue(
      currentValue,
      settings.drawable.min,
      settings.drawable.max,
      settings.blacklist.drawables || [],
      factor
    );
    handleComponentDrawableChange(componentId, newValue);
  };

  const handleTextureChange = (componentId: number, factor: number) => {
    if (!settingsById[componentId] || !componentsById[componentId]) {
      console.warn(`Component ${componentId} not found in settings or data`);
      return;
    }
    const currentValue = componentsById[componentId].texture;
    const settings = settingsById[componentId];
    const newValue = getSafeValue(
      currentValue,
      settings.texture.min,
      settings.texture.max,
      settings.blacklist.textures || [],
      factor
    );
    handleComponentTextureChange(componentId, newValue);
  };

  return (
    <div className="components-container">
      {!isPedFreemodeModel && <Item title={locales.components.head}>
          <Input
            title={locales.components.drawable}
            min={settingsById[0].drawable.min}
            max={settingsById[0].drawable.max}
            blacklisted={settingsById[0].blacklist.drawables}
            defaultValue={componentsById[0].drawable}
            clientValue={storedComponentsById[0].drawable}
            onChange={value => handleComponentDrawableChange(0, value)}
          />
          <Input
            title={locales.components.texture}
            min={settingsById[0].texture.min}
            max={settingsById[0].texture.max}
            blacklisted={settingsById[0].blacklist.textures}
            defaultValue={componentsById[0].texture}
            clientValue={storedComponentsById[0].texture}
            onChange={value => handleComponentTextureChange(0, value)}
          />
      </Item>}
      {componentConfig.masks && <div className="components-item">
          <h1>{locales.components.mask}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(1, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[1]?.drawable ?? storedComponentsById[1]?.drawable ?? 0}</span>
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
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(1, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[1]?.texture ?? storedComponentsById[1]?.texture ?? 0}</span>
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
      {componentConfig.scarfAndChains && !hasTracker && <div className="components-item">
          <h1>{locales.components.scarfAndChains}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(7, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[7]?.drawable ?? storedComponentsById[7]?.drawable ?? 0}</span>
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
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(7, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[7]?.texture ?? storedComponentsById[7]?.texture ?? 0}</span>
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
      {componentConfig.jackets && <div className="components-item">
          <h1>{locales.components.jackets}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(11, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[11]?.drawable ?? storedComponentsById[11]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(11, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(11, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[11]?.texture ?? storedComponentsById[11]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(11, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.shirts && <div className="components-item">
          <h1>{locales.components.shirt}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(8, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[8]?.drawable ?? storedComponentsById[8]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(8, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(8, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[8]?.texture ?? storedComponentsById[8]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(8, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.bodyArmor && <div className="components-item">
          <h1>{locales.components.bodyArmor}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(9, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[9]?.drawable ?? storedComponentsById[9]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(9, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(9, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[9]?.texture ?? storedComponentsById[9]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(9, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.bags && <div className="components-item">
          <h1>{locales.components.bags}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(5, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[5]?.drawable ?? storedComponentsById[5]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(5, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(5, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[5]?.texture ?? storedComponentsById[5]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(5, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.upperBody && <div className="components-item">
          <h1>{locales.components.upperBody}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(3, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[3]?.drawable ?? storedComponentsById[3]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(3, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(3, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[3]?.texture ?? storedComponentsById[3]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(3, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.lowerBody && <div className="components-item">
          <h1>{locales.components.lowerBody}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(4, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[4]?.drawable ?? storedComponentsById[4]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(4, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(4, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[4]?.texture ?? storedComponentsById[4]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(4, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
      </div>}
      {componentConfig.shoes && <div className="components-item">
          <h1>{locales.components.shoes}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(6, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[6]?.drawable ?? storedComponentsById[6]?.drawable ?? 0}</span>
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
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(6, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[6]?.texture ?? storedComponentsById[6]?.texture ?? 0}</span>
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
      {componentConfig.decals && <div className="components-item">
          <h1>{locales.components.decals}</h1>
          <div className="component-selector">
            <span>{locales.components.drawable}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(10, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[10]?.drawable ?? storedComponentsById[10]?.drawable ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleDrawableChange(10, 1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M4.5 3L7.5 6L4.5 9" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            </div>
          </div>
          <div className="component-selector">
            <span>{locales.components.texture}</span>
            <div>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(10, -1)}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 12 12" fill="none">
                  <path d="M7.5 9L4.5 6L7.5 3" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
              <span className="component-value">{componentsById[10]?.texture ?? storedComponentsById[10]?.texture ?? 0}</span>
              <button 
                className="arrow-button" 
                onClick={() => handleTextureChange(10, 1)}
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

export default Components;