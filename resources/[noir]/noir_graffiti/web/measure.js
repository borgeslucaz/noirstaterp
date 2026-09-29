// Medição da tinta, e não da caixa de layout.
//
// offsetWidth/offsetHeight devolvem a caixa da linha: largura de avanço por line-height.
// Fonte de graffiti pinta fora disso o tempo todo — pingo descendo abaixo da descendente,
// swash passando da largura, contorno estourando para os lados. Escalar o texto para a
// caixa de layout encher a textura corta exatamente esse excesso.
//
// As métricas actualBoundingBox* do canvas dão os limites reais da tinta. Daqui sai quanto
// ela passa da caixa de layout em cada lado, para quem chama somar antes de escalar.
//
// Usado pelo renderer (web/scene.html) e pelo preview (web/ui.html), para os dois medirem
// exatamente igual.
window.NoirMeasure = (function () {
  const gauge = document.createElement('canvas').getContext('2d');

  function inkOverflow(lines, family, size, lineHeight, layoutWidth, layoutHeight) {
    if (!lines.length) return { left: 0, right: 0, top: 0, bottom: 0 };

    // Centrado, igual ao CSS: assim as medidas saem a partir do meio de cada linha.
    gauge.textAlign = 'center';
    gauge.textBaseline = 'alphabetic';
    gauge.font = `${size}px "${family}", Arial, sans-serif`;

    const probe = gauge.measureText('M');
    const fontAscent = probe.fontBoundingBoxAscent;
    const fontDescent = probe.fontBoundingBoxDescent;
    // O CSS distribui a sobra do line-height igualmente acima e abaixo da fonte; é isso
    // que posiciona a primeira linha de base dentro da caixa.
    const halfLeading = (lineHeight - (fontAscent + fontDescent)) / 2;

    let left = 0, right = 0, top = Infinity, bottom = -Infinity;
    lines.forEach((line, index) => {
      const metrics = gauge.measureText(line || ' ');
      left = Math.max(left, metrics.actualBoundingBoxLeft);
      right = Math.max(right, metrics.actualBoundingBoxRight);
      const baseline = halfLeading + fontAscent + index * lineHeight;
      top = Math.min(top, baseline - metrics.actualBoundingBoxAscent);
      bottom = Math.max(bottom, baseline + metrics.actualBoundingBoxDescent);
    });

    return {
      left: Math.max(0, left - layoutWidth / 2),
      right: Math.max(0, right - layoutWidth / 2),
      top: Math.max(0, -top),
      bottom: Math.max(0, bottom - layoutHeight),
    };
  }

  return { inkOverflow };
})();
