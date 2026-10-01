// Teste: inicia a missão (inteira, a partir de um passo ou sandbox) e ferramentas que agem
// numa instância de teste em andamento. Tudo salva antes; com erro, não testa.
import { el, button, setBusy, notice } from '../../dom.js';
import { fetchNui } from '../../nui.js';
import { codeText } from '../../codes.js';
import { state } from '../store.js';
import { refItems } from '../refs.js';
import { sectionHead } from '../ui.js';
import { valueSelect } from '../../forms/fields-basic.js';

// Ferramenta → coleção que ela usa (contrato editorTestTool).
const TOOLS = [
    { tool: 'teleport_step', label: 'TELEPORTAR PARA O PASSO', ref: 'steps', done: 'Teleportado para o passo.' },
    { tool: 'spawn_group', label: 'CRIAR GRUPO DE NPC', ref: 'pedGroups', done: 'Grupo criado.' },
    { tool: 'spawn_vehicle', label: 'CRIAR VEÍCULO', ref: 'vehicles', done: 'Veículo criado.' },
    { tool: 'spawn_prop', label: 'CRIAR OBJETO', ref: 'props', done: 'Objeto criado.' },
    { tool: 'reinforcement', label: 'MANDAR REFORÇO', ref: 'reinforcements', done: 'Reforço a caminho.' },
    { tool: 'chase', label: 'TESTAR PERSEGUIÇÃO', ref: 'chases', done: 'Perseguição iniciada.' },
    { tool: 'delivery', label: 'TESTAR ENTREGA', ref: 'deliveryGroups', done: 'Entrega sorteada.' },
];

// Resultados guardados fora do DOM: salvar antes do teste redesenha a seção no meio da chamada.
const history = [];

function drawResults() {
    const box = document.querySelector('.test-results');
    if (box) box.replaceChildren(...history.map((entry) => notice(entry.tone, entry.text)));
}

export function renderTest(host, ctx) {
    const { S, def } = ctx;
    const results = el('div', { class: 'test-results', 'aria-live': 'polite' });
    if (history.length && history[0].mission !== def.id) history.length = 0;

    const show = (tone, text) => {
        history.unshift({ tone, text, mission: def.id });
        history.length = Math.min(history.length, 4);
        drawResults();
    };

    /** Salva se preciso e roda a chamada; mostra o resultado na própria seção. */
    const run = async (btn, call, okText, needsSave = true) => {
        setBusy(btn, true);
        try {
            if (needsSave && !(await ctx.ensureSaved())) {
                show('warning', 'Teste não iniciado: salve a missão sem erros primeiro.');
                return;
            }
            const response = await call();
            if (response.ok) show('success', okText);
            else show('danger', codeText(response.code));
        } finally {
            setBusy(btn, false);
        }
    };

    const stepOptions = () => refItems(S, def, 'steps').map((item) => ({ value: item.id, label: item.label === item.id ? item.id : `${item.label} (${item.id})` }));

    // Missão inteira, a partir do passo, sandbox.
    const steps = stepOptions();
    let fromStep = steps[0]?.value;
    const stepSelect = valueSelect(steps.length ? steps : [{ value: undefined, label: 'Nenhum passo' }], fromStep, (value) => { fromStep = value; }, { 'aria-label': 'Passo inicial' });

    const fullBtn = button('TESTAR MISSÃO', () => run(fullBtn,
        () => fetchNui('editorTest', { id: def.id, mode: 'full' }), 'Teste iniciado. Você é o único participante.'), 'confirm');
    const stepBtn = button('TESTAR A PARTIR DO PASSO', () => run(stepBtn,
        () => fetchNui('editorTest', { id: def.id, mode: 'step', step: fromStep }), `Teste iniciado a partir de ${fromStep}.`), '', { disabled: !steps.length });
    const sandboxBtn = button('INICIAR SANDBOX', () => run(sandboxBtn,
        () => fetchNui('editorTest', { id: def.id, mode: 'sandbox' }), 'Sandbox iniciado: instância sem passos para usar as ferramentas.'));
    const resetBtn = button('ENCERRAR TESTE', () => run(resetBtn,
        () => fetchNui('editorTestTool', { id: def.id, tool: 'reset' }), 'Teste encerrado e entidades removidas.', false), 'danger');

    // Ferramentas: uma linha por ferramenta com o seletor da coleção dela.
    const toolRows = TOOLS.map((entry) => {
        const items = entry.ref === 'steps' ? stepOptions() : refItems(S, def, entry.ref).map((item) => ({ value: item.id, label: item.label === item.id ? item.id : `${item.label} (${item.id})` }));
        let ref = items[0]?.value;
        const select = valueSelect(items.length ? items : [{ value: undefined, label: 'Nada cadastrado' }], ref, (value) => { ref = value; }, { 'aria-label': entry.label });
        select.disabled = !items.length;
        const btn = button(entry.label, () => run(btn,
            () => fetchNui('editorTestTool', { id: def.id, tool: entry.tool, ref }), entry.done), '', { disabled: !items.length });
        const collection = entry.ref === 'steps' ? 'Passos' : S.collectionByKey.get(entry.ref)?.label || entry.ref;
        return el('div', 'tool-row', btn, select, el('span', { class: 'tool-help', text: collection }));
    });

    // Desenho de zonas/pontos no mundo: só liga e desliga, sem salvar.
    const debugInput = el('input', { type: 'checkbox', checked: state.debug });
    debugInput.addEventListener('change', async () => {
        const enabled = debugInput.checked;
        const response = await fetchNui('editorDebug', { enabled, id: def.id });
        if (!response.ok) {
            debugInput.checked = !enabled;
            show('danger', codeText(response.code));
            return;
        }
        state.debug = enabled;
    });

    host.append(el('div', { class: 'pane-scroll', dataset: { scroll: 'test' } },
        el('div', 'pane-pad',
            sectionHead('Teste', 'Testar salva o rascunho antes. Missão com erro não testa.'),
            results,
            el('div', 'block',
                el('h3', { class: 'block-title', text: 'Executar' }),
                el('div', 'test-grid',
                    fullBtn,
                    el('div', 'test-inline', stepBtn, stepSelect),
                    sandboxBtn,
                    resetBtn)),
            el('div', 'block',
                el('h3', { class: 'block-title', text: 'Ferramentas' }),
                el('p', { class: 'block-help', text: 'Agem no teste em andamento (missão ou sandbox).' }),
                el('div', 'tools', toolRows)),
            el('div', 'block',
                el('h3', { class: 'block-title', text: 'Visualização' }),
                el('label', 'toggle', debugInput, el('span', 'track'), el('span', { text: 'Desenhar zonas e pontos no mundo' }))))));
    drawResults();
}
