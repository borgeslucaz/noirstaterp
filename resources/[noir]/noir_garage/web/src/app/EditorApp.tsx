import React, { useRef, useState } from 'react';
import {
  ArrowLeftRight, Car, Check, Eye, MapPin, Navigation, Palette, Plus, Save, Search, Shapes, Tag, Trash2,
  Users, Warehouse, Share2, CircleParking, Map as MapIcon, Briefcase, Skull, Square, SquareCheck, TriangleAlert,
  Crosshair, Keyboard, PersonStanding, Shirt, Clapperboard, RotateCw, Move3d, LocateFixed,
} from 'lucide-react';

import Menu, { MenuItem, MenuNotice } from '../components/Menu';
import ConfirmDialog from '../components/ConfirmDialog';
import { fetchNui } from '../utils/fetchNui';
import { useNuiEvent } from '../hooks/useNuiEvent';
import { isEnvBrowser } from '../utils/misc';
import {
  EditorGarage, EditorGroupOption, EditorGroupOptions, EditorPoint, EditorResult, EditorVehicleType, Vec3, Vec4,
} from '../utils/interface';

type Page = { id: 'root' } | { id: 'garage' } | { id: 'groups' } | { id: 'point'; index: number };

interface StackEntry {
  page: Page;
  index: number;
}

type Confirm =
  | { kind: 'delete' }
  | { kind: 'discard'; then: () => void };

const ROOT: StackEntry[] = [{ page: { id: 'root' }, index: 1 }];

const TYPES: EditorVehicleType[] = ['car', 'air', 'sea'];
const TYPE_LABEL: Record<EditorVehicleType, string> = { car: 'Carro', air: 'Aeronave', sea: 'Barco' };

const fmt = (v?: Vec3) => (v ? `${v.x.toFixed(1)}, ${v.y.toFixed(1)}, ${v.z.toFixed(1)}` : undefined);

/** Proximo cargo minimo ao apertar Enter: desligado -> cada cargo em ordem -> desligado. */
const nextGrade = (option: EditorGroupOption, current?: number): number | undefined => {
  const levels = option.grades.length > 0 ? option.grades.map(g => g.level) : [0];
  if (current === undefined) return levels[0];
  const i = levels.indexOf(current);
  return i >= 0 && i < levels.length - 1 ? levels[i + 1] : undefined;
};

const gradeLabel = (option: EditorGroupOption, level: number) => {
  const first = option.grades[0]?.level ?? 0;
  if (level === first) return 'Qualquer cargo';
  const grade = option.grades.find(g => g.level === level);
  return `${grade?.name ?? `Cargo ${level}`} ou acima`;
};

/** Animacoes do atendente (as mesmas que o servidor aceita). */
const SCENARIOS: { value?: string; label: string }[] = [
  { value: undefined, label: 'Parado' },
  { value: 'WORLD_HUMAN_CLIPBOARD', label: 'Prancheta' },
  { value: 'WORLD_HUMAN_GUARD_STAND', label: 'Braços cruzados' },
  { value: 'WORLD_HUMAN_STAND_MOBILE', label: 'Celular' },
  { value: 'WORLD_HUMAN_SMOKING', label: 'Fumando' },
];
const DEFAULT_PED = 's_m_y_valet_01';

const clone = <T,>(value: T): T => JSON.parse(JSON.stringify(value));

const newGarage = (): EditorGarage => ({
  label: '',
  vehicleType: 'car',
  depot: false,
  shared: false,
  accessPoints: [{ blip: { sprite: 357, color: 3 } }],
});

const pointSummary = (point: EditorPoint) =>
  [
    `Balcão ${point.coords ? '✓' : '—'}`,
    point.spawns?.length ? `${point.spawns.length} vaga(s)` : 'Sem vaga',
    `Guardar ${point.dropPoint ? '✓' : 'na vaga 1'}`,
  ].join(' · ');

