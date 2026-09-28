import type { Skill } from './types';

// Cenários do preview no navegador (v4 §10). Em jogo quem manda a lista é o client/main.lua.
const skill = (
  name: string,
  label: string,
  icon: string,
  color: string,
  level: number,
  maxLevel: number,
  xp: number,
  need: number | null,
): Skill => ({ name, label, icon, color, level, maxLevel, xp, need, ratio: need ? xp / need : 1 });

const NORMAL: Skill[] = [
  skill('arrombamento', 'Arrombamento', 'key', '#FFC96B', 15, 15, 0, null),
  skill('mecanica', 'Mecânica', 'wrench', '#9BE8FF', 11, 20, 240, 341),
  skill('trafico', 'Tráfico', 'leaf', '#C48BFF', 3, 15, 44, 113),
];

const LONG: Skill[] = [
  ...NORMAL,
  skill('direcao', 'Direção', 'car', '#8FE3A1', 7, 20, 1180, 1420),
  skill('tiro', 'Pontaria com armas curtas', 'gun', '#FF8A7A', 2, 15, 12, 90),
  skill('quimica', 'Química', 'flask', '#7FD1C7', 9, 15, 520, 610),
  skill('carga', 'Carga', 'box', '#E0B98A', 5, 15, 88, 200),
  skill('negocios', 'Negócios', 'chart', '#A3B8FF', 12, 20, 12400, 18000),
  skill('pesca', 'Pesca', 'fish', '#6FC3FF', 1, 10, 3, 40),
  skill('forja', 'Forja', 'hammer', '#D9A06B', 4, 15, 150, 160),
  skill('furtividade', 'Furtividade', 'desconhecido', '#BFBFBF', 6, 15, 30, 250),
];

export const PREVIEWS: Record<string, Skill[]> = {
  Normal: NORMAL,
  Vazia: [],
  'Lista longa': LONG,
};
