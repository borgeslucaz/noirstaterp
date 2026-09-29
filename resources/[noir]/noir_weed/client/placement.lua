---Posicionar o vaso pela mira. Não usa gizmo: no Enhanced o object_gizmo abre mas as
---alças não pegam o clique. Mesmo modo do editor do noir_garage — o fantasma segue o
---raycast da câmera, a roda gira, Enter confirma.

local Shared = require 'config.shared'

local Placement = {}

---@param model integer
---@return { x: number, y: number, z: number, w: number }? placement
function Placement.run(model)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then
        lib.print.error(('modelo indisponível: %s'):format(model))
        return nil
    end

    local start = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 1.5
    local ghost = CreateObject(model, start.x, start.y, start.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if ghost == 0 then return nil end

    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityAlpha(ghost, 180, false)

    local position = start
    local valid = false
    local heading = GetEntityHeading(cache.ped)
    local placing = true
    local result

    -- Mira em thread própria: o raycast do ox_lib espera um frame, e o laço abaixo
    -- precisa ler as teclas em todo frame.
    CreateThread(function()
        while placing do
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, Shared.placeRange + 4.0)
            if placing then
                valid = hit and #(coords - GetEntityCoords(cache.ped)) <= Shared.placeRange
                if valid then position = coords end
            end
        end
    end)

    lib.showTextUI(locale('place_help'))
    while placing do
        DisableControlAction(0, 14, true)  -- roda: arma seguinte
        DisableControlAction(0, 15, true)  -- roda: arma anterior
        DisableControlAction(0, 16, true)
        DisableControlAction(0, 17, true)
        DisableControlAction(0, 24, true)  -- ataque
        DisableControlAction(0, 25, true)  -- mirar
        DisableControlAction(0, 177, true) -- Backspace não abre o menu de pausa
        DisablePlayerFiring(cache.playerId, true)

        local step = IsControlPressed(0, 21) and 15.0 or 5.0 -- Shift
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then
            heading = (heading - step) % 360
        elseif IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then
            heading = (heading + step) % 360
        end

        SetEntityCoordsNoOffset(ghost, position.x, position.y, position.z, false, false, false)
        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, valid and 180 or 70, false)

        if valid and (IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201)) then -- Enter
            result = { x = position.x, y = position.y, z = position.z, w = heading }
            placing = false
        elseif IsDisabledControlJustReleased(0, 177) then -- Backspace
            placing = false
        end
        Wait(0)
    end
    lib.hideTextUI()

    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    return result
end

return Placement
