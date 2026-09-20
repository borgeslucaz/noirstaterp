---Vocabulário do resource: nomes que client e servidor precisam enxergar igual.
---Nada aqui é ajuste de gameplay — isso mora em `config/`.

local RESOURCE = 'noir_prettycrimes'

local Constants = {}

Constants.resource = RESOURCE

---Crimes que o container sabe carregar de verdade (têm módulo em client/crimes e
---server/crimes). Funciona como allowlist: uma chave em `Config.crimes` que não
---esteja aqui é erro de digitação, e o boot avisa em vez de ignorar em silêncio.
Constants.crimes = {
    smashgrab = 'smashgrab',
    parkingmeter = 'parkingmeter',
}

---Crimes previstos no roadmap, ainda sem módulo. Existem só para o boot dar uma
---mensagem melhor que "crime desconhecido" quando alguém liga um deles cedo demais.
Constants.plannedCrimes = {
    vendingmachine = true,
    atm = true,
    streetrobbery = true,
    cardoor = true,
}

---Monta um nome de evento dentro do namespace do resource.
---Todo evento sai como `noir_prettycrimes:<side>:<crime>:<action>`; não existe
---evento genérico, e é isso que impede um crime de escutar o evento do outro.
---@param side 'client'|'server'
---@param crime string
---@param action string
---@return string
function Constants.event(side, crime, action)
    return ('%s:%s:%s:%s'):format(RESOURCE, side, crime, action)
end

---Chaves de state bag usadas em entidades.
---
---São a forma de dois jogadores enxergarem o mesmo estado sem o servidor varrer
---nada: quem escreve é sempre o servidor, com replicação ligada, e o client só lê.
---Nada de identidade do jogador entra aqui — state bag de entidade é público para
---todo mundo que estiver com a entidade carregada.
Constants.state = {
    -- Smash & grab, na entidade do veículo. `nil` = objeto disponível (ou o carro
    -- nunca teve nenhum); `{ status = 'reserved' }` = alguém está pegando agora;
    -- `{ status = 'claimed' }` = já levaram, e todo client apaga o prop.
    --
    -- Repare no que NÃO está no payload: quem reservou. Essa informação fica na
    -- tabela do servidor, porque state bag de entidade é pública.
    smashGrab = 'noirSmashGrab',

    -- Parquímetro não aparece aqui, e a ausência é a parte interessante: ele é
    -- prop de MAPA. Não existe entidade para pendurar state bag — nem no
    -- servidor, nem com um handle que sobreviva ao streaming. O estado de
    -- "este já foi esvaziado" viaja como evento, com a coordenada em grade
    -- servindo de identidade. Veja `shared/parkingmeter_rules.lua`.
}

return Constants
