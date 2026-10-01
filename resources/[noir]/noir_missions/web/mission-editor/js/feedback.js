// Saída de mensagens curtas (resultado de ação, erro do servidor). Os campos não conhecem a
// tela: quem monta o editor liga o destino com setFeedbackSink().
let sink = (tone, text) => console.log(`[noir_missions] ${tone}: ${text}`);

export function setFeedbackSink(fn) {
    sink = fn;
}

/** @param {'success'|'warning'|'danger'|'info'} tone */
export function notify(tone, text) {
    sink(tone, text);
}
