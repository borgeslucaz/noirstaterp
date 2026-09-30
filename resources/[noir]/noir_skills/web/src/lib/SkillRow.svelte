<script lang="ts">
  import Icon from './Icon.svelte';
  import type { Skill } from '../types';

  let { skill }: { skill: Skill } = $props();

  const maxed = $derived(skill.need === null || skill.need === undefined);
  const percent = $derived(Math.round(Math.min(Math.max(skill.ratio, 0), 1) * 100));
  const format = (value: number) => value.toLocaleString('pt-BR');
</script>

<!-- Linha informativa do Menu Lateral (v4 ML.4): sem hover nem seleção. A cor da habilidade
     fica só na barra — detalhe, não superfície. -->
<li class="row" style="--skill: {skill.color}">
  <span class="icon"><Icon name={skill.icon} size={18} /></span>

  <span class="body">
    <span class="label">{skill.label}</span>
    {#if skill.title}<span class="title">{skill.title}</span>{/if}
    <span class="description">
      {#if maxed}
        Habilidade completa
      {:else}
        {format(skill.xp)} / {format(skill.need!)} XP · {percent}%
      {/if}
    </span>
  </span>

  <span class="value">
    {#if maxed}
      Máximo
    {:else}
      Nível {skill.level}<span class="of">/{skill.maxLevel}</span>
    {/if}
  </span>

  <span
    class="track"
    role="progressbar"
    aria-label="Progresso de {skill.label}"
    aria-valuenow={percent}
    aria-valuemin="0"
    aria-valuemax="100"
  >
    <span class="fill" style="width: {percent}%"></span>
  </span>

  {#if skill.nextTitle}
    <span class="next">Próximo título: {skill.nextTitle.title} · nível {skill.nextTitle.level}</span>
  {/if}
</li>

<style>
  .row {
    display: grid;
    grid-template-columns: 18px minmax(0, 1fr) auto;
    grid-template-rows: auto auto;
    align-items: center;
    column-gap: 12px;
    row-gap: 8px;
    min-height: 72px;
    padding: 12px 20px;
  }

  .icon {
    display: grid;
    place-items: center;
    color: rgba(255, 255, 255, 0.82);
  }

  .body {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .label {
    overflow: hidden;
    font-family: var(--font-display);
    font-size: 18px;
    font-weight: 500;
    line-height: 1.15;
    letter-spacing: 0.02em;
    text-transform: uppercase;
    white-space: nowrap;
    text-overflow: ellipsis;
    color: var(--noir-text-strong);
  }

  .title {
    font-size: 13.5px;
    font-weight: 600;
    line-height: 1.25;
    color: var(--noir-text);
  }

  .description {
    font-size: 12.5px;
    font-weight: 500;
    line-height: 1.3;
    color: var(--noir-text-muted);
    font-variant-numeric: tabular-nums;
  }

  .value {
    align-self: start;
    padding-top: 1px;
    font-size: 14px;
    font-weight: 600;
    white-space: nowrap;
    color: var(--noir-text-strong);
    font-variant-numeric: tabular-nums;
  }

  .of {
    color: var(--noir-text-muted);
  }

  /* A barra ocupa a largura do texto e do valor, alinhada ao rótulo e não ao ícone. */
  .track {
    grid-column: 2 / 4;
    display: block;
    height: 4px;
    overflow: hidden;
    border-radius: var(--radius);
    background: rgba(255, 255, 255, 0.08);
  }

  /* O próximo título fica embaixo da barra: é o que a barra está buscando. */
  .next {
    grid-column: 2 / 4;
    margin-top: -2px;
    font-size: 12px;
    font-weight: 500;
    line-height: 1.3;
    color: var(--noir-text-muted);
  }

  .fill {
    display: block;
    height: 100%;
    background: var(--skill);
    transition: width var(--duration-panel) var(--ease-out);
  }
</style>
