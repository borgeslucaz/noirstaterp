import { useState, useEffect, useCallback } from 'react';
import { NuiStateProvider, useNuiState } from './hooks/nuiState';
import './styles/global.css';
import Others from './components/Others';
import bgImage from './img/bg.png';
import Appearance from './components/Appearance';
import Nui from './Nui';
import { CustomizationConfig, PedAppearance } from './components/Appearance/interfaces';

const AppContent: React.FC = () => {
  const [selectedSection, setSelectedSection] = useState<string | null>('DNA');
  const [config, setConfig] = useState<CustomizationConfig | undefined>();
  const [appearanceData, setAppearanceData] = useState<PedAppearance | undefined>();
  const { display } = useNuiState();

  const fetchConfig = useCallback(async () => {
    const result = await Nui.post('appearance_get_data');
    console.log('fetchConfig', result.config);
    if (result?.config) {
      setConfig(result.config);
    }
    if (result?.appearanceData) {
      setAppearanceData(result.appearanceData);
    }
  }, []);

  useEffect(() => {
    fetchConfig();
  }, [fetchConfig]);

  useEffect(() => {
    if (display.appearance) {
      fetchConfig();
    }
  }, [display.appearance, fetchConfig]);

  useEffect(() => {
    Nui.onEvent('appearance_display', async (data: any) => {
      const result = await Nui.post('appearance_get_data');
      if (result?.config) {
        setConfig(result.config);
      }
      if (result?.appearanceData) {
        setAppearanceData(result.appearanceData);
      }
    });

    Nui.onEvent('appearance_hide', () => {
      setConfig(undefined);
      setAppearanceData(undefined);
    });
  }, []);

  return (
    <>
      {/* <div 
        style={{
          position: 'fixed',
          top: 0,
          left: 0,
          width: '100vw',
          height: '100vh',
          backgroundImage: `url(${bgImage})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          backgroundRepeat: 'no-repeat',
          zIndex: -1
        }}
      /> */}
      <Others selectedSection={selectedSection} setSelectedSection={setSelectedSection} config={config} data={appearanceData} />
      <Appearance selectedSection={selectedSection} config={config} />
    </>
  );
};

const App: React.FC = () => {
  return (
    <NuiStateProvider>
      <AppContent />
    </NuiStateProvider>
  );
};

export default App;
