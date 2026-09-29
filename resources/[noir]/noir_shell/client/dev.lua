-- Development-only helpers for testing shell models and copying relative offsets.
-- Restricted via the `command` ace permission; not intended for gameplay use.
local testShell

RegisterCommand('testshell', function(_, args)
    local model = args[1]

    if not model then
        print('[noir_shell] usage: /testshell <model>')
        return
    end

    if testShell then
        testShell:Destroy()
        testShell = nil
    end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    local shell, err = Manager.Create({
        model = model,
        origin = vec4(pedCoords.x, pedCoords.y, pedCoords.z, GetEntityHeading(ped)),
    })

    if not shell then
        print(('[noir_shell] failed to create test shell: %s'):format(err))
        return
    end

    testShell = shell

    SetEntityCoords(ped, pedCoords.x, pedCoords.y, pedCoords.z + 1.0, false, false, false, false)

    print(('[noir_shell] test shell ready (entity %d) - use /testshell_exit to clean up'):format(shell:GetEntity()))
end, true)

RegisterCommand('testshell_exit', function()
    if not testShell then
        print('[noir_shell] no active test shell')
        return
    end

    testShell:Destroy()
    testShell = nil

    print('[noir_shell] test shell destroyed')
end, true)

RegisterCommand('shelloffset', function()
    if not testShell or not testShell:IsValid() then
        print('[noir_shell] no active test shell')
        return
    end

    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local shellEntity = testShell:GetEntity()

    local offset = GetOffsetFromEntityGivenWorldCoords(shellEntity, pedCoords.x, pedCoords.y, pedCoords.z)
    local text = ('vec3(%.3f, %.3f, %.3f)'):format(offset.x, offset.y, offset.z)

    print(('[noir_shell] offset: %s'):format(text))
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    testShell = nil
end)
