import { useCallback, useEffect, useState } from 'react';
import { AlertCircle, CheckCircle2, Gamepad2, HeartPulse, Hospital, Radio } from 'lucide-react';
import { useNuiEvent } from './hooks/useNuiEvent';
import { fetchNui } from './utils/fetchNui';
import { formatClock, formatMoney } from './utils/format';
import Minigames from './components/Minigames';
import type { ActionResult, DeathSnapshot, DoctorInfo } from './types';

type ActionId = 'alertEms' | 'callDoctor' | 'respawn' | 'games';

interface Action {
  id: ActionId;
  label: string;
  description: string;
  value?: string;
  icon: typeof Radio;
  disabled: boolean;
}

const DOCTOR_LABEL: Record<DoctorInfo['stage'], string> = {
  idle: '',
  enroute: 'Ambulância a caminho',
  walking: 'Médico chegando',
  treating: 'Massagem cardíaca',
  done: 'Reanimado',
  failed: 'Atendimento não concluído',
};

const MOCK_RESULT: ActionResult = { ok: true, message: 'Chamado enviado aos paramédicos' };

export default function DeathApp() {
  const [snapshot, setSnapshot] = useState<DeathSnapshot | null>(null);
  const [gamesOpen, setGamesOpen] = useState(false);
  const [busy, setBusy] = useState<ActionId | null>(null);
  const [feedback, setFeedback] = useState<ActionResult | null>(null);
  const [alertReadyAt, setAlertReadyAt] = useState(0);
  const [treatStartedAt, setTreatStartedAt] = useState(0);
  const [now, setNow] = useState(Date.now());

  useNuiEvent<DeathSnapshot>('open', (data) => {
    setSnapshot(data);
    setGamesOpen(false);
    setFeedback(null);
  });

  useNuiEvent<DeathSnapshot>('update', (data) => {
    setSnapshot((current) => (current ? { ...data, doctor: current.doctor } : current));
  });

  useNuiEvent<DoctorInfo>('doctor', (doctor) => {
    setSnapshot((current) => (current ? { ...current, doctor } : current));
    if (doctor.stage === 'treating') setTreatStartedAt(Date.now());
    if (doctor.stage === 'failed' && doctor.reason) setFeedback({ ok: false, message: doctor.reason });
  });

  useNuiEvent('close', () => {
    setSnapshot(null);
    setGamesOpen(false);
  });

  useEffect(() => {
    fetchNui('ready');
  }, []);

  // Relogio local so para a barra da massagem e o intervalo do chamado de EMS.
  useEffect(() => {
    if (!snapshot) return;
    const id = window.setInterval(() => setNow(Date.now()), 250);
    return () => window.clearInterval(id);
  }, [snapshot]);

  useEffect(() => {
    if (!feedback) return;
    const id = window.setTimeout(() => setFeedback(null), 5000);
    return () => window.clearTimeout(id);
  }, [feedback]);

  const run = useCallback(async (id: ActionId) => {
    if (id === 'games') {
      setGamesOpen(true);
      return;
    }
    setBusy(id);
    try {
      const result = await fetchNui<ActionResult>(id, undefined, { data: MOCK_RESULT, delay: 400 });
      if (result?.message) setFeedback(result);
      if (id === 'alertEms' && result?.ok && snapshot) {
        setAlertReadyAt(Date.now() + snapshot.alertCooldown * 1000);
      }
    } catch {
      setFeedback({ ok: false, message: 'Sem resposta do servidor' });
    } finally {
      setBusy(null);
    }
  }, [snapshot]);

  if (!snapshot) return null;

  const dead = snapshot.state === 'dead';
  const doctorActive = !['idle', 'done', 'failed'].includes(snapshot.doctor.stage);
  const alertWait = Math.ceil((alertReadyAt - now) / 1000);

  const actions: Action[] = [
    {
      id: 'alertEms',
      label: 'Chamar EMS',
      description: snapshot.emsOnDuty === 0
        ? 'Nenhum paramédico em serviço'
        : alertWait > 0 ? `Chamado enviado · de novo em ${alertWait} s` : 'Envia sua localização aos paramédicos',
      icon: Radio,
      disabled: snapshot.emsOnDuty === 0 || alertWait > 0,
    },
    {
      id: 'callDoctor',
      label: 'Chamar médico',
      description: doctorActive
        ? 'Médico já está a caminho'
        : snapshot.doctorWait > 0
          ? `Disponível após ${formatClock(snapshot.doctorWait)} caído`
        : snapshot.doctorAvailable ? 'Médico particular vem até você' : 'Indisponível com paramédicos em serviço',
      value: formatMoney(snapshot.price),
      icon: HeartPulse,
      disabled: doctorActive || !snapshot.doctorAvailable,
    },
    {
      id: 'respawn',
      label: 'Desistir',
      description: snapshot.canRespawn
        ? 'Acordar no hospital'
        : !dead ? 'Liberado depois que você apagar' : doctorActive ? 'Médico a caminho' : `Liberado em ${formatClock(snapshot.seconds)}`,
      icon: Hospital,
      disabled: !snapshot.canRespawn,
    },
    {
      id: 'games',
      label: 'Jogos',
      description: 'Passar o tempo enquanto espera',
      icon: Gamepad2,
      disabled: false,
    },
  ];

  return (
    <>
      <DeathPanel
        snapshot={snapshot}
        actions={actions}
        busy={busy}
        feedback={feedback}
        treatProgress={snapshot.doctor.stage === 'treating'
          ? Math.min(1, (now - treatStartedAt) / (snapshot.doctor.duration || snapshot.reviveTime))
          : 0}
        onAction={run}
      />
      {gamesOpen && <Minigames onClose={() => setGamesOpen(false)} />}
    </>
  );
}

