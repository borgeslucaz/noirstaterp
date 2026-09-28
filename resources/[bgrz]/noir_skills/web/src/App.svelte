<script lang="ts">
  import Icon from './lib/Icon.svelte';
  import SkillRow from './lib/SkillRow.svelte';
  import { fetchNui, isBrowser, onNuiMessage } from './lib/nui';
  import { PREVIEWS } from './preview';
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

  // v4 ML.6: coluna única, então Esc, Backspace e → fecham.
  $effect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (!visible) return;
      if (event.key === 'Escape' || event.key === 'Backspace' || event.key === 'ArrowRight') close();
    };

    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  // `npm run dev` abre com dados de exemplo; em jogo isto nunca roda. `?preset=` escolhe o
  // cenário direto pela URL. Só habilidades com XP chegam aqui — o cliente já filtra as zeradas.
  const browser = isBrowser();
  const openPreview = (name: string) => {
    skills = PREVIEWS[name] ?? PREVIEWS.Normal;
    visible = true;
  };

  if (browser) openPreview(new URLSearchParams(location.search).get('preset') ?? 'Normal');
</script>

{#if visible}
  <aside class="menu" aria-labelledby="skills-title">
    <header>
      <h1 id="skills-title">Habilidades</h1>
      <p class="subtitle">Personagem</p>

      <button type="button" class="close" onclick={close} aria-label="Fechar">
        <Icon name="close" size={20} />
      </button>
    </header>

    <ul class="list">
      {#each skills as skill (skill.name)}
        <SkillRow {skill} />
      {:else}
        <li class="empty">
          <span class="empty-title">Nenhuma habilidade treinada</span>
          <span>Elas aparecem aqui assim que você ganhar o primeiro XP.</span>
        </li>
      {/each}
    </ul>
  </aside>

  <div class="keys">
    <span class="key"><kbd>ESC</kbd>Fechar</span>
  </div>
{/if}

{#if browser}
  <div class="dev">
    {#each Object.keys(PREVIEWS) as name (name)}
      <button type="button" onclick={() => openPreview(name)}>{name}</button>
    {/each}
  </div>
{/if}

<style>
  /* v4 ML.2: coluna colada na borda direita, de cima a baixo. */
  .menu {
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    width: clamp(320px, 20vw, 380px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    background: linear-gradient(180deg, rgba(12, 14, 18, 0.94) 0%, rgba(12, 14, 18, 0.8) 100%);
    animation: menu-in var(--duration-panel) var(--ease-out);
  }

  header {
    position: relative;
    flex: none;
    min-height: 104px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 2px;
    padding: 18px 56px 16px 20px;
    background: linear-gradient(180deg, rgba(0, 0, 0, 0.55), rgba(0, 0, 0, 0.25));
  }

  h1 {
    font-family: var(--font-display);
    font-size: 34px;
    font-weight: 700;
    line-height: 1;
    letter-spacing: 0.01em;
    text-transform: uppercase;
    color: var(--noir-text-strong);
  }

  .subtitle {
    font-size: 15px;
    font-weight: 500;
    color: var(--noir-text);
  }

  .close {
    position: absolute;
    top: 14px;
    right: 12px;
    display: grid;
    place-items: center;
    width: 40px;
    height: 40px;
    border: 0;
    border-radius: var(--radius);
    background: transparent;
    color: var(--noir-text-muted);
    cursor: pointer;
    transition:
      color var(--duration-control) var(--ease-soft),
      background-color var(--duration-control) var(--ease-soft);
  }

  .close:hover {
    color: var(--noir-text-strong);
    background: rgba(255, 255, 255, 0.06);
  }

  .close:focus-visible {
    outline: 2px solid rgba(255, 255, 255, 0.78);
    outline-offset: 2px;
  }

  /* Só a lista rola; a folga de baixo impede que as teclas cubram a última linha. */
  .list {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    list-style: none;
    padding: 4px 0 64px;
  }

  .empty {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 16px 20px;
    font-size: 12.5px;
    font-weight: 500;
    line-height: 1.4;
    color: var(--noir-text-muted);
  }

  .empty-title {
    font-family: var(--font-display);
    font-size: 18px;
    font-weight: 500;
    letter-spacing: 0.02em;
    text-transform: uppercase;
    color: var(--noir-text-strong);
  }

  /* v4 §7: teclas visíveis no canto inferior direito. */
  .keys {
    position: fixed;
    right: 16px;
    bottom: 16px;
    display: flex;
    gap: 8px;
  }

  .key {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 5px 10px 5px 6px;
    border-radius: var(--radius);
    background: rgba(0, 0, 0, 0.72);
    font-family: var(--font-display);
    font-size: 14px;
    font-weight: 700;
    letter-spacing: 0.03em;
    text-transform: uppercase;
    color: #fff;
  }

  .key kbd {
    min-width: 22px;
    padding: 1px 5px;
    border-radius: var(--radius);
    background: var(--noir-selection);
    font: 700 11px/1.4 var(--font-ui);
    text-align: center;
    color: var(--noir-on-light);
  }

  /* Botões de cenário: só no navegador, canto inferior esquerdo (v4 §10). */
  .dev {
    position: fixed;
    left: 16px;
    bottom: 16px;
    display: flex;
    gap: 8px;
  }

  .dev button {
    padding: 8px 12px;
    border: 1px solid rgba(255, 255, 255, 0.11);
    border-radius: var(--radius);
    background: #171719;
    font-family: var(--font-display);
    font-size: 14px;
    font-weight: 700;
    text-transform: uppercase;
    color: var(--noir-text-strong);
    cursor: pointer;
  }

  @media (max-height: 760px) {
    header {
      min-height: 64px;
      padding-block: 10px;
    }
  }

  @keyframes menu-in {
    from {
      opacity: 0;
      transform: translateX(16px);
    }
  }
</style>
