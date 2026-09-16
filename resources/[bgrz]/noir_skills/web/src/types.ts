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
};

export type SkillsPayload = {
  visible: boolean;
  skills: Skill[];
};
