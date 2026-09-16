-- Ponte para o sistema territorial.
--
-- É tudo o que este resource sabe sobre território: uma tag nasceu, uma tag morreu, e a lista
-- inteira quando um dos dois lados sobe. Raio da área, formato e regra de disputa são do
-- noir_territories.
--
-- Por isso o aviso não carrega raio. A tentação é mandar `radius = 25.0` junto, e aí o
-- alcance do domínio passa a ser decisão de quem picha — no dia em que o modelo virar
-- influência progressiva ou polígono, seria este arquivo a mudar também. O que sai daqui é só
-- o fato: existe uma tag desta gang nesta coordenada.

NoirTerritories = {}

local RESOURCE = 'noir_territories'

local function call(method, ...)
    if GetResourceState(RESOURCE) ~= 'started' then return end

    local args = table.pack(...)
    local ok, err = pcall(function()
        return exports[RESOURCE][method](exports[RESOURCE], table.unpack(args, 1, args.n))
    end)

    if not ok then
        print(('[noir_graffiti] falha ao avisar o %s em %s: %s'):format(RESOURCE, method, err))
    end
end

local function claimOf(graffiti)
    return {
        id = graffiti.id,
        type = 'graffiti',
        gang = graffiti.gang,
        coords = graffiti.coords,
    }
end

---Tag sem gang não reivindica nada, e nem chega a ser anunciada.
function NoirTerritories.Register(graffiti)
    if type(graffiti) ~= 'table' or not graffiti.gang then return end
    call('registerClaim', claimOf(graffiti))
end

function NoirTerritories.Remove(id)
    if not id then return end
    call('removeClaim', 'graffiti', id)
end

---As áreas não têm tabela própria no banco: elas são reconstruídas a partir dos graffitis que
---existem. Esta é a reconstrução.
function NoirTerritories.PushAll()
    local list = {}
    for _, graffiti in pairs(NoirStore.active) do
        if graffiti.gang then list[#list + 1] = claimOf(graffiti) end
    end
    call('setClaims', 'graffiti', list)
end

CreateThread(function()
    while not NoirStore.ready do Wait(50) end
    NoirTerritories.PushAll()
end)

---O outro lado pode subir depois deste, ou reiniciar no meio do expediente: nos dois casos o
---registro dele nasce vazio, e quem tem os dados somos nós.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    CreateThread(function()
        Wait(500)
        NoirTerritories.PushAll()
    end)
end)
