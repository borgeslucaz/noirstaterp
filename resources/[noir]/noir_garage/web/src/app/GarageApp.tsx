import React, { useCallback, useState } from 'react';
import {
  ArrowLeftRight, CarFront, Eye, EyeOff, Fuel, Gauge, History, KeyRound, Lock, Pencil, Save, Search,
  Star, Warehouse, Wrench, Undo2, Check,
} from 'lucide-react';

import Menu, { MenuItem, MenuNotice } from '../components/Menu';
import { VehicleIcon, vehicleStatus } from '../components/vehicle';
import { fetchNui } from '../utils/fetchNui';
import { useNuiEvent } from '../hooks/useNuiEvent';
import { isEnvBrowser } from '../utils/misc';
import {
  GarageDataProps, GarageOption, LogProps, VehicleProps, VehicleStatsProps, formatMoney,
} from '../utils/interface';

const FAVORITE_STORAGE_KEY = 'garage_favorite';

const loadFavorites = (): Record<string, boolean> => {
  try {
    return JSON.parse(localStorage.getItem(FAVORITE_STORAGE_KEY) || '{}');
  } catch {
    return {};
  }
};

type Page =
  | { id: 'root' }
  | { id: 'vehicle' }
  | { id: 'rename' }
  | { id: 'transfer' }
  | { id: 'transferConfirm'; target: GarageOption }
  | { id: 'lock' }
  | { id: 'history' }
  | { id: 'stats' };

interface StackEntry {
  page: Page;
  index: number;
}

// Abre no primeiro carro, nao na busca (item 0).
const ROOT: StackEntry[] = [{ page: { id: 'root' }, index: 1 }];
const money = (value: number) => `$${formatMoney(value)}`;

