<script lang="ts">
  import Icon from './lib/Icon.svelte';
  import SkillCard from './lib/SkillCard.svelte';
  import { fetchNui, isBrowser, onNuiMessage } from './lib/nui';
  import type { Skill, SkillsPayload } from './types';

  let visible = $state(false);
  let skills = $state<Skill[]>([]);

  const close = () => {
    visible = false;
    fetchNui('close');
  };

  $effect(() =>
    onNuiMessage<SkillsPayload>('skills', (data) => {
      skills = data.skills ?? [];
      visible = data.visible;
    }),
  );

  $effect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (visible && (event.key === 'Escape' || event.key === 'Backspace')) close();
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  // `npm run dev` abre com dados de exemplo; em jogo isto nunca roda. Só habilidades com
  // XP entram na lista — o cliente já filtra as zeradas antes de mandar para cá.
  if (isBrowser()) {
    skills = [
      { name: 'arrombamento', label: 'Arrombamento', icon: 'key', color: '#FFC96B', level: 15, maxLevel: 15, xp: 0, need: null, ratio: 1 },
      { name: 'mecanica', label: 'Mecânica', icon: 'wrench', color: '#9BE8FF', level: 11, maxLevel: 20, xp: 240, need: 341, ratio: 240 / 341 },
      { name: 'trafico', label: 'Tráfico', icon: 'leaf', color: '#C48BFF', level: 3, maxLevel: 15, xp: 44, need: 113, ratio: 44 / 113 },
    ];
    visible = true;
  }
</script>

{#if visible}
  <main>
    <section class="panel">
      <header>
        <div class="title">
          <p class="eyebrow">Personagem</p>
          <h1>Habilidades</h1>
        </div>

        <button type="button" class="close" onclick={close} title="Fechar (ESC)" aria-label="Fechar">
          <Icon name="close" size={18} />
        </button>
      </header>

      <div class="list">
        {#each skills as skill (skill.name)}
          <SkillCard {skill} />
        {:else}
          <div class="empty">
            <p class="empty-title">Nenhuma habilidade treinada</p>
            <p>Elas aparecem aqui assim que você ganhar o primeiro XP.</p>
          </div>
        {/each}
      </div>
    </section>
  </main>
{/if}

<style>
  /* Tamanho e posição validados em jogo: painel lateral à direita, sem cobrir a cena.
     A v3 entra na superfície, na tipografia, na forma e no movimento. */
  main {
    position: fixed;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    /* Safe zone: nada encosta na borda da tela nem no HUD. */
    padding: clamp(24px, 4vh, 56px);
  }

  .panel {
    display: grid;
    grid-template-rows: auto minmax(0, 1fr);
    width: min(384px, 92vw);
    max-height: min(80dvh, 720px);
    min-height: 0;
    overflow: hidden;
    border: 1px solid var(--noir-border-soft);
    border-radius: var(--radius-md);
    background: var(--noir-canvas);
    box-shadow: var(--shadow-window);
    animation: panel-in var(--duration-panel) var(--ease-out);
  }

  header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
    padding: 16px 16px 12px;
    border-bottom: 1px solid var(--noir-divider);
  }

  .eyebrow {
    font-size: 11px;
    font-weight: 600;
    line-height: 1.3;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--noir-text-muted);
  }

  h1 {
    margin-top: 2px;
    font-size: 24px;
    font-weight: 700;
    line-height: 1.15;
    letter-spacing: -0.025em;
    color: var(--noir-text-strong);
  }

  .close {
    flex: none;
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--noir-text-muted);
    cursor: pointer;
    transition:
      color var(--duration-control) var(--ease-soft),
      border-color var(--duration-control) var(--ease-soft),
      background-color var(--duration-control) var(--ease-soft);
  }

  .close:hover {
    color: var(--noir-text-strong);
    border-color: var(--noir-border-strong);
    background: var(--noir-field);
  }

  .close:focus-visible {
    outline: none;
    color: var(--noir-text-strong);
    border-color: var(--noir-border-strong);
    box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.07);
  }

  /* Só a lista rola: o painel inteiro nunca ganha barra de rolagem. */
  .list {
    display: flex;
    flex-direction: column;
    gap: 8px;
    min-height: 0;
    padding: 12px 16px 16px;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--noir-border-strong) transparent;
  }

  .list::-webkit-scrollbar {
    width: 6px;
  }

  .list::-webkit-scrollbar-thumb {
    border-radius: var(--radius-pill);
    background: var(--noir-border-strong);
  }

  .empty {
    padding: 24px 0;
    text-align: center;
    font-size: 13px;
    line-height: 1.5;
    color: var(--noir-text-muted);
  }

  .empty-title {
    margin-bottom: 4px;
    font-size: 15px;
    font-weight: 600;
    color: var(--noir-text-strong);
  }

  @keyframes panel-in {
    from {
      opacity: 0;
      transform: translateX(16px);
    }
  }
</style>
