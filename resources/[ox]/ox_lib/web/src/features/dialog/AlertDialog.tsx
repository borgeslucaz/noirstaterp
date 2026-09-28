import { Modal } from '@mantine/core';
import { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import LibIcon from '../../components/LibIcon';
import MarkdownComponents from '../../config/MarkdownComponents';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import { useLocales } from '../../providers/LocaleProvider';
import type { AlertProps } from '../../typings';
import { fetchNui } from '../../utils/fetchNui';
import { dialogModalProps, dialogSizes } from './modalStyles';

const AlertDialog: React.FC = () => {
  const { locale } = useLocales();
  const [opened, setOpened] = useState(false);
  const [dialogData, setDialogData] = useState<AlertProps>({
    header: '',
    content: '',
  });

  const closeAlert = (button: string) => {
    setOpened(false);
    fetchNui('closeAlert', button);
  };

  useNuiEvent('sendAlert', (data: AlertProps) => {
    setDialogData(data);
    setOpened(true);
  });

  useNuiEvent('closeAlertDialog', () => {
    setOpened(false);
  });

  return (
    <Modal
      {...dialogModalProps}
      opened={opened}
      size={dialogSizes[dialogData.size || 'md']}
      overflow={dialogData.overflow ? 'inside' : 'outside'}
      onClose={() => closeAlert('cancel')}
    >
      <header className="dialog__header">
        <div className="dialog__title">
          <ReactMarkdown components={MarkdownComponents}>{dialogData.header}</ReactMarkdown>
        </div>
        {dialogData.cancel && (
          <button type="button" className="dialog__close" aria-label="Fechar" onClick={() => closeAlert('cancel')}>
            <LibIcon icon="xmark" fixedWidth />
          </button>
        )}
      </header>
      <div className="dialog__body">
        <ReactMarkdown remarkPlugins={[remarkGfm]} components={MarkdownComponents}>
          {dialogData.content}
        </ReactMarkdown>
      </div>
      {/* Confirmação: foco inicial em Cancelar, um Enter sem querer não executa. */}
      <div className="dialog__footer" data-single={dialogData.cancel ? undefined : ''}>
        {dialogData.cancel && (
          <button type="button" className="dialog-button" data-autofocus onClick={() => closeAlert('cancel')}>
            {dialogData.labels?.cancel || locale.ui.cancel}
          </button>
        )}
        <button
          type="button"
          className="dialog-button dialog-button--confirm"
          data-autofocus={dialogData.cancel ? undefined : true}
          onClick={() => closeAlert('confirm')}
        >
          {dialogData.labels?.confirm || locale.ui.confirm}
        </button>
      </div>
    </Modal>
  );
};

export default AlertDialog;
