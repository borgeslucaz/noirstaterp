// Preview no navegador (DESIGN_v4 10): monta o web/index.html real e faz o papel do Lua.
// Fica fora de web/, entao nao entra no resource (fxmanifest empacota so web/**).

window.GetParentResourceName = () => "ox_target";

const post = (data) => window.postMessage(data, "*");
const goBack = { name: "builtin:goback", icon: "fa-solid fa-circle-chevron-left", label: "Voltar", openMenu: "home" };

const scenarios = {
  lojista: {
    label: "Lojista (varias opcoes)",
    pos: [0.44, 0.47],
    home: [
      { label: "Ver catalogo de produtos", icon: "fa-solid fa-cart-shopping" },
      { label: "Operacoes do mercado", icon: "fa-solid fa-briefcase", openMenu: "market" },
      { label: "Conversar", icon: "fa-solid fa-comments" },
      { label: "Pedir emprego", icon: "fa-solid fa-id-badge" },
      { label: "Comprar no balcao noturno", icon: "fa-solid fa-moon" },
    ],
    market: [
      { label: "Verificar estoque", icon: "fa-solid fa-boxes-stacked" },
      { label: "Pedir reposicao", icon: "fa-solid fa-truck-ramp-box" },
      { label: "Fechar o caixa", icon: "fa-solid fa-cash-register" },
    ],
  },
  truck: {
    label: "Uma opcao (truckjob)",
    pos: [0.5, 0.42],
    home: [{ label: "Pressione E para abrir o menu", icon: "fas fa-gears" }],
  },
  longo: {
    label: "Texto longo",
    pos: [0.3, 0.55],
    home: [
      { label: "Verificar placa do veiculo roubado na central de policia", icon: "fa-solid fa-magnifying-glass" },
      { label: "Guardar", icon: "fa-solid fa-warehouse", iconColor: "#39df45" },
      { label: "Abrir porta-malas", icon: "fa-solid fa-car-rear" },
    ],
  },
  borda: {
    label: "Perto da borda",
    pos: [0.86, 0.5],
    home: [
      { label: "Abrir porta do motorista", icon: "fa-solid fa-car-side" },
      { label: "Abrir capo", icon: "fa-solid fa-car" },
    ],
  },
};

let current = "lojista";
let menu = "home";

function sendTarget() {
  const sc = scenarios[current];
  const list = menu === "home" ? sc.home : [goBack, ...sc[menu]];
  post({ event: "setTarget", options: { __global: list }, zones: [] });
  post({ event: "position", visible: true, x: sc.pos[0], y: sc.pos[1] });
}

function show(key) {
  current = key;
  menu = "home";
  post({ event: "visible", state: true });
  if (key === "vazio") return post({ event: "leftTarget" });
  if (key === "fora") {
    sendTarget();
    return post({ event: "position", visible: false });
  }
  sendTarget();
}

function toast(text) {
  const el = document.getElementById("dev-toast");
  el.textContent = text;
  el.classList.add("show");
  clearTimeout(toast.t);
  toast.t = setTimeout(() => el.classList.remove("show"), 1400);
}

// Mesmo contrato do RegisterNUICallback('select') do client/main.lua.
const realFetch = window.fetch.bind(window);
window.fetch = async (url, init) => {
  if (typeof url !== "string" || !url.startsWith("https://ox_target/")) return realFetch(url, init);

  const [, id] = JSON.parse(init.body);
  const sc = scenarios[current];
  const list = menu === "home" ? sc.home : [goBack, ...sc[menu]];
  const option = list[id - 1];

  if (option?.openMenu) {
    menu = option.openMenu === "home" ? "home" : option.openMenu;
    sendTarget();
  } else if (option) {
    toast(`Escolhido: ${option.label}`);
    // No jogo a acao fecha o target ate o proximo ALT.
    post({ event: "visible", state: false });
    setTimeout(() => show(current), 900);
  }
  return new Response("1");
};

// Controles: roda = scroll; E ou clique na cena = confirmar.
window.addEventListener("wheel", (e) => post({ event: "scroll", dir: e.deltaY > 0 ? 1 : -1 }), { passive: true });
window.addEventListener("keydown", (e) => { if (e.key === "e" || e.key === "E") post({ event: "confirm" }); });
// So clique real: o .click() que o confirm dispara na opcao tambem sobe ate aqui.
window.addEventListener("click", (e) => { if (e.isTrusted && !e.target.closest("#dev")) post({ event: "confirm" }); });

async function boot() {
  // Usa o markup real da NUI em vez de uma copia.
  const html = await (await realFetch("/web/index.html")).text();
  const doc = new DOMParser().parseFromString(html, "text/html");
  doc.querySelectorAll("script").forEach((s) => s.remove());
  document.body.insertAdjacentHTML("afterbegin", doc.body.innerHTML);
  await import("/web/js/main.js");

  const panel = document.getElementById("dev");
  const buttons = { ...Object.fromEntries(Object.entries(scenarios).map(([k, v]) => [k, v.label])), fora: "Alvo fora da tela", vazio: "Sem alvo (so o olho)" };
  for (const [key, label] of Object.entries(buttons)) {
    const b = document.createElement("button");
    b.textContent = label;
    b.onclick = () => {
      panel.querySelectorAll("button").forEach((x) => x.classList.toggle("is-on", x === b));
      show(key);
    };
    panel.appendChild(b);
  }
  panel.firstChild.click();
}

boot();
