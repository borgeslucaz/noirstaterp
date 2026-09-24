import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import WeightBar from '../utils/WeightBar';
import InventorySlot from './InventorySlot';
import { getTotalWeight, isSlotWithItem } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';

const PAGE_SIZE = 30;

export const formatKg = (grams: number) =>
  (grams / 1000).toLocaleString('en-us', { minimumFractionDigits: 1, maximumFractionDigits: 1 });

interface Props {
  inventory: Inventory;
  // primeiro slot mostrado (os bolsos comecam depois dos atalhos 1-5)
  start?: number;
  className?: string;
  children?: React.ReactNode;
}

const InventoryGrid: React.FC<Props> = ({ inventory, start = 0, className, children }) => {
  const weight = useMemo(
    () =>
      inventory.maxWeight !== undefined
        ? Math.floor(getTotalWeight(inventory.items, inventory.equipment) * 1000) / 1000
        : 0,
    [inventory.maxWeight, inventory.items, inventory.equipment]
  );
  const itemCount = useMemo(
    () =>
      [...inventory.items, ...Object.values(inventory.equipment ?? {})].filter((item) => isSlotWithItem(item)).length,
    [inventory.items, inventory.equipment]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  const slots = inventory.items.slice(start, start + (page + 1) * PAGE_SIZE);

  return (
    <div
      className={`inventory-panel${className ? ` ${className}` : ''}`}
      style={{ pointerEvents: isBusy ? 'none' : 'auto' }}
    >
      <div className="inventory-panel-header">
        <div className="inventory-panel-title">
          <p>{inventory.label}</p>
          <span>{itemCount} itens</span>
        </div>
        {inventory.maxWeight ? (
          <p className="inventory-panel-weight">
            {formatKg(weight)} / {formatKg(inventory.maxWeight)} kg
          </p>
        ) : null}
      </div>
      {inventory.maxWeight ? <WeightBar percent={(weight / inventory.maxWeight) * 100} /> : null}
      {children}
      <div className="inventory-grid-container" ref={containerRef}>
        {slots.map((item, index) => (
          <InventorySlot
            key={`${inventory.type}-${inventory.id}-${item.slot}`}
            item={item}
            ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
            inventoryId={inventory.id}
          />
        ))}
      </div>
    </div>
  );
};

export default InventoryGrid;
