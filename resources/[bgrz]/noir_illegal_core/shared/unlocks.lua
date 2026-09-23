NoirIllegal.Unlocks = {
    dealer_contact = {
        scope = 'player',
        automatic = true,
        requirements = {
            reputation = { drug = 200 },
            maxHeat = 25,
        },
        manualGrantOverridesRequirements = true,
    },

    -- Contatos da gang. O nível em `drug` é da GANG, não de quem fez a venda que o empurrou: o
    -- unlock é avaliado com a reputação e os unlocks da organização. Chegar no nível só abre a
    -- porta — o contato aparece; o que ele libera de fato (fornecedor, laboratório) vem depois
    -- da prova, e é outro unlock, concedido por quem conduz a prova.
    --
    -- Unlock de gang não aceita `maxHeat` nem `organization`: heat é de uma pessoa, e a gang
    -- não tem uma. A validação no start recusa a combinação em vez de ler o heat de quem estiver
    -- por perto.
    --
    -- Uma vez concedido, não cai quando a reputação cai. Perder reputação atrasa o próximo
    -- contato; não tira o que já foi conquistado.
    contact_meth = {
        scope = 'organization',
        automatic = true,
        requirements = {
            minLevel = { drug = 2 },
        },
    },
    contact_coke = {
        scope = 'organization',
        automatic = true,
        requirements = {
            minLevel = { drug = 4 },
            unlocks = { 'contact_meth' },
        },
    },
}
