export const formatClock = (total: number): string => {
  const safe = Math.max(0, Math.floor(total));
  const minutes = Math.floor(safe / 60);
  const seconds = safe % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
};

export const formatMoney = (value: number): string => `$${value.toLocaleString('pt-BR')}`;
