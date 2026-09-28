local p = nil

local function MiniGame()
    -- Uma partida por vez: uma segunda chamada com a primeira aberta perderia a promise.
    if p then return false end
    p = promise.new()
    SendNUIMessage({
        action = 'startGame',
    })
    SetNuiFocus(true, true)
    local result = Citizen.Await(p)
    return result
end

exports("MiniGame", MiniGame)

RegisterNUICallback('finish', function(data, cb)
    cb('ok')
    if not p then return end
    local current = p
    p = nil
    SendNUIMessage({
        action = 'closeUi',
    })
    SetNuiFocus(false, false)
    current:resolve(data.result == true)
end)
