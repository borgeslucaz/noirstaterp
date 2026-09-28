import React from 'react';
import './side-menu.css';

export interface KeyHint {
  key: string;
  label: string;
}

// Pílulas de tecla no canto inferior direito da tela (DESIGN_v4 §7).
const KeyHints: React.FC<{ keys: KeyHint[] }> = ({ keys }) => {
  if (keys.length === 0) return null;

  return (
    <div className="side-menu-keys" aria-hidden="true">
      {keys.map((hint, index) => (
        <React.Fragment key={hint.key}>
          {index > 0 && <span className="side-menu-keys__sep">/</span>}
          <span className="side-menu-keys__key">
            <kbd>{hint.key}</kbd> {hint.label}
          </span>
        </React.Fragment>
      ))}
    </div>
  );
};

export default KeyHints;