const EditorApp: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [garages, setGarages] = useState<EditorGarage[]>([]);
  const [stack, setStack] = useState<StackEntry[]>(ROOT);
  const [draft, setDraft] = useState<EditorGarage | null>(null);
  const [groupOptions, setGroupOptions] = useState<EditorGroupOptions>({ jobs: [], gangs: [] });
  const [dirty, setDirtyState] = useState(false);
  // A confirmacao de descartar roda a acao seguinte na mesma volta: ela precisa ler o valor atual.
  const dirtyRef = useRef(false);
  const setDirty = (value: boolean) => {
    dirtyRef.current = value;
    setDirtyState(value);
  };
  const [notice, setNotice] = useState<MenuNotice | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const [confirm, setConfirm] = useState<Confirm | null>(null);


  useNuiEvent('editor', (data: {
    visible?: boolean;
    hidden?: boolean;
    garages?: EditorGarage[];
    groups?: EditorGroupOptions;
    gizmo?: { index: number; result: Vec4 | false };
  }) => {
    if (data.gizmo) {
      const { index, result } = data.gizmo;
      if (result) {
        updatePoint(index, p => {
          if (!p.ped) return;
          p.ped.position = result;
          delete p.ped.rotation;
        });
      }
    }
    if (data.hidden !== undefined) {
      setHidden(data.hidden);
      return;
    }
    if (!data.visible) {
      setVisible(false);
      return;
    }
    setGarages(Array.isArray(data.garages) ? data.garages : []);
    setGroupOptions({ jobs: data.groups?.jobs ?? [], gangs: data.groups?.gangs ?? [] });
    setStack(ROOT);
    setDraft(null);
    setDirty(false);
    setNotice(null);
    setSearch('');
    setHidden(false);
    setVisible(true);
  });

  // ── Navegacao ──────────────────────────────────────────────────────────

  const push = (page: Page) => {
    setNotice(null);
    setStack(previous => [...previous, { page, index: 0 }]);
  };

  const setIndex = (index: number) => {
    setStack(previous => previous.map((entry, i) => (i === previous.length - 1 ? { ...entry, index } : entry)));
  };

  /** Sair da garagem com alteracoes pendentes pede confirmacao. */
  const guard = (action: () => void) => {
    if (dirtyRef.current) setConfirm({ kind: 'discard', then: action });
    else action();
  };

  const leaveGarage = () => {
    setDraft(null);
    setDirty(false);
    setStack(ROOT);
  };

  const goToLevel = (level: number, after?: () => void) => {
    if (level >= stack.length - 1) {
      after?.();
      return;
    }
    const run = () => {
      setNotice(null);
      if (level === 0) leaveGarage();
      else setStack(previous => previous.slice(0, level + 1));
      after?.();
    };
    if (level === 0) guard(run);
    else run();
  };

  const back = () => goToLevel(stack.length - 2);

  const close = () => guard(() => {
    setVisible(false);
    setDraft(null);
    setDirty(false);
    if (!isEnvBrowser()) fetchNui('editor:close');
  });

  // ── Rascunho ───────────────────────────────────────────────────────────

  const openGarage = (garage: EditorGarage | null) => {
    const next = garage ? clone(garage) : newGarage();
    const open = () => {
      setDraft(next);
      setDirty(!garage);
      setNotice(null);
      setStack([...ROOT, { page: { id: 'garage' }, index: 0 }]);
    };
    guard(open);
  };

  const update = (change: (garage: EditorGarage) => void) => {
    setDraft(previous => {
      if (!previous) return previous;
      const next = clone(previous);
      change(next);
      return next;
    });
    setDirty(true);
    setNotice(null);
  };

  const updatePoint = (index: number, change: (point: EditorPoint) => void) => {
    update(garage => {
      const point = garage.accessPoints[index];
      if (point) change(point);
    });
  };

  /** Marca no jogo; `slot` e a vaga (indice em spawns) quando kind e 'spawn'. */
  const capture = async (index: number, kind: 'coords' | 'spawn' | 'dropPoint', slot = 0) => {
    if (!draft) return;
    const result = await fetchNui<Vec4 | false>('editor:capture', { kind, points: draft.accessPoints }, {
      data: { x: 215.3 + Math.random() * 10, y: -810.1 + Math.random() * 10, z: 30.73, w: Math.round(Math.random() * 360) },
      delay: 400,
    });
    if (!result) return;
    updatePoint(index, point => {
      if (kind === 'dropPoint') point.dropPoint = { x: result.x, y: result.y, z: result.z };
      else if (kind === 'spawn') {
        const spawns = [...(point.spawns ?? [])];
        spawns[slot] = result;
        point.spawns = spawns;
      } else point.coords = result;
    });
  };

  /** Posicionar no jogo (mira + roda do mouse); a tela some e o resultado volta pela mensagem 'editor' (gizmo). */
  const placePed = async (index: number) => {
    const point = draft?.accessPoints[index];
    if (!point?.ped) return;
    const start = point.ped.position ?? point.coords;
    const started = await fetchNui<boolean>('editor:placePed', { index, model: point.ped.model, position: start }, {
      data: true,
      delay: 100,
    });
    if (started && isEnvBrowser()) {
      const result = start ? { ...start, x: start.x + 1.2, w: (start.w + 30) % 360 } : { x: 215.3, y: -810.1, z: 30.7, w: 90 };
      window.dispatchEvent(new MessageEvent('message', { data: { action: 'editor', data: { hidden: false, gizmo: { index, result } } } }));
    }
  };

  const save = async () => {
    if (!draft || busy) return;
    const garage = { ...draft, groups: draft.groups && Object.keys(draft.groups).length > 0 ? draft.groups : undefined };
    delete garage.stored;
    delete garage.name;
    setBusy('save');
    const result = await fetchNui<EditorResult>('editor:save', { name: draft.name, garage }, {
      data: {
        ok: true,
        name: draft.name ?? (draft.label.toLowerCase().replace(/[^a-z0-9]/g, '') || 'garagem'),
        list: undefined,
      },
      delay: 500,
    });
    setBusy(null);
    if (!result?.ok) {
      setNotice({ tone: 'danger', text: result?.error ?? 'Não foi possível salvar.' });
      return;
    }
    const saved = { ...garage, name: result.name, stored: draft.stored ?? 0 };
    setGarages(result.list ?? [...garages.filter(g => g.name !== saved.name), saved].sort((a, b) => a.label.localeCompare(b.label, 'pt-BR')));
    setDraft(saved);
    setDirty(false);
    setNotice({ tone: 'success', text: 'Garagem salva. Já vale para todos no servidor.' });
  };

  const remove = async () => {
    if (!draft?.name) return;
    setConfirm(null);
    setBusy('delete');
    const result = await fetchNui<EditorResult>('editor:delete', { name: draft.name }, {
      data: (draft.stored ?? 0) > 0
        ? { ok: false, error: `Há ${draft.stored} veículo(s) guardado(s) nesta garagem. Transfira-os antes de apagar.` }
        : { ok: true },
      delay: 500,
    });
    setBusy(null);
    if (!result?.ok) {
      setNotice({ tone: 'danger', text: result?.error ?? 'Não foi possível apagar.' });
      return;
    }
    const label = draft.label;
    setGarages(result.list ?? garages.filter(g => g.name !== draft.name));
    leaveGarage();
    setNotice({ tone: 'success', text: `${label} apagada.` });
  };

  if (!visible || hidden) return null;

  // ── Paginas ────────────────────────────────────────────────────────────

  const describe = (page: Page, isTop: boolean) => {
    let title = 'Garagens';
    let eyebrow: string | undefined = 'Editor';
    let items: MenuItem[] = [];
    const pageNotice = isTop ? notice : null;

    if (page.id === 'root' || !draft) {
      const term = search.trim().toLowerCase();
      items = [
        {
          key: 'search',
          label: 'Buscar',
          hideLabel: true,
          icon: <Search size={18} aria-hidden="true" />,
          input: { value: search, placeholder: 'Buscar por nome ou identificador', onChange: setSearch },
        },
        {
          key: 'new',
          label: 'Nova garagem',
          icon: <Plus size={18} aria-hidden="true" />,
          activeDescription: 'Cria uma garagem vazia; marque os pontos em seguida.',
          onSelect: () => openGarage(null),
        },
      ];
      for (const garage of garages) {
        if (term && !garage.label.toLowerCase().includes(term) && !(garage.name ?? '').includes(term)) continue;
        const tags = [garage.name, TYPE_LABEL[garage.vehicleType], garage.depot ? 'Pátio' : null, `${garage.accessPoints.length} ponto(s)`]
          .filter(Boolean).join(' · ');
        items.push({
          key: `garage-${garage.name}`,
          label: garage.label,
          icon: garage.depot ? <CircleParking size={18} aria-hidden="true" /> : <Warehouse size={18} aria-hidden="true" />,
          description: tags,
          value: garage.stored ? `${garage.stored} carro(s)` : undefined,
          onSelect: () => openGarage(garage),
        });
      }
    } else if (page.id === 'garage') {
      title = draft.label || 'Nova garagem';
      eyebrow = draft.name ?? 'Não salva';
      items = [
        {
          key: 'label',
          label: 'Nome',
          icon: <Tag size={18} aria-hidden="true" />,
          input: { value: draft.label, maxLength: 50, placeholder: 'Garagem da Praça', onChange: value => update(g => { g.label = value; }) },
        },
        {
          key: 'type',
          label: 'Tipo de veículo',
          icon: <Car size={18} aria-hidden="true" />,
          value: TYPE_LABEL[draft.vehicleType],
          activeDescription: 'Clique ou Enter para trocar.',
          onSelect: () => update(g => { g.vehicleType = TYPES[(TYPES.indexOf(g.vehicleType) + 1) % TYPES.length]; }),
        },
        {
          key: 'depot',
          label: 'Pátio',
          icon: <CircleParking size={18} aria-hidden="true" />,
          value: draft.depot ? 'Sim' : 'Não',
          activeDescription: 'Pátio só retira (carro fora ou apreendido), não guarda.',
          onSelect: () => update(g => { g.depot = !g.depot; }),
        },
      ];
      if (!draft.depot) {
        items.push({
          key: 'shared',
          label: 'Compartilhada',
          icon: <Share2 size={18} aria-hidden="true" />,
          value: draft.shared ? 'Sim' : 'Não',
          activeDescription: 'Quem tem acesso usa todos os carros guardados nela.',
          onSelect: () => update(g => { g.shared = !g.shared; }),
        });
      }
      const allGroups = [...groupOptions.jobs, ...groupOptions.gangs];
      const chosen = Object.keys(draft.groups ?? {});
      items.push({
        key: 'groups',
        label: 'Grupos (job ou gang)',
        icon: <Users size={18} aria-hidden="true" />,
        description: chosen.length === 0
          ? 'Todos podem usar'
          : chosen.map(name => allGroups.find(g => g.name === name)?.label ?? name).join(', '),
        value: chosen.length > 0 ? `${chosen.length}` : undefined,
        submenu: true,
        onSelect: () => push({ id: 'groups' }),
      });

      draft.accessPoints.forEach((point, i) => {
        items.push({
          key: `point-${i}`,
          label: `Ponto de acesso ${i + 1}`,
          icon: <MapPin size={18} aria-hidden="true" />,
          description: pointSummary(point),
          submenu: true,
          onSelect: () => push({ id: 'point', index: i }),
        });
      });

      items.push(
        {
          key: 'addPoint',
          label: 'Adicionar ponto de acesso',
          icon: <Plus size={18} aria-hidden="true" />,
          disabled: draft.accessPoints.length >= 10,
          onSelect: () => {
            const index = draft.accessPoints.length;
            update(g => { g.accessPoints.push({}); });
            push({ id: 'point', index });
          },
        },
        {
          key: 'save',
          label: 'Salvar garagem',
          icon: <Save size={18} aria-hidden="true" />,
          activeDescription: dirty ? 'Vale na hora para todos no servidor.' : 'Nada para salvar.',
          disabled: !dirty,
          busy: busy === 'save',
          onSelect: save,
        },
      );
      if (draft.name) {
        items.push({
          key: 'delete',
          label: 'Apagar garagem',
          icon: <Trash2 size={18} aria-hidden="true" />,
          tone: 'danger',
          value: draft.stored ? `${draft.stored} carro(s)` : undefined,
          activeDescription: draft.stored ? 'Transfira os carros guardados antes.' : 'Some do mapa na hora.',
          busy: busy === 'delete',
          onSelect: () => setConfirm({ kind: 'delete' }),
        });
      }
    } else if (page.id === 'groups') {
      title = 'Grupos';
      eyebrow = undefined;
      const selected = draft.groups ?? {};
      const toggle = (option: EditorGroupOption) => update(g => {
        const grade = nextGrade(option, g.groups?.[option.name]);
        const groups = { ...(g.groups ?? {}) };
        if (grade === undefined) delete groups[option.name];
        else groups[option.name] = grade;
        g.groups = groups;
      });
      const section = (key: string, label: string, icon: React.ReactNode, options: EditorGroupOption[]) => {
        items.push({
          key: `hdr-${key}`,
          label,
          icon,
          description: options.length === 0 ? 'Nenhum configurado' : 'Enter liga, sobe o cargo mínimo e, depois do último, tira',
        });
        for (const option of options) {
          const on = selected[option.name] !== undefined;
          items.push({
            key: `${key}-${option.name}`,
            label: option.label,
            icon: on ? <SquareCheck size={18} aria-hidden="true" /> : <Square size={18} aria-hidden="true" />,
            description: on ? gradeLabel(option, selected[option.name]) : option.name,
            onSelect: () => toggle(option),
          });
        }
      };
      items.push({
        key: 'clear',
        label: 'Liberar para todos',
        icon: <Users size={18} aria-hidden="true" />,
        disabled: Object.keys(selected).length === 0,
        activeDescription: 'Tira todos os grupos: qualquer jogador usa.',
        onSelect: () => update(g => { g.groups = undefined; }),
      });
      section('job', 'Jobs', <Briefcase size={18} aria-hidden="true" />, groupOptions.jobs);
      section('gang', 'Gangs', <Skull size={18} aria-hidden="true" />, groupOptions.gangs);

      const known = new Set([...groupOptions.jobs, ...groupOptions.gangs].map(g => g.name));
      for (const name of Object.keys(selected).filter(n => !known.has(n))) {
        items.push({
          key: `missing-${name}`,
          label: `${name} (não existe mais)`,
          icon: <TriangleAlert size={18} aria-hidden="true" />,
          tone: 'danger',
          activeDescription: 'Enter tira este grupo da garagem.',
          onSelect: () => update(g => {
            const groups = { ...(g.groups ?? {}) };
            delete groups[name];
            g.groups = groups;
          }),
        });
      }
    } else if (page.id === 'point') {
      const i = page.index;
      const point = draft.accessPoints[i];
      title = `Ponto ${i + 1}`;
      eyebrow = undefined;
      if (point) {
        items = [
          {
            key: 'coords',
            label: 'Balcão (abre o menu)',
            icon: <MapPin size={18} aria-hidden="true" />,
            description: fmt(point.coords) ?? 'Não marcado',
            value: point.coords ? <Check size={16} aria-label="Marcado" /> : undefined,
            onSelect: () => capture(i, 'coords'),
          },
          ...(point.spawns ?? []).map((spot, n) => ({
            key: `spawn-${n}`,
            label: `Vaga ${n + 1}`,
            icon: <Navigation size={18} aria-hidden="true" />,
            description: fmt(spot),
            value: <Check size={16} aria-label="Marcada" />,
            activeDescription: n === 0 ? 'Tentada primeiro. Enter marca de novo.' : `Tentada se as ${n} de cima estiverem ocupadas.`,
            onSelect: () => capture(i, 'spawn', n),
          })),
          {
            key: 'spawnAdd',
            label: point.spawns?.length ? 'Adicionar vaga' : 'Marcar vaga de saída',
            icon: <Plus size={18} aria-hidden="true" />,
            description: point.spawns?.length ? undefined : 'Sem vaga, o carro sai no balcão',
            activeDescription: point.spawns?.length ? 'Dentro do carro, a vaga pega a posição e a direção dele.' : undefined,
            disabled: (point.spawns?.length ?? 0) >= 10,
            onSelect: () => capture(i, 'spawn', point.spawns?.length ?? 0),
          },
          ...(point.spawns?.length ? [{
            key: 'spawnRemove',
            label: 'Remover última vaga',
            icon: <Trash2 size={18} aria-hidden="true" />,
            onSelect: () => updatePoint(i, p => {
              const spawns = (p.spawns ?? []).slice(0, -1);
              p.spawns = spawns.length ? spawns : undefined;
            }),
          }] : []),
          {
            key: 'dropPoint',
            label: 'Ponto de guardar',
            icon: <ArrowLeftRight size={18} aria-hidden="true" />,
            description: fmt(point.dropPoint) ?? 'Não marcado: guarda na vaga 1',
            value: point.dropPoint ? <Check size={16} aria-label="Marcado" /> : undefined,
            onSelect: () => capture(i, 'dropPoint'),
          },
        ];
        if (point.dropPoint) {
          items.push({
            key: 'clearDrop',
            label: 'Guardar na vaga 1',
            icon: <Eye size={18} aria-hidden="true" />,
            activeDescription: 'Apaga o ponto de guardar; usa a vaga 1.',
            onSelect: () => updatePoint(i, p => { delete p.dropPoint; }),
          });
        }
        const target = point.interaction === 'target';
        items.push({
          key: 'interaction',
          label: 'Interação no balcão',
          icon: target ? <Crosshair size={18} aria-hidden="true" /> : <Keyboard size={18} aria-hidden="true" />,
          value: target ? 'ox_target' : 'Aperte E',
          activeDescription: target ? 'Olho do target no atendente ou no ponto.' : 'Marcador no chão e a tecla E.',
          onSelect: () => updatePoint(i, p => { p.interaction = p.interaction === 'target' ? 'key' : 'target'; }),
        });
        items.push({
          key: 'ped',
          label: 'Atendente (PED)',
          icon: <PersonStanding size={18} aria-hidden="true" />,
          value: point.ped ? 'Sim' : 'Não',
          activeDescription: 'Um PED parado no balcão.',
          onSelect: () => updatePoint(i, p => { p.ped = p.ped ? undefined : { model: DEFAULT_PED }; }),
        });
        if (point.ped) {
          const ped = point.ped;
          const scenarioIndex = Math.max(0, SCENARIOS.findIndex(sc => sc.value === ped.scenario));
          items.push(
            {
              key: 'pedModel',
              label: 'Modelo do PED',
              icon: <Shirt size={18} aria-hidden="true" />,
              input: {
                value: ped.model,
                maxLength: 40,
                placeholder: DEFAULT_PED,
                onChange: value => updatePoint(i, p => {
                  if (p.ped) p.ped.model = value.replace(/[^\w]/g, '').toLowerCase();
                }),
              },
            },
            {
              key: 'pedGizmo',
              label: 'Posicionar atendente',
              icon: <Move3d size={18} aria-hidden="true" />,
              description: ped.position ? `Posição própria: ${fmt(ped.position)}` : 'No balcão',
              onSelect: () => placePed(i),
            },
            ...(ped.position ? [{
              key: 'pedReset',
              label: 'Atendente no balcão',
              icon: <LocateFixed size={18} aria-hidden="true" />,
              activeDescription: 'Volta o atendente para o ponto do balcão.',
              onSelect: () => updatePoint(i, p => { if (p.ped) delete p.ped.position; }),
            }] : []),
            {
              key: 'pedRotation',
              label: 'Girar atendente',
              icon: <RotateCw size={18} aria-hidden="true" />,
              value: ped.rotation ? `+${ped.rotation}°` : 'Como marcado',
              activeDescription: 'Enter gira 45° (+180° = de frente).',
              onSelect: () => updatePoint(i, p => {
                if (p.ped) p.ped.rotation = ((p.ped.rotation ?? 0) + 45) % 360 || undefined;
              }),
            },
            {
              key: 'pedScenario',
              label: 'Animação',
              icon: <Clapperboard size={18} aria-hidden="true" />,
              value: SCENARIOS[scenarioIndex].label,
              activeDescription: 'Enter troca a animação.',
              onSelect: () => updatePoint(i, p => {
                if (!p.ped) return;
                p.ped.scenario = SCENARIOS[(scenarioIndex + 1) % SCENARIOS.length].value;
              }),
            },
          );
        }
        items.push({
          key: 'blip',
          label: 'Blip no mapa',
          icon: <MapIcon size={18} aria-hidden="true" />,
          value: point.blip ? 'Sim' : 'Não',
          onSelect: () => updatePoint(i, p => { p.blip = p.blip ? undefined : { sprite: 357, color: 3 }; }),
        });
        if (point.blip) {
          const blip = point.blip;
          const numberInput = (key: 'sprite' | 'color') => (value: string) => {
            const digits = value.replace(/\D/g, '').slice(0, 3);
            updatePoint(i, p => { if (p.blip) p.blip[key] = digits === '' ? 0 : Number.parseInt(digits, 10); });
          };
          items.push(
            {
              key: 'blipName',
              label: 'Nome no mapa',
              icon: <Tag size={18} aria-hidden="true" />,
              input: {
                value: blip.name ?? '',
                maxLength: 40,
                placeholder: draft.label || 'Nome da garagem',
                onChange: value => updatePoint(i, p => { if (p.blip) p.blip.name = value || undefined; }),
              },
            },
            {
              key: 'blipSprite',
              label: 'Ícone do blip (357 = garagem)',
              icon: <Shapes size={18} aria-hidden="true" />,
              input: { value: String(blip.sprite), maxLength: 3, onChange: numberInput('sprite') },
            },
            {
              key: 'blipColor',
              label: 'Cor do blip (3 = azul)',
              icon: <Palette size={18} aria-hidden="true" />,
              input: { value: String(blip.color), maxLength: 2, onChange: numberInput('color') },
            },
          );
        }
        items.push(
          {
            key: 'goto',
            label: 'Ir até o balcão',
            icon: <Navigation size={18} aria-hidden="true" />,
            disabled: !point.coords,
            onSelect: () => fetchNui('editor:teleport', { coords: point.coords }, { data: 1 }),
          },
          {
            key: 'remove',
            label: 'Remover ponto',
            icon: <Trash2 size={18} aria-hidden="true" />,
            tone: 'danger',
            disabled: draft.accessPoints.length <= 1,
            activeDescription: draft.accessPoints.length <= 1 ? 'A garagem precisa de pelo menos um ponto.' : undefined,
            onSelect: () => {
              update(g => { g.accessPoints.splice(i, 1); });
              setStack(previous => previous.slice(0, -1));
            },
          },
        );
      }
    }

    return { title, eyebrow, items, notice: pageNotice };
  };

  const pick = (level: number, index: number, item?: MenuItem) => {
    if (level === stack.length - 1) return;
    goToLevel(level, () => {
      setStack(previous => previous.map((entry, i) => (i === level ? { ...entry, index } : entry)));
      if (item && !item.disabled && !item.busy && !item.input) item.onSelect?.();
    });
  };

  return (
    <div className="menus" data-service="garage">
      {stack.map((entry, level) => {
        const isTop = level === stack.length - 1;
        const view = describe(entry.page, isTop);
        // Com uma garagem aberta, o destaque da lista segue a garagem.
        const openIndex = level === 0 && !isTop && draft?.name
          ? view.items.findIndex(item => item.key === `garage-${draft.name}`)
          : level === 0 && !isTop && draft && !draft.name ? 1 : -1;
        const index = openIndex >= 0 ? openIndex : Math.min(entry.index, Math.max(0, view.items.length - 1));
        return (
          <Menu
            key={`${level}-${entry.page.id}`}
            title={view.title}
            eyebrow={view.eyebrow}
            items={view.items}
            index={index}
            active={isTop && !confirm}
            onIndexChange={setIndex}
            onPick={i => pick(level, i, view.items[i])}
            onBack={level > 0 ? back : undefined}
            onClose={level === 0 ? close : () => goToLevel(level - 1)}
            closeLabel={level === 0 ? 'Fechar editor' : 'Fechar este menu'}
            notice={view.notice}
          />
        );
      })}

      {!confirm && (
        <div className="menu__keys" aria-hidden="true">
          <span className="menu__key"><kbd>↵</kbd> Escolher</span>
          <span className="menu__key-sep">/</span>
          <span className="menu__key"><kbd>Esc</kbd> {stack.length > 1 ? 'Voltar' : 'Fechar'}</span>
        </div>
      )}

      {confirm?.kind === 'delete' && draft && (
        <ConfirmDialog title="Apagar garagem" confirmLabel="Apagar" danger onConfirm={remove} onClose={() => setConfirm(null)}>
          <p><strong>{draft.label}</strong> some do mapa para todos na hora. Não dá para desfazer.</p>
        </ConfirmDialog>
      )}
      {confirm?.kind === 'discard' && (
        <ConfirmDialog
          title="Descartar alterações"
          confirmLabel="Descartar"
          danger
          onConfirm={() => { const then = confirm.then; setConfirm(null); setDirty(false); then(); }}
          onClose={() => setConfirm(null)}
        >
          <p>As alterações desta garagem ainda não foram salvas.</p>
        </ConfirmDialog>
      )}
    </div>
  );
};

export default EditorApp;