const App: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [garage, setGarage] = useState<GarageDataProps | null>(null);
  const [vehicles, setVehicles] = useState<VehicleProps[]>([]);
  const [favorites, setFavorites] = useState<Record<string, boolean>>(loadFavorites);
  const [stack, setStack] = useState<StackEntry[]>(ROOT);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [search, setSearch] = useState('');
  const [notice, setNotice] = useState<MenuNotice | null>(null);

  const [renameValue, setRenameValue] = useState('');
  const [logs, setLogs] = useState<LogProps[] | null>(null);
  const [targets, setTargets] = useState<GarageOption[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const [previewing, setPreviewing] = useState(false);
  const [stats, setStats] = useState<VehicleStatsProps | null>(null);

  const top = stack[stack.length - 1];
  const vehicle = vehicles.find(v => v.id === selectedId) ?? null;

  const stopPreview = useCallback(() => {
    setPreviewing(previous => {
      if (previous) fetchNui('hideVehiclePreview', {}, { data: 1 });
      return false;
    });
    setStats(null);
  }, []);

  const reset = () => {
    stopPreview();
    setVisible(false);
    setStack(ROOT);
    setSelectedId(null);
    setSearch('');
    setNotice(null);
    setBusy(null);
  };

  const close = () => {
    reset();
    if (!isEnvBrowser()) fetchNui('exit');
  };

  useNuiEvent('setVisible', (data: { visible: boolean; vehicles?: VehicleProps[]; garage?: GarageDataProps }) => {
    if (!data.visible) {
      reset();
      return;
    }
    setVehicles(Array.isArray(data.vehicles) ? data.vehicles : []);
    if (data.garage) setGarage(data.garage);
    setStack(ROOT);
    setVisible(true);
  });

  const push = (page: Page) => {
    setNotice(null);
    setStack(previous => [...previous, { page, index: 0 }]);
  };

  const back = () => {
    setNotice(null);
    if (top.page.id === 'vehicle') {
      stopPreview();
      setSelectedId(null);
    }
    setStack(previous => (previous.length > 1 ? previous.slice(0, -1) : previous));
  };

  const setIndex = (index: number) => {
    setStack(previous => previous.map((entry, i) => (i === previous.length - 1 ? { ...entry, index } : entry)));
  };

  /** Fecha as colunas a esquerda de `level`, que volta a ser a ativa. */
  const goToLevel = (level: number) => {
    if (level >= stack.length - 1) return;
    setNotice(null);
    if (stack.slice(level + 1).some(entry => entry.page.id === 'vehicle')) {
      stopPreview();
      setSelectedId(null);
    }
    setStack(previous => previous.slice(0, level + 1));
  };

  /** Clique numa coluna de tras: volta para ela, marca o item e o escolhe. */
  const pick = (level: number, index: number, item?: MenuItem) => {
    goToLevel(level);
    setStack(previous => previous.map((entry, i) => (i === level ? { ...entry, index } : entry)));
    if (item && !item.disabled && !item.busy && !item.input) item.onSelect?.();
  };

  const toggleFavorite = (id: number) => {
    setFavorites(previous => {
      const next = { ...previous, [id]: !previous[id] };
      try {
        localStorage.setItem(FAVORITE_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // sem localStorage, o favorito vale so ate fechar o jogo
      }
      return next;
    });
  };

  // ── Acoes ──────────────────────────────────────────────────────────────

  const openVehicle = (id: number) => {
    setSelectedId(id);
    push({ id: 'vehicle' });
  };

  const takeOut = () => {
    if (!vehicle?.canTakeOut) return;
    fetchNui('spawnVehicle', { vehicleId: vehicle.id });
    reset();
  };

  const togglePreview = async () => {
    if (!vehicle) return;
    if (previewing) {
      stopPreview();
      return;
    }
    setBusy('preview');
    const shown = await fetchNui<boolean>('showVehiclePreview', { vehicleId: vehicle.id }, { data: true, delay: 300 });
    if (!shown) {
      setBusy(null);
      setNotice({ tone: 'danger', text: 'Não foi possível mostrar este veículo.' });
      return;
    }
    setPreviewing(true);
    const result = await fetchNui<VehicleStatsProps | null>('getVehicleStats', {}, {
      data: { speed: 70, acceleration: 55, braking: 40, handling: 60, traction: 65 },
      delay: 300,
    });
    setStats(result);
    setBusy(null);
  };

  const openHistory = () => {
    if (!vehicle) return;
    setLogs(null);
    push({ id: 'history' });
    fetchNui<LogProps[] | null>('getVehicleLogs', { vehicleId: vehicle.id }, {
      data: [
        { date: '26/09/2026 21:14', message: 'Guardado em Motel Parking' },
        { date: '27/09/2026 09:02', message: 'Retirado de Motel Parking' },
      ],
      delay: 300,
    }).then(response => setLogs(Array.isArray(response) ? [...response].reverse() : []));
  };

  const openRename = () => {
    if (!vehicle) return;
    setRenameValue(vehicle.name);
    push({ id: 'rename' });
  };

  const renameInvalid = !vehicle || !garage
    || !renameValue.trim()
    || renameValue.trim().length > garage.renameMaxLength
    || renameValue.trim() === vehicle.name;

  const saveRename = async () => {
    if (!vehicle || renameInvalid || busy) return;
    const name = renameValue.trim();
    setBusy('rename');
    const result = await fetchNui<string | false>('updateVehicleName', { vehicleId: vehicle.id, newName: name }, { data: name, delay: 500 });
    setBusy(null);
    if (!result) {
      setNotice({ tone: 'danger', text: 'Não foi possível salvar o apelido.' });
      return;
    }
    setVehicles(previous => previous.map(v => (v.id === vehicle.id ? { ...v, name: result } : v)));
    back();
    setNotice({ tone: 'success', text: `Apelido salvo: ${result}.` });
  };

  const openTransfer = () => {
    if (!vehicle) return;
    setTargets(null);
    push({ id: 'transfer' });
    fetchNui<GarageOption[]>('getGarageList', { vehicleId: vehicle.id }, {
      data: [
        { value: 'pillboxgarage', label: 'Pillbox Garage Parking' },
        { value: 'sapcounsel', label: 'San Andreas Parking' },
      ],
      delay: 300,
    }).then(response => setTargets(Array.isArray(response) ? response : []));
  };

  const transfer = async (target: GarageOption) => {
    if (!vehicle || busy) return;
    setBusy('transfer');
    const success = await fetchNui<boolean>('updateGarageName', { vehicleId: vehicle.id, garage: target.value }, { data: true, delay: 500 });
    setBusy(null);
    if (!success) {
      setNotice({ tone: 'danger', text: 'Não foi possível transferir o veículo.' });
      return;
    }
    stopPreview();
    setVehicles(previous => previous.filter(v => v.id !== vehicle.id));
    setSelectedId(null);
    setStack(ROOT);
    setNotice({ tone: 'success', text: `${vehicle.name} foi para ${target.label}.` });
  };

  const buyKeyCopy = async () => {
    if (!vehicle || busy) return;
    setBusy('keyCopy');
    const success = await fetchNui<boolean>('keyCopy', { vehicleId: vehicle.id }, { data: true, delay: 500 });
    setBusy(null);
    setNotice(success
      ? { tone: 'success', text: 'Cópia da chave entregue.' }
      : { tone: 'danger', text: 'Não foi possível fazer a cópia da chave.' });
  };

  const changeLock = async () => {
    if (!vehicle || busy) return;
    setBusy('lock');
    const success = await fetchNui<boolean>('lockChange', { vehicleId: vehicle.id }, { data: true, delay: 500 });
    setBusy(null);
    back();
    setNotice(success
      ? { tone: 'success', text: 'Fechadura trocada. Só a chave nova abre o veículo.' }
      : { tone: 'danger', text: 'Não foi possível trocar a fechadura.' });
  };

  if (!visible || !garage) return null;

  // ── Paginas ────────────────────────────────────────────────────────────

  const describe = (page: Page, isTop: boolean) => {
    let title = garage.label;
    let eyebrow: string | undefined = garage.isDepot ? 'Pátio' : 'Garagem';
    let items: MenuItem[] = [];
    let empty: string | undefined;
    let loading: string | null = null;
    let pageNotice = isTop ? notice : null;

    if (page.id === 'root' || !vehicle) {
      const term = search.trim().toLowerCase();
      const list = vehicles
        .filter(v => !term
          || v.name.toLowerCase().includes(term)
          || v.modelLabel.toLowerCase().includes(term)
          || v.plate.toLowerCase().includes(term))
        .sort((a, b) => Number(!!favorites[b.id]) - Number(!!favorites[a.id]) || a.name.localeCompare(b.name, 'pt-BR'));

      items = [{
        key: 'search',
        label: 'Buscar',
        hideLabel: true,
        icon: <Search size={18} aria-hidden="true" />,
        input: { value: search, placeholder: 'Buscar por nome, modelo ou placa', onChange: setSearch },
      }];

      for (const v of list) {
        const status = vehicleStatus(v, garage.isDepot);
        items.push({
          key: `vehicle-${v.id}`,
          label: v.name,
          icon: <VehicleIcon icon={v.icon} size={18} />,
          description: (
            <>
              <span className="plate">{v.plate}</span>
              <span className="status" data-tone={status.tone}>{status.label}</span>
            </>
          ),
          value: favorites[v.id] ? <Star className="favorite" size={14} fill="currentColor" aria-label="Favorito" /> : undefined,
          submenu: true,
          onSelect: () => openVehicle(v.id),
        });
      }

      if (list.length === 0) {
        items.push({
          key: 'no-results',
          label: vehicles.length === 0 ? 'Nenhum veículo aqui' : 'Nenhum resultado',
          description: vehicles.length === 0 ? 'Os veículos guardados aparecem nesta lista.' : 'Tente outro nome, modelo ou placa.',
        });
      }
    } else if (page.id === 'vehicle') {
      const status = vehicleStatus(vehicle, garage.isDepot);
      title = vehicle.name;
      eyebrow = vehicle.name === vehicle.modelLabel ? vehicle.plate : `${vehicle.modelLabel} · ${vehicle.plate}`;
      if (!pageNotice && vehicle.notice) pageNotice = { tone: vehicle.state === 2 ? 'danger' : 'warning', text: vehicle.notice };

      const payToTakeOut = garage.isDepot && vehicle.canTakeOut && vehicle.depotPrice > 0;
      items.push({
        key: 'takeOut',
        label: payToTakeOut ? 'Pagar e retirar' : 'Retirar veículo',
        icon: <CarFront size={18} aria-hidden="true" />,
        value: payToTakeOut ? money(vehicle.depotPrice) : undefined,
        description: <span className="status" data-tone={status.tone}>{status.label}</span>,
        disabled: !vehicle.canTakeOut,
        onSelect: takeOut,
      });

      items.push({
        key: 'preview',
        label: previewing ? 'Parar a prévia' : 'Ver na cena',
        icon: previewing ? <EyeOff size={18} aria-hidden="true" /> : <Eye size={18} aria-hidden="true" />,
        activeDescription: previewing
          ? 'Botão direito gira, a roda do mouse aproxima.'
          : 'Mostra o veículo no ponto de retirada.',
        busy: busy === 'preview',
        onSelect: togglePreview,
      });

      if (previewing && stats) {
        items.push({
          key: 'stats',
          label: 'Desempenho',
          icon: <Gauge size={18} aria-hidden="true" />,
          submenu: true,
          onSelect: () => push({ id: 'stats' }),
        });
      }

      const { fuel, body, engine } = vehicle.vehicle_status;
      items.push(
        { key: 'fuel', label: 'Combustível', icon: <Fuel size={18} aria-hidden="true" />, value: `${fuel}%`, progress: fuel },
        { key: 'body', label: 'Carroceria', icon: <CarFront size={18} aria-hidden="true" />, value: `${body}%`, progress: body },
        { key: 'engine', label: 'Motor', icon: <Wrench size={18} aria-hidden="true" />, value: `${engine}%`, progress: engine },
      );

      if (vehicle.canRename) {
        items.push({
          key: 'rename',
          label: 'Mudar apelido',
          icon: <Pencil size={18} aria-hidden="true" />,
          submenu: true,
          onSelect: openRename,
        });
      }

      if (vehicle.canTransfer) {
        items.push({
          key: 'transfer',
          label: 'Transferir de garagem',
          icon: <ArrowLeftRight size={18} aria-hidden="true" />,
          value: garage.transferPrice > 0 ? money(garage.transferPrice) : 'Grátis',
          submenu: true,
          onSelect: openTransfer,
        });
      }

      if (vehicle.canManageKeys && garage.keys) {
        items.push(
          {
            key: 'keyCopy',
            label: 'Cópia da chave',
            icon: <KeyRound size={18} aria-hidden="true" />,
            value: money(garage.keys.copy),
            activeDescription: 'Uma chave a mais para este veículo.',
            busy: busy === 'keyCopy',
            onSelect: buyKeyCopy,
          },
          {
            key: 'lock',
            label: 'Trocar fechadura',
            icon: <Lock size={18} aria-hidden="true" />,
            value: money(garage.keys.lock),
            submenu: true,
            onSelect: () => push({ id: 'lock' }),
          },
        );
      }

      if (vehicle.isOwner) {
        items.push({
          key: 'history',
          label: 'Histórico',
          icon: <History size={18} aria-hidden="true" />,
          submenu: true,
          onSelect: openHistory,
        });
      }

      const favorite = !!favorites[vehicle.id];
      items.push({
        key: 'favorite',
        label: favorite ? 'Tirar dos favoritos' : 'Favoritar',
        icon: <Star size={18} fill={favorite ? 'currentColor' : 'none'} aria-hidden="true" />,
        activeDescription: 'Favoritos aparecem no topo da lista.',
        onSelect: () => toggleFavorite(vehicle.id),
      });
    } else if (page.id === 'rename') {
      title = 'Mudar apelido';
      eyebrow = undefined;
      items = [
        {
          key: 'input',
          label: 'Apelido',
          icon: <Pencil size={18} aria-hidden="true" />,
          input: {
            value: renameValue,
            maxLength: garage.renameMaxLength,
            placeholder: 'Carro do trampo',
            onChange: value => { setRenameValue(value); setNotice(null); },
            onSubmit: saveRename,
          },
        },
        {
          key: 'save',
          label: 'Salvar apelido',
          icon: <Save size={18} aria-hidden="true" />,
          description: `Até ${garage.renameMaxLength} caracteres.`,
          disabled: renameInvalid,
          busy: busy === 'rename',
          onSelect: saveRename,
        },
      ];
    } else if (page.id === 'transfer') {
      title = 'Transferir de garagem';
      eyebrow = undefined;
      loading = targets === null ? 'Carregando garagens…' : null;
      empty = 'Nenhuma outra garagem aceita este veículo.';
      items = (targets ?? []).map(target => ({
        key: target.value,
        label: target.label,
        icon: <Warehouse size={18} aria-hidden="true" />,
        value: garage.transferPrice > 0 ? money(garage.transferPrice) : undefined,
        submenu: true,
        onSelect: () => push({ id: 'transferConfirm', target }),
      }));
    } else if (page.id === 'transferConfirm') {
      title = page.target.label;
      eyebrow = 'Transferir para';
      pageNotice = pageNotice ?? { tone: 'warning', text: `${vehicle.name} sai desta garagem e fica guardado em ${page.target.label}.` };
      items = [
        {
          key: 'confirm',
          label: 'Transferir veículo',
          icon: <Check size={18} aria-hidden="true" />,
          value: garage.transferPrice > 0 ? money(garage.transferPrice) : 'Grátis',
          busy: busy === 'transfer',
          onSelect: () => transfer(page.target),
        },
        { key: 'cancel', label: 'Cancelar', icon: <Undo2 size={18} aria-hidden="true" />, onSelect: back },
      ];
    } else if (page.id === 'lock' && garage.keys) {
      title = 'Trocar fechadura';
      eyebrow = undefined;
      pageNotice = pageNotice ?? {
        tone: 'danger',
        text: 'Todas as chaves deste veículo deixam de funcionar, inclusive as cópias com outras pessoas. Você recebe uma chave nova.',
      };
      items = [
        { key: 'cancel', label: 'Cancelar', icon: <Undo2 size={18} aria-hidden="true" />, onSelect: back },
        {
          key: 'confirm',
          label: 'Trocar fechadura',
          icon: <Lock size={18} aria-hidden="true" />,
          value: money(garage.keys.lock),
          tone: 'danger',
          busy: busy === 'lock',
          onSelect: changeLock,
        },
      ];
    } else if (page.id === 'history') {
      title = 'Histórico';
      eyebrow = undefined;
      loading = logs === null ? 'Carregando histórico…' : null;
      empty = 'Nenhum registro ainda.';
      items = (logs ?? []).map((log, i) => ({
        key: `log-${i}`,
        label: log.message,
        description: log.date,
      }));
    } else if (page.id === 'stats' && stats) {
      title = 'Desempenho';
      eyebrow = undefined;
      const rows: [keyof VehicleStatsProps, string][] = [
        ['speed', 'Velocidade'],
        ['acceleration', 'Aceleração'],
        ['braking', 'Frenagem'],
        ['handling', 'Dirigibilidade'],
        ['traction', 'Tração'],
      ];
      items = rows.map(([key, label]) => ({ key, label, value: `${stats[key]}`, progress: stats[key] }));
    }
    return { title, eyebrow, items, empty, loading, notice: pageNotice };
  };

  // Coluna 0 (a garagem) fica colada na borda direita; cada submenu abre a esquerda da anterior.
  return (
    <div className="menus" data-service="garage">
      {stack.map((entry, level) => {
        const isTop = level === stack.length - 1;
        const view = describe(entry.page, isTop);
        const index = Math.min(entry.index, Math.max(0, view.items.length - 1));
        return (
          <Menu
            key={`${level}-${entry.page.id}`}
            title={view.title}
            eyebrow={view.eyebrow}
            icon={level === 0 ? <span className="menu__mark"><Warehouse size={18} aria-hidden="true" /></span> : undefined}
            items={view.items}
            index={index}
            active={isTop}
            onIndexChange={setIndex}
            onPick={i => pick(level, i, view.items[i])}
            onBack={level > 0 ? back : undefined}
            onClose={level === 0 ? close : () => goToLevel(level - 1)}
            closeLabel={level === 0 ? 'Fechar' : 'Voltar'}
            notice={view.notice}
            empty={view.empty}
            loading={view.loading}
          />
        );
      })}
    </div>
  );
};

export default App;
