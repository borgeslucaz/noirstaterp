"use client"

import { useCallback, useEffect, useMemo, useState } from "react"
import { LocaleProvider } from "./contexts/LocaleContext"
import { useLocale } from "./hooks/useLocale"
import { useNuiEvent } from "./hooks/useNuiEvent"
import { fetchNui } from "./utils/fetchNui"
import { Sidebar } from "./components/Sidebar"
import { QuickActions } from "./components/QuickActions"
import { Accounts } from "./components/Accounts"
import { TransactionHistory } from "./components/TransactionHistory"
import { Stats } from "./components/Stats"
import { ActionModal, type BankAction } from "./components/ActionModal"
import { Atm } from "./components/Atm"
import { NotificationSystem, type Notification } from "./components/NotificationSystem"
import type { RenewedAccount } from "./types"

/**
 * Interface do banco sobre o Renewed-Banking.
 *
 * O contrato do resource é pequeno e esta tela se encaixa nele sem exigir **uma linha de Lua
 * alterada**:
 *
 *   recebe  `setLoading {status}`
 *           `setVisible {status, accounts, atm}`   <- as contas vêm juntas, já prontas
 *           `notify {status}`
 *   chama   `closeInterface`
 *           `deposit` / `withdraw` / `transfer`    <- devolvem a lista de contas atualizada
 *
 * Esse retorno é o que dispensa recarregar depois de cada operação: o servidor responde com o
 * estado novo e a tela só troca o que tem em mãos.
 */
