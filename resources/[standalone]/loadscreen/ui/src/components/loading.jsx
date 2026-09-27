import React, { useState, useEffect, useRef, useMemo } from "react";

// Mesmo skyline do hero de noirstate.com.br
const SKYLINE_PATHS = [
  "M5 472V405H40V285L88 258V332H138V472",
  "M117 332V142L188 181V392L222 397V472",
  "M208 395V120L220 113V90L245 76V3",
  "M245 76L270 62V214L317 266V472",
  "M262 220V472",
  "M307 472V160L388 210V472H415V310L470 277V375H508V472",
];

// [x, yTopo, largura, yBase] das colunas internas de cada prédio
const SKYLINE_COLS = [
  [52, 300, 26, 460], [130, 170, 44, 380], [224, 130, 30, 380], [278, 232, 26, 460],
  [322, 190, 52, 460], [428, 320, 30, 460],
];

const CITY_W = 1600;
const CITY_H = 520;
const CITY_DENSITY = 0.55;

function skylineWindows() {
  const list = [];
  SKYLINE_COLS.forEach(([x, y0, w, y1]) => {
    for (let y = y0; y < y1; y += 22) {
      for (let cx = x; cx < x + w; cx += 13) {
        if (Math.random() > 0.28) continue;
        list.push({
          x: cx,
          y,
          t: (4 + Math.random() * 7).toFixed(2) + "s",
          wd: (1.8 + Math.random() * 6).toFixed(2) + "s",
        });
      }
    }
  });
  return list;
}

function cityShapes() {
  const shapes = [];
  [["far", 0.45, 0.95], ["", 0.3, 0.7]].forEach(([layer, minH, maxH]) => {
    let x = -20;
    while (x < CITY_W) {
      const w = 40 + Math.random() * 90;
      // prédios mais baixos no centro, para não disputar com o título
      const center = 1 - Math.exp(-(((x + w / 2 - CITY_W / 2) / (CITY_W * 0.28)) ** 2)) * 0.55;
      const h = CITY_H * (minH + Math.random() * (maxH - minH)) * center;
      const y = CITY_H - h;
      shapes.push({ x, y, width: w, height: h, cls: "b " + layer });
      if (Math.random() < 0.25) {
        shapes.push({ x: x + w / 2 - 1, y: y - 30, width: 2, height: 30, cls: "b " + layer });
      }
      if (!layer) {
        for (let wy = y + 14; wy < CITY_H - 10; wy += 16) {
          for (let wx = x + 8; wx < x + w - 10; wx += 12) {
            if (Math.random() > 0.1 * CITY_DENSITY) continue;
            shapes.push({
              x: wx,
              y: wy,
              width: 4,
              height: 6,
              cls: "w" + (Math.random() < 0.18 ? " lamp" : "") + (Math.random() < 0.3 ? " blink" : ""),
              t: (5 + Math.random() * 9).toFixed(1) + "s",
              wd: (Math.random() * 8).toFixed(1) + "s",
            });
          }
        }
      }
      x += w + (layer ? -10 : 4 + Math.random() * 10);
    }
  });
  return shapes;
}

function Loading() {
  const [progress, setProgress] = useState(0);
  // segue o <audio>: se o autoplay for bloqueado, o botão já nasce em "Tocar"
  const [playing, setPlaying] = useState(false);
  const audio = useRef();
  const windows = useMemo(skylineWindows, []);
  const city = useMemo(cityShapes, []);

  const toggleMusic = () => {
    if (audio.current.paused) {
      audio.current.play().catch(() => {});
    } else {
      audio.current.pause();
    }
  };

  // Progresso real: o FiveM manda loadProgress (loadFraction de 0 a 1) para o loadscreen
  useEffect(() => {
    const onMessage = (e) => {
      if (e.data?.eventName !== "loadProgress") return;
      const pct = Math.min(Math.max(e.data.loadFraction * 100, 0), 100);
      setProgress((prev) => Math.max(prev, pct));
    };
    window.addEventListener("message", onMessage);
    return () => window.removeEventListener("message", onMessage);
  }, []);

  // No navegador (vite dev) não há FiveM mandando progresso; simula para dar para ver a barra
  useEffect(() => {
    if (!import.meta.env.DEV || window.invokeNative) return;
    const t = setInterval(() => setProgress((prev) => Math.min(prev + 0.3, 100)), 100);
    return () => clearInterval(t);
  }, []);

  return (
    <div className="loading-wrapper">
      <audio
        ref={audio}
        autoPlay
        loop
        onPlay={() => setPlaying(true)}
        onPause={() => setPlaying(false)}
      >
        <source src="../song/soundsurfer-boom-bap-592994.mp3" />
      </audio>

      <div className="grain" aria-hidden="true"></div>

      <div className="hero__bg" aria-hidden="true">
        <svg className="city" viewBox={`0 0 ${CITY_W} ${CITY_H}`} preserveAspectRatio="xMidYMax slice">
          {city.map((s, i) => (
            <rect
              key={i}
              x={s.x}
              y={s.y}
              width={s.width}
              height={s.height}
              className={s.cls}
              style={s.t ? { "--t": s.t, "--wd": s.wd } : undefined}
            />
          ))}
        </svg>
      </div>
      <div className="hero__rain" aria-hidden="true"></div>

      <div className="hero__inner">
        <svg className="skyline" viewBox="0 0 520 480" role="img" aria-label="Skyline Noir State">
          <g className="skyline__lines">
            {SKYLINE_PATHS.map((d) => (
              <path key={d} pathLength="1" d={d} />
            ))}
          </g>
          <g className="skyline__windows">
            {windows.map((w, i) => (
              <rect
                key={i}
                x={w.x}
                y={w.y}
                width="6"
                height="9"
                className="on"
                style={{ "--t": w.t, "--wd": w.wd }}
              />
            ))}
          </g>
        </svg>

        <h1 className="hero__title">
          <span className="reveal-load" style={{ "--d": "1.6s" }}>NOIR</span>
          <span className="reveal-load" style={{ "--d": "1.75s" }}>STATE</span>
        </h1>
      </div>

      <div className="footer reveal-load" style={{ "--d": "2.2s" }}>
        <div className="footer__row">
          <span className="eyebrow">
            <span className="dot pulse"></span> Carregando
          </span>
          <span className="eyebrow footer__pct">{Math.floor(progress)}%</span>
        </div>
        <div className="bar">
          <div className="bar__value" style={{ width: progress + "%" }}></div>
        </div>
        <button className="eyebrow audio" onClick={toggleMusic}>
          {playing ? "Pausar música" : "Tocar música"}
        </button>
      </div>
    </div>
  );
}

export default Loading;
