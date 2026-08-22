Config = {}

GetFramework = function()
    if GetResourceState('es_extended') ~= 'missing' then
        return 'esx'
    elseif GetResourceState('qbx_core') ~= 'missing' then
        return 'qbx'
    elseif GetResourceState('qb-core') ~= 'missing' then
        return 'qb'
    else
        return 'qbx'
    end
end

GetSkinMenu = function ()
    if GetResourceState('illenium-appearance') == 'missing' then
        return false
    else
        return true
    end
end

Config.framework = GetFramework() -- qb / esx /qbox /ox

Config.oxinventory = true
Config.illeniumappearance = GetSkinMenu()

Config.StarterItems = {
    {
        name = 'phone',
        amount = 1,
    },
    {
        name = 'id_card',
        amount = 1,
    },
    {
        name = 'driver_license',
        amount = 1,
    },
}

Config.AdminGroup = 'admin'
Config.AdminCommand = 'profiles'

Config.ProfilEditorCommand = 'editprofile'

Config.appartmentstart = false
Config.appartmentevent = 'apartments:client:setupSpawnUI' -- ps-housing:client:setupSpawnUI
Config.SpawnSelector = true

Config.Prefix = 'char'
Config.Maxslots = 4
Config.Identifier = 'license'

Config.maxdob = 2005
Config.mindob = 1970

Config.Routingbucket = 0


Config.NewCharacterSpawn = { -- Scene location for creation of new characters
    camcoords = vec3(-1051.2159, -2721.8655, 20.1689),
    camrotation = vec3(1.865273, 0.013506, -120.393661),
    startcoords = vec3(-1042.6187, -2746.0239, 21.3594),
    endcoords = vec3(-1035.1150, -2733.3511, 20.1693)
}

Config.skincoords = vec4(-811.7291, 175.1966, 76.7454, 114.4258) -- Location for character customization menu

Config.CreateMenu = {
    selectionlocation = false, -- Set this to true if you dont want a seperate location for CreateMenu
    model = -20018299,
    dict = 'timetable@ron@ig_3_couch',
    anim = 'base',
    location = vec4(-1377.5295, -1201.0742, 3.4508, 261.4065),
    camoffset = vec3(0, 0, -0.2),
    camrotation = vec3(0, 0, 0),
    pointcamoffset = vec3(-0.3, 0, 0.2),
    fov = 30.0,
}


Config.uniqueweathertime = true

Config.CharacterSelection = {
    {
        id = 'casino',
        weather = 'EXTRASUNNY',
        time = {
            hours = 7,
            minutes = 00,
            seconds = 00
        },
        dict = 'amb@world_human_leaning@female@wall@back@holding_elbow@idle_a',
        anim = 'idle_a',
        vehicle = 'banshee2',
        location = vec4(870.8840, -34.0424, 77.7642, 128.9946),
        vehiclelocation = vec4(872.0671, -33.2925, 78.3486, 58.7252),
        camlocation = vec3(866.0497, -35.3764, 78.7642),
        camrotation = vec3(2.648569, 0.014925, -73.680183),
        fov = 40.0,
    },
    {
        id = 'zancudo',
        weather = 'EXTRASUNNY',
        time = {
            hours = 20,
            minutes = 0,
            seconds = 00
        },
        dict = 'amb@world_human_picnic@female@idle_a',
        anim = 'idle_a',
        vehicle = 'banshee2',
        location = vec4(-1146.6541, 2663.2451, 17.9856, 311.0547),
        vehiclelocation = vec4(-1147.3054, 2663.8030, 17.6563, 221.6297),
        camlocation = vec3(-1141.5577, 2663.3613, 18.0520),
        camrotation = vec3(1.180936, 0.054204, 79.498993),
        fov = 40.0,
    },
    {
        id = 'sinner',
        weather = 'EXTRASUNNY',
        time = {
            hours = 12,
            minutes = 0,
            seconds = 00
        },
        dict = 'amb@world_human_leaning@female@wall@back@holding_elbow@idle_a',
        anim = 'idle_a',
        vehicle = 'akuma',
        location = vec4(453.4954, -764.8195, 26.3578, 41.3342),
        vehiclelocation = vec4(453.8455, -765.2072, 26.8668, 312.7693),
        camlocation = vec3(453.1763, -762.3759, 27.0578),
        camrotation = vec3(15.472958, 0.021996, -171.108337),
        fov = 40.0,
    },
    {
        id = 'confine',
        weather = 'EXTRASUNNY',
        time = {
            hours = 12,
            minutes = 0,
            seconds = 00
        },
        dict = 'amb@world_human_leaning@female@wall@back@holding_elbow@idle_a',
        anim = 'idle_a',
        vehicle = false,
        location = vec4(402.8329, -996.3921, -100.0002, 181.3700),
        camlocation = vec3(402.8754, -998.3820, -98.6040),
        camrotation = vec3(-3.047215, 0.014113, -0.650071),
        fov = 40.0,
    },
    {
        id = 'xmas',
        weather = 'XMAS',
        time = {
            hours = 20,
            minutes = 0,
            seconds = 00
        },
        dict = 'timetable@ron@ig_3_couch',
        anim = 'base',
        vehicle = false,
        location = vec4(776.0637, 4185.4146, 40.7790, 103.7116),
        camlocation = vec3(776.2673, 4187.0581, 41.8303),
        camrotation = vector3(-5.791659, 0.012236, 174.061890),
        fov = 40.0,
    }
}




