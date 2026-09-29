-- Throwaway test script: consumes noir_shell to spawn the lev-apartments
-- shell, and ox_target for the world entrance/interior exit interactions.
--
-- noir_shell's exported API is id-based (not the shell:Method() OOP form)
-- because FiveM exports serialize their return values, which strips
-- metatables from any object returned across the resource boundary.

-- real-world apartment door, where the ox_target enter zone lives
local ENTRANCE = vec4(-197.21, -831.62, 30.75, 116.81)

-- shell instance placed well below the map so it never collides with anything
local ORIGIN = vec4(120.83, -1128.245, -101.233, 335.0)
local MODEL = `lev_apartment_shell`

-- absolute world position of the interior door (measured in-game); the
-- player is teleported here both when entering and when standing at the
-- exit target, since it's the same doorway
local EXIT_POS = vec3(119.4, -1130.32, -99.84)
local ENTER_HEADING = 270.76

local shellId
local exitZone

local function destroyShell()
    if exitZone then
        exports.ox_target:removeZone(exitZone)
        exitZone = nil
    end

    if shellId then
        exports.noir_shell:Destroy(shellId)
        shellId = nil
    end
end

local function addExitZone()
    if exitZone then
        exports.ox_target:removeZone(exitZone)
        exitZone = nil
    end

    exitZone = exports.ox_target:addSphereZone({
        coords = EXIT_POS,
        radius = 0.6,
        debug = false,
        options = {{
            name = 'noir_shell_test_exit',
            icon = 'fa-solid fa-right-from-bracket',
            label = 'Sair do apartamento',
            distance = 2.0,
            onSelect = function()
                local ped = PlayerPedId()

                SetEntityCoords(ped, ENTRANCE.x, ENTRANCE.y, ENTRANCE.z, false, false, false, false)
                SetEntityHeading(ped, ENTRANCE.w)

                TriggerServerEvent('noir_shell_test:exit')

                destroyShell()
            end,
        }},
    })
end

exports.ox_target:addSphereZone({
    coords = vec3(ENTRANCE.x, ENTRANCE.y, ENTRANCE.z),
    radius = 0.8,
    debug = false,
    options = {{
        name = 'noir_shell_test_enter',
        icon = 'fa-solid fa-door-open',
        label = 'Entrar no apartamento (teste)',
        distance = 2.0,
        onSelect = function()
            if not shellId or not exports.noir_shell:IsValid(shellId) then
                local id, err = exports.noir_shell:Create({
                    model = MODEL,
                    origin = ORIGIN,
                })

                if not id then
                    lib.notify({ description = ('Failed to create shell: %s'):format(err), type = 'error' })
                    return
                end

                shellId = id
                addExitZone()
            end

            local ped = PlayerPedId()

            TriggerServerEvent('noir_shell_test:enter')

            SetEntityCoords(ped, EXIT_POS.x, EXIT_POS.y, EXIT_POS.z, false, false, false, false)
            SetEntityHeading(ped, ENTER_HEADING)
        end,
    }},
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if shellId then
        TriggerServerEvent('noir_shell_test:exit')
    end

    destroyShell()
end)
