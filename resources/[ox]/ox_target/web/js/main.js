import { createOptions } from "./createOptions.js";

const optionsWrapper = document.getElementById("options-wrapper");
const group = document.getElementById("target-group");
const body = document.body;
const eye = document.getElementById("eyeSvg");
const key = document.getElementById("target-key");

// Opcao destacada: o scroll move, o E (ou clique) confirma. Sem cursor.
let items = [];
let active = 0;

function setActive(index) {
  if (!items.length) return;

  active = (index + items.length) % items.length;
  items.forEach((el, i) => el.classList.toggle("is-active", i === active));
  // A tecla E desce ate a opcao ativa; a lista fica parada.
  key.style.transform = `translateY(${items[active].offsetTop}px)`;
}

function clearOptions() {
  optionsWrapper.innerHTML = "";
  items = [];
  active = 0;
  body.classList.remove("has-target");
}

window.addEventListener("message", (event) => {
  switch (event.data.event) {
    case "visible": {
      clearOptions();
      body.style.visibility = event.data.state ? "visible" : "hidden";
      return eye.classList.remove("eye-hover");
    }

    case "leftTarget": {
      clearOptions();
      return eye.classList.remove("eye-hover");
    }

    case "setTarget": {
      clearOptions();
      eye.classList.add("eye-hover");

      if (event.data.options) {
        for (const type in event.data.options) {
          event.data.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
      }

      if (event.data.zones) {
        for (let i = 0; i < event.data.zones.length; i++) {
          event.data.zones[i].forEach((data, id) => {
            createOptions("zones", data, id + 1, i + 1);
          });
        }
      }

      items = Array.from(optionsWrapper.children);
      body.classList.toggle("has-target", items.length > 0);
      return setActive(0);
    }

    case "scroll": {
      return setActive(active + event.data.dir);
    }

    case "confirm": {
      return items[active]?.click();
    }

    // Posicao do alvo na tela (0..1); fora da tela esconde o grupo.
    case "position": {
      if (!event.data.visible) return group.classList.add("is-offscreen");

      group.classList.remove("is-offscreen");
      group.style.left = `${event.data.x * 100}%`;
      group.style.top = `${event.data.y * 100}%`;
      return;
    }
  }
});
