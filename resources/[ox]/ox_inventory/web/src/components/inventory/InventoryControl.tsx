import React from 'react';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';

// Rodape: fechar e dicas de atalho. Quantidade, Usar e Dar ficam no menu do botao direito.
const InventoryControl: React.FC = () => (
  <div className="inventory-control">
    <button className="inventory-control-key" onClick={() => fetchNui('exit')}>
      <kbd>ESC</kbd>
      <span>{Locale.ui_close || 'Fechar'}</span>
    </button>
    <div className="inventory-control-hints">
      <p>
        <kbd>RMB</kbd> menu
      </p>
      <p>
        <kbd>ALT</kbd>+<kbd>LMB</kbd> usar
      </p>
      <p>
        <kbd>CTRL</kbd>+<kbd>LMB</kbd> mover rápido
      </p>
      <p>
        <kbd>SHIFT</kbd> arrastar metade
      </p>
    </div>
  </div>
);

export default InventoryControl;
