export type Page = 'main' | 'companies' | 'leaderboard' | 'profile'

export type Tier = 'low' | 'medium' | 'high'

export type OfferStatus =
  | 'available'
  | 'locked'
  | 'starting'
  | 'in_progress'
  | 'completed'
  | 'failed'
  | 'failed_system'
  | 'expired'
  | 'unavailable'

export type Requirement = {
  label: string
  icon: string
}

export type Route = {
  label: string
  vehicle: string[]
  reqPoint?: number
  extraPayment?: number
}

export type Mission = {
  id: number
  image: string
  small_image?: string
  header: string
  companyIndex: number
  payment: number
  reqPoint?: number
  reqLevel?: number
  routes: Route[]
  requirementsLabel: Requirement[]
}

export type Truck = {
  name: string
  image: string
  label: string
  level: number
  desc?: string
}

export type TruckProjection = {
  name: string
  label: string
  image: string
  level: number
  unlocked: boolean
}

export type ContractOffer = {
  offerId: string
  rotationId: string
  missionId: number
  routeIndex: number
  tier: Tier
  companyIndex: number
  companyName: string
  title: string
  image: string
  smallImage: string
  routeLabel: string
  routeCount: number
  cargoLabel: string
  specialFlow: 'trailer' | 'no_trailer' | 'manual_boxes'
  estimatedMinutes: number
  paymentPreview: number
  basePayPreview: number
  xpPreview: number
  reputationPreview: number
  moneyBonusPercent: number
  xpBonusPercent: number
  levelBand: { min: number; max?: number | null }
  missionLevel?: number
  status: OfferStatus
  eligible: boolean
  lockReasons: string[]
  mine: boolean
  compatibleTrucks: TruckProjection[]
}

export type DispatchSnapshot = {
  serverNow: number
  rotation?: {
    id: string
    expiresAt: number
    refreshSeconds: number
  } | null
  player: {
    name?: string
    level: number
    xp: number
    usedThisRotation: boolean
    activeSessionId?: string
  }
  offers: ContractOffer[]
}

export type ScoreBreakdown = {
  integrity: number
  punctuality: number
  steps: number
  handover: number
}

export type JobResult = {
  sessionId: string
  offerId: string
  rotationId: string
  missionId: number
  routeIndex: number
  tier: Tier
  title: string
  routeLabel: string
  companyIndex: number
  companyName: string
  grade: string
  score: number
  scoreBreakdown: ScoreBreakdown
  elapsedMinutes: number
  estimatedMinutes: number
  integrityPct: number
  basePay: number
  marketBonus: number
  marketBonusPercent: number
  qualityDelta: number
  qualityPercent: number
  damagePenalty: number
  illegalBonus: number
  total: number
  xp: number
  reputation: number
  completedAt: number
  completedBeforeExpiry: boolean
}

export type JobFailedPayload = {
  status: 'failed' | 'failed_system'
  reason: string
  sessionId: string
}

export type DailyMission = {
  key?: string
  header: string
  label: string
  max: number
  xp: number
  reputation?: number
  process: number
  claimed?: boolean
}

export type HistoryEntry = {
  sessionId?: string
  label: string
  routeLabel?: string
  company?: string
  companyIndex?: number
  tier?: Tier | null
  grade?: string | null
  score?: number | null
  basePay?: number
  bonus?: number
  penalty?: number
  total?: number
  earn: number
  xp?: number
  reputation?: number
  status?: 'completed' | 'failed' | 'failed_system' | string
  reason?: string | null
  date: number
  completedAt?: number | null
  legacy?: boolean
  supply?: string
}

export type PlayerData = {
  name?: string
  avatar?: string
  level?: number
  xp?: number
  points?: Record<string, number>
  totalEarnings?: number
  completedJobs?: number
  failedJobs?: number
  globalCompleted?: number
  globalFailed?: number
  dailymissions?: {
    data: Record<string, DailyMission>
    resetAt: number
  }
  history?: HistoryEntry[]
}

export type JobInfo = {
  started?: boolean
  attachedTrailer?: boolean
  bodyHealth?: number
  fuel?: number
  routeHeader?: string
  boxProgress?: string
  tier?: Tier | null
}

export type LeaderboardEntry = {
  rank: number
  name: string
  avatar?: string
  level: number
  globalCompleted: number
  isMe?: boolean
}

export type LeaderboardResponse = {
  ok?: boolean
  metric?: 'level' | 'global'
  data?: LeaderboardEntry[]
  me?: {
    position?: number | null
    name?: string
    level?: number
    xp?: number
    globalCompleted?: number
    ranked?: boolean
  } | null
}

export type ReputationTier = { key: string; min: number }

export type ContractConfig = {
  companies?: Record<string, string> | string[]
  reputationTiers?: ReputationTier[]
  levelBands?: Record<Tier, { min: number; max?: number | null }>
  starterMissions?: Record<string, boolean>
  routeMeta?: Record<string, { tier: Tier; estimatedMinutes: number; baseXP: number }>
  rotationMinutes?: number
}

export type Language = Record<string, string>
export type XpTable = Record<number, number> | number[]

export type KeyBinds = {
  mark_location?: {
    label: string
    key: number
  }
}
