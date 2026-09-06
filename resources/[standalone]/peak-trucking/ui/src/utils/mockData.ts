import type {
  ContractConfig,
  DispatchSnapshot,
  JobResult,
  KeyBinds,
  Language,
  Mission,
  PlayerData,
  Truck,
  XpTable,
} from '../types/trucking'

export const mockLanguage: Language = {
  transportation_stage: 'Etapa de Transporte',
  trailer_quality: 'Integridade da Carga',
  truck_fuel: 'Combustível do Caminhão',
  detach_trailer: 'Soltar Carreta',
  mark_location: 'Marcar Local',
  nts_main: 'NTS PRINCIPAL',
  companies: 'EMPRESAS',
  leaderboard: 'CLASSIFICAÇÃO',
  profile: 'PERFIL',
  global_market: 'MERCADO GLOBAL',
  new_cargo_in: 'Novas cargas em',
  one_per_rotation: '1 CONTRATO POR ROTAÇÃO',
  board_empty_title: 'TODAS AS CARGAS DESTA ROTAÇÃO FORAM DISTRIBUÍDAS',
  board_empty_sub: 'Novas oportunidades em',
  tier_low: 'Baixo',
  tier_medium: 'Médio',
  tier_high: 'Alto',
  status_available: 'DISPONÍVEL',
  status_locked: 'BLOQUEADO',
  status_starting: 'INICIANDO...',
  status_in_progress: 'EM ANDAMENTO',
  status_completed: 'CONCLUÍDO',
  status_failed: 'FRACASSADO',
  status_expired: 'EXPIRADO',
  status_unavailable: 'INDISPONÍVEL',
  for_beginners: 'Para iniciantes',
  start_job: 'INICIAR CONTRATO',
  starting_job: 'INICIANDO...',
  stop_job: 'CANCELAR ENTREGA',
  requirement_not_met: 'REQUISITO NÃO ATENDIDO',
  daily_missions: 'Missões Diárias',
  completed: 'Concluída',
  claimed: 'Recebida',
  hour: 'h',
  select_truck: 'Selecione um Caminhão',
  select_your_truck: 'Selecione seu caminhão',
  select_mission_and_route: 'Selecione uma oferta',
  start_the_job: 'Inicie o contrato',
  completed_jobs: 'Entregas Concluídas',
  total_missions_completed: 'Contratos globais concluídos com todas as empresas.',
  total_earnings: 'Ganhos Totais',
  total_earnings_desc: 'Total de dinheiro ganho em entregas validadas.',
  current_level: 'Nível Atual',
  latest_works: 'Últimas Entregas',
  earned: 'Ganho',
  report_title: 'ENTREGA CONCLUÍDA',
}

export const mockKeyBinds: KeyBinds = {
  mark_location: { label: 'G', key: 133 },
}

export const mockXp: XpTable = Array.from({ length: 100 }, (_, index) => (index + 1) * 1000)

export const mockTrucks: Truck[] = [
  { name: 'packer', image: 'truck-1.png', label: 'Packer', level: 1 },
  { name: 'hauler', image: 'truck-2.png', label: 'Hauler', level: 5 },
  { name: 'phantom3', image: 'truck-3.png', label: 'Phantom Classic', level: 10 },
  { name: 'mule3', image: 'truck-4.png', label: 'Armored Mule', level: 15 },
]

