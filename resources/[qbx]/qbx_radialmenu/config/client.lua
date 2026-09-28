local bags = {[40] = true, [41] = true, [44] = true, [45] = true}

return {
    enableExtraMenu = true,
    flipTime = 15000,

    menuItems = {
        {
            id = 'citizen',
            icon = 'user',
            label = 'Cidadão',
            items = {
                {
                    id = 'givenum',
                    icon = 'address-book',
                    label = 'Passar contato',
                    event = 'qb-phone:client:GiveContactDetails'
                },
                {
                    id = 'skills',
                    icon = 'chart-line',
                    label = 'Habilidades',
                    -- Export em vez do /skills: o comando recusa com NUI em foco, e o radial
                    -- ainda está soltando o foco no frame do clique.
                    onSelect = function() exports.noir_skills:Open() end,
                },
                {
                    id = 'getintrunk',
                    icon = 'car',
                    label = 'Entrar no porta-malas',
                    event = 'qb-trunk:client:GetIn'
                },
                {
                    id = 'cornerselling',
                    icon = 'cannabis',
                    label = 'Vender na esquina',
                    event = 'qb-drugs:client:cornerselling'
                },
                {
                    id = 'interactions',
                    icon = 'exclamation-triangle',
                    label = 'Interação',
                    items = {
                        {
                            id = 'handcuff',
                            icon = 'user-lock',
                            label = 'Algemar',
                            event = 'police:client:CuffPlayer',
                        },
                        {
                            id = 'playerInVehicle',
                            icon = 'car-side',
                            label = 'Colocar no veículo',
                            event = 'police:client:PutPlayerInVehicle',
                        },
                        {
                            id = 'playerOutVehicle',
                            icon = 'car-side',
                            label = 'Tirar do veículo',
                            event = 'police:client:SetPlayerOutVehicle',
                        },
                        {
                            id = 'stealPlayer',
                            icon = 'mask',
                            label = 'Roubar',
                            event = 'police:client:RobPlayer',
                        },
                        {
                            id = 'kidnapPlayer',
                            icon = 'user-group',
                            label = 'Sequestrar',
                            event = 'police:client:KidnapPlayer',
                        },
                        {
                            id = 'escortPlayer',
                            icon = 'user-group',
                            label = 'Escoltar',
                            event = 'police:client:EscortPlayer',
                        },
                        {
                            id = 'takeHostage',
                            icon = 'child',
                            label = 'Fazer refém',
                            event = 'police:client:TakeHostage',
                        },
                    },
                },
            },
        },
        {
            id = 'general',
            icon = 'rectangle-list',
            label = 'Geral',
            items = {
                {
                    id = 'clothesMenu',
                    icon = 'shirt',
                    label = 'Roupas',
                    items = {
                        {
                            id = 'hair',
                            icon = 'user',
                            label = 'Cabelo',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Hair'},
                        },
                        {
                            id = 'ear',
                            icon = 'ear-deaf',
                            label = 'Brinco',
                            event = 'qb-radialmenu:ToggleProps',
                            args = 'Ear',
                        },
                        {
                            id = 'neck',
                            icon = 'user-tie',
                            label = 'Pescoço',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Neck'},
                        },
                        {
                            id = 'top',
                            icon = 'shirt',
                            label = 'Blusa',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Top'},
                        },
                        {
                            id = 'shirt',
                            icon = 'shirt',
                            label = 'Camisa',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Shirt'},
                        },
                        {
                            id = 'pants',
                            icon = 'user',
                            label = 'Calça',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Pants'},
                        },
                        {
                            id = 'shoes',
                            icon = 'shoe-prints',
                            label = 'Sapatos',
                            event = 'qb-radialmenu:ToggleClothing',
                            args = {id = 'Shoes'},
                        },
                        {
                            id = 'clothingExtras',
                            icon = 'plus',
                            label = 'Extras',
                            items = {
                                {
                                    id = 'hat',
                                    icon = 'hat-cowboy-side',
                                    label = 'Chapéu',
                                    event = 'qb-radialmenu:ToggleProps',
                                    args = 'Hat',
                                },
                                {
                                    id = 'glasses',
                                    icon = 'glasses',
                                    label = 'Óculos',
                                    event = 'qb-radialmenu:ToggleProps',
                                    args = 'Glasses',
                                },
                                {
                                    id = 'visor',
                                    icon = 'hat-cowboy-side',
                                    label = 'Viseira',
                                    event = 'qb-radialmenu:ToggleProps',
                                    args = 'Visor',
                                },
                                {
                                    id = 'mask',
                                    icon = 'masks-theater',
                                    label = 'Máscara',
                                    event = 'qb-radialmenu:ToggleClothing',
                                    args = {id = 'Mask'},
                                },
                                {
                                    id = 'vest',
                                    icon = 'vest',
                                    label = 'Colete',
                                    event = 'qb-radialmenu:ToggleClothing',
                                    args = {id = 'Vest'},
                                },
                                {
                                    id = 'bag',
                                    icon = 'bag',
                                    label = 'Mochila',
                                    event = 'qb-radialmenu:ToggleClothing',
                                    args = {id = 'Bag'},
                                },
                                {
                                    id = 'bracelet',
                                    icon = 'user',
                                    label = 'Pulseira',
                                    event = 'qb-radialmenu:ToggleProps',
                                    args = 'Bracelet',
                                },
                                {
                                    id = 'watch',
                                    icon = 'stopwatch',
                                    label = 'Relógio',
                                    event = 'qb-radialmenu:ToggleProps',
                                    args = 'Watch',
                                },
                                {
                                    id = 'gloves',
                                    icon = 'mitten',
                                    label = 'Luvas',
                                    event = 'qb-radialmenu:ToggleClothing',
                                    args = {id = 'Gloves'},
                                },
                            },
                        },
                    },
                },
            },
        },
    },

    jobItems = {
        police = {
            {
                id = 'emergencyButton',
                icon = 'bell',
                label = 'Botão de emergência',
                event = 'police:client:SendPoliceEmergencyAlert',
            },
            {
                id = 'resetHouse',
                icon = 'key',
                label = 'Trocar fechadura da casa',
                event = 'qb-houses:client:ResetHouse',
            },
            {
                id = 'revokeDriversLicense',
                icon = 'id-card',
                label = 'Apreender CNH',
                event = 'police:client:SeizeDriverLicense',
            },
            {
                id = 'policeInteractions',
                icon = 'list-check',
                label = 'Ações policiais',
                items = {
                    {
                        id = 'statusCheck',
                        icon = 'heart-pulse',
                        label = 'Verificar estado de saúde',
                        event = 'hospital:client:CheckStatus',
                    },
                    {
                        id = 'escort',
                        icon = 'user-group',
                        label = 'Escoltar',
                        event = 'police:client:EscortPlayer',
                    },
                    {
                        id = 'search',
                        icon = 'magnifying-glass',
                        label = 'Revistar',
                        event = 'police:client:SearchPlayer',
                    },
                    {
                        id = 'jail',
                        icon = 'user-lock',
                        label = 'Prender',
                        event = 'police:client:JailPlayer',
                    },
                },
            },
            {
                id = 'policeObjects',
                icon = 'road',
                label = 'Objetos policiais',
                items = {
                    {
                        id = 'cone',
                        icon = 'triangle-exclamation',
                        label = 'Cone',
                        event = 'police:client:spawnPObj',
                        args = 'cone',
                    },
                    {
                        id = 'gate',
                        icon = 'torii-gate',
                        label = 'Barreira',
                        event = 'police:client:spawnPObj',
                        args = 'barrier',
                    },
                    {
                        id = 'speedSign',
                        icon = 'sign-hanging',
                        label = 'Placa de velocidade',
                        event = 'police:client:spawnPObj',
                        args = 'roadsign',
                    },
                    {
                        id = 'tent',
                        icon = 'campground',
                        label = 'Tenda',
                        event = 'police:client:spawnPObj',
                        args = 'tent',
                    },
                    {
                        id = 'lighting',
                        icon = 'lightbulb',
                        label = 'Iluminação',
                        event = 'police:client:spawnPObj',
                        args = 'light',
                    },
                    {
                        id = 'spikeStrip',
                        icon = 'caret-up',
                        label = 'Tapete de pregos',
                        event = 'police:client:SpawnSpikeStrip',
                    },
                    {
                        id = 'deleteObject',
                        icon = 'trash',
                        label = 'Remover objeto',
                        event = 'police:client:deleteObject',
                    },
                },
            },
        },
        ambulance = {
            {
                id = 'statusCheck',
                icon = 'heart-pulse',
                label = 'Verificar estado de saúde',
                event = 'hospital:client:CheckStatus',
            },
            {
                id = 'revive',
                icon = 'user-doctor',
                label = 'Reanimar',
                event = 'hospital:client:RevivePlayer',
            },
            {
                id = 'treatWounds',
                icon = 'bandage',
                label = 'Tratar ferimentos',
                event = 'hospital:client:TreatWounds',
            },
            {
                id = 'emergencyButton',
                icon = 'bell',
                label = 'Botão de emergência',
                serverEvent = 'hospital:server:emergencyAlert',
            },
            {
                id = 'escort',
                icon = 'user-group',
                label = 'Escoltar',
                event = 'police:client:EscortPlayer',
            },
        },
        mechanic = {
            {
                id = 'towVehicle',
                icon = 'truck-pickup',
                label = 'Rebocar veículo',
                event = 'qb-tow:client:TowVehicle',
            },
        },
        taxi = {
            {
                id = 'togglemeter',
                icon = 'eye-slash',
                label = 'Mostrar/ocultar taxímetro',
                event = 'qb-taxi:client:toggleMeter',
            },
            {
                id = 'togglemouse',
                icon = 'hourglass-start',
                label = 'Ligar/desligar taxímetro',
                event = 'qb-taxi:client:enableMeter',
            },
            {
                id = 'npcMission',
                icon = 'taxi',
                label = 'Corrida com NPC',
                event = 'qb-taxi:client:DoTaxiNpc',
            },
        },
        tow = {
            {
                id = 'togglenpc',
                icon = 'toggle-on',
                label = 'Ligar/desligar NPC',
                event = 'jobs:client:ToggleNpc',
            },
            {
                id = 'towVehicle',
                icon = 'truck-pickup',
                label = 'Rebocar veículo',
                event = 'qb-tow:client:TowVehicle',
            },
        },
    },

    gangItems = {},

    vehicleDoors = {
        id = 'vehicleDoors',
        icon = 'car-side',
        label = 'Portas',
        items = {
            {
                id = 'door0',
                icon = 'car-side',
                label = 'Porta do motorista',
                event = 'qb-radialmenu:client:openDoor',
                args = 0,
            },
            {
                id = 'door1',
                icon = 'car-side',
                label = 'Porta do passageiro',
                event = 'qb-radialmenu:client:openDoor',
                args = 1,
            },
            {
                id = 'door2',
                icon = 'car-side',
                label = 'Porta traseira esquerda',
                event = 'qb-radialmenu:client:openDoor',
                args = 2,
            },
            {
                id = 'door3',
                icon = 'car-side',
                label = 'Porta traseira direita',
                event = 'qb-radialmenu:client:openDoor',
                args = 3,
            },
            {
                id = 'door4',
                icon = 'car-side',
                label = 'Capô',
                event = 'qb-radialmenu:client:openDoor',
                args = 4,
            },
            {
                id = 'door5',
                icon = 'car-side',
                label = 'Porta-malas',
                event = 'qb-radialmenu:client:openDoor',
                args = 5,
            },
        },
    },

    vehicleWindows = {
        id = 'vehicleWindows',
        icon = 'car-side',
        label = 'Janelas',
        items = {
            {
                id = 'window0',
                icon = 'car-side',
                label = 'Janela do motorista',
                event = 'qbx_radialmenu:client:toggleWindows',
                args = 0,
            },
            {
                id = 'window1',
                icon = 'car-side',
                label = 'Janela do passageiro',
                event = 'qbx_radialmenu:client:toggleWindows',
                args = 1,
            },
            {
                id = 'window2',
                icon = 'car-side',
                label = 'Janela traseira esquerda',
                event = 'qbx_radialmenu:client:toggleWindows',
                args = 2,
            },
            {
                id = 'window3',
                icon = 'car-side',
                label = 'Janela traseira direita',
                event = 'qbx_radialmenu:client:toggleWindows',
                args = 3,
            },
        },
    },

    vehicleSeats = {
        id = 'vehicleSeats',
        icon = 'chair',
        label = 'Bancos',
        menu = 'vehicleSeatsMenu'
    },

    vehicleExtras = {
        id = 'vehicleExtras',
        icon = 'plus',
        label = 'Extras do veículo',
        items = {
            {
                id = 'extra1',
                icon = 'box-open',
                label = 'Extra 1',
                event = 'radialmenu:client:setExtra',
                args = 1,
            },
            {
                id = 'extra2',
                icon = 'box-open',
                label = 'Extra 2',
                event = 'radialmenu:client:setExtra',
                args = 2,
            },
            {
                id = 'extra3',
                icon = 'box-open',
                label = 'Extra 3',
                event = 'radialmenu:client:setExtra',
                args = 3,
            },
            {
                id = 'extra4',
                icon = 'box-open',
                label = 'Extra 4',
                event = 'radialmenu:client:setExtra',
                args = 4,
            },
            {
                id = 'extra5',
                icon = 'box-open',
                label = 'Extra 5',
                event = 'radialmenu:client:setExtra',
                args = 5,
            },
            {
                id = 'extra6',
                icon = 'box-open',
                label = 'Extra 6',
                event = 'radialmenu:client:setExtra',
                args = 6,
            },
            {
                id = 'extra7',
                icon = 'box-open',
                label = 'Extra 7',
                event = 'radialmenu:client:setExtra',
                args = 7,
            },
            {
                id = 'extra8',
                icon = 'box-open',
                label = 'Extra 8',
                event = 'radialmenu:client:setExtra',
                args = 8,
            },
            {
                id = 'extra9',
                icon = 'box-open',
                label = 'Extra 9',
                event = 'radialmenu:client:setExtra',
                args = 9,
            },
            {
                id = 'extra10',
                icon = 'box-open',
                label = 'Extra 10',
                event = 'radialmenu:client:setExtra',
                args = 10,
            },
            {
                id = 'extra11',
                icon = 'box-open',
                label = 'Extra 11',
                event = 'radialmenu:client:setExtra',
                args = 11,
            },
            {
                id = 'extra12',
                icon = 'box-open',
                label = 'Extra 12',
                event = 'radialmenu:client:setExtra',
                args = 12,
            },
            {
                id = 'extra13',
                icon = 'box-open',
                label = 'Extra 13',
                event = 'radialmenu:client:setExtra',
                args = 13,
            },
        },
    },

    trunkClasses = {
        [0] = {allowed = true, x = 0.0, y = -1.5, z = 0.0}, -- Coupes
        [1] = {allowed = true, x = 0.0, y = -2.0, z = 0.0}, -- Sedans
        [2] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- SUVs
        [3] = {allowed = true, x = 0.0, y = -1.5, z = 0.0}, -- Coupes
        [4] = {allowed = true, x = 0.0, y = -2.0, z = 0.0}, -- Muscle
        [5] = {allowed = true, x = 0.0, y = -2.0, z = 0.0}, -- Sports Classics
        [6] = {allowed = true, x = 0.0, y = -2.0, z = 0.0}, -- Sports
        [7] = {allowed = true, x = 0.0, y = -2.0, z = 0.0}, -- Super
        [8] = {allowed = false, x = 0.0, y = -1.0, z = 0.25}, -- Motorcycles
        [9] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Off-road
        [10] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Industrial
        [11] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Utility
        [12] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Vans
        [13] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Cycles
        [14] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Boats
        [15] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Helicopters
        [16] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Planes
        [17] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Service
        [18] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Emergency
        [19] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Military
        [20] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Commercial
        [21] = {allowed = true, x = 0.0, y = -1.0, z = 0.25}, -- Trains
    },

    clothingCommands = {
        top = {
            Func = function() ToggleClothing({'Top'}) end,
            Sprite = 'top',
            Desc = 'Tirar/colocar a blusa',
            Button = 1,
            Name = 'Torso',
        },
        gloves = {
            Func = function() ToggleClothing({'Gloves'}) end,
            Sprite = 'gloves',
            Desc = 'Tirar/colocar as luvas',
            Button = 2,
            Name = 'Gloves',
        },
        visor = {
            Func = function() ToggleProps({'Visor'}) end,
            Sprite = 'visor',
            Desc = 'Alternar a aba do chapéu',
            Button = 3,
            Name = 'Visor',
        },
        bag = {
            Func = function() ToggleClothing({'Bag'}) end,
            Sprite = 'bag',
            Desc = 'Abrir/fechar a mochila',
            Button = 8,
            Name = 'Bag',
        },
        shoes = {
            Func = function() ToggleClothing({'Shoes'}) end,
            Sprite = 'shoes',
            Desc = 'Tirar/colocar os sapatos',
            Button = 5,
            Name = 'Shoes',
        },
        vest = {
            Func = function() ToggleClothing({'Vest'}) end,
            Sprite = 'vest',
            Desc = 'Tirar/colocar o colete',
            Button = 14,
            Name = 'Vest',
        },
        hair = {
            Func = function() ToggleClothing({'Hair'}) end,
            Sprite = 'hair',
            Desc = 'Prender/soltar o cabelo',
            Button = 7,
            Name = 'Hair',
        },
        hat = {
            Func = function() ToggleProps({'Hat'}) end,
            Sprite = 'hat',
            Desc = 'Tirar/colocar o chapéu',
            Button = 4,
            Name = 'Hat',
        },
        glasses = {
            Func = function() ToggleProps({'Glasses'}) end,
            Sprite = 'glasses',
            Desc = 'Tirar/colocar os óculos',
            Button = 9,
            Name = 'Glasses',
        },
        ear = {
            Func = function() ToggleProps({'Ear'}) end,
            Sprite = 'ear',
            Desc = 'Tirar/colocar o brinco',
            Button = 10,
            Name = 'Ear',
        },
        neck = {
            Func = function() ToggleClothing({'Neck'}) end,
            Sprite = 'neck',
            Desc = 'Tirar/colocar o acessório do pescoço',
            Button = 11,
            Name = 'Neck',
        },
        watch = {
            Func = function() ToggleProps({'Watch'}) end,
            Sprite = 'watch',
            Desc = 'Tirar/colocar o relógio',
            Button = 12,
            Name = 'Watch',
            Rotation = 5.0,
        },
        bracelet = {
            Func = function() ToggleProps({'Bracelet'}) end,
            Sprite = 'bracelet',
            Desc = 'Tirar/colocar a pulseira',
            Button = 13,
            Name = 'Bracelet',
        },
        mask = {
            Func = function() ToggleClothing({'Mask'}) end,
            Sprite = 'mask',
            Desc = 'Tirar/colocar a máscara',
            Button = 6,
            Name = 'Mask',
        },

        pants = {
            Func = function() ToggleClothing({'Pants', true}) end,
            Sprite = 'pants',
            Desc = 'Tirar/colocar a calça',
            Name = 'Pants',
            OffsetX = -0.04,
            OffsetY = 0.0,
        },
        shirt = {
            Func = function() ToggleClothing({'Shirt', true}) end,
            Sprite = 'shirt',
            Desc = 'Tirar/colocar a camisa',
            Name = 'shirt',
            OffsetX = 0.04,
            OffsetY = 0.0,
        },
        reset = {
            Func = function()
                if not ResetClothing(true) then
                    Notify('Nada para restaurar', 'error')
                end
            end,
            Sprite = 'reset',
            Desc = 'Voltar tudo ao normal',
            Name = 'reset',
            OffsetX = 0.12,
            OffsetY = 0.2,
            Rotate = true
        },
        bagoff = {
            Func = function() ToggleClothing({'Bagoff', true}) end,
            Sprite = 'bagoff',
            SpriteFunc = function()
                local Bag = GetPedDrawableVariation(cache.ped, 5)
                local BagOff = LastEquipped['Bagoff']
                if LastEquipped['Bagoff'] then
                    if bags[BagOff.Drawable] then
                        return 'bagoff'
                    else
                        return 'paraoff'
                    end
                end
                if Bag ~= 0 then
                    if bags[Bag] then
                        return 'bagoff'
                    else
                        return 'paraoff'
                    end
                else
                    return false
                end
            end,
            Desc = 'Tirar/colocar a mochila',
            Name = 'bagoff',
            OffsetX = -0.12,
            OffsetY = 0.2,
        }
    },
}
