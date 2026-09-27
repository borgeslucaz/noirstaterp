import React, { useEffect, useRef } from "react";
import { ChevronRight, LoaderCircle, TriangleAlert, X } from "lucide-react";

export type MenuTone = 'danger';

/** Um item do menu. `onSelect` roda no Enter ou no clique; sem ele o item e so informativo. */
export interface MenuItem {
  key: string;
  label: string;
  /** Rotulo so para leitor de tela (a busca mostra apenas o campo). */
  hideLabel?: boolean;
  icon?: React.ReactNode;
  description?: React.ReactNode;
  /** Descricao de uma linha que so aparece com o item ativo. O item ja reserva a altura dela. */
  activeDescription?: React.ReactNode;
  value?: React.ReactNode;
  /** Abre outra coluna a esquerda (Seta para a esquerda tambem abre). */
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

/**
 * Uma coluna do menu. So a coluna `active` (a mais a esquerda) responde ao teclado; as de tras
 * continuam visiveis com o item que abriu a coluna seguinte marcado, e um clique nelas volta para la.
 */
const Menu: React.FC<{
  title: string;
  eyebrow?: string;
  icon?: React.ReactNode;
  items: MenuItem[];
  index: number;
  active: boolean;
  onIndexChange: (index: number) => void;
  /** Clique num item de uma coluna de tras: fecha as colunas a esquerda dela e escolhe o item. */
  onPick: (index: number) => void;
  onBack?: () => void;
  onClose: () => void;
  closeLabel: string;
  /** X no cabecalho (submenus): fecha esta coluna e substitui o botao do rodape. */
  headerClose?: boolean;
  notice?: MenuNotice | null;
  empty?: string;
  loading?: string | null;
}> = ({ title, eyebrow, icon, items, index, active, onIndexChange, onPick, onBack, onClose, closeLabel, headerClose, notice, empty, loading }) => {
  const listRef = useRef<HTMLDivElement>(null);
  const current = items[index];

  // O item ativo fica sempre visivel; se for um campo, ele recebe o foco para digitar direto.
  useEffect(() => {
    const element = listRef.current?.querySelector<HTMLElement>(`[data-index="${index}"]`);
    element?.scrollIntoView({ block: 'nearest' });
    if (!active) return;
    const input = element?.querySelector<HTMLInputElement>('input');
    if (input) input.focus();
    else if (document.activeElement instanceof HTMLInputElement) document.activeElement.blur();
  }, [index, items.length, title, active]);

  const move = (delta: number) => {
    if (items.length === 0) return;
    onIndexChange((index + delta + items.length) % items.length);
  };

  const activate = (item?: MenuItem) => {
    if (!item || item.disabled || item.busy) return;
    if (item.input) item.input.onSubmit?.();
    else item.onSelect?.();
  };

  const goBack = () => (onBack ? onBack() : onClose());

  useEffect(() => {
    if (!active) return;
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
        case 'ArrowLeft':
          if (typing || !current?.submenu) return;
          event.preventDefault();
          activate(current);
          break;
        case 'ArrowRight':
          if (typing || !onBack) return;
          event.preventDefault();
          onBack();
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
          activate(current);
          break;
        case 'Backspace':
          if (typing) return;
          event.preventDefault();
          goBack();
          break;
        case 'Escape':
          event.preventDefault();
          goBack();
          break;
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  });

  return (
    <section className="menu" data-active={active} aria-label={title}>
      <header className="menu__header">
        {icon}
        <h1 className="menu__title" title={title}>{title}</h1>
        {eyebrow && <p className="eyebrow menu__eyebrow" title={eyebrow}>{eyebrow}</p>}
        {headerClose && (
          <button type="button" className="icon-button icon-button--small" aria-label="Fechar este menu" title="Fechar" onClick={onClose}>
            <X size={18} aria-hidden="true" />
          </button>
        )}
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
          const isCurrent = i === index;
          const kind = item.input ? 'input' : item.onSelect ? 'action' : 'info';
          const description = item.description;
          const content = (
            <>
              <span className="menu-item__icon">{item.icon}</span>
              <span className="menu-item__body">
                <span className={item.hideLabel ? 'sr-only' : 'menu-item__label'}>{item.label}</span>
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
                    onFocus={() => (active ? onIndexChange(i) : onPick(i))}
                  />
                ) : description && (
                  typeof description === 'string'
                    ? <span className="menu-item__description">{description}</span>
                    : <span className="menu-item__meta">{description}</span>
                )}
                {item.activeDescription && !item.input && (
                  <span className="menu-item__reveal" aria-hidden={!(isCurrent && active)}>{item.activeDescription}</span>
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
                  {kind === 'action' && <ChevronRight className="menu-item__chevron" size={16} aria-hidden="true" />}
                </span>
              )}
            </>
          );

          const common = {
            'data-index': i,
            'data-active': isCurrent,
            'data-kind': kind,
            'data-reveal': item.activeDescription ? true : undefined,
            'data-tone': item.tone,
            'data-meter': item.progress !== undefined ? meterTone(item.progress) : undefined,
            className: `menu-item${item.input ? ' menu-item--input' : ''}`,
            onMouseEnter: active ? () => onIndexChange(i) : undefined,
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
              aria-expanded={item.submenu ? (isCurrent && !active) : undefined}
              tabIndex={isCurrent && active ? 0 : -1}
              onClick={() => {
                if (!active) {
                  onPick(i);
                  return;
                }
                onIndexChange(i);
                if (kind === 'action') activate(item);
              }}
            >
              {content}
            </button>
          );
        })}
      </div>

      {!headerClose && (
        <footer className="menu__footer">
          <button type="button" className="button button--block" onClick={onClose}>{closeLabel}</button>
        </footer>
      )}
    </section>
  );
};

export default Menu;