export const mockMissions: Mission[] = [
  {
    id: 1,
    image: 'map_1.png',
    small_image: 'map_1_small.png',
    header: 'Paleto Forest Samwill Woods',
    companyIndex: 0,
    payment: 2500,
    reqPoint: 10,
    routes: [
      { label: 'LS Dock - Paleto Route', vehicle: ['hauler', 'packer', 'phantom3'] },
      { label: 'Grapeseed - Paleto Route', vehicle: ['hauler', 'packer'], reqPoint: 5, extraPayment: 250 },
    ],
    requirementsLabel: [
      { label: 'Wood Supply', icon: 'supply-icon.svg' },
      { label: '$2,500 Profit', icon: 'profit-icon.svg' },
      { label: '2 Different Route', icon: 'route-icon.svg' },
      { label: '+1 Company Trust', icon: 'trust-icon.svg' },
    ],
  },
  {
    id: 3,
    image: 'map_3.png',
    small_image: 'map_3_small.png',
    header: 'Paleto Bay Tobaccos',
    companyIndex: 2,
    payment: 10500,
    reqPoint: 10,
    reqLevel: 25,
    routes: [
      { label: 'LS Dock - Paleto Bay Route', vehicle: ['hauler', 'packer'] },
      { label: 'Paleto Bay - Elysian Island Route', vehicle: ['hauler', 'packer'], reqPoint: 5, extraPayment: 250 },
    ],
    requirementsLabel: [
      { label: 'Packed Cigar Supply', icon: 'supply-icon.svg' },
      { label: '$10,500 Profit', icon: 'profit-icon.svg' },
      { label: '2 Different Route', icon: 'route-icon.svg' },
      { label: '+1 Company Trust', icon: 'trust-icon.svg' },
    ],
  },
]

const now = Math.floor(Date.now() / 1000)

export const mockContractConfig: ContractConfig = {
  reputationTiers: [
    { key: 'unknown', min: 0 },
    { key: 'partner', min: 5 },
    { key: 'trusted', min: 15 },
    { key: 'specialist', min: 30 },
    { key: 'elite', min: 60 },
  ],
  levelBands: {
    low: { min: 1, max: 14 },
    medium: { min: 15, max: 34 },
    high: { min: 35, max: null },
  },
  starterMissions: { '1': true },
  rotationMinutes: 60,
}

export const mockSnapshot: DispatchSnapshot = {
  serverNow: now,
  rotation: { id: String(Math.floor(now / 3600)), expiresAt: (Math.floor(now / 3600) + 1) * 3600, refreshSeconds: 3600 },
  player: { name: 'Alex Morgan', level: 12, xp: 3200, usedThisRotation: false },
  offers: [
    {
      offerId: 'r-g-1', rotationId: 'r', missionId: 1, routeIndex: 2, tier: 'low', companyIndex: 0,
      companyName: 'National Transfer & Storage Co.', title: 'Paleto Forest Samwill Woods', image: 'map_1.png',
      smallImage: 'map_1_small.png', routeLabel: 'Grapeseed - Paleto Route', routeCount: 3, cargoLabel: 'Wood Supply',
      specialFlow: 'trailer', estimatedMinutes: 32, paymentPreview: 5300, basePayPreview: 4800, xpPreview: 644,
      reputationPreview: 2, moneyBonusPercent: 10, xpBonusPercent: 15, levelBand: { min: 1, max: 14 },
      status: 'available', eligible: true, lockReasons: [], mine: false,
      compatibleTrucks: [
        { name: 'packer', label: 'Packer', image: 'truck-1.png', level: 1, unlocked: true },
        { name: 'hauler', label: 'Hauler', image: 'truck-2.png', level: 5, unlocked: true },
        { name: 'phantom', label: 'Phantom', image: 'truck-5.png', level: 20, unlocked: false },
      ],
    },
    {
      offerId: 'r-g-2', rotationId: 'r', missionId: 3, routeIndex: 1, tier: 'medium', companyIndex: 2,
      companyName: 'Redwood Cigarettes Company', title: 'Paleto Bay Tobaccos', image: 'map_3.png',
      smallImage: 'map_3_small.png', routeLabel: 'LS Dock - Paleto Bay Route', routeCount: 2, cargoLabel: 'Packed Cigar Supply',
      specialFlow: 'trailer', estimatedMinutes: 32, paymentPreview: 8000, basePayPreview: 6960, xpPreview: 984,
      reputationPreview: 2, moneyBonusPercent: 15, xpBonusPercent: 20, levelBand: { min: 15, max: 34 }, missionLevel: 25,
      status: 'locked', eligible: false, lockReasons: ['Somente nível 15–34', 'Nível 25 necessário'], mine: false,
      compatibleTrucks: [{ name: 'packer', label: 'Packer', image: 'truck-1.png', level: 1, unlocked: true }],
    },
    {
      offerId: 'r-g-3', rotationId: 'r', missionId: 13, routeIndex: 2, tier: 'high', companyIndex: 7,
      companyName: 'Merry Weather Security', title: 'MWS Army Tank Transport', image: 'map_13.png',
      smallImage: 'map_13_small.png', routeLabel: 'Fort Zancudo - Grand Senora Desert', routeCount: 3, cargoLabel: 'Tank Transport',
      specialFlow: 'trailer', estimatedMinutes: 31, paymentPreview: 12500, basePayPreview: 10000, xpPreview: 1562,
      reputationPreview: 3, moneyBonusPercent: 25, xpBonusPercent: 25, levelBand: { min: 35, max: null }, missionLevel: 60,
      status: 'in_progress', eligible: false, lockReasons: [], mine: false,
      compatibleTrucks: [{ name: 'packer', label: 'Packer', image: 'truck-1.png', level: 1, unlocked: true }],
    },
  ],
}

