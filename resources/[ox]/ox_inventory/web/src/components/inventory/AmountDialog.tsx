import React, { useEffect, useRef, useState } from 'react';
import { FloatingOverlay, FloatingPortal } from '@floating-ui/react';
import { useAppDispatch, useAppSelector } from '../../store';
import { AmountAction, closeAmountDialog } from '../../store/contextMenu';
import { getItemUrl } from '../../helpers';
import { Items } from '../../store/items';
import { SlotWithItem } from '../../typings';

const TITLES: Record<AmountAction, string> = {
  split: 'Dividir item',
  give: 'Dar item',
  drop: 'Soltar item',
};

// Dividir deixa pelo menos 1 na pilha original; Dar e Soltar podem levar tudo.
export const amountRange = (action: AmountAction, item: SlotWithItem) => {
  const max = action === 'split' ? item.count - 1 : item.count;
  const initial = action === 'split' ? Math.floor(item.count / 2) : item.count;

  return { max, initial };
};

const clamp = (value: number, max: number) => Math.min(Math.max(1, Math.floor(value) || 1), max);

// Janela de quantidade do menu do botao direito: confirma a acao com a quantidade escolhida.
const AmountDialog: React.FC<{ onConfirm: (action: AmountAction, item: SlotWithItem, count: number) => void }> = ({
  onConfirm,
}) => {
  const dialog = useAppSelector((state) => state.contextMenu.amountDialog);
  const dispatch = useAppDispatch();
  const [amount, setAmount] = useState(1);
  const inputRef = useRef<HTMLInputElement>(null);

  const range = dialog ? amountRange(dialog.action, dialog.item) : { max: 1, initial: 1 };

  useEffect(() => {
    if (!dialog) return;

    setAmount(range.initial);
    requestAnimationFrame(() => inputRef.current?.select());
  }, [dialog]);

  const close = () => dispatch(closeAmountDialog());

  const confirm = () => {
    if (!dialog) return;

    onConfirm(dialog.action, dialog.item, clamp(amount, range.max));
    close();
  };

  // ESC fecha so a janela: captura antes do listener que fecha o inventario inteiro
  useEffect(() => {
    if (!dialog) return;

    const onKey = (event: KeyboardEvent) => {
      if (event.code === 'Escape') {
        event.stopImmediatePropagation();
        if (event.type === 'keyup') close();
      } else if (event.code === 'Enter' || event.code === 'NumpadEnter') {
        if (event.type === 'keyup') confirm();
      }
    };

    window.addEventListener('keydown', onKey, true);
    window.addEventListener('keyup', onKey, true);

    return () => {
      window.removeEventListener('keydown', onKey, true);
      window.removeEventListener('keyup', onKey, true);
    };
  });

  if (!dialog) return null;

  const { item, action } = dialog;
  const label = item.metadata?.label || Items[item.name]?.label || item.name;
  const percent = range.max > 1 ? ((amount - 1) / (range.max - 1)) * 100 : 100;

  return (
    <FloatingPortal>
      <FloatingOverlay className="amount-dialog-overlay" onMouseDown={(event) => event.target === event.currentTarget && close()}>
        <div className="amount-dialog" role="dialog" aria-label={TITLES[action]}>
          <p className="amount-dialog-title">{TITLES[action]}</p>
          <div className="amount-dialog-item">
            <div className="amount-dialog-image" style={{ backgroundImage: `url(${getItemUrl(item)})` }} />
            <p>{label}</p>
          </div>
          <label className="amount-dialog-field">
            <span>Quantidade</span>
            <div>
              <input
                ref={inputRef}
                type="number"
                min={1}
                max={range.max}
                value={amount}
                onChange={(event) => setAmount(Number(event.target.value))}
                onBlur={() => setAmount(clamp(amount, range.max))}
              />
              <span>de {range.max.toLocaleString('pt-BR')}</span>
            </div>
          </label>
          <input
            className="amount-dialog-range"
            type="range"
            min={1}
            max={range.max}
            value={clamp(amount, range.max)}
            style={{ '--fill': `${percent}%` } as React.CSSProperties}
            onChange={(event) => setAmount(Number(event.target.value))}
          />
          <div className="amount-dialog-actions">
            <button type="button" className="is-primary" onClick={confirm}>
              Confirmar
            </button>
            <button type="button" onClick={close}>
              Cancelar
            </button>
          </div>
        </div>
      </FloatingOverlay>
    </FloatingPortal>
  );
};

export default AmountDialog;
