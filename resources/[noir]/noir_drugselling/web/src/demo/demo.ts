import { debugData } from "../utils/debugData";
import { isEnvBrowser } from "../utils/misc";

// Preview no navegador (DESIGN_v4 §10): textos do locales/pt-br.lua, os saquinhos do
// noir_weed com as imagens do inventário (cópia em web/dev, fora do build) e o fundo de cena.
// Os botões do canto inferior esquerdo trocam quantas drogas diferentes o vendedor tem.
const img = (name: string) => `/dev/${name}.png`;

type G = [string, number];
const S = 1.5, A = 1.25, B = 1, C = 0.8;
const mult: Record<string, number> = { S, A, B, C };
const grades = (list: G[]) => list.map(([grade, amount]) => ({ grade, amount, multiplier: mult[grade] }));

// Catálogo do preview: as drogas do servidor, com preços do MainConfig e graus variados.
const CATALOG = [
  { spawn_name: "weed_skunk_baggy", label: "Saquinho de Skunk", amount: 18, normalPrice: 60, priceRangeMin: 48, priceRangeMax: 72, grades: grades([["S", 5], ["B", 10], ["C", 3]]) },
  { spawn_name: "weed_og-kush_baggy", label: "Saquinho de OG Kush", amount: 6, normalPrice: 43, priceRangeMin: 33, priceRangeMax: 53, grades: grades([["A", 6]]) },
  { spawn_name: "weed_purple-haze_baggy", label: "Saquinho de Purple Haze", amount: 3, normalPrice: 77, priceRangeMin: 61, priceRangeMax: 93, grades: [] },
  { spawn_name: "weed_white-widow_brick", label: "Tijolo de White Widow", amount: 1, normalPrice: 1005, priceRangeMin: 805, priceRangeMax: 1205, grades: [] },
  { spawn_name: "weed_ak47_baggy", label: "Saquinho de AK47", amount: 124, normalPrice: 43, priceRangeMin: 33, priceRangeMax: 53, grades: grades([["B", 100], ["C", 24]]) },
  { spawn_name: "weed_amnesia_baggy", label: "Saquinho de Amnesia", amount: 9, normalPrice: 60, priceRangeMin: 48, priceRangeMax: 72, grades: grades([["S", 9]]) },
  { spawn_name: "weed_white-widow_baggy", label: "Saquinho de White Widow", amount: 12, normalPrice: 77, priceRangeMin: 61, priceRangeMax: 93, grades: grades([["A", 7], ["B", 5]]) },
  { spawn_name: "meth", label: "Metanfetamina", amount: 7, normalPrice: 180, priceRangeMin: 150, priceRangeMax: 250, grades: [] },
  { spawn_name: "cokebaggy", label: "Pacote de cocaína", amount: 4, normalPrice: 580, priceRangeMin: 450, priceRangeMax: 700, grades: [] },
  { spawn_name: "weed_og-kush_brick", label: "Tijolo de OG Kush", amount: 2, normalPrice: 555, priceRangeMin: 435, priceRangeMax: 695, grades: [] },
  { spawn_name: "weed_ak47_brick", label: "Tijolo de AK47", amount: 1, normalPrice: 555, priceRangeMin: 435, priceRangeMax: 695, grades: [] },
  { spawn_name: "weed_skunk_brick", label: "Tijolo de Skunk", amount: 3, normalPrice: 780, priceRangeMin: 625, priceRangeMax: 935, grades: [] },
  { spawn_name: "weed_amnesia_brick", label: "Tijolo de Amnesia", amount: 1, normalPrice: 780, priceRangeMin: 625, priceRangeMax: 935, grades: [] },
  { spawn_name: "weed_purple-haze_brick", label: "Tijolo de Purple Haze", amount: 2, normalPrice: 1005, priceRangeMin: 805, priceRangeMax: 1205, grades: [] },
  { spawn_name: "crack_baggy", label: "Pedra de crack", amount: 15, normalPrice: 120, priceRangeMin: 90, priceRangeMax: 150, grades: [] },
].map((drug) => ({ ...drug, icon: img(drug.spawn_name) }));

export const PRESETS = [1, 2, 4, 5, 8, 15];

