import { canStack, findAvailableSlot, getSlot, getTargetInventory, isSlotWithItem, slotAccepts } from '../helpers';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';
import { notify } from '../utils/notify';

const itemLabel = (slot: SlotWithItem) => slot.metadata?.label || Items[slot.name]?.label || slot.name;

export const onDrop = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();

  const { sourceInventory, targetInventory } = getTargetInventory(state, source.inventory, target?.inventory);

  const sourceSlot = getSlot(sourceInventory, source.item.slot) as SlotWithItem;

  const sourceData = Items[sourceSlot.name];

  if (sourceData === undefined) return console.error(`${sourceSlot.name} item data undefined!`);

  // If dragging from container slot
  if (sourceSlot.metadata?.container !== undefined) {
    // Prevent storing container in container
    if (targetInventory.type === InventoryType.CONTAINER || targetInventory.type === InventoryType.BACKPACK)
      return notify(`Não dá para guardar ${itemLabel(sourceSlot)} dentro de outro container.`);

    // Prevent dragging of container slot when opened
    if (state.rightInventory.id === sourceSlot.metadata.container)
      return notify(`Feche ${itemLabel(sourceSlot)} antes de mover.`);
  }

  // equipment: regras da mochila equipada que o servidor tambem aplica
  if (sourceInventory.type === InventoryType.BACKPACK && targetInventory.type === 'newdrop')
    return notify('Tire o item da mochila antes de largar no chão.');

  if (
    (sourceInventory.type === InventoryType.BACKPACK && targetInventory.type === InventoryType.CONTAINER) ||
    (sourceInventory.type === InventoryType.CONTAINER && targetInventory.type === InventoryType.BACKPACK)
  )
    return notify(`Feche ${state.rightInventory.label || 'o container aberto'} para mover entre ele e a mochila.`);

  const targetSlot = target
    ? getSlot(targetInventory, target.item.slot)
    : findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

  if (targetSlot === undefined) return notify(`Sem espaço em ${targetInventory.label || 'destino'}.`);

  // equipment: slot de equipamento so recebe os itens dele, inclusive na troca de volta
  if (
    !slotAccepts(targetInventory.type, targetSlot.slot, sourceSlot.name) ||
    (isSlotWithItem(targetSlot) && !slotAccepts(sourceInventory.type, sourceSlot.slot, targetSlot.name))
  )
    return;

  // If dropping on container slot when opened
  if (targetSlot.metadata?.container !== undefined && state.rightInventory.id === targetSlot.metadata.container)
    return notify(`Feche ${itemLabel(targetSlot as SlotWithItem)} antes de trocar.`);

  const count =
    state.shiftPressed && sourceSlot.count > 1 && sourceInventory.type !== 'shop'
      ? Math.floor(sourceSlot.count / 2)
      : state.itemAmount === 0 || state.itemAmount > sourceSlot.count
        ? sourceSlot.count
        : state.itemAmount;

  const data = {
    fromSlot: sourceSlot,
    toSlot: targetSlot,
    fromType: sourceInventory.type,
    toType: targetInventory.type,
    count: count,
  };

  const usesBackpack = data.fromType === InventoryType.BACKPACK || data.toType === InventoryType.BACKPACK;

  store.dispatch(
    validateMove({
      ...data,
      fromSlot: sourceSlot.slot,
      toSlot: targetSlot.slot,
      containerId: usesBackpack ? state.backpackInventory.id : state.rightInventory.id,
    })
  );

  isSlotWithItem(targetSlot, true)
    ? sourceData.stack && canStack(sourceSlot, targetSlot)
      ? store.dispatch(
          stackSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
      : store.dispatch(
          swapSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
    : store.dispatch(moveSlots(data));
};
