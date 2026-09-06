import { useEffect, useMemo, useState } from 'react'
import type { ContractOffer, DispatchSnapshot, JobInfo, Language, PlayerData, Truck, TruckProjection, XpTable } from '../types/trucking'
import { LockIcon, TruckIcon } from './Icons'
import { fetchNui } from '../utils/nui'
import { clock, makeT, money } from '../utils/format'

type Props = {
  snapshot: DispatchSnapshot | null
  loading: boolean
  serverOffset: number
  trucks: Truck[]
  playerData: PlayerData
  language: Language
  jobInfo: JobInfo
  xp: XpTable
  selectedOfferId?: string
  selectedTruckName?: string
  startingOfferId?: string
  onOfferChange: (offerId: string) => void
  onTruckChange: (truckName: string) => void
  onStart: (offer: ContractOffer, truckName: string) => void
  onRefresh: () => void
  notify: (message: string) => void
}

type T = ReturnType<typeof makeT>

function useCountdown(expiresAt: number | undefined, serverOffset: number) {
  const [remaining, setRemaining] = useState(0)
  useEffect(() => {
    if (!expiresAt) {
      setRemaining(0)
      return
    }
    const tick = () => setRemaining(Math.max(0, Math.floor((expiresAt * 1000 - (Date.now() + serverOffset)) / 1000)))
    tick()
    const timer = window.setInterval(tick, 1000)
    return () => window.clearInterval(timer)
  }, [expiresAt, serverOffset])
  return remaining
}

// ============================================================
// TruckingDashboard
// ============================================================

export function DispatchView({
  snapshot,
  loading,
  serverOffset,
  playerData,
  language,
  jobInfo,
  xp,
  selectedOfferId,
  selectedTruckName,
  startingOfferId,
  onOfferChange,
  onTruckChange,
  onStart,
  notify,
}: Props) {
  const t = useMemo(() => makeT(language), [language])
  const offers = snapshot?.offers ?? []
  const remaining = useCountdown(snapshot?.rotation?.expiresAt, serverOffset)
  const level = playerData.level ?? snapshot?.player.level ?? 1

  // Seleção de contrato: mantém o comportamento atual (primeira carga válida).
  const activeOffer =
    offers.find((offer) => offer.offerId === selectedOfferId) ??
    offers.find((offer) => offer.status === 'available' && offer.eligible) ??
    offers.find((offer) => offer.status === 'available' || offer.status === 'locked') ??
    offers[0]

  // Frota: preserva o caminhão escolhido quando permitido pela oferta.
  const compatibleTrucks = activeOffer?.compatibleTrucks ?? []
  const activeTruck =
    compatibleTrucks.find((truck) => truck.name === selectedTruckName) ??
    compatibleTrucks.find((truck) => truck.unlocked)

  const isStarting = Boolean(startingOfferId)
  const hasActiveSession = Boolean(jobInfo.started || snapshot?.player.activeSessionId)
  const canStart = Boolean(
    activeOffer && activeOffer.status === 'available' && activeOffer.eligible && activeTruck?.unlocked && !isStarting && !hasActiveSession,
  )

  const selectTruck = (truck: TruckProjection) => {
    if (!truck.unlocked) {
      notify(t('lock_mission_level', 'Nível %s necessário', truck.level))
      return
    }
    onTruckChange(truck.name)
  }

  const onPrimary = () => {
    if (hasActiveSession) {
      void fetchNui('stopJob')
      return
    }
    if (!canStart || !activeOffer || !activeTruck) return
    onStart(activeOffer, activeTruck.name)
  }

  return (
    <div className="dashboard">
      <PlayerStats
        t={t}
        playerData={playerData}
        level={level}
        xp={xp}
        rotationRemaining={remaining}
        rotationId={snapshot?.rotation?.id}
      />

      <div className="dashboard__content">
        <ContractsPanel
          t={t}
          offers={offers}
          loading={loading}
          snapshot={snapshot}
          remaining={remaining}
          level={level}
          activeOfferId={activeOffer?.offerId}
          startingOfferId={startingOfferId}
          onOfferChange={onOfferChange}
        />

        <FleetPanel
          t={t}
          trucks={compatibleTrucks}
          activeTruck={activeTruck}
          onSelect={selectTruck}
        />

        <DailyMissions t={t} playerData={playerData} />

        <ContractCheckout
          t={t}
          offer={activeOffer}
          activeTruck={activeTruck}
          canStart={canStart}
          isStarting={isStarting}
          hasActiveSession={hasActiveSession}
          onPrimary={onPrimary}
        />
      </div>
    </div>
  )
}

