import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { onDrop } from '../../dnd/onDrop';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { isSlotWithItem } from '../../helpers';
import { setClipboard } from '../../utils/setClipboard';
import { notify } from '../../utils/notify';
import { store, useAppDispatch, useAppSelector } from '../../store';
import { AmountAction, openAmountDialog } from '../../store/contextMenu';
import AmountDialog from './AmountDialog';
import React from 'react';
import { Menu, MenuItem } from '../utils/menu/Menu';
import { InventoryType, SlotWithItem } from '../../typings';

const RARITY_LABELS: Record<string, string> = {
  common: 'Comum',
  uncommon: 'Incomum',
  rare: 'Raro',
  epic: 'Épico',
  legendary: 'Lendário',
  mythic: 'Mítico',
};

const formatWeight = (weight: number) =>
  weight >= 1000
    ? `${(weight / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 2 })} kg`
    : `${weight.toLocaleString('pt-BR')} g`;

// Dividir: a quantidade escolhida vai para o primeiro slot vazio dos bolsos
const splitItem = (item: SlotWithItem, count: number) => {
  const { leftInventory } = store.getState().inventory;
  // bolsos primeiro (depois dos atalhos 1-5); atalho so se os bolsos estiverem cheios
  const isEmpty = (slot: SlotWithItem | { slot: number }) => !isSlotWithItem(slot);
  const emptySlot = leftInventory.items.slice(5).find(isEmpty) ?? leftInventory.items.slice(0, 5).find(isEmpty);

  if (!emptySlot) return notify('Sem espaço nos bolsos para dividir.');

  onDrop(
    { item: { name: item.name, slot: item.slot }, inventory: InventoryType.PLAYER },
    { item: { slot: emptySlot.slot }, inventory: InventoryType.PLAYER },
    count
  );
};

interface DataProps {
  action: string;
  component?: string;
  slot?: number;
  serial?: string;
  id?: number;
}

interface Button {
  label: string;
  index: number;
  group?: string;
}

interface Group {
  groupName: string | null;
  buttons: ButtonWithIndex[];
}

interface ButtonWithIndex extends Button {
  index: number;
}

interface GroupedButtons extends Array<Group> {}

// Acoes com quantidade, ja confirmada na janela (ou 1, para item sem pilha)
const runAmountAction = (action: AmountAction, item: SlotWithItem, count: number) => {
  switch (action) {
    case 'split':
      return splitItem(item, count);
    case 'give':
      return onGive({ name: item.name, slot: item.slot }, count);
    case 'drop':
      return onDrop({ item: item, inventory: 'player' }, undefined, count);
  }
};

const InventoryContext: React.FC = () => {
  const contextMenu = useAppSelector((state) => state.contextMenu);
  const dispatch = useAppDispatch();
  const item = contextMenu.item;

  // Dividir, Dar e Soltar pedem a quantidade quando ha mais de uma unidade
  const withAmount = (action: AmountAction) => {
    if (!item || !isSlotWithItem(item)) return;
    if (item.count > 1) return dispatch(openAmountDialog({ action, item }));

    runAmountAction(action, item, 1);
  };

  const handleClick = (data: DataProps) => {
    if (!item) return;

    switch (data && data.action) {
      case 'use':
        onUse({ name: item.name, slot: item.slot });
        break;
      case 'split':
      case 'give':
      case 'drop':
        withAmount(data.action as AmountAction);
        break;
      case 'remove':
        fetchNui('removeComponent', { component: data?.component, slot: data?.slot });
        break;
      case 'removeAmmo':
        fetchNui('removeAmmo', item.slot);
        break;
      case 'copy':
        setClipboard(data.serial || '');
        break;
      case 'custom':
        fetchNui('useButton', { id: (data?.id || 0) + 1, slot: item.slot });
        break;
    }
  };

  const groupButtons = (buttons: any): GroupedButtons => {
    return buttons.reduce((groups: Group[], button: Button, index: number) => {
      if (button.group) {
        const groupIndex = groups.findIndex((group) => group.groupName === button.group);
        if (groupIndex !== -1) {
          groups[groupIndex].buttons.push({ ...button, index });
        } else {
          groups.push({
            groupName: button.group,
            buttons: [{ ...button, index }],
          });
        }
      } else {
        groups.push({
          groupName: null,
          buttons: [{ ...button, index }],
        });
      }
      return groups;
    }, []);
  };

  const itemData = item?.name ? Items[item.name] : undefined;
  const canSplit = !!item && !!itemData?.stack && (item.count ?? 0) > 1;

  const header = item && (
    <div className="context-menu-header">
      <span>{RARITY_LABELS[itemData?.rarity ?? ''] ?? 'Item'}</span>
      <p>{item.metadata?.label || itemData?.label || item.name}</p>
      {item.weight > 0 && (
        <div className="context-menu-meta">
          <span>{formatWeight(item.weight)}</span>
        </div>
      )}
    </div>
  );

  const footer = (
    <div className="context-menu-footer">
      <span>
        <kbd>LMB</kbd> confirmar
      </span>
      <span>clique fora fecha</span>
    </div>
  );

  return (
    <>
      <AmountDialog onConfirm={runAmountAction} />
      <Menu header={header} footer={footer}>
        <MenuItem primary onClick={() => handleClick({ action: 'use' })} label={Locale.ui_use || 'Usar'} />
        {canSplit && <MenuItem onClick={() => handleClick({ action: 'split' })} label="Dividir" />}
        <MenuItem onClick={() => handleClick({ action: 'give' })} label={Locale.ui_give || 'Dar'} />
        <MenuItem onClick={() => handleClick({ action: 'drop' })} label={Locale.ui_drop || 'Soltar'} />
        {item && item.metadata?.ammo > 0 && (
          <MenuItem onClick={() => handleClick({ action: 'removeAmmo' })} label={Locale.ui_remove_ammo} />
        )}
        {item && item.metadata?.serial && (
          <MenuItem
            onClick={() => handleClick({ action: 'copy', serial: item.metadata?.serial })}
            label={Locale.ui_copy}
          />
        )}
        {item && item.metadata?.components && item.metadata?.components.length > 0 && (
          <Menu label={Locale.ui_removeattachments}>
            {item &&
              item.metadata?.components.map((component: string, index: number) => (
                <MenuItem
                  key={index}
                  onClick={() => handleClick({ action: 'remove', component, slot: item.slot })}
                  label={Items[component]?.label || ''}
                />
              ))}
          </Menu>
        )}
        {((item && item.name && Items[item.name]?.buttons?.length) || 0) > 0 && (
          <>
            {item &&
              item.name &&
              groupButtons(Items[item.name]?.buttons).map((group: Group, index: number) => (
                <React.Fragment key={index}>
                  {group.groupName ? (
                    <Menu label={group.groupName}>
                      {group.buttons.map((button: Button) => (
                        <MenuItem
                          key={button.index}
                          onClick={() => handleClick({ action: 'custom', id: button.index })}
                          label={button.label}
                        />
                      ))}
                    </Menu>
                  ) : (
                    group.buttons.map((button: Button) => (
                      <MenuItem
                        key={button.index}
                        onClick={() => handleClick({ action: 'custom', id: button.index })}
                        label={button.label}
                      />
                    ))
                  )}
                </React.Fragment>
              ))}
          </>
        )}
      </Menu>
    </>
  );
};

export default InventoryContext;