export function dealingFor(count: number) {
  return {
    pedType: "Dependente",
    pedBorder: "#8400ff",
    pedBg: "#8400ff8c",
    pedName: "Marcos Vinícius",
    playerLevel: 4,
    playerBoost: 6,
    playerDrugs: CATALOG.slice(0, count),
  };
}

debugData<any>([
  { action: "setLanguage", data: { locale: {
    "dealing_welcometext_1": "O que você tem para mim, parceiro?",
    "dealing_welcometext_2": "Tem alguma coisa que bate de verdade?",
    "dealing_welcometext_3": "Preciso de algo para agitar a noite.",
    "dealing_welcometext_4": "Cansei de produto ruim. Mostra o que você tem.",
    "dealing_welcometext_5": "E aí, tem algo que vale meu tempo?",
    "dealing_welcometext_6": "Ouvi dizer que você tem produto de primeira.",
    "dealing_welcometext_7": "Preciso de algo que dure a noite toda.",
    "dealing_welcometext_8": "Não perca meu tempo com coisa fraca.",
    "dealing_welcometext_9": "Tem alguma coisa forte hoje?",
    "dealing_welcometext_10": "Estou procurando algo fora do comum.",
    "dealing_welcometext_11": "Quero algo forte, nada de produto fraco.",
    "dealing_welcometext_12": "Disseram que você sempre traz coisa boa. Mostra aí.",
    "dealing_welcometext_13": "Tem alguma novidade? Cansei das mesmas coisas.",
    "dealing_welcometext_14": "Arruma alguma coisa diferente para hoje à noite.",
    "dealing_welcometext_15": "Qual é a coisa mais forte que você tem?",
    "dealing_welcometext_16": "Sem brincadeira, só pago pelo melhor.",
    "dealing_welcometext_17": "Preciso de algo rápido. O que você tem?",
    "dealing_welcometext_18": "Quero produto de verdade, sem mistura.",
    "dealing_welcometext_19": "Mostra por que todo mundo fala de você.",
    "dealing_welcometext_20": "Se não for bom, não vou comprar.",
    "dealing_answertext_1": "Que tal este aqui?",
    "dealing_answertext_2": "Está brincando? Eu tenho produto bom.",
    "dealing_answertext_3": "Isto vai deixar sua festa inesquecível.",
    "dealing_answertext_4": "Relaxa, eu só vendo produto de qualidade.",
    "dealing_answertext_5": "Este aqui vai te derrubar.",
    "dealing_answertext_6": "Direto da melhor fonte, qualidade pura.",
    "dealing_answertext_7": "Confia em mim. Depois de provar, você vai voltar.",
    "dealing_answertext_8": "Forte, suave e sem arrependimento.",
    "dealing_answertext_9": "Tenho o pacote perfeito para noites longas.",
    "dealing_answertext_10": "Não é barato, mas é o melhor que você vai encontrar.",
    "dealing_answertext_11": "Tenho uma novidade. Produto de primeira.",
    "dealing_answertext_12": "Você vai sentir o efeito antes de chegar em casa.",
    "dealing_answertext_13": "Já tem gente fazendo fila por este pacote.",
    "dealing_answertext_14": "Forte, limpo e com efeito garantido.",
    "dealing_answertext_15": "Eu não venderia se não confiasse no produto.",
    "dealing_answertext_16": "Depois de experimentar, você esquece o resto.",
    "dealing_answertext_17": "É caro, mas vale cada centavo.",
    "dealing_answertext_18": "Tenho uma mistura que vai te manter acordado a noite toda.",
    "dealing_answertext_19": "Equilíbrio perfeito: nem forte, nem fraco demais.",
    "dealing_answertext_20": "Produto puro, sem enchimento e sem conversa.",
    "dealing_nvw": "Deixa para lá",
    "hereyougo": "Fechar negócio",
    "pricepergram": "Preço por unidade:",
    "loyality": "Seu nível de vendedor é %a | Bônus de %b% por transação."
  } } },
  { action: "setCurrency", data: { currency: "USD", style: "currency", format: "en-US" } },
  { action: "setDrugDealingData", data: dealingFor(4) },
], 100);

if (import.meta.env.MODE === "development" && isEnvBrowser()) {
  document.documentElement.style.setProperty("background", "#111 url('/dev/sinner.png') center / cover no-repeat", "important");
}