// ============================================================
// PlayerStats — faixa superior
// ============================================================

function PlayerStats({
  t,
  playerData,
  level,
  xp,
  rotationRemaining,
  rotationId,
}: {
  t: T
  playerData: PlayerData
  level: number
  xp: XpTable
  rotationRemaining: number
  rotationId?: string
}) {
  const currentXp = playerData.xp ?? 0
  const nextXp = Array.isArray(xp) ? xp[level - 1] ?? level * 1000 : xp[level] ?? level * 1000
  const progress = nextXp > 0 ? Math.min(100, Math.round((currentXp / nextXp) * 100)) : 100
  const deliveries = playerData.globalCompleted ?? playerData.completedJobs ?? 0

  return (
    <section className="stats-row">
      <div className="stats-row__player">
        <img src={playerData.avatar ?? './assets/images/test-pp.png'} alt="" />
        <div>
          <strong>{playerData.name ?? t('driver', 'Motorista')}</strong>
          <span>{t('level', 'Nível')} {level}</span>
        </div>
      </div>

      <div className="stats-row__stat">
        <p className="eyebrow">{t('completed_jobs', 'Entregas Concluídas')}</p>
        <strong>{deliveries}</strong>
      </div>

      <div className="stats-row__stat">
        <p className="eyebrow">{t('total_earnings', 'Ganhos Totais')}</p>
        <strong>{money(playerData.totalEarnings)}</strong>
      </div>

      <div className="stats-row__level">
        <div className="stats-row__level-head">
          <p className="eyebrow">{t('current_level', 'Nível Atual')}</p>
          <strong>{level}</strong>
        </div>
        <div className="meter__track"><span style={{ width: `${progress}%` }} /></div>
        <small>
          {currentXp.toLocaleString('en-US')} / {nextXp.toLocaleString('en-US')} XP · {Math.max(0, nextXp - currentXp).toLocaleString('en-US')} {t('xp_to_next', 'XP para o próximo nível')}
        </small>
      </div>

      <div className="stats-row__rotation" title={rotationId ? `${t('rotation', 'Rotação')} ${rotationId}` : undefined}>
        <p className="eyebrow">{t('new_cargo_in', 'Novas cargas em')}</p>
        <strong>{clock(rotationRemaining)}</strong>
      </div>
    </section>
  )
}

// ============================================================
// ContractsPanel — lista vertical de contratos
// ============================================================

function ContractsPanel({
  t,
  offers,
  loading,
  snapshot,
  remaining,
  level,
  activeOfferId,
  startingOfferId,
  onOfferChange,
}: {
  t: T
  offers: ContractOffer[]
  loading: boolean
  snapshot: DispatchSnapshot | null
  remaining: number
  level: number
  activeOfferId?: string
  startingOfferId?: string
  onOfferChange: (offerId: string) => void
}) {
  const openOffers = offers.filter((offer) => offer.status === 'available' || offer.status === 'locked')

  return (
    <section className="contracts-panel">
      <h2 className="panel-title">{t('available_cargo', 'Contratos disponíveis')}</h2>
      <div className="contracts-list">
        {loading && offers.length === 0 && (
          <div className="board-empty">
            <strong>{t('board_loading', 'Carregando o mercado...')}</strong>
          </div>
        )}
        {!loading && snapshot && openOffers.length === 0 && (
          <div className="board-empty">
            <strong>{t('board_empty_title', 'TODAS AS CARGAS DESTA ROTAÇÃO FORAM DISTRIBUÍDAS')}</strong>
            <span>{t('board_empty_sub', 'Novas oportunidades em')} {clock(remaining)}</span>
          </div>
        )}
        {!loading && !snapshot && (
          <div className="board-empty">
            <strong>{t('err_db', 'A central de fretes está indisponível no momento.')}</strong>
          </div>
        )}
        {offers.map((offer) => (
          <ContractRow
            key={offer.offerId}
            t={t}
            offer={offer}
            level={level}
            active={offer.offerId === activeOfferId}
            starting={startingOfferId === offer.offerId}
            onSelect={() => onOfferChange(offer.offerId)}
          />
        ))}
      </div>
    </section>
  )
}

