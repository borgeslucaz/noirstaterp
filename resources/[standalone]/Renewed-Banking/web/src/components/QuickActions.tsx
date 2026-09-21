"use client"

import type React from "react"
import { ArrowDownLeft, ArrowUpRight, Send } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface QuickActionsProps {
    onAction: (action: "deposit" | "withdraw" | "transfer") => void
}

/**
 * Atalhos do topo do painel.
 *
 * Os quatro botões eram verde, laranja, azul e roxo saturados. Isso viola o §24
 * em dois pontos: gradiente colorido decorativo, e laranja/vermelho em `Sacar`,
 * que rouba o significado de `danger` -- sacar é operação comum, não destrutiva.
 *
 * Também não há botão primário branco aqui: esta é uma régua de atalhos, não uma
 * região de decisão, e o §11.1 reserva o branco para uma ação por decisão. Os
 * quatro são pares e ficam neutros; o que os distingue é ícone e rótulo.
 */
export const QuickActions: React.FC<QuickActionsProps> = ({ onAction }) => {
    const { t } = useLocale()

    // Criar, renomear e compartilhar conta são menus do ox_lib no ped do banco, do lado do
    // Renewed -- não passam pelo NUI. Por isso só três atalhos aqui.
    const actions = [
        { id: "deposit" as const, label: t("quickActions.deposit"), icon: ArrowDownLeft },
        { id: "withdraw" as const, label: t("quickActions.withdraw"), icon: ArrowUpRight },
        { id: "transfer" as const, label: t("quickActions.transfer"), icon: Send },
    ]

    return (
        <div className="grid grid-cols-3 gap-3">
            {actions.map((action) => (
                <button
                    key={action.id}
                    onClick={() => onAction(action.id)}
                    className="group flex flex-col items-center justify-center gap-2 px-4 py-4 rounded-md transition-colors"
                    style={{
                        minHeight: 40,
                        background: "var(--noir-card)",
                        border: "1px solid var(--noir-border-soft)",
                        color: "var(--noir-text)",
                    }}
                    onMouseEnter={(e) => {
                        e.currentTarget.style.background = "var(--noir-card-hover)"
                        e.currentTarget.style.borderColor = "var(--noir-border)"
                        e.currentTarget.style.color = "var(--noir-text-strong)"
                    }}
                    onMouseLeave={(e) => {
                        e.currentTarget.style.background = "var(--noir-card)"
                        e.currentTarget.style.borderColor = "var(--noir-border-soft)"
                        e.currentTarget.style.color = "var(--noir-text)"
                    }}
                >
                    <action.icon size={20} />
                    <span className="text-[13px] font-medium">{action.label}</span>
                </button>
            ))}
        </div>
    )
}
