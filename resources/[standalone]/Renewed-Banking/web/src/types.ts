/**
 * Formato de dados do Renewed-Banking.
 *
 * O servidor devolve uma lista chata de contas em `getBankData`: a pessoal, as de job e gang em
 * que o personagem tem `bankAuth`, e as compartilhadas. Todas no mesmo formato -- é o que permite
 * a tira de contas desenhar as três categorias sem tratamento especial.
 */
export interface RenewedTransaction {
    trans_id: string
    title: string
    amount: number
    /** 'deposit' entra na conta, 'withdraw' sai. */
    trans_type: string
    receiver: string
    issuer: string
    message: string
    /** Unix em SEGUNDOS, não milissegundos. */
    time: number
}

export interface RenewedAccount {
    /** citizenid na conta pessoal; nome do job/gang nas de organização. É a chave nas operações. */
    id: string
    /** Rótulo traduzido de categoria, vindo do locale do Renewed ("Pessoal" / "Organização"). */
    type: string
    name: string
    amount: number
    /** Só a conta pessoal traz dinheiro em espécie. É o que distingue ela das demais. */
    cash?: number
    frozen?: boolean | number
    transactions?: RenewedTransaction[]
}

/**
 * Separa a conta pessoal das de organização.
 *
 * `cash` sozinho era frágil: se o framework não devolvesse dinheiro em espécie, a conta pessoal
 * seria classificada como organização e a tira inteira sairia errada. O `getBankData` do Renewed
 * empilha a pessoal SEMPRE primeiro, antes dos jobs, gangs e compartilhadas -- essa ordem é
 * estrutural, não coincidência, então é o critério primário. O `cash` fica como confirmação.
 */
export const splitAccounts = (accounts: RenewedAccount[]) => {
    const personal: RenewedAccount[] = []
    const orgs: RenewedAccount[] = []

    accounts.forEach((account, index) => {
        const isPersonal = index === 0 || typeof account.cash === "number"
        ;(isPersonal ? personal : orgs).push(account)
    })

    return { personal, orgs }
}

export const isFrozen = (account: RenewedAccount): boolean =>
    account.frozen === true || account.frozen === 1
