---Config pública (vai para o cliente). Catálogo e economia moram no banco e chegam pelo
---servidor; aqui só o que é da tela e do desenho do editor.
return {
    ---Raio do círculo onde os passageiros nascem numa parada ainda sem área desenhada.
    fallbackSpawnRadius = 2.0,

    editor = {
        ---Até onde o editor desenha paradas e áreas em volta do admin (m).
        drawDistance = 150.0,
        ---Área nova: largura e altura iniciais (m); a roda do mouse ajusta a largura.
        zoneWidth = 3.0,
        zoneHeight = 3.0,
        ---Alcance da mira ao desenhar a área (m).
        reach = 40.0,
    },
}
