---Posicionar por mira, o mesmo modo do noir_garage: uma entidade de teste segue o chão
---para onde a câmera aponta, a roda do mouse gira (Shift = mais rápido), Enter confirma e
---Backspace cancela. Sem gizmo: no Enhanced o object_gizmo desenha as alças mas não pega
---o clique.
---
---Serve para o atendente da Central e as vagas onde o táxi alugado nasce (cópia do noir_busjob).

Placement = {}

local KIND = {
    ped = { isModel = IsModelAPed, reach = 25.0 },
    vehicle = { isModel = IsModelAVehicle, reach = 40.0 },
    object = { isModel = function(model) return not IsModelAPed(model) and not IsModelAVehicle(model) end, reach = 25.0 },
}

---Model conferido antes de qualquer request: model que não existe derruba o cliente no
---Enhanced.
---@param name string
---@param kind 'ped'|'vehicle'|'object'
---@return integer? model
function Placement.loadModel(name, kind)
    local model = joaat(name)
    if not IsModelInCdimage(model) or not KIND[kind].isModel(model) then return nil end
    if not pcall(lib.requestModel, model, 5000) then return nil end
    return model
end

local function createEntity(kind, model, start)
    if kind == 'ped' then
        return CreatePed(4, model, start.x, start.y, start.z - 1.0, start.w, false, false), 1.0
    elseif kind == 'vehicle' then
        local min = GetModelDimensions(model)
        return CreateVehicle(model, start.x, start.y, start.z, start.w, false, false), -min.z
    end
    return CreateObject(model, start.x, start.y, start.z, false, false, false), 0.0
end

local function destroy(kind, entity)
    if not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    if kind == 'object' then DeleteObject(entity) else DeleteEntity(entity) end
end

---Abre o modo de posicionar e devolve onde o admin confirmou, ou nil se cancelou.
---@param kind 'ped'|'vehicle'|'object'
---@param modelName string
---@param current? { x: number, y: number, z: number, w: number } posição salva, para partir dela
---@return { x: number, y: number, z: number, w: number }?
function Placement.run(kind, modelName, current)
    local model = Placement.loadModel(modelName, kind)
    if not model then
        Integrations.notify(('Modelo %s não existe neste build.'):format(modelName), 'error')
        return nil
    end

    local start = current
    if not start then
        local ahead = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * (kind == 'vehicle' and 6.0 or 1.5)
        local heading = GetEntityHeading(cache.ped)
        start = { x = ahead.x, y = ahead.y, z = ahead.z, w = kind == 'ped' and (heading + 180.0) % 360 or heading }
    end

    local entity, lift = createEntity(kind, model, start)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 then return nil end

    SetEntityInvincible(entity, true)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)
    SetEntityAlpha(entity, 200, false)
    if kind == 'ped' then SetBlockingOfNonTemporaryEvents(entity, true) end
    if kind == 'vehicle' then SetVehicleDoorsLocked(entity, 2) end

    local position = vec3(start.x, start.y, start.z)
    local heading = start.w or 0.0
    local placing, result = true, nil

    -- Mira em thread própria: o raycast do ox_lib espera um frame, e o laço abaixo precisa
    -- ler as teclas em todo frame para não perder o Enter nem a roda do mouse.
    CreateThread(function()
        while placing do
            local hit, _, coords = lib.raycast.fromCamera(1 | 16, 4, KIND[kind].reach)
            if hit and placing then position = vec3(coords.x, coords.y, coords.z + lift) end
        end
    end)

    Integrations.showKeys({
        { key = 'Mira', label = 'Posição' },
        { key = 'Roda', label = 'Girar' },
        { key = 'Enter', label = 'Confirmar' },
        { key = 'Backspace', label = 'Cancelar' },
    })
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

        SetEntityCoordsNoOffset(entity, position.x, position.y, position.z, false, false, false)
        SetEntityHeading(entity, heading)

        if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then -- Enter
            -- Do NPC fica a altura do corpo (~1 m do chão); quem cria usa z - 1, como aqui.
            local c = GetEntityCoords(entity)
            result = { x = c.x, y = c.y, z = c.z, w = heading }
            placing = false
        elseif IsDisabledControlJustReleased(0, 177) then -- Backspace
            placing = false
        end
        Wait(0)
    end

    Integrations.hideKeys()
    destroy(kind, entity)
    return result
end

