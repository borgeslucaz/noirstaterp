# noir_elevator

Elevador sem teleporte à vista. O jogador chama o elevador pelo `ox_target` e escolhe o
andar no painel. Depois ele entra até o centro da cabine e vira para a porta, a porta fecha (som) e
a câmera trava nos olhos dele, presa na porta, tremendo de leve, com o contador `▲ Andar 5` no alto. No meio
do caminho ele troca de andar numa piscada curta, quando o destino é a mesma porta no mesmo
enquadramento. A porta abre (som) e o controle volta.

Só client, sem servidor: é deslocamento do próprio jogador, sem regra nem recompensa.

## Novo elevador

Uma entrada em `config/client.lua → elevators`:

```lua
meu_predio = {
    label = 'Meu Prédio',
    secondsPerFloor = 0.9,   -- tempo por andar
    minSeconds = 3.0,        -- viagem mínima
    waitInterior = true,     -- destino é MLO/IPL: espera o interior antes de soltar
    -- botão em relação ao centro da cabine, olhando a porta; girado com o w de cada parada
    button = { forward = 1.42, right = 0.98, up = 0.17, size = 0.25 },
    stops = {
        { label = 'Térreo', level = 0, coords = vec4(x, y, z, wDeFrenteParaPorta) },
        { label = 'Andar 1', level = 1, coords = vec4(x, y, z, wDeFrenteParaPorta) },
    },
},
```

- `coords` é o centro da cabine, onde o jogador viaja, e o `w` é de frente para a porta.
- O alvo é uma caixa no botão. Uma parada com `target = vec3(...)` usa o botão medido; as
  outras calculam pelo `button`. `debugTargets` no config desenha as caixas para conferir.
- `level` é o andar físico. O contador passa por todos os andares entre a origem e o destino
  e mostra o `label` do stop com aquele `level`.
- A troca de andar só fica invisível se todas as paradas tiverem a mesma porta no mesmo
  enquadramento. No Wiwang, o lobby é outra porta, então só nele a piscada aparece.

## Wiwang Hotel

O `elevators.lua` do `map_wiwang_hotel_enh` (menu com teleporte e fade) saiu. O `ipl.lua`
do mapa continua trocando o IPL do andar por zona, e a viagem espera esse interior ficar
pronto (`loadTimeoutMs`) antes de soltar o jogador.