SignIn = function()

end

SignOut = function()

end

Config.Lang = {
    START = 'INICIAR',
    CREDIT = 'CRÉDITOS',
    create = 'CRIAR',
    character = 'PERSONAGEM',
    description = 'Preencha os dados do personagem com um nome e uma data de nascimento realistas',
    firstName = 'NOME',
    lastName = 'SOBRENOME',
    male = 'Masculino',
    female = 'Feminino',
    dob = 'DATA DE NASCIMENTO',
    year = 'Ano',
    day = 'Dia',
    month = 'Mês',
    nationality = 'NACIONALIDADE',
    searchcountry = 'Buscar país',
    done = 'Concluir',
    esc = 'ESC',
    back = 'VOLTAR',
    exit = 'SAIR',
    EXIT = 'SAIR',
    enter = 'ENTRAR',
    dev = '@Desenvolvido por',
    afterlife = 'AfterLife Studios',
    exitgame = 'SAIR DO JOGO',
    exitdescription = 'Tem certeza de que deseja sair do jogo?',
    delete = 'EXCLUIR PERSONAGEM',
    deletedescription = 'Tem certeza de que deseja excluir este personagem?',
    hold = 'Segure',
    loadingsession = "CARREGANDO SESSÃO",
    loadingscene = "CARREGANDO CENA",
    loadingcharacter = "CARREGANDO PERSONAGEM"
}



