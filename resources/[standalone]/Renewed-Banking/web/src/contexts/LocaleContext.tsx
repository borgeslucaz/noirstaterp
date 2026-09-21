"use client"

import React, { createContext, useContext, useCallback } from "react"
import ptBR from "../locale-pt.json"

type LocaleData = Record<string, any>

interface LocaleContextType {
    t: (key: string, vars?: Record<string, string | number>) => string
}

const LocaleContext = createContext<LocaleContextType | undefined>(undefined)

/**
 * Traduções do NUI.
 *
 * O upstream do qual esta interface veio buscava o arquivo por `fetch` em runtime e começava em
 * espanhol até a resposta chegar -- e se a mensagem que manda trocar de idioma se perdesse, ficava
 * em espanhol para sempre. Aqui é um `import`: uma língua, dentro do bundle, sem corrida e sem
 * uma peça a mais para dar errado.
 */
export const LocaleProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const t = useCallback((key: string, vars?: Record<string, string | number>): string => {
        let value: LocaleData | string = ptBR
        for (const part of key.split(".")) {
            if (typeof value !== "object" || value === null) return key
            value = (value as LocaleData)[part]
            if (value === undefined) return key
        }
        if (typeof value !== "string") return key

        let text = value
        if (vars) {
            for (const [k, v] of Object.entries(vars)) {
                text = text.replace(new RegExp(`\\{${k}\\}`, "g"), String(v))
            }
        }
        return text
    }, [])

    return <LocaleContext.Provider value={{ t }}>{children}</LocaleContext.Provider>
}

export const useLocaleContext = () => {
    const ctx = useContext(LocaleContext)
    if (!ctx) throw new Error("useLocale precisa estar dentro de LocaleProvider")
    return ctx
}
