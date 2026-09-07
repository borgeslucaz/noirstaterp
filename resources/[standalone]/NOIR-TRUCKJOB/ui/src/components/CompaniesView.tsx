import { useMemo } from 'react'
import type { ContractConfig, Language, Mission, PlayerData } from '../types/trucking'
import { companyName, defaultCompanies, makeT, money } from '../utils/format'

type Props = {
  missions: Mission[]
  playerData: PlayerData
  language: Language
  contractConfig: ContractConfig
  selectedCompany: number
  onCompanyChange: (company: number) => void
}

const defaultTiers = [
  { key: 'unknown', min: 0 },
  { key: 'partner', min: 5 },
  { key: 'trusted', min: 15 },
  { key: 'specialist', min: 30 },
  { key: 'elite', min: 60 },
]

export function CompaniesView({ missions, playerData, language, contractConfig, selectedCompany, onCompanyChange }: Props) {
  const t = useMemo(() => makeT(language), [language])
  const companies = contractConfig.companies ?? defaultCompanies
  const tiers = contractConfig.reputationTiers?.length ? contractConfig.reputationTiers : defaultTiers
  const starters = contractConfig.starterMissions ?? { '1': true }
  const level = playerData.level ?? 1

  const companyMissions = missions.filter((mission) => mission.companyIndex === selectedCompany)
  const reputation = playerData.points?.[String(selectedCompany)] ?? 0

  const currentTierIndex = tiers.reduce((acc, tier, index) => (reputation >= tier.min ? index : acc), 0)
  const currentTier = tiers[currentTierIndex]
  const nextTier = tiers[currentTierIndex + 1]
  const progress = nextTier
    ? Math.min(100, Math.round(((reputation - currentTier.min) / Math.max(1, nextTier.min - currentTier.min)) * 100))
    : 100

  const requirement = (mission: Mission) => {
    if (starters[String(mission.id)]) return { available: true, text: t('status_available', 'DISPONÍVEL') }
    if (mission.reqLevel) {
      const ok = level >= mission.reqLevel
      return { available: ok, text: ok ? t('status_available', 'DISPONÍVEL') : t('lock_mission_level', 'Nível %s necessário', mission.reqLevel) }
    }
    const need = mission.reqPoint ?? 0
    const ok = reputation >= need
    return { available: ok, text: ok ? t('status_available', 'DISPONÍVEL') : t('lock_reputation', '%s de reputação necessária', need) }
  }

  return (
    <div className="companies-view">
      <aside className="company-sidebar">
        {Object.keys(Array.isArray(companies) ? companies : companies).map((key, index) => {
          const idx = Array.isArray(companies) ? index : Number(key)
          const name = companyName(companies, idx)
          return (
            <button className={selectedCompany === idx ? 'is-active' : ''} key={idx} onClick={() => onCompanyChange(idx)}>
              <img src={`./assets/images/logo_${idx + 1}.png`} alt="" />
              <span>{name}</span>
            </button>
          )
        })}
      </aside>
      <section className="company-content">
        <div className="company-title">
          <div>
            <p>{t('company_reputation', 'Reputação da empresa')}</p>
            <h2>{companyName(companies, selectedCompany)}</h2>
          </div>
          <strong>{reputation} {t('trust_point', 'Reputação')}</strong>
        </div>

        <div className="reputation-box">
          <div className="reputation-box__head">
            <span>{t(`rep_${currentTier.key}`, currentTier.key)}</span>
            <span>
              {nextTier
                ? `${t('next_tier', 'Próximo patamar')}: ${t(`rep_${nextTier.key}`, nextTier.key)} (${reputation}/${nextTier.min})`
                : t('max_tier', 'Patamar máximo')}
            </span>
          </div>
          <div className="meter__track"><span style={{ width: `${progress}%` }} /></div>
          <div className="reputation-box__tiers">
            {tiers.map((tier, index) => (
              <em className={index <= currentTierIndex ? 'is-reached' : ''} key={tier.key}>
                {t(`rep_${tier.key}`, tier.key)} · {tier.min}
              </em>
            ))}
          </div>
        </div>

        <div className="company-missions">
          {companyMissions.map((mission) => {
            const req = requirement(mission)
            return (
              <article className={`company-mission ${req.available ? '' : 'is-locked'}`} key={mission.id}>
                <img src={`./assets/images/${mission.image}`} alt="" />
                <div>
                  <span>{mission.routes.length} {t('routes', 'rotas')}</span>
                  <h3>{mission.header}</h3>
                  <p>
                    {mission.requirementsLabel[0]?.label}
                    {mission.routes.some((route) => route.reqPoint)
                      ? ` · ${t('lock_route_reputation', '%s de reputação na rota', Math.max(...mission.routes.map((route) => route.reqPoint ?? 0)))}`
                      : ''}
                    {mission.routes.some((route) => route.extraPayment)
                      ? ` · +${money(Math.max(...mission.routes.map((route) => route.extraPayment ?? 0)))}`
                      : ''}
                  </p>
                </div>
                <div className={`company-mission__status ${req.available ? 'is-ok' : 'is-locked'}`}>
                  {req.available ? t('unlocked', 'DISPONÍVEL') : t('locked', 'BLOQUEADA')}
                  {!req.available ? <small>{req.text}</small> : null}
                </div>
              </article>
            )
          })}
        </div>
      </section>
    </div>
  )
}
