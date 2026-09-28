import type { ModalProps } from '@mantine/core';
import './dialog.css';

// Janela central (DESIGN_v4 §6): centro da tela, min(430px, 100vw - 48px), overlay escuro atrás.
export const dialogModalProps: Partial<ModalProps> = {
  centered: true,
  padding: 0,
  withCloseButton: false,
  closeOnClickOutside: false,
  overlayColor: '#000',
  overlayOpacity: 0.76,
  overlayBlur: 0,
  transition: 'fade',
  transitionDuration: 180,
  exitTransitionDuration: 120,
  classNames: { modal: 'dialog' },
  styles: {
    modal: {
      maxWidth: 'calc(100vw - 48px)',
      overflow: 'hidden',
      border: '1px solid var(--noir-border)',
      borderRadius: 'var(--noir-radius)',
      backgroundColor: 'var(--noir-panel-raised)',
      boxShadow: 'var(--shadow-modal)',
      color: 'var(--noir-text)',
      fontFamily: 'var(--font-ui)',
    },
  },
};

// Tamanhos do lib.alertDialog; sem tamanho, a largura padrão da v4.
export const dialogSizes = { xs: 320, sm: 380, md: 430, lg: 620, xl: 780 };
