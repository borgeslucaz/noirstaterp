import React, { useMemo } from 'react';

// Cores do DESIGN_v4 (§3.1): durabilidade e "mais e melhor" (perigo ate 35%, alerta ate 60%,
// sucesso acima); peso e "mais e pior", entao fica neutro e so avisa perto de encher.
const DANGER = '#d51a1a';
const WARNING = '#d7a84b';
const SUCCESS = '#39df45';
const NEUTRAL = 'rgba(255, 255, 255, 0.82)';

const WeightBar: React.FC<{ percent: number; durability?: boolean }> = ({ percent, durability }) => {
  const color = useMemo(
    () =>
      durability
        ? percent <= 35
          ? DANGER
          : percent <= 60
            ? WARNING
            : SUCCESS
        : percent <= 80
          ? NEUTRAL
          : percent <= 95
            ? WARNING
            : DANGER,
    [durability, percent]
  );

  return (
    <div className={durability ? 'durability-bar' : 'weight-bar'}>
      <div
        style={{
          visibility: percent > 0 ? 'visible' : 'hidden',
          height: '100%',
          width: `${percent}%`,
          backgroundColor: color,
          transition: `background ${0.3}s ease, width ${0.3}s ease`,
        }}
      ></div>
    </div>
  );
};
export default WeightBar;
