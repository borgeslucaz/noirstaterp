import React, { useEffect, useRef } from "react";
import { ChevronLeft, ChevronRight, LoaderCircle, TriangleAlert, X } from "lucide-react";

export type MenuTone = 'danger';

/** Um item do menu. `onSelect` roda no Enter ou no clique; sem ele o item e so informativo. */
export interface MenuItem {
  key: string;
  label: string;
  icon?: React.ReactNode;
  description?: React.ReactNode;
  /** Descricao que so aparece com o item ativo (como no ox_lib). */
  activeDescription?: React.ReactNode;
  value?: React.ReactNode;
  submenu?: boolean;
  disabled?: boolean;
  busy?: boolean;
  tone?: MenuTone;
  /** 0-100: barra de progresso abaixo do rotulo. */
  progress?: number;
  onSelect?: () => void;
  /** Campo de texto na propria linha (apelido, busca). */
  input?: {
    value: string;
    placeholder?: string;
    maxLength?: number;
    onChange: (value: string) => void;
    onSubmit?: () => void;
  };
}

export interface MenuNotice {
  tone?: 'warning' | 'danger' | 'success';
  text: string;
}

const meterTone = (value: number) => value <= 35 ? 'danger' : value <= 60 ? 'warning' : undefined;

const Menu: React.FC<{
  title: string;
  eyebrow?: string;
  icon?: React.ReactNode;
  items: MenuItem[];
  index: number;
  onIndexChange: (index: number) => void;
  onBack?: () => void;
  onClose: () => void;
  notice?: MenuNotice | null;
  empty?: string;
  loading?: string | null;
}> = ({ title, eyebrow, icon, items, index, onIndexChange, onBack, onClose, notice, empty, loading }) => {
  const listRef = useRef<HTMLDivElement>(null);
  const active = items[index];

  // O item ativo fica sempre visivel; se for um campo, ele recebe o foco para digitar direto.
  useEffect(() => {
    const element = listRef.current?.querySelector<HTMLElement>(`[data-index="${index}"]`);
    element?.scrollIntoView({ block: 'nearest' });
    const input = element?.querySelector<HTMLInputElement>('input');
    if (input) input.focus();
    else if (document.activeElement instanceof HTMLInputElement) document.activeElement.blur();
  }, [index, items.length, title]);

  const move = (delta: number) => {
    if (items.length === 0) return;
    onIndexChange((index + delta + items.length) % items.length);
  };

  const activate = (item?: MenuItem) => {
    if (!item || item.disabled || item.busy) return;
    if (item.input) item.input.onSubmit?.();
    else item.onSelect?.();
  };

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const typing = event.target instanceof HTMLInputElement;
      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault();
          move(1);
          break;
        case 'ArrowUp':
          event.preventDefault();
          move(-1);
          break;
        case 'Home':
          if (typing) return;
          event.preventDefault();
          onIndexChange(0);
          break;
        case 'End':
          if (typing) return;
          event.preventDefault();
          onIndexChange(Math.max(0, items.length - 1));
          break;
        case 'Enter':
          event.preventDefault();
          activate(active);
          break;
        case 'Backspace':
          if (typing) return;
          event.preventDefault();
          if (onBack) onBack();
          else onClose();
          break;
        case 'Escape':
          event.preventDefault();
          if (onBack) onBack();
          else onClose();
          break;
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  });

  return (
    <div className="menu" data-service="garage" role="dialog" aria-label={title}>
      <header className="menu__header">
        {onBack && (
          <button type="button" className="icon-button icon-button--small" aria-label="Voltar" title="Voltar (Backspace)" onClick={onBack}>
            <ChevronLeft size={18} aria-hidden="true" />
          </button>
        )}
        {!onBack && icon}
        <div className="menu__titles">
          {eyebrow && <p className="eyebrow">{eyebrow}</p>}
          <h1 className="menu__title" title={title}>{title}</h1>
        </div>
        <button type="button" className="icon-button icon-button--small" aria-label="Fechar" title="Fechar" onClick={onClose}>
          <X size={18} aria-hidden="true" />
        </button>
      </header>

      {notice && (
        <p className="menu__notice" data-tone={notice.tone ?? 'warning'} role="status">
          <TriangleAlert size={14} aria-hidden="true" />
          {notice.text}
        </p>
      )}

      <div ref={listRef} className="menu__items" role="menu" aria-label={title}>
        {loading ? (
          <p className="loading menu__empty"><LoaderCircle className="spin" size={16} aria-hidden="true" /> {loading}</p>
        ) : items.length === 0 ? (
          <p className="menu__empty">{empty ?? 'Nada por aqui.'}</p>
        ) : items.map((item, i) => {
          const isActive = i === index;
          const kind = item.input ? 'input' : item.onSelect ? 'action' : 'info';
          const description = isActive && item.activeDescription ? item.activeDescription : item.description;
          const content = (
            <>
              <span className="menu-item__icon">{item.icon}</span>
              <span className="menu-item__body">
                <span className="menu-item__label">{item.label}</span>
                {item.input ? (
                  <input
                    className="field"
                    type="text"
                    autoComplete="off"
                    value={item.input.value}
                    placeholder={item.input.placeholder}
                    maxLength={item.input.maxLength}
                    aria-label={item.label}
                    onChange={event => item.input!.onChange(event.target.value)}
                    onFocus={() => onIndexChange(i)}
                  />
                ) : description && (
                  typeof description === 'string'
                    ? <span className="menu-item__description">{description}</span>
                    : <span className="menu-item__meta">{description}</span>
                )}
                {item.progress !== undefined && (
                  <span className="menu-item__progress" aria-hidden="true">
                    <span style={{ width: `${Math.max(0, Math.min(100, item.progress))}%` }} />
                  </span>
                )}
              </span>
              {!item.input && (
                <span className="menu-item__value">
                  {item.busy ? <LoaderCircle className="spin" size={16} aria-hidden="true" /> : item.value}
                  {item.submenu && <ChevronRight size={16} aria-hidden="true" />}
                </span>
              )}
            </>
          );

          const common = {
            'data-index': i,
            'data-active': isActive,
            'data-kind': kind,
            'data-tone': item.tone,
            'data-meter': item.progress !== undefined ? meterTone(item.progress) : undefined,
            className: `menu-item${item.input ? ' menu-item--input' : ''}`,
            onMouseEnter: () => onIndexChange(i),
          };

          if (item.input) {
            return <label key={item.key} {...common}>{content}</label>;
          }
          return (
            <button
              key={item.key}
              {...common}
              type="button"
              role="menuitem"
              aria-disabled={item.disabled || item.busy || undefined}
              aria-busy={item.busy || undefined}
              tabIndex={isActive ? 0 : -1}
              onClick={() => { onIndexChange(i); if (kind === 'action') activate(item); }}
            >
              {content}
            </button>
          );
        })}
      </div>

    </div>
  );
};

export default Menu;
