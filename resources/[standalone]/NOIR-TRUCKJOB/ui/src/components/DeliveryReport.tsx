import type { JobResult, Language } from '../types/trucking'
import { makeT, money, signedMoney } from '../utils/format'

type Props = {
  result: JobResult
  language: Language
  interactive: boolean
  onClose: () => void
}

export function DeliveryReport({ result, language, interactive, onClose }: Props) {
  const t = makeT(language)

  return (
    <div className={`report ${interactive ? 'report--interactive' : ''}`}>
      <div className="report__shell">
        <div className="report__head">
          <div>
            <p className="eyebrow">{result.companyName}</p>
            <h2>{t('report_title', 'ENTREGA CONCLUÍDA')}</h2>
            <span>{result.title} · {result.routeLabel}</span>
          </div>
          <div className={`report__grade report__grade--${result.grade}`}>
            <small>{t('report_grade', 'NOTA')}</small>
            <strong>{result.grade}</strong>
            <em>{result.score.toFixed(1)}</em>
          </div>
        </div>

        <div className="report__lines">
          <Line label={t('report_base', 'Pagamento base')} value={money(result.basePay)} />
          <Line label={`${t('report_market', 'Bônus do Mercado Global')} (+${result.marketBonusPercent}%)`} value={signedMoney(result.marketBonus)} tone="plus" />
          <Line
            label={`${result.qualityDelta >= 0 ? t('report_quality', 'Bônus de qualidade') : t('report_quality_penalty', 'Ajuste de qualidade')} (${result.qualityPercent >= 0 ? '+' : ''}${result.qualityPercent}%)`}
            value={signedMoney(result.qualityDelta)}
            tone={result.qualityDelta >= 0 ? 'plus' : 'minus'}
          />
          {result.damagePenalty > 0 && (
            <Line label={t('report_damage', 'Penalidade por danos')} value={signedMoney(-result.damagePenalty)} tone="minus" />
          )}
          {result.illegalBonus > 0 && (
            <Line label={t('report_illegal', 'Bônus de carga ilegal')} value={signedMoney(result.illegalBonus)} tone="plus" />
          )}
          <div className="report__total">
            <span>{t('report_total', 'Total')}</span>
            <strong>{money(result.total)}</strong>
          </div>
        </div>

        <div className="report__meta">
          <div><span>{t('report_xp', 'XP recebido')}</span><strong>{result.xp}</strong></div>
          <div><span>{t('report_reputation', 'Reputação')}</span><strong>+{result.reputation}</strong></div>
          <div><span>{t('score_integrity', 'Integridade')}</span><strong>{result.scoreBreakdown.integrity.toFixed(0)}/40</strong></div>
          <div><span>{t('score_punctuality', 'Pontualidade')}</span><strong>{result.scoreBreakdown.punctuality.toFixed(0)}/25</strong></div>
          <div><span>{t('score_steps', 'Etapas')}</span><strong>{result.scoreBreakdown.steps.toFixed(0)}/20</strong></div>
          <div><span>{t('score_handover', 'Devolução')}</span><strong>{result.scoreBreakdown.handover.toFixed(0)}/15</strong></div>
        </div>

        {interactive && (
          <button className="primary-action" onClick={onClose}>
            {t('report_close', 'FECHAR')}
          </button>
        )}
      </div>
    </div>
  )
}

function Line({ label, value, tone }: { label: string; value: string; tone?: 'plus' | 'minus' }) {
  return (
    <div className={`report__line ${tone ? `report__line--${tone}` : ''}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  )
}
