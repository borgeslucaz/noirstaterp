<script lang="ts">
  // Família linear única (traço 1.6px, no espírito do Lucide), desenhada aqui dentro em vez
  // de vir de uma fonte de ícones remota. Nome desconhecido cai no padrão: habilidade nova
  // no config aparece na hora, com ícone genérico, em vez de sumir da lista.
  const ICONS: Record<string, string> = {
    car: '<path d="M4.2 12.8 6 8.4A2 2 0 0 1 7.9 7.1h8.2a2 2 0 0 1 1.9 1.3l1.8 4.4"/><path d="M3 12.8h18v4.4a.6.6 0 0 1-.6.6H19a1 1 0 0 1-1-1v-1.1H6v1.1a1 1 0 0 1-1 1H3.6a.6.6 0 0 1-.6-.6z"/><circle cx="7.1" cy="15.4" r=".9"/><circle cx="16.9" cy="15.4" r=".9"/>',
    gun: '<path d="M3 8.4h11.4l3.4 2.5H21v2.6h-3.4l-2 3.4h-3l-1.3-3.4H8.6v3.6a1 1 0 0 1-1 1H6.4A3.4 3.4 0 0 1 3 14.7z"/>',
    key: '<circle cx="8" cy="12" r="3.6"/><path d="M11.6 12H21m-3.2 0v2.6m-3-2.6v2"/>',
    flask: '<path d="M9.4 3v6.3l-4.6 7.6A2 2 0 0 0 6.5 20h11a2 2 0 0 0 1.7-3.1L14.6 9.3V3"/><path d="M8 3h8M7.4 14.2h9.2"/>',
    wrench: '<path d="M20.4 6.6a5.5 5.5 0 0 1-7.2 7.2l-6.4 6.4a2.1 2.1 0 0 1-3-3l6.4-6.4a5.5 5.5 0 0 1 7.2-7.2l-3.3 3.3.9 3 3 .9z"/>',
    box: '<path d="M12 3 21 7.5v9L12 21l-9-4.5v-9z"/><path d="m3 7.5 9 4.5 9-4.5M12 12v9"/>',
    chart: '<path d="M4 4v16h16"/><path d="M8 16.5v-4.8M12.5 16.5V7.6M17 16.5V11"/>',
    leaf: '<path d="M5 19c0-8.2 5-13 15-13 0 9-4.6 13-11 13H5z"/><path d="M5.2 19c2.4-4 5.4-6.7 8.8-8.3"/>',
    fish: '<path d="M3.8 12c3.6-4.4 7.3-5.9 10.5-5.9 3.7 0 6.1 2.4 6.6 5.9-.5 3.5-2.9 5.9-6.6 5.9-3.2 0-6.9-1.5-10.5-5.9z"/><path d="M6.6 12H7"/>',
    hammer: '<path d="m14.2 6.1 3.9-3.1L21 6l-3 4z"/><path d="M13.6 7.6 5 16.2a2.1 2.1 0 0 0 3 3l8.6-8.6z"/>',
    close: '<path d="M6.4 6.4 17.6 17.6M17.6 6.4 6.4 17.6"/>',
    default: '<path d="m12 3.6 2.6 5.3 5.9.8-4.3 4.2 1 5.8-5.2-2.7-5.2 2.7 1-5.8L3.5 9.7l5.9-.8z"/>',
  };

  let { name, size = 20 }: { name: string; size?: number } = $props();
  const markup = $derived(ICONS[name] ?? ICONS.default);
</script>

<!-- Decorativo: quem nomeia o que o ícone significa é o texto ao lado. -->
<svg
  aria-hidden="true"
  focusable="false"
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="1.6"
  stroke-linecap="round"
  stroke-linejoin="round"
>
  {@html markup}
</svg>