interface PanelProps {
  snapshot: DeathSnapshot;
  actions: Action[];
  busy: ActionId | null;
  feedback: ActionResult | null;
  treatProgress: number;
  onAction: (id: ActionId) => void;
}

function DeathPanel({ snapshot, actions, busy, feedback, treatProgress, onAction }: PanelProps) {
  const dead = snapshot.state === 'dead';

  const doctorStage = snapshot.doctor.stage;
  const showDoctor = doctorStage !== 'idle' && doctorStage !== 'failed';

  return (
    <>
      <section className="death" aria-live="polite">
        <header className="death__head">
          <div>
            <h1 className="death__title">{dead ? 'Inconsciente' : 'Ferido'}</h1>
            <p className="death__subtitle">
              {dead ? 'Volta automática ao hospital em' : 'Sangrando. Sem atendimento, você apaga em'}
            </p>
          </div>
          <div className={`death__clock${snapshot.seconds <= 30 ? ' death__clock--low' : ''}`} role="timer">
            {formatClock(snapshot.seconds)}
          </div>
        </header>

        <div className="death__status">
          <span className={`death__dot${snapshot.emsOnDuty > 0 ? ' death__dot--on' : ''}`} aria-hidden="true" />
          {snapshot.emsOnDuty === 0
            ? 'Nenhum paramédico em serviço'
            : snapshot.emsOnDuty === 1 ? '1 paramédico em serviço' : `${snapshot.emsOnDuty} paramédicos em serviço`}
        </div>

        {showDoctor && (
          <div className="death__doctor">
            <div className="death__doctor-row">
              <span className="death__doctor-label">{DOCTOR_LABEL[doctorStage]}</span>
              {doctorStage === 'treating' && (
                <span className="death__doctor-value">{Math.round(treatProgress * 100)}%</span>
              )}
            </div>
            {doctorStage === 'treating' && (
              <div className="death__bar"><div style={{ width: `${treatProgress * 100}%` }} /></div>
            )}
          </div>
        )}

        <ul className="death__actions">
          {actions.map((action) => {
            const Icon = action.icon;
            return (
              <li key={action.id}>
                <button
                  type="button"
                  className="death__action"
                  disabled={action.disabled || busy !== null}
                  aria-busy={busy === action.id}
                  onClick={() => onAction(action.id)}
                >
                  <Icon className="death__action-icon" size={20} aria-hidden="true" />
                  <span className="death__action-text">
                    <span className="death__action-label">{action.label}</span>
                    <span className="death__action-desc">{action.description}</span>
                  </span>
                  {busy === action.id
                    ? <span className="spinner" aria-hidden="true" />
                    : action.value && <span className="death__action-value">{action.value}</span>}
                </button>
              </li>
            );
          })}
        </ul>

        {feedback?.message && (
          <p className={`death__feedback${feedback.ok ? ' death__feedback--ok' : ''}`} role="status">
            {feedback.ok ? <CheckCircle2 size={16} aria-hidden="true" /> : <AlertCircle size={16} aria-hidden="true" />}
            {feedback.message}
          </p>
        )}
      </section>
    </>
  );
}