const Bank = () => {
    const { t } = useLocale()

    const [visible, setVisible] = useState(false)
    const [loading, setLoading] = useState(false)
    const [accounts, setAccounts] = useState<RenewedAccount[]>([])
    const [selectedId, setSelectedId] = useState<string | null>(null)
    const [activeTab, setActiveTab] = useState("accounts")
    const [modal, setModal] = useState<BankAction | null>(null)
    /** O Renewed manda `atm = true` quando a tela foi aberta num caixa eletrônico. */
    const [isAtm, setIsAtm] = useState(false)
    const [busy, setBusy] = useState(false)
    const [notes, setNotes] = useState<Notification[]>([])

    const note = useCallback((message: string, type: Notification["type"] = "info") => {
        const id = `${Date.now()}-${Math.random()}`
        setNotes((prev) => [...prev, { id, type, message }])
        setTimeout(() => setNotes((prev) => prev.filter((n) => n.id !== id)), 5000)
    }, [])

    /** Aceita tanto lista quanto objeto indexado: o Lua serializa um ou outro conforme as chaves. */
    const applyAccounts = useCallback((incoming: unknown) => {
        // Diagnóstico no console do jogo (F8). É a única janela que temos para o que o Lua
        // realmente manda -- o formato depende do framework, do bankAuth do cargo e de quantas
        // contas o personagem alcança.
        console.log("[banco] contas recebidas:", JSON.stringify(incoming))

        const list: RenewedAccount[] = Array.isArray(incoming)
            ? incoming
            : incoming && typeof incoming === "object"
                ? Object.values(incoming as Record<string, RenewedAccount>)
                : []
        setAccounts(list)
        setSelectedId((current) =>
            current && list.some((a) => a.id === current) ? current : list[0]?.id ?? null)
    }, [])

    useNuiEvent<{ status: boolean }>("setLoading", (data) => setLoading(!!data?.status))

    useNuiEvent<any>("setVisible", (data) => {
        applyAccounts(data?.accounts)
        setLoading(!!data?.loading)
        // O Renewed manda `status` com a visibilidade que o client já aplicou ao foco. Quando a
        // chave não vem, tratamos como abrir -- a mensagem só é enviada para mostrar a tela.
        setVisible(data?.status !== false)
        setIsAtm(!!data?.atm)
        setActiveTab("accounts")
    })

    useNuiEvent<any>("notify", (data) => {
        const msg = typeof data?.status === "string" ? data.status : data?.status?.description
        if (msg) note(msg, "info")
    })

    const close = useCallback(() => {
        setVisible(false)
        setModal(null)
        fetchNui("closeInterface")
    }, [])

    /**
     * Esc fecha o banco.
     *
     * Registrado na fase de BOLHA de propósito: o `ActionModal` escuta na fase de CAPTURA e
     * chama `stopPropagation`, então com um modal aberto o Esc para nele e não fecha a tela
     * inteira por trás. Sem modal, o evento chega aqui.
     */
    useEffect(() => {
        if (!visible) return

        const onKey = (event: KeyboardEvent) => {
            if (event.key === "Escape") close()
        }

        window.addEventListener("keydown", onKey)
        return () => window.removeEventListener("keydown", onKey)
    }, [visible, close])

    const selected = useMemo(
        () => accounts.find((a) => a.id === selectedId) ?? accounts[0] ?? null,
        [accounts, selectedId])

    const transactions = useMemo(() => selected?.transactions ?? [], [selected])

    const submit = useCallback(async (amount: number, comment: string, target?: string) => {
        if (!selected || busy) return
        setBusy(true)
        const action = modal as BankAction

        const result = await fetchNui<RenewedAccount[] | false>(action, {
            fromAccount: selected.id,
            stateid: target,
            amount,
            comment,
        })

        setBusy(false)
        setModal(null)

        // O servidor responde `false` quando recusa -- saldo insuficiente, conta inválida. Ele
        // já notifica o jogador pelo próprio canal, então aqui só evitamos sobrescrever o estado
        // com um retorno vazio.
        console.log(`[banco] ${action} respondeu:`, JSON.stringify(result))

        if (result === false) {
            // Recusa do servidor -- saldo insuficiente, conta inválida. Ele já avisa o jogador
            // pelo canal dele; aqui só não sobrescrevemos o estado.
            note(t("renewed.actionFailed"), "error")
            return
        }
        if (result == null) {
            // Nem recusa nem dados: o callback não respondeu. Quase sempre é o NUI falando com
            // um nome de resource errado, então vale dizer qual foi tentado.
            note(`${t("renewed.actionFailed")} (${action})`, "error")
            return
        }
        applyAccounts(result)
    }, [selected, busy, modal, applyAccounts, note, t])

    if (!visible) return null

    // Caixa eletrônico: janela estreita, sem rail e sem abas. Mesmo backend, enquadramento outro.
    if (isAtm) {
        return (
            <>
                <Atm
                    accounts={accounts}
                    selectedId={selectedId}
                    onSelect={setSelectedId}
                    onAction={(a) => setModal(a)}
                    onClose={close}
                />
                {modal && (
                    <ActionModal action={modal} busy={busy}
                                 onCancel={() => setModal(null)} onConfirm={submit} />
                )}
                <NotificationSystem notifications={notes}
                                    onRemove={(id) => setNotes((p) => p.filter((n) => n.id !== id))} />
            </>
        )
    }

    return (
        <div className="fixed inset-0 flex items-center justify-center p-4 md:p-8 animate-in">
            <div className="w-full max-w-7xl h-[90vh] flex rounded-3xl overflow-hidden relative animate-scale-in">
                <div className="absolute inset-0 z-0" style={{ background: "var(--noir-canvas-solid)" }} />

                <div className="relative z-10 flex w-full h-full">
                    <Sidebar
                        activeTab={activeTab}
                        setActiveTab={setActiveTab}
                        onClose={close}
                    />

                    <main className="flex-1 p-4 md:p-8 overflow-y-auto custom-scrollbar flex flex-col">
                        {loading ? (
                            <p className="m-auto text-[13px]" style={{ color: "var(--noir-text-muted)" }}>
                                {t("dashboard.loading_bank")}
                            </p>
                        ) : (
                            <>
                                {activeTab === "accounts" && (
                                    <div className="space-y-6">
                                        <QuickActions onAction={(a) => setModal(a)} />
                                        <Accounts accounts={accounts} selectedId={selectedId}
                                                  onSelect={setSelectedId} />
                                    </div>
                                )}
                                {activeTab === "transactions" && <TransactionHistory transactions={transactions} />}
                                {activeTab === "stats" && <Stats transactions={transactions}
                                                                 accountName={selected?.name} />}
                            </>
                        )}
                    </main>
                </div>
            </div>

            {modal && (
                <ActionModal action={modal} busy={busy}
                             onCancel={() => setModal(null)} onConfirm={submit} />
            )}

            <NotificationSystem notifications={notes}
                                onRemove={(id) => setNotes((p) => p.filter((n) => n.id !== id))} />
        </div>
    )
}

const App = () => (
    <LocaleProvider>
        <Bank />
    </LocaleProvider>
)

export default App