--- This is for esx skinchanger
Config.DefaultSkin = {
    ["m"] = {
        mom = 43,
        dad = 29,
        face_md_weight = 61,
        skin_md_weight = 27,
        nose_1 = -5,
        nose_2 = 6,
        nose_3 = 5,
        nose_4 = 8,
        nose_5 = 10,
        nose_6 = 0,
        cheeks_1 = 2,
        cheeks_2 = -10,
        cheeks_3 = 6,
        lip_thickness = -2,
        jaw_1 = 0,
        jaw_2 = 0,
        chin_1 = 0,
        chin_2 = 0,
        chin_13 = 0,
        chin_4 = 0,
        neck_thickness = 0,
        hair_1 = 76,
        hair_2 = 0,
        hair_color_1 = 61,
        hair_color_2 = 29,
        tshirt_1 = 4,
        tshirt_2 = 2,
        torso_1 = 23,
        torso_2 = 2,
        decals_1 = 0,
        decals_2 = 0,
        arms = 1,
        arms_2 = 0,
        pants_1 = 28,
        pants_2 = 3,
        shoes_1 = 70,
        shoes_2 = 2,
        mask_1 = 0,
        mask_2 = 0,
        bproof_1 = 0,
        bproof_2 = 0,
        chain_1 = 22,
        chain_2 = 2,
        helmet_1 = -1,
        helmet_2 = 0,
        glasses_1 = 0,
        glasses_2 = 0,
        watches_1 = -1,
        watches_2 = 0,
        bracelets_1 = -1,
        bracelets_2 = 0,
        bags_1 = 0,
        bags_2 = 0,
        eye_color = 0,
        eye_squint = 0,
        eyebrows_2 = 0,
        eyebrows_1 = 0,
        eyebrows_3 = 0,
        eyebrows_4 = 0,
        eyebrows_5 = 0,
        eyebrows_6 = 0,
        makeup_1 = 0,
        makeup_2 = 0,
        makeup_3 = 0,
        makeup_4 = 0,
        lipstick_1 = 0,
        lipstick_2 = 0,
        lipstick_3 = 0,
        lipstick_4 = 0,
        ears_1 = -1,
        ears_2 = 0,
        chest_1 = 0,
        chest_2 = 0,
        chest_3 = 0,
        bodyb_1 = -1,
        bodyb_2 = 0,
        bodyb_3 = -1,
        bodyb_4 = 0,
        age_1 = 0,
        age_2 = 0,
        blemishes_1 = 0,
        blemishes_2 = 0,
        blush_1 = 0,
        blush_2 = 0,
        blush_3 = 0,
        complexion_1 = 0,
        complexion_2 = 0,
        sun_1 = 0,
        sun_2 = 0,
        moles_1 = 0,
        moles_2 = 0,
        beard_1 = 11,
        beard_2 = 10,
        beard_3 = 0,
        beard_4 = 0,
    },
    ["f"] = {
        mom = 28,
        dad = 6,
        face_md_weight = 63,
        skin_md_weight = 60,
        nose_1 = -10,
        nose_2 = 4,
        nose_3 = 5,
        nose_4 = 0,
        nose_5 = 0,
        nose_6 = 0,
        cheeks_1 = 0,
        cheeks_2 = 0,
        cheeks_3 = 0,
        lip_thickness = 0,
        jaw_1 = 0,
        jaw_2 = 0,
        chin_1 = -10,
        chin_2 = 10,
        chin_13 = -10,
        chin_4 = 0,
        neck_thickness = -5,
        hair_1 = 43,
        hair_2 = 0,
        hair_color_1 = 29,
        hair_color_2 = 35,
        tshirt_1 = 111,
        tshirt_2 = 5,
        torso_1 = 25,
        torso_2 = 2,
        decals_1 = 0,
        decals_2 = 0,
        arms = 3,
        arms_2 = 0,
        pants_1 = 12,
        pants_2 = 2,
        shoes_1 = 20,
        shoes_2 = 10,
        mask_1 = 0,
        mask_2 = 0,
        bproof_1 = 0,
        bproof_2 = 0,
        chain_1 = 85,
        chain_2 = 0,
        helmet_1 = -1,
        helmet_2 = 0,
        glasses_1 = 33,
        glasses_2 = 12,
        watches_1 = -1,
        watches_2 = 0,
        bracelets_1 = -1,
        bracelets_2 = 0,
        bags_1 = 0,
        bags_2 = 0,
        eye_color = 8,
        eye_squint = -6,
        eyebrows_2 = 7,
        eyebrows_1 = 32,
        eyebrows_3 = 52,
        eyebrows_4 = 9,
        eyebrows_5 = -5,
        eyebrows_6 = -8,
        makeup_1 = 0,
        makeup_2 = 0,
        makeup_3 = 0,
        makeup_4 = 0,
        lipstick_1 = 0,
        lipstick_2 = 0,
        lipstick_3 = 0,
        lipstick_4 = 0,
        ears_1 = -1,
        ears_2 = 0,
        chest_1 = 0,
        chest_2 = 0,
        chest_3 = 0,
        bodyb_1 = -1,
        bodyb_2 = 0,
        bodyb_3 = -1,
        bodyb_4 = 0,
        age_1 = 0,
        age_2 = 0,
        blemishes_1 = 0,
        blemishes_2 = 0,
        blush_1 = 0,
        blush_2 = 0,
        blush_3 = 0,
        complexion_1 = 0,
        complexion_2 = 0,
        sun_1 = 0,
        sun_2 = 0,
        moles_1 = 12,
        moles_2 = 8,
        beard_1 = 0,
        beard_2 = 0,
        beard_3 = 0,
        beard_4 = 0,
    },
}
