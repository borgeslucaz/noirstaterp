import React, { useMemo } from 'react'
import '@fontsource/big-shoulders-display/latin-800'

// Mesmo skyline do site (noirstate.com.br, /srv/noirsite): linhas dos prédios desenhadas em
// sequência e janelas acesas que piscam em tempos aleatórios.
const BUILDINGS = [
  'M5 472V405H40V285L88 258V332H138V472',
  'M117 332V142L188 181V392L222 397V472',
  'M208 395V120L220 113V90L245 76V3',
  'M245 76L270 62V214L317 266V472',
  'M262 220V472',
  'M307 472V160L388 210V472H415V310L470 277V375H508V472'
]

// [x, yTopo, largura, yBase] das colunas internas de cada prédio, iguais às do site.
const WINDOW_COLUMNS = [
  [52, 300, 26, 460], [130, 170, 44, 380], [224, 130, 30, 380], [278, 232, 26, 460],
  [322, 190, 52, 460], [428, 320, 30, 460]
]

const buildWindows = () => {
  const windows = []
  WINDOW_COLUMNS.forEach(([x, top, width, bottom]) => {
    for (let y = top; y < bottom; y += 22) {
      for (let cx = x; cx < x + width; cx += 13) {
        if (Math.random() > 0.28) continue
        windows.push({
          x: cx,
          y,
          period: (4 + Math.random() * 7).toFixed(2),
          delay: (1.8 + Math.random() * 6).toFixed(2)
        })
      }
    }
  })
  return windows
}

const NoirLogo = () => {
  // Sorteadas uma vez por abertura da tela, como no site a cada carregamento.
  const windows = useMemo(buildWindows, [])

  return (
    <div className='noir-logo' aria-label='Noir State' role='img'>
      <svg className='noir-logo__skyline' viewBox='0 0 520 480' aria-hidden='true'>
        <g className='noir-logo__lines'>
          {BUILDINGS.map((d) => <path key={d} pathLength='1' d={d} />)}
        </g>
        <g className='noir-logo__windows'>
          {windows.map((w) => (
            <rect key={`${w.x}-${w.y}`} x={w.x} y={w.y} width='6' height='9' style={{ '--t': `${w.period}s`, '--wd': `${w.delay}s` }} />
          ))}
        </g>
      </svg>
      <div className='noir-logo__title' aria-hidden='true'>
        <span>NOIR</span>
        <span>STATE</span>
      </div>
    </div>
  )
}

export default NoirLogo
