"use client"

import type React from "react"
import { useEffect, useRef, useState } from "react"
import { useLocale } from "../hooks/useLocale"

export type BankAction = "deposit" | "withdraw" | "transfer"

interface ActionModalProps {
    action: BankAction
    busy: boolean
    onCancel: () => void
    onConfirm: (amount: number, comment: string, target?: string) => void
}

/** §12: modal central e compacto, foco preso, primário branco, `Escape` cancela. */
export const ActionModal: React.FC<ActionModalProps> = ({ action, busy, onCancel, onConfirm }) => {
    const { t } = useLocale()
    const [amount, setAmount] = useState("")
    const [target, setTarget] = useState("")
    const [comment, setComment] = useState("")
    const firstField = useRef<HTMLInputElement | null>(null)

    useEffect(() => { firstField.current?.focus() }, [])

    useEffect(() => {
        const onKey = (e: KeyboardEvent) => {
            // O Escape do banco fecha a NUI inteira; aqui ele para no modal.
            if (e.key === "Escape") { e.stopPropagation(); onCancel() }
        }
        window.addEventListener("keydown", onKey, true)
        return () => window.removeEventListener("keydown", onKey, true)
    }, [onCancel])

    const value = Number(amount)
    const valid = Number.isFinite(value) && value >= 1 && (action !== "transfer" || target.trim() !== "")

    return (
        <div className="fixed inset-0 z-50 grid place-items-center p-6"
             style={{ background: "var(--noir-overlay)" }}>
            <div role="dialog" aria-modal="true" aria-label={t(`modals.${action}.title`)}
                 className="w-full max-w-[430px] rounded-xl animate-scale-in"
                 style={{ background: "var(--noir-panel-raised)", border: "1px solid var(--noir-border)",
                          boxShadow: "var(--shadow-modal)" }}>
                <div className="px-5 py-4" style={{ borderBottom: "1px solid var(--noir-divider)" }}>
                    <h3 className="text-[17px] font-semibold" style={{ color: "var(--noir-text-strong)" }}>
                        {t(`modals.${action}.title`)}
                    </h3>
                </div>

                <div className="p-5 space-y-4">
                    <div>
                        <label htmlFor="valor" className="block text-[12px] font-semibold mb-2"
                               style={{ color: "var(--noir-text)" }}>
                            {t("modals.common.amount")}
                        </label>
                        <input id="valor" ref={firstField} type="number" min={1} value={amount}
                               onChange={(e) => setAmount(e.target.value)}
                               className="input-field w-full rounded-md px-3 text-[13px]" />
                    </div>

                    {action === "transfer" && (
                        <div>
                            <label htmlFor="destino" className="block text-[12px] font-semibold mb-2"
                                   style={{ color: "var(--noir-text)" }}>
                                {t("renewed.transferTo")}
                            </label>
                            <input id="destino" value={target} onChange={(e) => setTarget(e.target.value)}
                                   className="input-field w-full rounded-md px-3 text-[13px]" />
                        </div>
                    )}

                    <div>
                        <label htmlFor="descricao" className="block text-[12px] font-semibold mb-2"
                               style={{ color: "var(--noir-text)" }}>
                            {t("renewed.comment")}
                        </label>
                        <input id="descricao" value={comment} onChange={(e) => setComment(e.target.value)}
                               placeholder={t("renewed.commentPlaceholder")}
                               className="input-field w-full rounded-md px-3 text-[13px]" />
                    </div>
                </div>

                <div className="flex gap-3 px-5 pb-5">
                    <button onClick={onCancel} className="btn-base btn-ghost flex-1 py-3">
                        {t("common.cancel")}
                    </button>
                    <button
                        onClick={() => onConfirm(value, comment, target.trim() || undefined)}
                        disabled={!valid || busy}
                        aria-busy={busy}
                        className="btn-base btn-primary flex-1 py-3"
                    >
                        {t("common.confirm")}
                    </button>
                </div>
            </div>
        </div>
    )
}