export const mockResult: JobResult = {
  sessionId: 's', offerId: 'r-g-1', rotationId: 'r', missionId: 1, routeIndex: 2, tier: 'low',
  title: 'Paleto Forest Samwill Woods', routeLabel: 'Grapeseed - Paleto Route', companyIndex: 0,
  companyName: 'National Transfer & Storage Co.', grade: 'A', score: 88.5,
  scoreBreakdown: { integrity: 36, punctuality: 25, steps: 20, handover: 7.5 },
  elapsedMinutes: 27.4, estimatedMinutes: 32, integrityPct: 90, basePay: 8500, marketBonus: 1275, marketBonusPercent: 15,
  qualityDelta: 978, qualityPercent: 10, damagePenalty: 350, illegalBonus: 0, total: 10403, xp: 920, reputation: 3,
  completedAt: now, completedBeforeExpiry: true,
}

export const mockPlayerData: PlayerData = {
  name: 'Alex Morgan',
  avatar: './assets/images/test-pp.png',
  level: 12,
  xp: 3200,
  totalEarnings: 85600,
  completedJobs: 28,
  failedJobs: 2,
  globalCompleted: 28,
  globalFailed: 2,
  points: { '0': 14, '1': 7, '2': 3, '3': 5, '4': 1, '5': 0, '6': 0, '7': 0 },
  dailymissions: {
    resetAt: now + 21600,
    data: {
      complete_global: { header: 'Conquiste uma carga', label: 'Conclua um contrato global.', max: 1, process: 1, xp: 1500, claimed: true },
      grade_a_or_s: { header: 'Excelência', label: 'Finalize uma entrega com nota A ou S.', max: 1, process: 0, xp: 2000 },
      two_companies: { header: 'Diversifique', label: 'Entregue para duas empresas diferentes.', max: 2, process: 1, xp: 2000 },
    },
  },
  history: [
    { label: 'Paleto Forest Samwill Woods', routeLabel: 'Grapeseed - Paleto Route', company: 'National Transfer & Storage Co.', tier: 'low', grade: 'A', basePay: 4800, bonus: 1200, penalty: 100, total: 5900, earn: 5900, xp: 620, reputation: 3, status: 'completed', date: now - 86400, completedAt: now - 86400 },
    { label: 'Paleto Bay Tobaccos', routeLabel: 'LS Dock - Paleto Bay Route', company: 'Redwood Cigarettes Company', tier: 'medium', grade: null, basePay: 0, bonus: 0, penalty: 0, total: 0, earn: 0, status: 'failed', reason: 'truck_destroyed', date: now - 172800 },
  ],
}
