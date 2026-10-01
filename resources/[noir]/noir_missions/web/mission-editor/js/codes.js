// Códigos de erro do contrato em texto para o admin. Código desconhecido aparece cru no fim,
// para dar pista de onde veio.

const CODES = {
    not_allowed: 'Sem permissão para isso.',
    invalid_id: 'ID inválido. Use minúsculas, números, _ e -, de 2 a 48 caracteres.',
    id_exists: 'Já existe uma missão com esse ID.',
    not_found: 'Missão não encontrada. Ela pode ter sido apagada.',
    invalid_definition: 'A missão tem erros. Corrija antes de continuar.',
    busy: 'Outra operação ainda está em andamento. Tente de novo em instantes.',
    rate_limited: 'Muitas ações seguidas. Espere um pouco.',
    no_instance: 'Nenhum teste em andamento. Inicie um teste ou o sandbox primeiro.',
    not_enough_players: 'Jogadores insuficientes para começar.',
    cooldown: 'A missão está em cooldown.',
    gang_required: 'Esta missão exige gang.',
    mission_disabled: 'A missão está desativada.',
    max_instances: 'Limite de missões simultâneas atingido.',
    invalid_model: 'Modelo inexistente neste build.',
    internal_error: 'Erro interno no servidor. Veja o console.',
    transport_error: 'Sem resposta do jogo. Tente de novo.',
    expired: 'A oferta expirou.',
};

/** @param {string|undefined} code */
export function codeText(code) {
    if (!code) return 'Não deu certo.';
    return CODES[code] || `Não deu certo (${code}).`;
}
