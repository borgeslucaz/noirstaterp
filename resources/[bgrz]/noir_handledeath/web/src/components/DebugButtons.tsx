import { isEnvBrowser } from '../utils/misc';
import type { DeathSnapshot, DoctorInfo } from '../types';

const base: DeathSnapshot = {
  state: 'laststand',
  seconds: 347,
  canRespawn: false,
  emsOnDuty: 0,
  doctorAvailable: true,
  doctorWait: 0,
  price: 5000,
  reviveTime: 20000,
  alertCooldown: 60,
  doctor: { stage: 'idle' },
};

const fire = (action: string, data: unknown) => {
  window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
};

const PRESETS: { label: string; run: () => void }[] = [
  { label: 'Caído', run: () => fire('open', base) },
  { label: 'Espera médico', run: () => fire('open', { ...base, doctorAvailable: false, doctorWait: 180 }) },
  { label: 'Caído com EMS', run: () => fire('open', { ...base, emsOnDuty: 2, doctorAvailable: false }) },
  { label: 'Morto', run: () => fire('open', { ...base, state: 'dead', seconds: 284, canRespawn: true }) },
  { label: 'Morto com EMS', run: () => fire('open', { ...base, state: 'dead', seconds: 25, emsOnDuty: 1, doctorAvailable: false }) },
  { label: 'Médico a caminho', run: () => fire('doctor', { stage: 'enroute' } satisfies DoctorInfo) },
  { label: 'Massagem', run: () => fire('doctor', { stage: 'treating', duration: 20000 } satisfies DoctorInfo) },
  { label: 'Falha', run: () => fire('doctor', { stage: 'failed', reason: 'A ambulância não encontrou caminho até você' } satisfies DoctorInfo) },
  { label: 'Fechar', run: () => fire('close', null) },
];

// Botoes de preview no canto inferior esquerdo, so no navegador (DESIGN_v4 §10).
// ?preset=Morto abre direto um cenario (atalho para screenshot e link).
if (isEnvBrowser()) {
  const wanted = new URLSearchParams(window.location.search).get('preset');
  const preset = PRESETS.find((item) => item.label === wanted);
  if (preset) window.setTimeout(preset.run, 300);
}

export default function DebugButtons() {
  if (!isEnvBrowser()) return null;
  return (
    <div className="debug">
      {PRESETS.map((preset) => (
        <button key={preset.label} type="button" onClick={preset.run}>{preset.label}</button>
      ))}
    </div>
  );
}
