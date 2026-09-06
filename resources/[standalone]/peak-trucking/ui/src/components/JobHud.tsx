import { useState, useEffect, useRef } from 'react'
import type { JobInfo, KeyBinds, Language } from '../types/trucking'
import { TruckIcon } from './Icons'
import { fetchNui } from '../utils/nui'
import { makeT } from '../utils/format'

type Props = {
  jobInfo: JobInfo
  language: Language
  keybinds: KeyBinds
  isEditing?: boolean
}

export function JobHud({ jobInfo, language, keybinds, isEditing }: Props) {
  const t = makeT(language)
  const [pos, setPos] = useState({ x: 0, y: 0 })
  const [isDragging, setIsDragging] = useState(false)
  const dragStart = useRef({ x: 0, y: 0 })
  const hudRef = useRef<HTMLElement>(null)

  useEffect(() => {
    try {
      const saved = localStorage.getItem('peak_trucking_hud_pos')
      if (saved) setPos(JSON.parse(saved))
    } catch (e) {
      console.error('Failed to load HUD position', e)
    }
  }, [])

  const handleMouseDown = (e: React.MouseEvent) => {
    if (!isEditing) return
    setIsDragging(true)
    dragStart.current = {
      x: e.clientX - pos.x,
      y: e.clientY - pos.y,
    }
  }

  useEffect(() => {
    if (!isDragging) return

    const handleMouseMove = (e: MouseEvent) => {
      setPos({
        x: e.clientX - dragStart.current.x,
        y: e.clientY - dragStart.current.y,
      })
    }

    const handleMouseUp = () => {
      setIsDragging(false)
      try {
        localStorage.setItem('peak_trucking_hud_pos', JSON.stringify(pos))
      } catch {
        // storage indisponível
      }
    }

    window.addEventListener('mousemove', handleMouseMove)
    window.addEventListener('mouseup', handleMouseUp)
    return () => {
      window.removeEventListener('mousemove', handleMouseMove)
      window.removeEventListener('mouseup', handleMouseUp)
    }
  }, [isDragging, pos])

  const handleSave = () => {
    void fetchNui('save_hud_pos')
  }

  const handleCancel = () => {
    void fetchNui('stopJob')
  }

  if (!jobInfo.started && !isEditing) return null

  return (
    <aside
      ref={hudRef}
      className={`job-hud ${isEditing ? 'is-editing' : ''}`}
      style={{ transform: `translate(${pos.x}px, ${pos.y}px)` }}
      onMouseDown={handleMouseDown}
    >
      <div className="job-hud__media">
        <TruckIcon />
        <span>{jobInfo.attachedTrailer ? t('status_in_progress', 'EM ANDAMENTO') : t('cargo', 'Carga')}</span>
        {jobInfo.tier ? <em className={`tier-badge tier-badge--${jobInfo.tier}`}>{t(`tier_${jobInfo.tier}`, jobInfo.tier)}</em> : null}
      </div>
      <div className="job-hud__content">
        <p className="eyebrow">{t('transportation_stage', 'Etapa de Transporte')}</p>
        <h2>{jobInfo.routeHeader ?? (isEditing ? 'Modo de edição' : t('route', 'Rota'))}</h2>

        {isEditing ? (
          <button className="primary-action" onClick={handleSave} style={{ height: '36px', fontSize: '11px' }}>
            Salvar posição
          </button>
        ) : (
          <>
            <div className="metric-row">
              <Meter label={t('trailer_quality', 'Integridade da Carga')} value={Math.max(0, Math.min(100, jobInfo.bodyHealth ?? 0))} />
              <Meter label={t('truck_fuel', 'Combustível do Caminhão')} value={Math.max(0, Math.min(100, jobInfo.fuel ?? 0))} />
            </div>
            {jobInfo.boxProgress && (
              <div className="metric-row" style={{ marginTop: '8px', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: '8px' }}>
                <div className="meter">
                  <div>
                    <span>{t('box_progress', 'Progresso da Carga')}</span>
                    <strong>{jobInfo.boxProgress}</strong>
                  </div>
                </div>
              </div>
            )}
            <div className="key-row">
              <kbd>H</kbd><span>{t('detach_trailer', 'Soltar Carreta')}</span>
              <kbd>{keybinds.mark_location?.label ?? 'G'}</kbd><span>{t('mark_location', 'Marcar Local')}</span>
              <kbd>/canceltrucking</kbd><span>{t('cancel_job', 'Cancelar Entrega')}</span>
            </div>
            <button className="cancel-job-btn" onClick={handleCancel}>
              {t('cancel_job', 'Cancelar Entrega')}
            </button>
          </>
        )}
      </div>
    </aside>
  )
}

function Meter({ label, value }: { label: string; value: number }) {
  return (
    <div className="meter">
      <div>
        <span>{label}</span>
        <strong>{value.toFixed(0)}%</strong>
      </div>
      <div className="meter__track">
        <span style={{ width: `${value}%` }} />
      </div>
    </div>
  )
}
