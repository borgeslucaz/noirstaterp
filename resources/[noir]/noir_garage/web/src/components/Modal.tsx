import React, { useEffect, useId, useRef } from "react";
import { X } from "lucide-react";

const FOCUSABLE = 'button:not(:disabled), input:not(:disabled), select:not(:disabled), [tabindex]:not([tabindex="-1"])';

/** Janela no centro da tela para digitar ou confirmar: prende o foco, Esc cancela, devolve o foco ao sair. */
const Modal: React.FC<{
  title: string;
  onClose: () => void;
  closable?: boolean;
  footer: React.ReactNode;
  children: React.ReactNode;
}> = ({ title, onClose, closable = true, footer, children }) => {
  const titleId = useId();
  const dialogRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const opener = document.activeElement as HTMLElement | null;
    const dialog = dialogRef.current;
    const first = dialog?.querySelector<HTMLElement>('[data-autofocus]') ?? dialog?.querySelector<HTMLElement>(FOCUSABLE);
    first?.focus();
    return () => opener?.focus?.();
  }, []);

  const onKeyDown = (event: React.KeyboardEvent) => {
    // A tecla nao sai da janela: ao fechar, o menu volta a escutar o teclado ainda durante este
    // mesmo evento e trataria o Esc/Enter de novo (fechando a coluna de tras).
    event.stopPropagation();
    if (event.key === 'Escape') {
      event.preventDefault();
      if (closable) onClose();
      return;
    }
    if (event.key !== 'Tab' || !dialogRef.current) return;

    const items = Array.from(dialogRef.current.querySelectorAll<HTMLElement>(FOCUSABLE));
    if (items.length === 0) return;
    const first = items[0];
    const last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };

  return (
    <div className="modal-backdrop" onKeyDown={onKeyDown}>
      <div ref={dialogRef} className="modal" role="dialog" aria-modal="true" aria-labelledby={titleId}>
        <div className="modal__header">
          <h2 id={titleId} className="modal__title">{title}</h2>
          <button type="button" className="icon-button icon-button--small" aria-label="Cancelar" onClick={onClose} disabled={!closable}>
            <X size={18} aria-hidden="true" />
          </button>
        </div>
        <div className="modal__body">{children}</div>
        <div className="modal__footer">{footer}</div>
      </div>
    </div>
  );
};

export default Modal;
