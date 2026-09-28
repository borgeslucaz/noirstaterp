import { useEffect, useState } from 'react';
import ReactMarkdown from 'react-markdown';
import MarkdownComponents from '../../../config/MarkdownComponents';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { ContextMenuProps } from '../../../typings';
import { fetchNui } from '../../../utils/fetchNui';
import KeyHints from '../KeyHints';
import ContextButton from './components/ContextButton';
import HeaderButton from './components/HeaderButton';

const openMenu = (id: string | undefined) => {
  fetchNui<ContextMenuProps>('openContext', { id: id, back: true });
};

const ContextMenu: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [contextMenu, setContextMenu] = useState<ContextMenuProps>({
    title: '',
    options: { '': { description: '', metadata: [] } },
  });

  const closeContext = () => {
    if (contextMenu.canClose === false) return;
    setVisible(false);
    fetchNui('closeContext');
  };

  // Hides the context menu on ESC
  useEffect(() => {
    if (!visible) return;

    const keyHandler = (e: KeyboardEvent) => {
      if (['Escape'].includes(e.code)) closeContext();
    };

    window.addEventListener('keydown', keyHandler);

    return () => window.removeEventListener('keydown', keyHandler);
  }, [visible]);

  useNuiEvent('hideContext', () => setVisible(false));

  useNuiEvent<ContextMenuProps>('showContext', async (data) => {
    if (visible) {
      setVisible(false);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    setContextMenu(data);
    setVisible(true);
  });

  if (!visible) return null;

  const actions = (contextMenu.menu ? 1 : 0) + 1;
  const options = Object.entries(contextMenu.options);
  // Uma opção com ícone reserva a coluna para todas: títulos alinhados.
  const iconColumn = options.some(([, option]) => !!option.icon);

  return (
    <>
      <section className="side-menu" aria-label={contextMenu.title}>
        <header className="side-menu__header" data-actions={actions}>
          <div className="side-menu__title">
            <ReactMarkdown components={MarkdownComponents}>{contextMenu.title}</ReactMarkdown>
          </div>
          <div className="side-menu__actions">
            {contextMenu.menu && (
              <HeaderButton icon="arrow-left" label="Voltar" handleClick={() => openMenu(contextMenu.menu)} />
            )}
            <HeaderButton icon="xmark" label="Fechar" canClose={contextMenu.canClose} handleClick={closeContext} />
          </div>
        </header>
        <div className="side-menu__items">
          {options.map((option, index) => (
            <ContextButton option={option} iconColumn={iconColumn} key={`context-item-${index}`} />
          ))}
        </div>
      </section>
      <KeyHints keys={contextMenu.canClose === false ? [] : [{ key: 'Esc', label: 'Fechar' }]} />
    </>
  );
};

export default ContextMenu;