function statusLabel(t: T, status: ContractOffer['status']) {
  switch (status) {
    case 'available': return t('status_available', 'DISPONÍVEL')
    case 'locked': return t('status_locked', 'BLOQUEADO')
    case 'starting': return t('status_starting', 'INICIANDO...')
    case 'in_progress': return t('status_in_progress', 'EM ANDAMENTO')
    case 'completed': return t('status_completed', 'CONCLUÍDO')
    case 'failed':
    case 'failed_system': return t('status_failed', 'FRACASSADO')
    case 'expired': return t('status_expired', 'EXPIRADO')
    case 'unavailable': return t('status_unavailable', 'INDISPONÍVEL')
    default: return status
  }
}

function ContractRow({
  t,
  offer,
  level,
  active,
  starting,
  onSelect,
}: {
  t: T
  offer: ContractOffer
  level: number
  active: boolean
  starting: boolean
  onSelect: () => void
}) {
  const status: ContractOffer['status'] = starting ? 'starting' : offer.status
  const reduced = status === 'completed' || status === 'failed' || status === 'failed_system' || status === 'expired'
  const beginnersOnly = status === 'locked' && offer.levelBand.max != null && level > offer.levelBand.max
  const bandLabel = `${t('level', 'Nível')} ${offer.levelBand.min}${offer.levelBand.max != null ? `–${offer.levelBand.max}` : '+'}`
  const requirement = status === 'locked' ? (offer.lockReasons[0] ?? bandLabel) : null

  return (
    <button
      className={`contract-row contract-row--${status} ${active ? 'is-active' : ''} ${reduced ? 'is-reduced' : ''} ${offer.mine ? 'is-mine' : ''}`}
      onClick={onSelect}
      disabled={status === 'unavailable'}
    >
      <img src={`./assets/images/${offer.smallImage ?? offer.image}`} alt="" />
      <div className="contract-row__body">
        <span className="contract-row__name">{offer.title}</span>
        <small className="contract-row__meta">
          <em className={`tier-badge tier-badge--${offer.tier}`}>{t(`tier_${offer.tier}`, offer.tier)}</em>
          <span>{offer.companyName} · {offer.estimatedMinutes} {t('minutes_short', 'min')}</span>
          {requirement ? <b>· {beginnersOnly ? t('for_beginners', 'Para iniciantes') : requirement}</b> : null}
        </small>
      </div>
      <div className="contract-row__side">
        <strong>{money(offer.paymentPreview)}</strong>
        <b className={`offer-status offer-status--${status}`}>
          {status === 'locked' ? <LockIcon /> : null}
          {status === 'starting' ? <i className="spinner" /> : null}
          {status === 'completed' ? '✓ ' : ''}
          {statusLabel(t, status)}
          {offer.moneyBonusPercent ? <u>+{offer.moneyBonusPercent}%</u> : null}
        </b>
      </div>
    </button>
  )
}

// ============================================================
// FleetPanel — frota da empresa
// ============================================================

function FleetPanel({
  t,
  trucks,
  activeTruck,
  onSelect,
}: {
  t: T
  trucks: TruckProjection[]
  activeTruck?: TruckProjection
  onSelect: (truck: TruckProjection) => void
}) {
  return (
    <section className="fleet-panel">
      <div className="panel-head">
        <div>
          <p className="eyebrow">{t('company_fleet', 'Frota da empresa')}</p>
          <h2>{activeTruck?.label ?? t('choose_equipment', 'Escolha o equipamento')}</h2>
        </div>
        <TruckIcon />
      </div>
      <div className="fleet-grid">
        {trucks.map((truck) => (
          <button
            className={`truck-card ${activeTruck?.name === truck.name ? 'is-active' : ''} ${truck.unlocked ? '' : 'is-locked'}`}
            key={truck.name}
            onClick={() => onSelect(truck)}
          >
            <img src={`./assets/images/${truck.image}`} alt="" />
            <span>{truck.label}</span>
            <small>{t('level_short', 'Nv.')} {truck.level}</small>
          </button>
        ))}
        {trucks.length === 0 && (
          <div className="truck-card is-locked truck-card--empty">
            <span>{t('select_offer', 'Selecione uma oferta')}</span>
          </div>
        )}
      </div>
    </section>
  )
}

