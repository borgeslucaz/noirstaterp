import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type {
  ContractConfig,
  ContractOffer,
  DispatchSnapshot,
  JobFailedPayload,
  JobInfo,
  JobResult,
  KeyBinds,
  Language,
  Mission,
  Page,
  PlayerData,
  Truck,
  XpTable,
} from './types/trucking'
import { useNuiEvent } from './hooks/useNuiEvent'
import { fetchNui, isFiveM } from './utils/nui'
import { makeT } from './utils/format'
import {
  mockContractConfig,
  mockKeyBinds,
  mockLanguage,
  mockMissions,
  mockPlayerData,
  mockSnapshot,
  mockTrucks,
  mockXp,
} from './utils/mockData'
import { DispatchView } from './components/DispatchView'
import { CompaniesView } from './components/CompaniesView'
import { ProfileView } from './components/ProfileView'
import { LeaderboardView } from './components/LeaderboardView'
import { JobHud } from './components/JobHud'
import { NotificationStack } from './components/NotificationStack'
import { PhoneCall } from './components/PhoneCall'
import { DeliveryReport } from './components/DeliveryReport'
import { TruckIcon } from './components/Icons'

type SyncPayload = {
  key: keyof PlayerData
  value: PlayerData[keyof PlayerData]
}

type JobPayload = {
  key: keyof JobInfo
  value: JobInfo[keyof JobInfo]
}

type BoardResponse = {
  ok?: boolean
  snapshot?: DispatchSnapshot
  message?: string
}

type StartResponse = {
  ok?: boolean
  error?: string
  message?: string
  sessionId?: string
}

type ClaimPayload = {
  rotationId: string
  offerId: string
  status: string
}

const initialOpen = !isFiveM()
const REPORT_AUTO_CLOSE_MS = 18000

