import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { fas } from '@fortawesome/free-solid-svg-icons';
import { far } from '@fortawesome/free-regular-svg-icons';
import { fab } from '@fortawesome/free-brands-svg-icons';
import { library } from '@fortawesome/fontawesome-svg-core';
import { isEnvBrowser } from './utils/misc';
import LocaleProvider from './providers/LocaleProvider';
import ConfigProvider from './providers/ConfigProvider';

library.add(fas, far, fab);

if (isEnvBrowser()) {
  const root = document.getElementById('root');

  // Foto de cena do preview (DESIGN_v4 §10): servida só pelo vite dev, fora do build.
  root!.style.setProperty('background-image', 'url("/dev/sinner.png")', 'important');
  root!.style.setProperty('background-size', 'cover', 'important');
  root!.style.setProperty('background-repeat', 'no-repeat', 'important');
  root!.style.setProperty('background-position', 'center', 'important');
}

const root = document.getElementById('root');
ReactDOM.createRoot(root!).render(
  <React.StrictMode>
    <LocaleProvider>
      <ConfigProvider>
        <App />
      </ConfigProvider>
    </LocaleProvider>
  </React.StrictMode>
);
