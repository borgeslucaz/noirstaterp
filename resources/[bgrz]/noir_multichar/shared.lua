Config = {}

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

Config.AdminCommand = 'profiles'

Config.ProfilEditorCommand = 'editprofile'

Config.SpawnSelector = true

Config.Prefix = 'char'
Config.Maxslots = 4
Config.Identifier = 'license'

Config.maxdob = 2005
Config.mindob = 1970

Config.Routingbucket = 0

-- Direct spawn used only after creating a new Qbox character.
-- vector4 is required so the player's heading is preserved.
Config.NewCharacterLocation = vector4(-1041.13, -2734.80, -0.20, 357.71)

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

-- Poses do preview, as mesmas do noir_pausemenu (shared/config.lua). Sorteadas pelo gênero do
-- personagem nas cenas que não definem pose própria.
Config.AnimationPropPresets = {
    phone_male = {
        model = 'prop_phone_ing',
        bone = 28422,
        pos = { x = 0.0, y = 0.0, z = 0.0 },
        rot = { x = 0.0, y = 0.0, z = 0.0 },
        delay = 500,
    },
    phone_female = {
        model = 'prop_phone_ing',
        bone = 28422,
        pos = { x = 0.0, y = 0.0, z = 0.0301 },
        rot = { x = 0.0, y = 0.0, z = 0.0 },
        delay = 500,
    },
    cigarette = {
        model = 'prop_cs_ciggy_01',
        bone = 28422,
        pos = { x = 0.0, y = 0.0, z = 0.0 },
        rot = { x = 0.0, y = 0.0, z = 0.0 },
        delay = 400,
    },
}

Config.Animations = {
    male = {
        { dict = 'amb@world_human_hang_out_street@male_a@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_hang_out_street@male_b@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_hang_out_street@male_c@idle_a', anim = 'idle_b' },
        { dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_stand_guard@male@idle_a', anim = 'idle_a' },
        { dict = 'cellphone@', anim = 'cellphone_text_read_base', prop = 'phone_male' },
        { dict = 'anim@amb@business@bgen@bgen_no_work@', anim = 'stand_phone_phoneputdown_idle_nowork' },
        { dict = 'amb@world_human_smoking@male@male_a@idle_a', anim = 'idle_a', prop = 'cigarette' },
        { dict = 'amb@world_human_aa_smoke@male@idle_a', anim = 'idle_c', prop = 'cigarette' },
        { dict = 'amb@world_human_muscle_flex@arms_at_side@idle_a', anim = 'idle_a' },
        { dict = 'anim@heists@heist_corona@single_team', anim = 'single_team_loop_boss' },
    },
    female = {
        { dict = 'amb@world_human_hang_out_street@female_a@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_hang_out_street@female_hold_arm@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_hang_out_street@female_arms_crossed@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_hang_out_street@female_arm_side@idle_a', anim = 'idle_a' },
        { dict = 'amb@world_human_stand_impatient@female@no_sign@idle_a', anim = 'idle_a' },
        { dict = 'cellphone@female', anim = 'cellphone_text_read_base', prop = 'phone_female' },
        { dict = 'anim@amb@business@bgen@bgen_no_work@', anim = 'stand_phone_phoneputdown_idle_nowork' },
        { dict = 'amb@world_human_smoking@female@idle_a', anim = 'idle_b', prop = 'cigarette' },
    },
}

-- Blur da seleção, o mesmo do noir_pausemenu (PauseMenuBlur): foco no ped, o resto desfocado.
Config.SceneBlur = {
    enabled = true,
    strength = 1.0,         -- BlurStrength do pausemenu
    focalMultiplier = 50.0, -- BlurFocalMultiplier do pausemenu
    padding = 0.2,          -- BlurFocusPadding: metros nítidos antes e depois do ped
}

-- Sem som do mundo (trânsito, pedestres, vento) enquanto a seleção de personagem está na tela.
Config.MuteScene = true

-- Câmera viva na seleção de personagem: push-in lento + balanço leve de câmera na mão.
Config.CinematicCamera = {
    enabled = true,
    pushDistance = 0.5,   -- metros que a câmera avança na direção em que olha
    pushDuration = 20000, -- ms para percorrer esse trecho (bem lento de propósito)
    fovDrop = 2.0,        -- FOV que fecha junto com o avanço (zoom leve)
    shake = 0.12,         -- intensidade do HAND_SHAKE (0 desliga)
}

-- Cenas da seleção: uma é sorteada a cada abertura. Cena sem dict/anim sorteia a pose de
-- Config.Animations; com dict/anim (sentado), usa a própria. Monte novas com /capturarcena
-- (resource freecamera).
Config.CharacterSelection = {
    {
        id = 'vespucci',
        weather = 'EXTRASUNNY',
        time = { hours = 14, minutes = 57, seconds = 0 },
        vehicle = false,
        location = vec4(-1331.4290, -1409.6901, 4.3135, 206.3320),
        camlocation = vec3(-1329.5468, -1411.7997, 4.7608),
        camrotation = vec3(-4.4723, -0.0000, 47.9334),
        fov = 33.3,
    },
    {
        id = 'centro',
        weather = 'EXTRASUNNY',
        time = { hours = 15, minutes = 43, seconds = 0 },
        vehicle = false,
        location = vec4(-506.8483, -622.1392, 34.6763, 97.7534),
        camlocation = vec3(-508.9498, -623.1917, 34.9274),
        camrotation = vec3(0.9448, 0.0000, -53.9188),
        fov = 33.3,
    },
    {
        id = 'vinewood',
        weather = 'EXTRASUNNY',
        time = { hours = 16, minutes = 16, seconds = 0 },
        vehicle = false,
        location = vec4(539.3155, 704.4937, 202.2889, 211.7955),
        camlocation = vec3(541.6722, 703.1392, 203.0879),
        camrotation = vec3(-11.2756, -0.0000, 67.8391),
        fov = 33.3,
    },
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
