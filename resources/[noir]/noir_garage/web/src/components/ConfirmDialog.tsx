import React from "react";
import Modal from "./Modal";

/** Confirmacao simples no centro da tela: Cancelar a esquerda (ja focado), acao a direita. */
const ConfirmDialog: React.FC<{
  title: string;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: () => void;
  onClose: () => void;
  children: React.ReactNode;
}> = ({ title, confirmLabel, danger, onConfirm, onClose, children }) => (
  <Modal
    title={title}
    onClose={onClose}
    footer={(
      <>
        <button type="button" className="button" data-autofocus onClick={onClose}>Cancelar</button>
        <button type="button" className={`button ${danger ? 'button--danger' : 'button--success'}`} onClick={onConfirm}>{confirmLabel}</button>
      </>
    )}
  >
    {children}
  </Modal>
);

export default ConfirmDialog;