export default function App() {
  const [isOpen, setIsOpen] = useState(initialOpen)
  const [activePage, setActivePage] = useState<Page>('main')
  const [missions, setMissions] = useState<Mission[]>(isFiveM() ? [] : mockMissions)
  const [trucks, setTrucks] = useState<Truck[]>(isFiveM() ? [] : mockTrucks)
  const [trucksCopy, setTrucksCopy] = useState<Truck[]>(isFiveM() ? [] : mockTrucks)
  const [playerData, setPlayerData] = useState<PlayerData>(isFiveM() ? {} : mockPlayerData)
  const [jobInfo, setJobInfo] = useState<JobInfo>({})
  const [language, setLanguage] = useState<Language>(isFiveM() ? {} : mockLanguage)
  const [xp, setXp] = useState<XpTable>(isFiveM() ? [] : mockXp)
  const [keybinds, setKeybinds] = useState<KeyBinds>(isFiveM() ? {} : mockKeyBinds)
  const [contractConfig, setContractConfig] = useState<ContractConfig>(isFiveM() ? {} : mockContractConfig)
  const [notifications, setNotifications] = useState<string[]>([])
  const [showPhone, setShowPhone] = useState(false)
  const [isEditingHud, setIsEditingHud] = useState(false)
  const [selectedCompany, setSelectedCompany] = useState(0)

  // Mercado Global
  const [snapshot, setSnapshot] = useState<DispatchSnapshot | null>(isFiveM() ? null : mockSnapshot)
  const [snapshotLoading, setSnapshotLoading] = useState(isFiveM())
  const [serverOffset, setServerOffset] = useState(0) // serverNow*1000 - Date.now()
  const [selectedOfferId, setSelectedOfferId] = useState<string | undefined>()
  const [selectedTruckName, setSelectedTruckName] = useState<string | undefined>()
  const [startingOfferId, setStartingOfferId] = useState<string | undefined>()
  const [report, setReport] = useState<JobResult | null>(null)
  const refreshTimer = useRef<number | null>(null)

  const t = useMemo(() => makeT(language), [language])

  const notify = useCallback((message: string) => {
    setNotifications((current) => [...current, message])
    window.setTimeout(() => {
      setNotifications((current) => current.slice(1))
    }, 3200)
  }, [])

  const applySnapshot = useCallback((next: DispatchSnapshot | null | undefined) => {
    setSnapshotLoading(false)
    if (!next) {
      setSnapshot(null)
      return
    }
    setServerOffset(next.serverNow * 1000 - Date.now())
    setSnapshot(next)
  }, [])

  const refreshBoard = useCallback(async () => {
    if (!isFiveM()) {
      applySnapshot(mockSnapshot)
      return
    }
    setSnapshotLoading(true)
    const response = await fetchNui<BoardResponse>('refreshDispatchBoard')
    applySnapshot(response?.ok ? response.snapshot : null)
    if (response && !response.ok && response.message) notify(response.message)
  }, [applySnapshot, notify])

  useNuiEvent<void>('open', useCallback(() => {
    setIsOpen(true)
    setActivePage('main')
    setSnapshotLoading(true)
  }, []))
  useNuiEvent<void>('close', useCallback(() => setIsOpen(false), []))
  useNuiEvent<void>('checknui', useCallback(() => void fetchNui('ready'), []))
  useNuiEvent<Mission[]>('set_missions', useCallback((payload) => setMissions(payload ?? []), []))
  useNuiEvent<Truck[]>('setTrucks', useCallback((payload) => setTrucks(payload ?? []), []))
  useNuiEvent<Truck[]>('setTrucksCopy', useCallback((payload) => setTrucksCopy(payload ?? []), []))
  useNuiEvent<XpTable>('setXP', useCallback((payload) => setXp(payload ?? []), []))
  useNuiEvent<Language>('setLanguage', useCallback((payload) => setLanguage(payload ?? {}), []))
  useNuiEvent<KeyBinds>('setKeyBinds', useCallback((payload) => setKeybinds(payload ?? {}), []))
  useNuiEvent<ContractConfig>('setContractConfig', useCallback((payload) => setContractConfig(payload ?? {}), []))
  useNuiEvent<string>('createNotification', useCallback((payload) => payload && notify(payload), [notify]))
  useNuiEvent<SyncPayload>('SyncPlayerDataByKey', useCallback((payload) => {
    if (!payload?.key) return
    setPlayerData((current) => ({ ...current, [payload.key]: payload.value }))
  }, []))
  useNuiEvent<PlayerData>('SyncAllPlayerData', useCallback((payload) => {
    if (!payload) return
    setPlayerData(payload)
  }, []))
  useNuiEvent<JobPayload>('setJobInfo', useCallback((payload) => {
    if (!payload?.key) return
    setJobInfo((current) => ({ ...current, [payload.key]: payload.value }))
  }, []))
  useNuiEvent<DispatchSnapshot | null>('dispatchSnapshot', useCallback((payload) => applySnapshot(payload), [applySnapshot]))
  useNuiEvent<{ rotationId: string; expiresAt: number; serverNow: number }>('rotationChanged', useCallback((payload) => {
    if (payload?.serverNow) setServerOffset(payload.serverNow * 1000 - Date.now())
    setSelectedOfferId(undefined)
    setStartingOfferId(undefined)
  }, []))
  useNuiEvent<ClaimPayload>('globalOfferClaimed', useCallback((payload) => {
    if (!payload?.offerId) return
    setSnapshot((current) => {
      if (!current || !current.rotation || current.rotation.id !== payload.rotationId) return current
      const offers = current.offers.map((offer): ContractOffer => {
        if (offer.offerId !== payload.offerId) return offer
        const status = payload.status as ContractOffer['status']
        const nextStatus = status === 'in_progress' && !offer.mine ? 'unavailable' : status
        return { ...offer, status: nextStatus, eligible: false }
      })
      return { ...current, offers }
    })
    if (payload.status === 'in_progress') {
      window.setTimeout(() => {
        setSnapshot((current) => {
          if (!current) return current
          return {
            ...current,
            offers: current.offers.map((offer) =>
              offer.offerId === payload.offerId && offer.status === 'unavailable'
                ? { ...offer, status: 'in_progress' }
                : offer,
            ),
          }
        })
      }, 2500)
    }
  }, []))
  useNuiEvent<{ sessionId: string; offerId: string }>('jobSessionStarted', useCallback((payload) => {
    setStartingOfferId(undefined)
    setSnapshot((current) => {
      if (!current) return current
      return {
        ...current,
        player: { ...current.player, usedThisRotation: true, activeSessionId: payload?.sessionId },
        offers: current.offers.map((offer) =>
          offer.offerId === payload?.offerId ? { ...offer, status: 'in_progress', mine: true, eligible: false } : offer,
        ),
      }
    })
  }, []))
  useNuiEvent<JobResult>('jobResult', useCallback((payload) => {
    if (!payload) return
    setReport(payload)
  }, []))
  useNuiEvent<JobFailedPayload>('jobFailed', useCallback((payload) => {
    if (!payload) return
    setSnapshot((current) => {
      if (!current) return current
      return { ...current, player: { ...current.player, activeSessionId: undefined } }
    })
  }, []))
  useNuiEvent<void>('callillegal', useCallback(() => {
    setShowPhone(true)
    void playSound('./mTruckerjob-Ringtone.mp3', 0.4)
  }, []))
  useNuiEvent<void>('acceptillegal', useCallback(() => {
    void playSound('./trevor-phonecall.mp3', 0.4)
  }, []))
  useNuiEvent<void>('declineillegal', useCallback(() => setShowPhone(false), []))
  useNuiEvent<{ editing: boolean }>('toggle_hud_edit', useCallback((payload) => {
    setIsEditingHud(payload?.editing ?? false)
  }, []))

  useEffect(() => {
    const keyHandler = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        if (isEditingHud) {
          setIsEditingHud(false)
          void fetchNui('save_hud_pos')
          return
        }
        setIsOpen(false)
        void fetchNui('close')
      }
    }

    window.addEventListener('keyup', keyHandler)
    void fetchNui('ready')
    return () => window.removeEventListener('keyup', keyHandler)
  }, [isEditingHud])

  // Auto-fecha o relatório de entrega
  useEffect(() => {
    if (!report) return
    const timer = window.setTimeout(() => setReport(null), REPORT_AUTO_CLOSE_MS)
    return () => window.clearTimeout(timer)
  }, [report])

  // Ao expirar a rotação com o menu aberto, ressincroniza uma única vez.
  useEffect(() => {
    if (!isOpen || !snapshot?.rotation) return
    const remainingMs = snapshot.rotation.expiresAt * 1000 - (Date.now() + serverOffset)
    if (refreshTimer.current) window.clearTimeout(refreshTimer.current)
    refreshTimer.current = window.setTimeout(() => {
      void refreshBoard()
    }, Math.max(1000, remainingMs + 1500))
    return () => {
      if (refreshTimer.current) window.clearTimeout(refreshTimer.current)
    }
  }, [isOpen, snapshot, serverOffset, refreshBoard])

  const startContract = useCallback(async (offer: ContractOffer, truckName: string) => {
    if (startingOfferId) return
    setStartingOfferId(offer.offerId)
    const response = await fetchNui<StartResponse>('startContract', {
      rotationId: offer.rotationId,
      offerId: offer.offerId,
      truckModel: truckName,
    })
    if (!isFiveM()) {
      setStartingOfferId(undefined)
      notify('Modo de desenvolvimento: contrato simulado.')
      return
    }
    if (response?.ok) {
      setStartingOfferId(undefined)
      setIsOpen(false)
      return
    }
    setStartingOfferId(undefined)
    if (response?.message) notify(response.message)
    // Conflito/timeout: nunca assumir vitória; ressincroniza o quadro.
    await refreshBoard()
  }, [notify, refreshBoard, startingOfferId])

  const visibleTrucks = useMemo(() => (trucks.length ? trucks : trucksCopy), [trucks, trucksCopy])

  const nav = [
    ['main', t('nts_main', 'NTS PRINCIPAL')],
    ['companies', t('companies', 'EMPRESAS')],
    ['leaderboard', t('leaderboard', 'CLASSIFICAÇÃO')],
    ['profile', t('profile', 'PERFIL')],
  ] as const

  return (
    <>
      <NotificationStack notifications={notifications} menuOpen={isOpen} />
      <JobHud jobInfo={jobInfo} language={language} keybinds={keybinds} isEditing={isEditingHud} />
      <PhoneCall visible={showPhone} />
      {report && (
        <DeliveryReport
          result={report}
          language={language}
          interactive={isOpen}
          onClose={() => {
            setReport(null)
            void fetchNui('reportClosed')
          }}
        />
      )}

      {isOpen && (
        <main className="app-shell">
          <header className="app-header">
            <div className="brand">
              <TruckIcon />
              <div>
                <span>Peak Trucking</span>
                <strong>{t('freight_ops', 'Operações de frete')}</strong>
              </div>
            </div>
            <nav>
              {nav.map(([page, label]) => (
                <button className={activePage === page ? 'is-active' : ''} key={page} onClick={() => setActivePage(page)}>
                  {label}
                </button>
              ))}
            </nav>
            <div className="driver-mini">
              <div>
                <strong>{playerData.name ?? t('driver', 'Motorista')}</strong>
                <span>{t('level_short', 'Nv.')} {playerData.level ?? 1}</span>
              </div>
              <img src={playerData.avatar ?? './assets/images/test-pp.png'} alt="" />
            </div>
          </header>

          <section className="app-body">
            {activePage === 'main' && (
              <DispatchView
                snapshot={snapshot}
                loading={snapshotLoading}
                serverOffset={serverOffset}
                trucks={visibleTrucks}
                playerData={playerData}
                language={language}
                jobInfo={jobInfo}
                xp={xp}
                selectedOfferId={selectedOfferId}
                selectedTruckName={selectedTruckName}
                startingOfferId={startingOfferId}
                onOfferChange={(offerId) => {
                  setSelectedOfferId(offerId)
                  setSelectedTruckName(undefined)
                }}
                onTruckChange={setSelectedTruckName}
                onStart={startContract}
                onRefresh={refreshBoard}
                notify={notify}
              />
            )}
            {activePage === 'companies' && (
              <CompaniesView
                missions={missions}
                playerData={playerData}
                language={language}
                contractConfig={contractConfig}
                selectedCompany={selectedCompany}
                onCompanyChange={setSelectedCompany}
              />
            )}
            {activePage === 'profile' && <ProfileView playerData={playerData} language={language} xp={xp} />}
            {activePage === 'leaderboard' && <LeaderboardView language={language} />}
          </section>
        </main>
      )}
    </>
  )
}

async function playSound(src: string, volume: number) {
  const audio = new Audio(src)
  audio.volume = volume
  try {
    await audio.play()
  } catch {
    // Browser autoplay rules can block sounds outside FiveM.
  }
}
