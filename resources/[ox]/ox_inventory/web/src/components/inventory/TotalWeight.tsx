import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { getTotalWeight } from '../../helpers';
import WeightBar from '../utils/WeightBar';
import { formatKg } from './InventoryGrid';

// Peso carregado pelo jogador: bolsos, atalhos e equipamento (a mochila conta com o conteudo).
const TotalWeight: React.FC = () => {
  const { items, equipment, maxWeight } = useAppSelector(selectLeftInventory);
  const weight = useMemo(() => getTotalWeight(items, equipment), [items, equipment]);

  if (!maxWeight) return null;

  return (
    <div className="total-weight">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.6} strokeLinejoin="round">
        <path d="M6 8h12l2 13H4zM9 8a3 3 0 0 1 6 0" />
      </svg>
      <div>
        <span>Peso total</span>
        <p>
          {formatKg(weight)} / {formatKg(maxWeight)} kg
        </p>
        <WeightBar percent={(weight / maxWeight) * 100} />
      </div>
    </div>
  );
};

export default TotalWeight;
