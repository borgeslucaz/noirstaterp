import { IconProp } from '@fortawesome/fontawesome-svg-core';
import React, { forwardRef } from 'react';
import LibIcon from '../../../components/LibIcon';
import type { MenuItem } from '../../../typings';
import { isIconUrl } from '../../../utils/isIconUrl';
import { meterTone } from '../meter';

interface Props {
  item: MenuItem;
  index: number;
  scrollIndex: number;
  checked: boolean;
  active: boolean;
  iconColumn: boolean;
}

// Descrição do item ativo: a do valor escolhido (values com objeto) tem precedência.
export const itemDescription = (item: MenuItem, scrollIndex: number) => {
  const value = Array.isArray(item.values) ? item.values[scrollIndex] : undefined;
  if (typeof value === 'object' && value.description) return value.description;
  return item.description;
};

const hasAnyDescription = (item: MenuItem) =>
  !!item.description || (Array.isArray(item.values) && item.values.some((v) => typeof v === 'object' && !!v.description));

const ListItem = forwardRef<Array<HTMLDivElement | null>, Props>(({ item, index, scrollIndex, checked, active, iconColumn }, ref) => {
  const description = itemDescription(item, scrollIndex);
  const value = Array.isArray(item.values) ? item.values[scrollIndex] : undefined;
  const progress = item.progress !== undefined;
  // Altura reservada para a descrição de ativo: o menu não pula ao navegar.
  const reveal = hasAnyDescription(item) ? (progress ? 'progress' : '') : undefined;

  return (
    <div
      tabIndex={index}
      className="side-menu-item"
      data-active={active}
      data-icon={iconColumn ? '' : undefined}
      data-reveal={reveal}
      data-meter={progress ? meterTone(item.colorScheme) : undefined}
      ref={(element) => {
        // @ts-ignore forwardRef de array
        if (ref) ref.current[index] = element;
      }}
    >
      {iconColumn && (
        <span className="side-menu-item__icon">
          {!item.icon ? null : typeof item.icon === 'string' && isIconUrl(item.icon) ? (
            <img src={item.icon} alt="" />
          ) : (
            <LibIcon
              icon={item.icon as IconProp}
              fixedWidth
              style={{ color: item.iconColor }}
              animation={item.iconAnimation}
            />
          )}
        </span>
      )}
      <span className="side-menu-item__body">
        <span className="side-menu-item__label">{item.label}</span>
        {progress && (
          <span className="side-menu-item__progress">
            <span style={{ width: `${Math.max(0, Math.min(100, item.progress!))}%` }} />
          </span>
        )}
        {reveal !== undefined && <span className="side-menu-item__reveal">{description}</span>}
      </span>
      {Array.isArray(item.values) ? (
        <span className="side-menu-item__value">
          <span className="side-menu-item__value-label">{typeof value === 'object' ? value.label : value}</span>
          <span className="side-menu-item__count">
            {scrollIndex + 1}/{item.values.length}
          </span>
        </span>
      ) : item.checked !== undefined ? (
        <span className="side-menu-item__value">
          <span className="side-menu-item__check" data-checked={checked}>
            <LibIcon icon="check" />
          </span>
        </span>
      ) : null}
    </div>
  );
});

export default React.memo(ListItem);
