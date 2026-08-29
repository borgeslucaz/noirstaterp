Config = {}

Config.RequireGang = true
Config.AdminAce = 'noir.graffitiadmin'

Config.Items = {
    spray = 'spraycan',
    remover = 'sprayremover',
    useMetadata = true,
    defaultUses = 5,
}

Config.Text = {
    minLength = 2,
    maxLength = 32,
    allowLineBreaks = false,
}

Config.Fonts = {
    { id = 'Rock Salt', label = 'Rock Salt' },
    { id = 'Creepster', label = 'Creepster' },
    { id = 'Oswald', label = 'Oswald' },
    { id = 'Geist', label = 'Geist' },
}

Config.GangColors = {
    ballas = '#74449A',
    families = '#3E8B52',
    vagos = '#D4C22F',
    marabunta = '#5096D2',
    lostmc = '#B4B4B4',
}
Config.DefaultColor = '#FFFFFF'

Config.Placement = {
    maxDistance = 4.0,
    minScale = 0.5,
    maxScale = 2.5,
    defaultScale = 1.0,
    scaleStep = 0.1,
    rotationStep = 5.0,
    positionStep = 0.02,
    cooldownSeconds = 30,
    minimumGraffitiDistance = 2.0,
    wallOffset = 0.012,
    maxWallNormalZ = 0.75,
}

Config.Render = {
    distance = 65.0,
    unloadDistance = 80.0,
    checkInterval = 750,
    maxActive = 24,
    width = 1024,
    height = 512,
    baseWorldWidth = 2.5,
}

Config.Remove = {
    targetDistance = 2.5,
    serverDistance = 3.0,
    duration = 5000,
}
