export type Skill = {
  name: string;
  label: string;
  icon: string;
  color: string;
  level: number;
  maxLevel: number;
  /** XP dentro do nível atual. */
  xp: number;
  /** XP que o nível atual pede; ausente quando a habilidade está no máximo. */
  need: number | null;
  ratio: number;
  /** Título do nível atual; ausente se a habilidade não tem títulos até aqui. */
  title?: string | null;
  /** Próximo título e o nível em que ele chega; ausente no último. */
  nextTitle?: { level: number; title: string } | null;
};

export type SkillsPayload = {
  visible: boolean;
  skills: Skill[];
};
