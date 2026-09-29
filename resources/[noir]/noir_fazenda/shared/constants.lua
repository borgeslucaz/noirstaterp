NoirFazenda = NoirFazenda or {}

NoirFazenda.Constants = {
    resource = 'noir_fazenda',

    subject = {
        player = 'player',
        org = 'org',
    },

    direction = {
        inbound = 'in',
        outbound = 'out',
    },

    -- Categorias do ledger. O que é tributável está em `taxableCategories`, não
    -- espalhado em ifs pelo código.
    category = {
        -- entrou por transferência de outra conta: alguém pagou o sujeito
        transferIn = 'transferencia_recebida',
        -- entrou porque o próprio dono colocou dinheiro em espécie na conta.
        -- NÃO é renda: é o mesmo dinheiro mudando de bolso.
        selfDeposit = 'deposito_proprio',
        -- saiu da conta, em qualquer forma
        outflow = 'saida',
        -- renda reportada por outro resource pelo export `RecordIncome`
        declaredIncome = 'renda_declarada',
        -- pagamento de imposto, para o extrato fechar
        taxPayment = 'imposto_pago',
    },

    status = {
        simulated = 'simulated',
        assessed = 'assessed',
        paid = 'paid',
        overdue = 'overdue',
        waived = 'waived',
        void = 'void',
    },

    periodPrefix = {
        weekly = 'W',
        daily = 'D',
    },

    errors = {
        notReady = 'NOT_READY',
        invalidArgument = 'INVALID_ARGUMENT',
        invalidSubject = 'INVALID_SUBJECT',
        invalidAmount = 'INVALID_AMOUNT',
        invalidPeriod = 'INVALID_PERIOD',
        forbidden = 'FORBIDDEN_CALLER',
        storageFailed = 'STORAGE_FAILED',
        bankingUnavailable = 'BANKING_UNAVAILABLE',
        collectionDisabled = 'COLLECTION_DISABLED',
        nothingDue = 'NOTHING_DUE',
    },
}

---@param code string
---@param context? table
---@return table
function NoirFazenda.error(code, context)
    local payload = { ok = false, error = code }
    if context then payload.context = context end
    return payload
end
