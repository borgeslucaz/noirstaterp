/**
 * Chama um `RegisterNUICallback` do resource que hospeda esta página.
 *
 * O Renewed-Banking registra `closeInterface`, `deposit`, `withdraw` e `transfer`. Os três
 * últimos repassam para o servidor e devolvem a lista de contas já atualizada -- ou `false`
 * quando a operação é recusada.
 */
export async function fetchNui<T = any>(eventName: string, data?: unknown): Promise<T | null> {
    const resource = (window as any).GetParentResourceName?.() ?? "Renewed-Banking"

    try {
        const resp = await fetch(`https://${resource}/${eventName}`, {
            method: "post",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data ?? {}),
        })
        const text = await resp.text()
        if (!text) return null
        return JSON.parse(text) as T
    } catch (err) {
        // Fora do FiveM (navegador) não existe para onde chamar. Em jogo, cair aqui significa
        // que o callback não existe no resource -- vale gritar no console, porque a tela sozinha
        // só mostraria "não deu".
        console.error(`[banco] falhou ao chamar '${eventName}' em '${resource}':`, err)
        return null
    }
}
