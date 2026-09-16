<script lang="ts">
  import Icon from './Icon.svelte';
  import type { Skill } from '../types';

  let { skill }: { skill: Skill } = $props();

  // Tinta do ícone calculada aqui em vez de `color-mix()` no CSS: o CEF do FiveM é uma
  // versão fixa do Chromium, e função de cor recente falharia deixando o tile sem fundo.
  const tint = (hex: string, alpha: number): string => {
    const short = hex.length === 4;
    const part = (index: number) =>
      parseInt(short ? hex[index + 1].repeat(2) : hex.slice(index * 2 + 1, index * 2 + 3), 16) || 0;
    return `rgba(${part(0)}, ${part(1)}, ${part(2)}, ${alpha})`;
  };

  const maxed = $derived(skill.need === null || skill.need === undefined);
  const percent = $derived(Math.round(Math.min(Math.max(skill.ratio, 0), 1) * 100));
  const format = (value: number) => value.toLocaleString('pt-BR');
</script>

<!-- A cor da habilidade fica no ícone e na barra: superfície e texto continuam neutros,
     como pede a v3 para cor semântica em área pequena. -->
<article class="card" style="--skill: {skill.color}; --skill-soft: {tint(skill.color, 0.13)}">
  <div class="icon"><Icon name={skill.icon} /></div>

  <div class="body">
    <div class="head">
      <h2>{skill.label}</h2>
      <p class="level">
        {#if maxed}
          Nível máximo
        {:else}
          Nível <strong>{skill.level}</strong><span class="of">/{skill.maxLevel}</span>
        {/if}
      </p>
    </div>

    <div
      class="track"
      role="progressbar"
      aria-label="Progresso de {skill.label}"
      aria-valuenow={percent}
      aria-valuemin="0"
      aria-valuemax="100"
    >
      <div class="fill" style="width: {percent}%"></div>
    </div>

    <div class="meta">
      <span>
        {#if maxed}
          Habilidade completa
        {:else}
          {format(skill.xp)} / {format(skill.need!)} XP
        {/if}
      </span>
      <span class="percent">{percent}%</span>
    </div>
  </div>
</article>

<style>
  .card {
    display: grid;
    grid-template-columns: 40px minmax(0, 1fr);
    align-items: center;
    gap: 12px;
    padding: 12px;
    border: 1px solid var(--noir-border-soft);
    border-radius: var(--radius-sm);
    background: var(--noir-card);
  }

  .icon {
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    border-radius: var(--radius-sm);
    color: var(--skill);
    background: var(--skill-soft);
  }

  .body {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .head {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 12px;
  }

  h2 {
    font-size: 15px;
    font-weight: 600;
    line-height: 1.3;
    color: var(--noir-text-strong);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .level {
    flex: none;
    font-size: 12px;
    font-weight: 500;
    line-height: 1.3;
    color: var(--noir-text-muted);
    font-variant-numeric: tabular-nums;
  }

  .level strong {
    font-weight: 600;
    color: var(--noir-text-strong);
  }

  .of {
    color: var(--noir-text-muted);
  }

  .track {
    height: 4px;
    border-radius: var(--radius-pill);
    background: var(--noir-field);
    overflow: hidden;
  }

  .fill {
    height: 100%;
    border-radius: var(--radius-pill);
    background: var(--skill);
    transition: width var(--duration-panel) var(--ease-soft);
  }

  .meta {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    font-size: 11px;
    font-weight: 400;
    line-height: 1.4;
    color: var(--noir-text-muted);
    font-variant-numeric: tabular-nums;
  }

  .percent {
    color: var(--noir-text);
  }
</style>
