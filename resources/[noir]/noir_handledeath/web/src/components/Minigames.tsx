import { useEffect, useRef, useState } from 'react';
import { Bird, ChevronLeft, Grid2x2, X } from 'lucide-react';

type GameId = '2048' | 'clumsy';

const GAMES = [
  { id: '2048' as const, title: '2048', description: 'Junte os números até chegar a 2048. Setas ou WASD.', src: './games/2048/index.html', icon: Grid2x2 },
  { id: 'clumsy' as const, title: 'Clumsy Bird', description: 'Passe entre os canos. Espaço ou clique.', src: './games/clumsy-bird/index.html', icon: Bird },
];

const ARROWS = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'w', 'a', 's', 'd', 'W', 'A', 'S', 'D'];

interface Props {
  onClose: () => void;
}

// Janela central (DESIGN_v4 §6). O CEF nao entrega o teclado ao iframe de forma confiavel, entao
// as teclas do jogo sao repassadas por postMessage (os jogos foram adaptados para isso).
export default function Minigames({ onClose }: Props) {
  const [gameId, setGameId] = useState<GameId | null>(null);
  const frameRef = useRef<HTMLIFrameElement>(null);
  const game = GAMES.find((item) => item.id === gameId) ?? null;

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      event.stopPropagation();
      if (event.key === 'Escape') {
        event.preventDefault();
        if (gameId) setGameId(null);
        else onClose();
        return;
      }

      const target = frameRef.current?.contentWindow;
      if (!gameId || !target) return;

      if (gameId === 'clumsy' && (event.code === 'Space' || event.key === ' ')) {
        event.preventDefault();
        if (!event.repeat) target.postMessage({ type: 'clumsy-key', code: event.code, key: event.key }, '*');
        return;
      }
      if (gameId === '2048' && ARROWS.includes(event.key)) {
        event.preventDefault();
        target.postMessage({ type: '2048-key', key: event.key, which: event.which || event.keyCode }, '*');
      }
    };
    // Esc apertado com o foco dentro do jogo chega por mensagem do iframe.
    const onMessage = (event: MessageEvent) => {
      if (event.source !== frameRef.current?.contentWindow || event.data?.type !== 'minigame-escape') return;
      setGameId(null);
    };
    // Captura: a tela de tras nao ve a tecla enquanto a janela esta aberta.
    window.addEventListener('keydown', onKey, true);
    window.addEventListener('message', onMessage);
    return () => {
      window.removeEventListener('keydown', onKey, true);
      window.removeEventListener('message', onMessage);
    };
  }, [gameId, onClose]);

  return (
    <div className="overlay">
      <div className={`window${game ? ' window--game' : ''}`} role="dialog" aria-modal="true" aria-label="Jogos">
        <header className="window__head">
          {game && (
            <button type="button" className="icon-button" onClick={() => setGameId(null)} aria-label="Voltar">
              <ChevronLeft size={20} />
            </button>
          )}
          <h2 className="window__title">{game ? game.title : 'Jogos'}</h2>
          <button type="button" className="icon-button" onClick={onClose} aria-label="Fechar">
            <X size={20} />
          </button>
        </header>

        {game ? (
          <iframe ref={frameRef} className="window__frame" src={game.src} title={game.title} />
        ) : (
          <ul className="window__list">
            {GAMES.map((item) => {
              const Icon = item.icon;
              return (
                <li key={item.id}>
                  <button type="button" className="death__action" onClick={() => setGameId(item.id)}>
                    <Icon className="death__action-icon" size={20} aria-hidden="true" />
                    <span className="death__action-text">
                      <span className="death__action-label">{item.title}</span>
                      <span className="death__action-desc">{item.description}</span>
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

    </div>
  );
}