// ============================================================
// DailyMissions — coluna direita
// ============================================================

function DailyMissions({ t, playerData }: { t: T; playerData: PlayerData }) {
  const resetAt = playerData.dailymissions?.resetAt
  const remaining = resetAt ? Math.max(0, Math.ceil((resetAt * 1000 - Date.now()) / 3600000)) : 0
  const missions = Object.values(playerData.dailymissions?.data ?? {})

  return (
    <section className="missions-panel">
      <div className="panel-head panel-head--tight">
        <h2>{t('daily_missions', 'Missões Diárias')}</h2>
        <span className="panel-head__accent">{remaining}{t('hour', 'h')}</span>
      </div>
      <div className="missions-list">
        {missions.map((mission) => (
          <div className="mission-row" key={mission.key ?? mission.header}>
            <div className="mission-row__head">
              <strong>{mission.header}</strong>
              <span>
                {mission.claimed || mission.process >= mission.max
                  ? t('claimed', 'Recebida')
                  : `${mission.process}/${mission.max}`}
              </span>
            </div>
            <p>{mission.label}</p>
          </div>
        ))}
      </div>
    </section>
  )
}

// ============================================================
// ContractCheckout — resumo da recompensa + CTA
// ============================================================

function ContractCheckout({
  t,
  offer,
  activeTruck,
  canStart,
  isStarting,
  hasActiveSession,
  onPrimary,
}: {
  t: T
  offer?: ContractOffer
  activeTruck?: TruckProjection
  canStart: boolean
  isStarting: boolean
  hasActiveSession: boolean
  onPrimary: () => void
}) {
  const primaryLabel = (() => {
    if (hasActiveSession) return t('stop_job', 'CANCELAR ENTREGA')
    if (isStarting) return t('starting_job', 'INICIANDO...')
    if (!offer || offer.status !== 'available' || !offer.eligible || !activeTruck?.unlocked) {
      return t('requirement_not_met', 'REQUISITO NÃO ATENDIDO')
    }
    return t('start_job', 'INICIAR CONTRATO')
  })()

  const eligibilityText = (() => {
    if (!offer) return t('select_offer', 'Selecione uma oferta')
    if (offer.eligible && offer.status === 'available') return t('eligible', 'Elegível')
    return offer.lockReasons[0] ?? statusLabel(t, offer.status)
  })()
  const eligible = Boolean(offer && offer.eligible && offer.status === 'available')

  return (
    <section className="checkout-panel">
      <div className="reward-summary">
        <h2 className="reward-summary__title">{t('reward_summary', 'Resumo da recompensa')}</h2>
        {offer ? (
          <p className="reward-summary__subtitle">
            {offer.title} · {offer.routeLabel}
            {offer.missionLevel ? ` · ${t('lock_mission_level', 'Nível %s necessário', offer.missionLevel)}` : ''}
          </p>
        ) : null}
        <div className="reward-summary__lines">
          <div><span>{t('payment', 'Pagamento')}</span><strong className="is-primary">{offer ? money(offer.paymentPreview) : '—'}</strong></div>
          <div><span>{t('xp', 'XP')}</span><strong>{offer ? offer.xpPreview : '—'}</strong></div>
          <div><span>{t('reputation', 'Reputação')}</span><strong>{offer ? `+${offer.reputationPreview}` : '—'}</strong></div>
          <div>
            <span>{t('market_bonus', 'Bônus de mercado')}</span>
            <strong>{offer ? `+${offer.moneyBonusPercent}% / +${offer.xpBonusPercent}% ${t('xp', 'XP')}` : '—'}</strong>
          </div>
          <div className={`reward-summary__eligibility ${eligible ? 'is-ok' : 'is-blocked'}`}>
            <span>{t('eligibility', 'Elegibilidade')}</span>
            <strong>{eligibilityText}</strong>
          </div>
        </div>
      </div>

      <button
        className={`primary-action ${canStart || hasActiveSession ? '' : 'is-disabled'} ${isStarting ? 'is-busy' : ''}`}
        onClick={onPrimary}
        disabled={!canStart && !hasActiveSession}
      >
        {isStarting ? <i className="spinner spinner--dark" /> : null}
        {primaryLabel}
      </button>
    </section>
  )
}
