Config = {}

Config.Framework = 'auto'                -- auto, qbox, qb
Config.Target = 'auto'                   -- auto, ox_target, qb-target
Config.UseOxTarget = true                -- legacy option kept for compatibility
Config.TargetDistance = 2.5
Config.BrowseLabel = 'Browse Vehicles'

Config.PedLocation = vector4(-55.57, -1097.98, 26.42, 351.45)
Config.PedModel = 'cs_siemonyetarian'

Config.TestDriveTime = 300
Config.TestDrive = {
    enabled = true,
    time = Config.TestDriveTime,
    cooldown = 30,
    handoffTimeout = 25,                -- seconds allowed for fade, streaming, and seating
    returnFallbackTimeout = 8000,       -- server fallback if the faded return never completes
    clearanceRadius = 4.0,
    maxDistance = 750.0,
    cancelOnExit = true,
    invinciblePlayer = false,
    invincibleVehicle = false
}

-- Smooth the switch from the showroom to a server-created vehicle. All waits
-- are bounded, and the client always restores the screen if a handoff fails.
Config.HandoffTransition = {
    enabled = true,
    fadeOut = 350,                      -- milliseconds
    fadeIn = 650,                       -- milliseconds
    settle = 400,                       -- brief seated/collision settling period
    collisionTimeout = 2500,            -- maximum collision-streaming wait
    maxBlackout = 22000,                -- fail-safe; always restores before server rollback
    spinner = true
}

Config.TestDriveCoords = vector4(-47.6, -1080.99, 26.28, 70.38)
Config.VehicleSpawnCoords = vector4(-18.2, -1103.5, 26.2, 159.75)
Config.DealershipCoords = vector3(-56.05, -1096.37, 26.42)

Config.Locations = {
    testDrive = Config.TestDriveCoords,
    spawn = Config.VehicleSpawnCoords,
    dealership = Config.DealershipCoords
}

Config.FuelScript = 'ox_fuel'            -- auto, ox_fuel, LegacyFuel, ps-fuel, cdn-fuel, native
Config.KeySystem = 'auto'                -- auto, qbx_vehiclekeys, qb-vehiclekeys, none
Config.GarageIntegration = 'none'        -- drs (drs_garages or legacy lunar_garage), auto, none
                                         -- noir: 'none' porque o servidor usa qbx_garages, que nao tem RegisterActiveVehicle
Config.PaymentAccount = 'cash'           -- cash, bank, crypto
Config.DefaultGarage = 'pillboxgarage'
Config.DefaultGarages = {
    car = 'pillboxgarage',
    boat = 'lsymc',                     -- noir: nomes das garagens do qbx_garages
    air = 'intairport'
}
Config.PurchasedVehicleState = 0         -- 0 = out, 1 = stored/garaged on most QB/Qbox garage tables
Config.PurchasedVehicleStored = Config.PurchasedVehicleState
Config.DeliverPurchasedVehicles = true   -- false stages every purchase safely in its configured garage
Config.DeliveryClearanceRadius = 4.0
Config.EntityHandoffTimeout = 10000
Config.DeliveryAcknowledgementTimeout = 25000 -- includes fade/streaming time before client confirmation
Config.ServerSpawnTimeout = 5000
Config.QuarantineRoutingBucket = 900000     -- isolated holding bucket used only after a failed entity deletion
Config.PlateGenerationAttempts = 25
Config.MaxPurchaseDistance = 25.0        -- required server-side purchase/test-drive validation radius
Config.PurchaseCooldown = 2500
Config.PlateFormat = '1LL3LL'            -- max 8 chars; 1/2/3/4 = digits, L = random letter

-- Factory checkout options. The UI sends only these stable ids; color indexes,
-- plate indexes, option prices, and the final plate are always resolved by the
-- server. Keep ids unique and prices as non-negative whole dollars.
Config.Checkout = {
    enabled = true,
    quoteCooldown = 750,                 -- milliseconds between quote requests per player
    quoteLifetime = 120,                 -- seconds before an unsubmitted quote expires
    resultLifetime = 600,                -- idempotent purchase-result cache lifetime
    capabilities = {
        colors = true,
        secondaryColor = true,
        platePrefix = true,              -- road vehicles only
        plateStyles = true,              -- road vehicles only
        delivery = true
    },
    colors = {
        { id = 'black',       label = 'Metallic Black',  swatch = '#0d0d0f', index = 0,   price = 0 },
        { id = 'graphite',    label = 'Graphite',        swatch = '#27282d', index = 1,   price = 0 },
        { id = 'silver',      label = 'Silver',          swatch = '#a9aaae', index = 4,   price = 0 },
        { id = 'frost_white', label = 'Frost White',     swatch = '#f1f1ea', index = 112, price = 0 },
        { id = 'torino_red',  label = 'Torino Red',      swatch = '#b42025', index = 28,  price = 1500 },
        { id = 'orange',      label = 'Metallic Orange', swatch = '#f26722', index = 38,  price = 1500 },
        { id = 'race_yellow', label = 'Race Yellow',     swatch = '#f3d725', index = 89,  price = 1500 },
        { id = 'racing_green',label = 'Racing Green',    swatch = '#123d2b', index = 50,  price = 1500 },
        { id = 'bright_blue', label = 'Bright Blue',     swatch = '#1764d9', index = 70,  price = 1500 },
        { id = 'ultra_blue',  label = 'Ultra Blue',      swatch = '#2955ff', index = 73,  price = 2500 }
    },
    -- Presentation-only subset shown by the checkout UI. The complete colors
    -- table above remains the server-authoritative allowlist for purchases.
    featuredColorIds = {
        'black',
        'graphite',
        'frost_white',
        'torino_red',
        'bright_blue'
    },
    platePrefix = {
        enabled = true,
        maxLength = 3,                   -- hard-capped by the server at three characters
        price = 7500,
        blocked = { 'PD', 'EMS', 'FIB', 'GOV', 'LEO' }
    },
    plateStyles = {
        { id = 'blue_white',   label = 'San Andreas Cursive', image = 'assets/plates/san-andreas-cursive.png', index = 0, price = 0 },
        { id = 'yellow_black', label = 'San Andreas Black',   image = 'assets/plates/san-andreas-black.png',   index = 1, price = 1000 },
        { id = 'yellow_blue',  label = 'San Andreas Blue',    image = 'assets/plates/san-andreas-blue.png',    index = 2, price = 1000 },
        { id = 'white_blue',   label = 'San Andreas Plain',   image = 'assets/plates/san-andreas-plain.png',   index = 3, price = 1000 },
        { id = 'sa_exempt',    label = 'SA Exempt',           image = 'assets/plates/sa-exempt.png',           index = 4, price = 1000 }
    },
    deliveryModes = {
        { id = 'driveaway', label = 'Drive away', description = 'Take delivery at the dealership.', price = 0 },
        { id = 'garage',    label = 'Garage',     description = 'Send it securely to your configured garage.', price = 0 }
    },
    defaults = {
        primaryColorId = 'graphite',
        secondaryColorId = 'graphite',
        plateMode = 'standard',
        plateStyleId = 'blue_white',
        deliveryMode = 'driveaway'
    }
}

-- Server-only society fleet checkout. The public UI never receives authority
-- to choose a price, plate, ownership row, or job. DRS Garages calls the
-- protected server exports with the acting boss and a durable request id; this
-- resource resolves the catalogue price and debits the configured society
-- account before asking DRS Garages to create the stored job vehicle.
Config.Fleet = {
    Enabled = false,                      -- noir: exige drs_garages, que nao usamos
    GarageResource = 'drs_garages',
    AllowedCallers = {
        drs_garages = true
    },
    -- `auto` prefers qb-banking because its mutation export returns an awaited
    -- affected-row result. Renewed-Banking remains supported, but its current
    -- export acknowledges before its asynchronous database write is confirmed.
    BankProvider = 'auto',                -- auto, renewed-banking, qb-banking, none
    RequireOnDuty = true,
    MinimumBossGrade = 0,
    PurchaseCooldown = 2500,
    MaxCatalogResults = 300,

    -- Fleet access is deliberately allowlisted per exact framework job. A rule
    -- may contain `models`, `categories`, or both; they are combined. Prices
    -- always come from Config.Vehicles. Add-on police/EMS models must be listed
    -- here (or enabled through an intentionally broader category rule).
    Catalogs = {
        police = {
            account = 'police',
            models = {
                'pbus', 'police', 'police2', 'police3', 'police4', 'policeb',
                'policet', 'polmav', 'predator', 'pranger', 'riot', 'sheriff',
                'sheriff2'
            }
        },
        ambulance = {
            account = 'ambulance',
            models = { 'ambulance', 'firetruk', 'frogger', 'lguard', 'seashark2' }
        }
    }
}

Config.DefaultShop = 'auto'

Config.Shops = {
    auto = {
        label = 'Premium Deluxe Motorsport',
        type = 'car',
        defaultCategory = 'sports',        -- initial catalogue category; validated client-side against this shop's inventory
        presentation = {
            image = 'assets/shops/auto.webp',
            logo = 'assets/shops/pdm.svg',
            eyebrow = 'Premium Deluxe Motorsport',
            title = 'Choose a vehicle to begin',
            description = 'Explore the showroom, compare performance, and select a vehicle to unlock its purchase and test-drive options.',
            details = {
                { label = 'Showroom', value = 'Road-ready inventory across every public vehicle class' },
                { label = 'Test drives', value = 'Five-minute supervised route from the dealership' },
                { label = 'Delivery', value = 'Direct handoff or secure garage staging' }
            }
        },
        ped = {
            model = Config.PedModel,
            coords = Config.PedLocation
        },
        targetLabel = Config.BrowseLabel,
        targetIcon = 'car',               -- Font Awesome icon name; target adapters add their required prefix
        categories = {
            'sports',
            'sportsclassic',
            'super',
            'sedans',
            'muscle',
            'suvs',
            'coupes',
            'compacts',
            'motorcycles',
            'off-road',
            'trucks',
            'vans',
            'drift',
            'luxury',
            'emergency'
        },
        dealership = Config.DealershipCoords,
        testDrive = Config.TestDriveCoords,
        spawn = Config.VehicleSpawnCoords,
        garage = Config.DefaultGarages.car,
        blip = {
            enabled = true,
            sprite = 326,
            color = 3,
            scale = 0.65
        }
    },
    boat = {
        label = 'Puerto Del Sol Boat Sales',
        type = 'boat',
        defaultCategory = 'boats',
        presentation = {
            image = 'assets/shops/boat.webp',
            logo = 'assets/shops/pds.svg',
            eyebrow = 'Puerto Del Sol Marina',
            title = 'Choose a vessel to begin',
            description = 'Browse the marina fleet, review each vessel, and select one to reveal its purchase and water-test options.',
            details = {
                { label = 'Marina', value = 'Recreational vessels prepared at Puerto Del Sol' },
                { label = 'Water tests', value = 'Launch directly into the marina test area' },
                { label = 'Boathouse', value = 'Purchased vessels register to marina storage' }
            }
        },
        ped = {
            model = 's_m_m_dockwork_01',
            coords = vector4(-832.46, -1411.32, 1.61, 289.61)
        },
        targetLabel = 'Browse Boats',
        targetIcon = 'ship',
        categories = {
            'boats'
        },
        dealership = vector3(-831.57, -1412.9, 1.61),
        testDrive = vector4(-834.69, -1418.18, 1.74, 199.18),
        spawn = vector4(-812.95, -1424.88, 1.83, 173.8),
        garage = Config.DefaultGarages.boat,
        blip = {
            enabled = true,
            sprite = 427,
            color = 3,
            scale = 0.65
        }
    },
    air = {
        label = 'Los Santos Air Sales',
        type = 'air',
        defaultCategory = 'helicopters',
        presentation = {
            image = 'assets/shops/air.webp',
            logo = 'assets/shops/lsa.svg',
            eyebrow = 'Los Santos Air Sales',
            title = 'Choose an aircraft to begin',
            description = 'Review the hangar inventory, compare flight performance, and select an aircraft for purchase or a flight test.',
            details = {
                { label = 'Hangar', value = 'Helicopters and fixed-wing aircraft in one catalogue' },
                { label = 'Flight tests', value = 'Depart from the airport testing apron' },
                { label = 'Storage', value = 'Purchases register to secure airport storage' }
            }
        },
        ped = {
            model = 's_m_m_pilot_02',
            coords = vector4(-941.13, -2954.73, 13.95, 151.25)
        },
        targetLabel = 'Browse Aircraft',
        targetIcon = 'helicopter',
        categories = {
            'helicopters',
            'planes'
        },
        dealership = vector3(-941.13, -2954.73, 13.95),
        testDrive = vector4(-979.06, -2995.78, 13.95, 60.24),
        spawn = vector4(-979.06, -2995.78, 13.95, 60.24),
        garage = Config.DefaultGarages.air,
        blip = {
            enabled = true,
            sprite = 423,
            color = 3,
            scale = 0.65
        }
    }
}

-- Server-enforced category authorization. Shop categories control visibility;
-- these exact Qbox/QB group names and minimum grades protect transactions.
Config.CategoryAccess = {
    emergency = { groups = { police = 0 } },
    -- service = { groups = { mechanic = 0, taxi = 0 } }
}

Config.Categories = {
    ["sports"] = "Sports",
    ["sportsclassic"] = "Sports Classic",
    ["super"] = "Super",
    ["sedans"] = "Sedans",
    ["muscle"] = "Muscle",
    ["suvs"] = "SUVs",
    ["coupes"] = "Coupes",
    ["compacts"] = "Compacts",
    ["motorcycles"] = "Motorcycles",
    ["off-road"] = "Off-Road",
    ["trucks"] = "Trucks",
    ["vans"] = "Vans",
    ["drift"] = "Drift",
    ["luxury"] = "Luxury",
    ["emergency"] = "Emergency",
    ["service"] = "Service",
    ["boats"] = "Boats",
    ["helicopters"] = "Helicopters",
    ["planes"] = "Planes",
}

local function vehicle(name, brand, model, price, category, vehicleType, image)
    local data = {
        name = name,
        brand = brand,
        model = model,
        price = price,
        category = category
    }

    if vehicleType then
        data.type = vehicleType
    end

    if image then
        data.image = image
    end

    return data
end

-- Vanilla GTA catalogue, including official DLC models restored from the legacy
-- configuration. Custom models are isolated in config-addons.lua and merged later.

Config.Vehicles = {
    ["compacts"] = {
        ["asbo"] = vehicle("Asbo", "Maxwell", "asbo", 12000, "compacts"),
        ["blista"] = vehicle("Blista", "Dinka", "blista", 11000, "compacts"),
        ["brioso"] = vehicle("Brioso R/A", "Grotti", "brioso", 18000, "compacts"),
        ["brioso2"] = vehicle("Brioso 300", "Grotti", "brioso2", 15500, "compacts"),
        ["brioso3"] = vehicle("Brioso 300 Widebody", "Grotti", "brioso3", 1499000, "compacts"),
        ["club"] = vehicle("Club", "BF", "club", 16500, "compacts"),
        ["dilettante"] = vehicle("Dilettante", "Karin", "dilettante", 12000, "compacts"),
        ["issi2"] = vehicle("Issi", "Weeny", "issi2", 13000, "compacts"),
        ["issi3"] = vehicle("Issi Classic", "Weeny", "issi3", 360000, "compacts"),
        ["kanjo"] = vehicle("Blista Kanjo", "Dinka", "kanjo", 580000, "compacts"),
        ["panto"] = vehicle("Panto", "Benefactor", "panto", 10000, "compacts"),
        ["prairie"] = vehicle("Prairie", "Bollokan", "prairie", 14000, "compacts"),
        ["rhapsody"] = vehicle("Rhapsody", "Declasse", "rhapsody", 12500, "compacts"),
        ["weevil"] = vehicle("Weevil", "BF", "weevil", 17000, "compacts"),
    },
    ["coupes"] = {
        ["cogcabrio"] = vehicle("Cognoscenti Cabrio", "Enus", "cogcabrio", 55000, "coupes"),
        ["exemplar"] = vehicle("Exemplar", "Dewbauchee", "exemplar", 62000, "coupes"),
        ["f620"] = vehicle("F620", "Ocelot", "f620", 52000, "coupes"),
        ["felon"] = vehicle("Felon", "Lampadati", "felon", 50000, "coupes"),
        ["felon2"] = vehicle("Felon GT", "Lampadati", "felon2", 58000, "coupes"),
        ["fr36"] = vehicle("FR36", "Fathom", "fr36", 1680000, "coupes"),
        ["jackal"] = vehicle("Jackal", "Ocelot", "jackal", 45000, "coupes"),
        ["kanjosj"] = vehicle("Kanjo SJ", "Dinka", "kanjosj", 1370000, "coupes"),
        ["oracle"] = vehicle("Oracle", "Ubermacht", "oracle", 42000, "coupes"),
        ["oracle2"] = vehicle("Oracle XS", "Ubermacht", "oracle2", 48000, "coupes"),
        ["postlude"] = vehicle("Postlude", "Dinka", "postlude", 1310000, "coupes"),
        ["previon"] = vehicle("Previon", "Karin", "previon", 1490000, "coupes"),
        ["sentinel"] = vehicle("Sentinel", "Ubermacht", "sentinel", 40000, "coupes"),
        ["sentinel2"] = vehicle("Sentinel XS", "Ubermacht", "sentinel2", 46000, "coupes"),
        ["windsor"] = vehicle("Windsor", "Enus", "windsor", 90000, "coupes"),
        ["windsor2"] = vehicle("Windsor Drop", "Enus", "windsor2", 95000, "coupes"),
        ["zion"] = vehicle("Zion", "Ubermacht", "zion", 42000, "coupes"),
        ["zion2"] = vehicle("Zion Cabrio", "Ubermacht", "zion2", 47000, "coupes"),
    },
    ["sedans"] = {
        ["asea"] = vehicle("Asea", "Declasse", "asea", 10000, "sedans"),
        ["asterope"] = vehicle("Asterope", "Karin", "asterope", 16000, "sedans"),
        ["asterope2"] = vehicle("Asterope GZ", "Karin", "asterope2", 1580000, "sedans"),
        ["cinquemila"] = vehicle("Cinquemila", "Lampadati", "cinquemila", 130000, "sedans"),
        ["cog55"] = vehicle("Cognoscenti 55", "Enus", "cog55", 85000, "sedans"),
        ["cognoscenti"] = vehicle("Cognoscenti", "Enus", "cognoscenti", 95000, "sedans"),
        ["deity"] = vehicle("Deity", "Enus", "deity", 150000, "sedans"),
        ["emperor"] = vehicle("Emperor", "Albany", "emperor", 10000, "sedans"),
        ["emperor2"] = vehicle("Emperor", "Albany", "emperor2", 8000, "sedans"),
        ["fugitive"] = vehicle("Fugitive", "Cheval", "fugitive", 24000, "sedans"),
        ["glendale"] = vehicle("Glendale", "Benefactor", "glendale", 22000, "sedans"),
        ["glendale2"] = vehicle("Glendale Custom", "Benefactor", "glendale2", 520000, "sedans"),
        ["impaler5"] = vehicle("Impaler SZ", "Declasse", "impaler5", 1620000, "sedans"),
        ["ingot"] = vehicle("Ingot", "Vulcar", "ingot", 12000, "sedans"),
        ["intruder"] = vehicle("Intruder", "Karin", "intruder", 18000, "sedans"),
        ["premier"] = vehicle("Premier", "Declasse", "premier", 14000, "sedans"),
        ["primo"] = vehicle("Primo", "Albany", "primo", 16000, "sedans"),
        ["primo2"] = vehicle("Primo Custom", "Albany", "primo2", 400000, "sedans"),
        ["regina"] = vehicle("Regina", "Dundreary", "regina", 8000, "sedans"),
        ["rhinehart"] = vehicle("Rhinehart", "Ubermacht", "rhinehart", 120000, "sedans"),
        ["romero"] = vehicle("Romero", "Chariot", "romero", 45000, "sedans"),
        ["schafter2"] = vehicle("Schafter", "Benefactor", "schafter2", 60000, "sedans"),
        ["stafford"] = vehicle("Stafford", "Enus", "stafford", 1272000, "sedans"),
        ["stanier"] = vehicle("Stanier", "Vapid", "stanier", 15000, "sedans"),
        ["stratum"] = vehicle("Stratum", "Zirconium", "stratum", 16000, "sedans"),
        ["stretch"] = vehicle("Stretch", "Dundreary", "stretch", 80000, "sedans"),
        ["superd"] = vehicle("Super Diamond", "Enus", "superd", 140000, "sedans"),
        ["surge"] = vehicle("Surge", "Cheval", "surge", 26000, "sedans"),
        ["tailgater"] = vehicle("Tailgater", "Obey", "tailgater", 35000, "sedans"),
        ["tailgater2"] = vehicle("Tailgater S", "Obey", "tailgater2", 105000, "sedans"),
        ["warrener"] = vehicle("Warrener", "Vulcar", "warrener", 24000, "sedans"),
        ["warrener2"] = vehicle("Warrener HKR", "Vulcar", "warrener2", 1260000, "sedans"),
        ["washington"] = vehicle("Washington", "Albany", "washington", 18000, "sedans"),
    },
    ["suvs"] = {
        ["aleutian"] = vehicle("Aleutian", "Vapid", "aleutian", 1760000, "suvs"),
        ["astron"] = vehicle("Astron", "Pfister", "astron", 1580000, "suvs"),
        ["baller"] = vehicle("Baller", "Gallivanter", "baller", 50000, "suvs"),
        ["baller2"] = vehicle("Baller LE", "Gallivanter", "baller2", 60000, "suvs"),
        ["baller3"] = vehicle("Baller LE LWB", "Gallivanter", "baller3", 70000, "suvs"),
        ["baller4"] = vehicle("Baller LE LWB Armored", "Gallivanter", "baller4", 95000, "suvs"),
        ["bjxl"] = vehicle("BeeJay XL", "Karin", "bjxl", 28000, "suvs"),
        ["cavalcade"] = vehicle("Cavalcade", "Albany", "cavalcade", 35000, "suvs"),
        ["cavalcade2"] = vehicle("Cavalcade II", "Albany", "cavalcade2", 42000, "suvs"),
        ["cavalcade3"] = vehicle("Cavalcade XL", "Albany", "cavalcade3", 1790000, "suvs"),
        ["dorado"] = vehicle("Dorado", "Bravado", "dorado", 1985000, "suvs"),
        ["dubsta"] = vehicle("Dubsta", "Benefactor", "dubsta", 60000, "suvs"),
        ["dubsta2"] = vehicle("Dubsta Luxury", "Benefactor", "dubsta2", 70000, "suvs"),
        ["fq2"] = vehicle("FQ 2", "Fathom", "fq2", 32000, "suvs"),
        ["granger"] = vehicle("Granger", "Declasse", "granger", 45000, "suvs"),
        ["granger2"] = vehicle("Granger 3600LX", "Declasse", "granger2", 95000, "suvs"),
        ["gresley"] = vehicle("Gresley", "Bravado", "gresley", 34000, "suvs"),
        ["habanero"] = vehicle("Habanero", "Emperor", "habanero", 30000, "suvs"),
        ["huntley"] = vehicle("Huntley S", "Enus", "huntley", 65000, "suvs"),
        ["issi8"] = vehicle("Issi Rally", "Grotti", "issi8", 1835000, "suvs"),
        ["iwagen"] = vehicle("I-Wagen", "Obey", "iwagen", 1720000, "suvs"),
        ["jubilee"] = vehicle("Jubilee", "Enus", "jubilee", 160000, "suvs"),
        ["landstalker"] = vehicle("Landstalker", "Dundreary", "landstalker", 38000, "suvs"),
        ["landstalker2"] = vehicle("Landstalker XL", "Dundreary", "landstalker2", 1220000, "suvs"),
        ["mesa"] = vehicle("Mesa", "Canis", "mesa", 30000, "suvs"),
        ["novak"] = vehicle("Novak", "Lampadati", "novak", 90000, "suvs"),
        ["patriot"] = vehicle("Patriot", "Mammoth", "patriot", 45000, "suvs"),
        ["patriot2"] = vehicle("Patriot Stretch", "Mammoth", "patriot2", 90000, "suvs"),
        ["radi"] = vehicle("Radius", "Vapid", "radi", 32000, "suvs"),
        ["rebla"] = vehicle("Rebla GTS", "Ubermacht", "rebla", 115000, "suvs"),
        ["rocoto"] = vehicle("Rocoto", "Obey", "rocoto", 55000, "suvs"),
        ["seminole"] = vehicle("Seminole", "Canis", "seminole", 30000, "suvs"),
        ["seminole2"] = vehicle("Seminole Frontier", "Canis", "seminole2", 678000, "suvs"),
        ["serrano"] = vehicle("Serrano", "Benefactor", "serrano", 48000, "suvs"),
        ["squaddie"] = vehicle("Squaddie", "Mammoth", "squaddie", 1130000, "suvs"),
        ["toros"] = vehicle("Toros", "Pegassi", "toros", 125000, "suvs"),
        ["vivanite"] = vehicle("Vivanite", "Karin", "vivanite", 1805000, "suvs"),
        ["xls"] = vehicle("XLS", "Benefactor", "xls", 80000, "suvs"),
    },
    ["muscle"] = {
        ["blade"] = vehicle("Blade", "Vapid", "blade", 28000, "muscle"),
        ["brigham"] = vehicle("Brigham", "Albany", "brigham", 1790000, "muscle"),
        ["broadway"] = vehicle("Broadway", "Classique", "broadway", 925000, "muscle"),
        ["buccaneer"] = vehicle("Buccaneer", "Albany", "buccaneer", 26000, "muscle"),
        ["buccaneer2"] = vehicle("Buccaneer Custom", "Albany", "buccaneer2", 390000, "muscle"),
        ["buffalo4"] = vehicle("Buffalo STX", "Bravado", "buffalo4", 2150000, "muscle"),
        ["buffalo5"] = vehicle("Buffalo EVX", "Bravado", "buffalo5", 2140000, "muscle"),
        ["chino"] = vehicle("Chino", "Vapid", "chino", 30000, "muscle"),
        ["chino2"] = vehicle("Chino Custom", "Vapid", "chino2", 180000, "muscle"),
        ["clique"] = vehicle("Clique", "Vapid", "clique", 42000, "muscle"),
        ["clique2"] = vehicle("Clique Wagon", "Vapid", "clique2", 1848000, "muscle"),
        ["coquette3"] = vehicle("Coquette BlackFin", "Vapid", "coquette3", 695000, "muscle"),
        ["deviant"] = vehicle("Deviant", "Schyster", "deviant", 48000, "muscle"),
        ["dominator"] = vehicle("Dominator", "Vapid", "dominator", 38000, "muscle"),
        ["dominator2"] = vehicle("Pisswasser Dominator", "Vapid", "dominator2", 315000, "muscle"),
        ["dominator3"] = vehicle("Dominator GTX", "Vapid", "dominator3", 70000, "muscle"),
        ["dominator7"] = vehicle("Dominator ASP", "Vapid", "dominator7", 95000, "muscle"),
        ["dominator8"] = vehicle("Dominator GTT", "Vapid", "dominator8", 85000, "muscle"),
        ["dominator9"] = vehicle("Dominator GT", "Vapid", "dominator9", 2195000, "muscle"),
        ["dominator10"] = vehicle("Dominator FX", "Vapid", "dominator10", 32702, "muscle", nil, "dominator10.webp"),
        ["dukes"] = vehicle("Dukes", "Imponte", "dukes", 32000, "muscle"),
        ["dukes3"] = vehicle("Beater Dukes", "Imponte", "dukes3", 378000, "muscle"),
        ["ellie"] = vehicle("Ellie", "Vapid", "ellie", 55000, "muscle"),
        ["eudora"] = vehicle("Eudora", "Willard", "eudora", 1250000, "muscle"),
        ["faction"] = vehicle("Faction", "Willard", "faction", 36000, "muscle"),
        ["faction2"] = vehicle("Faction Custom", "Willard", "faction2", 335000, "muscle"),
        ["faction3"] = vehicle("Faction Custom Donk", "Willard", "faction3", 695000, "muscle"),
        ["gauntlet"] = vehicle("Gauntlet", "Bravado", "gauntlet", 36000, "muscle"),
        ["gauntlet2"] = vehicle("Redwood Gauntlet", "Bravado", "gauntlet2", 230000, "muscle"),
        ["gauntlet3"] = vehicle("Gauntlet Classic", "Bravado", "gauntlet3", 65000, "muscle"),
        ["gauntlet4"] = vehicle("Gauntlet Hellfire", "Bravado", "gauntlet4", 90000, "muscle"),
        ["gauntlet5"] = vehicle("Gauntlet Classic Custom", "Bravado", "gauntlet5", 815000, "muscle"),
        ["greenwood"] = vehicle("Greenwood", "Bravado", "greenwood", 52000, "muscle"),
        ["hermes"] = vehicle("Hermes", "Albany", "hermes", 50000, "muscle"),
        ["hotknife"] = vehicle("Hotknife", "Vapid", "hotknife", 75000, "muscle"),
        ["hustler"] = vehicle("Hustler", "Vapid", "hustler", 625000, "muscle"),
        ["impaler"] = vehicle("Impaler", "Declasse", "impaler", 42000, "muscle"),
        ["impaler6"] = vehicle("Impaler LX", "Declasse", "impaler6", 1657500, "muscle"),
        ["lurcher"] = vehicle("Lurcher", "Albany", "lurcher", 650000, "muscle"),
        ["manana2"] = vehicle("Manana Custom", "Albany", "manana2", 925000, "muscle"),
        ["moonbeam"] = vehicle("Moonbeam", "Declasse", "moonbeam", 32500, "muscle"),
        ["moonbeam2"] = vehicle("Moonbeam Custom", "Declasse", "moonbeam2", 370000, "muscle"),
        ["nightshade"] = vehicle("Nightshade", "Imponte", "nightshade", 70000, "muscle"),
        ["peyote2"] = vehicle("Peyote Gasser", "Vapid", "peyote2", 805000, "muscle"),
        ["phoenix"] = vehicle("Phoenix", "Imponte", "phoenix", 32000, "muscle"),
        ["picador"] = vehicle("Picador", "Cheval", "picador", 26000, "muscle"),
        ["ratloader"] = vehicle("Rat-Loader", "Bravado", "ratloader", 6000, "muscle"),
        ["ratloader2"] = vehicle("Rat-Truck", "Bravado", "ratloader2", 37500, "muscle"),
        ["ruiner"] = vehicle("Ruiner", "Imponte", "ruiner", 30000, "muscle"),
        ["ruiner4"] = vehicle("Ruiner ZZ-8", "Imponte", "ruiner4", 1320000, "muscle"),
        ["sabregt"] = vehicle("Sabre Turbo", "Declasse", "sabregt", 34000, "muscle"),
        ["sabregt2"] = vehicle("Sabre Turbo Custom", "Declasse", "sabregt2", 490000, "muscle"),
        ["slamvan"] = vehicle("Slamvan", "Vapid", "slamvan", 36000, "muscle"),
        ["slamvan2"] = vehicle("Lost Slamvan", "Vapid", "slamvan2", 49500, "muscle"),
        ["slamvan3"] = vehicle("Slamvan Custom", "Vapid", "slamvan3", 415000, "muscle"),
        ["stalion"] = vehicle("Stalion", "Declasse", "stalion", 71000, "muscle"),
        ["tahoma"] = vehicle("Tahoma Coupe", "Declasse", "tahoma", 1500000, "muscle"),
        ["tampa"] = vehicle("Tampa", "Declasse", "tampa", 36000, "muscle"),
        ["tulip"] = vehicle("Tulip", "Declasse", "tulip", 45000, "muscle"),
        ["tulip2"] = vehicle("Tulip M-100", "Declasse", "tulip2", 100000, "muscle"),
        ["vamos"] = vehicle("Vamos", "Declasse", "vamos", 46000, "muscle"),
        ["vigero"] = vehicle("Vigero", "Declasse", "vigero", 32000, "muscle"),
        ["vigero2"] = vehicle("Vigero ZX", "Declasse", "vigero2", 95000, "muscle"),
        ["vigero3"] = vehicle("Vigero ZX Convertible", "Declasse", "vigero3", 100000, "muscle"),
        ["virgo"] = vehicle("Virgo", "Albany", "virgo", 30000, "muscle"),
        ["virgo2"] = vehicle("Virgo Classic Custom", "Dundreary", "virgo2", 415000, "muscle"),
        ["virgo3"] = vehicle("Virgo Classic", "Dundreary", "virgo3", 165000, "muscle"),
        ["voodoo"] = vehicle("Voodoo", "Declasse", "voodoo", 26000, "muscle"),
        ["voodoo2"] = vehicle("Voodoo", "Declasse", "voodoo2", 5500, "muscle"),
        ["weevil2"] = vehicle("Weevil Custom", "BF", "weevil2", 980000, "muscle"),
        ["yosemite"] = vehicle("Yosemite", "Declasse", "yosemite", 45000, "muscle"),
        ["yosemite2"] = vehicle("Yosemite Rancher", "Declasse", "yosemite2", 700000, "muscle"),
    },
    ["sports"] = {
        ["alpha"] = vehicle("Alpha", "Albany", "alpha", 60000, "sports"),
        ["banshee"] = vehicle("Banshee", "Bravado", "banshee", 85000, "sports"),
        ["bestiagts"] = vehicle("Bestia GTS", "Grotti", "bestiagts", 110000, "sports"),
        ["blista2"] = vehicle("Blista Compact", "Dinka", "blista2", 42000, "sports"),
        ["blista3"] = vehicle("Go Go Monkey Blista", "Dinka", "blista3", 42000, "sports"),
        ["buffalo"] = vehicle("Buffalo", "Bravado", "buffalo", 42000, "sports"),
        ["buffalo2"] = vehicle("Buffalo S", "Bravado", "buffalo2", 52000, "sports"),
        ["buffalo3"] = vehicle("Sprunk Buffalo", "Bravado", "buffalo3", 96000, "sports"),
        ["calico"] = vehicle("Calico GTF", "Karin", "calico", 1995000, "sports"),
        ["carbonizzare"] = vehicle("Carbonizzare", "Grotti", "carbonizzare", 95000, "sports"),
        ["comet2"] = vehicle("Comet", "Pfister", "comet2", 90000, "sports"),
        ["comet3"] = vehicle("Comet Retro Custom", "Pfister", "comet3", 115000, "sports"),
        ["comet4"] = vehicle("Comet Safari", "Pfister", "comet4", 710000, "sports"),
        ["comet5"] = vehicle("Comet SR", "Pfister", "comet5", 135000, "sports"),
        ["comet6"] = vehicle("Comet S2", "Pfister", "comet6", 1878000, "sports"),
        ["comet7"] = vehicle("Comet S2 Cabrio", "Pfister", "comet7", 1797000, "sports"),
        ["coquette"] = vehicle("Coquette", "Invetero", "coquette", 90000, "sports"),
        ["coquette4"] = vehicle("Coquette D10", "Invetero", "coquette4", 1510000, "sports"),
        ["corsita"] = vehicle("Corsita", "Lampadati", "corsita", 1795000, "sports"),
        ["coureur"] = vehicle("La Coureuse", "Classique", "coureur", 1925000, "sports"),
        ["cypher"] = vehicle("Cypher", "Ubermacht", "cypher", 115000, "sports"),
        ["drafter"] = vehicle("8F Drafter", "Obey", "drafter", 110000, "sports"),
        ["elegy"] = vehicle("Elegy Retro Custom", "Annis", "elegy", 100000, "sports"),
        ["elegy2"] = vehicle("Elegy RH8", "Annis", "elegy2", 85000, "sports"),
        ["euros"] = vehicle("Euros", "Annis", "euros", 95000, "sports"),
        ["eurosx32"] = vehicle("Euros X32", "Annis", "eurosx32", 100000, "sports"),
        ["feltzer2"] = vehicle("Feltzer", "Benefactor", "feltzer2", 70000, "sports"),
        ["firebolt"] = vehicle("Firebolt ASP", "Vapid", "firebolt", 96110, "sports"),
        ["flashgt"] = vehicle("Flash GT", "Vapid", "flashgt", 90000, "sports"),
        ["furoregt"] = vehicle("Furore GT", "Lampadati", "furoregt", 75000, "sports"),
        ["fusilade"] = vehicle("Fusilade", "Schyster", "fusilade", 40000, "sports"),
        ["futo"] = vehicle("Futo", "Karin", "futo", 32000, "sports"),
        ["futo2"] = vehicle("Futo GTX", "Karin", "futo2", 65000, "sports"),
        ["gb200"] = vehicle("GB200", "Vapid", "gb200", 940000, "sports"),
        ["growler"] = vehicle("Growler", "Pfister", "growler", 145000, "sports"),
        ["imorgon"] = vehicle("Imorgon", "Overflod", "imorgon", 2165000, "sports"),
        ["issi7"] = vehicle("Issi Sport", "Weeny", "issi7", 897000, "sports"),
        ["italigto"] = vehicle("Itali GTO", "Grotti", "italigto", 155000, "sports"),
        ["italirsx"] = vehicle("Itali RSX", "Grotti", "italirsx", 3465000, "sports"),
        ["jester"] = vehicle("Jester", "Dinka", "jester", 90000, "sports"),
        ["jester2"] = vehicle("Jester (Racecar)", "Dinka", "jester2", 350000, "sports"),
        ["jester3"] = vehicle("Jester Classic", "Dinka", "jester3", 100000, "sports"),
        ["jester4"] = vehicle("Jester RR", "Dinka", "jester4", 130000, "sports"),
        ["jester5"] = vehicle("Jester RR Widebody", "Dinka", "jester5", 79879, "sports", nil, "jester5.webp"),
        ["jugular"] = vehicle("Jugular", "Ocelot", "jugular", 120000, "sports"),
        ["khamelion"] = vehicle("Khamelion", "Hijak", "khamelion", 100000, "sports"),
        ["komoda"] = vehicle("Komoda", "Lampadati", "komoda", 120000, "sports"),
        ["kuruma"] = vehicle("Kuruma", "Karin", "kuruma", 60000, "sports"),
        ["locust"] = vehicle("Locust", "Ocelot", "locust", 105000, "sports"),
        ["lynx"] = vehicle("Lynx", "Ocelot", "lynx", 100000, "sports"),
        ["massacro"] = vehicle("Massacro", "Dewbauchee", "massacro", 95000, "sports"),
        ["massacro2"] = vehicle("Massacro (Racecar)", "Dewbauchee", "massacro2", 385000, "sports"),
        ["neo"] = vehicle("Neo", "Vysser", "neo", 145000, "sports"),
        ["neon"] = vehicle("Neon", "Pfister", "neon", 145000, "sports"),
        ["ninef"] = vehicle("9F", "Obey", "ninef", 85000, "sports"),
        ["ninef2"] = vehicle("9F Cabrio", "Obey", "ninef2", 130000, "sports"),
        ["omnis"] = vehicle("Omnis", "Obey", "omnis", 80000, "sports"),
        ["omnisegt"] = vehicle("Omnis e-GT", "Obey", "omnisegt", 100000, "sports"),
        ["panthere"] = vehicle("Panthere", "Toundra", "panthere", 100000, "sports"),
        ["paragon"] = vehicle("Paragon R", "Enus", "paragon", 145000, "sports"),
        ["paragon3"] = vehicle("Paragon S", "Enus", "paragon3", 100000, "sports"),
        ["pariah"] = vehicle("Pariah", "Ocelot", "pariah", 160000, "sports"),
        ["penumbra"] = vehicle("Penumbra", "Maibatsu", "penumbra", 42000, "sports"),
        ["penumbra2"] = vehicle("Penumbra FF", "Maibatsu", "penumbra2", 75000, "sports"),
        ["r300"] = vehicle("300R", "Declasse", "r300", 100000, "sports"),
        ["raiden"] = vehicle("Raiden", "Coil", "raiden", 1375000, "sports"),
        ["rapidgt"] = vehicle("Rapid GT", "Dewbauchee", "rapidgt", 70000, "sports"),
        ["rapidgt2"] = vehicle("Rapid GT Convertible", "Dewbauchee", "rapidgt2", 76000, "sports"),
        ["raptor"] = vehicle("Raptor", "BF", "raptor", 648000, "sports"),
        ["remus"] = vehicle("Remus", "Annis", "remus", 75000, "sports"),
        ["revolter"] = vehicle("Revolter", "Ubermacht", "revolter", 120000, "sports"),
        ["rt3000"] = vehicle("RT3000", "Dinka", "rt3000", 80000, "sports"),
        ["ruston"] = vehicle("Ruston", "Hijak", "ruston", 430000, "sports"),
        ["schafter3"] = vehicle("Schafter V12", "Benefactor", "schafter3", 116000, "sports"),
        ["schafter4"] = vehicle("Schafter LWB", "Benefactor", "schafter4", 120000, "sports"),
        ["schlagen"] = vehicle("Schlagen GT", "Benefactor", "schlagen", 135000, "sports"),
        ["schwarzer"] = vehicle("Schwartzer", "Benefactor", "schwarzer", 55000, "sports"),
        ["sentinel3"] = vehicle("Sentinel", "Ubermacht", "sentinel3", 650000, "sports"),
        ["sentinel4"] = vehicle("Sentinel Classic Widebody", "Ubermacht", "sentinel4", 700000, "sports"),
        ["seven70"] = vehicle("Seven-70", "Dewbauchee", "seven70", 120000, "sports"),
        ["sm722"] = vehicle("SM722", "Benefactor", "sm722", 2115000, "sports"),
        ["specter"] = vehicle("Specter", "Dewbauchee", "specter", 100000, "sports"),
        ["specter2"] = vehicle("Specter Custom", "Dewbauchee", "specter2", 252000, "sports"),
        ["stingertt"] = vehicle("Itali GTO Stinger TT", "Grotti", "stingertt", 2380000, "sports"),
        ["sugoi"] = vehicle("Sugoi", "Dinka", "sugoi", 1224000, "sports"),
        ["sultan"] = vehicle("Sultan", "Karin", "sultan", 50000, "sports"),
        ["sultan2"] = vehicle("Sultan Classic", "Karin", "sultan2", 85000, "sports"),
        ["sultan3"] = vehicle("Sultan RS Classic", "Karin", "sultan3", 95000, "sports"),
        ["surano"] = vehicle("Surano", "Benefactor", "surano", 70000, "sports"),
        ["tenf"] = vehicle("10F", "Obey", "tenf", 1675000, "sports"),
        ["tenf2"] = vehicle("10F Widebody", "Obey", "tenf2", 1875000, "sports"),
        ["tropos"] = vehicle("Tropos Rallye", "Lampadati", "tropos", 816000, "sports"),
        ["vectre"] = vehicle("Vectre", "Emperor", "vectre", 115000, "sports"),
        ["verlierer2"] = vehicle("Verlierer", "Bravado", "verlierer2", 695000, "sports"),
        ["veto"] = vehicle("Veto Classic", "Dinka", "veto", 895000, "sports"),
        ["veto2"] = vehicle("Veto Modern", "Dinka", "veto2", 995000, "sports"),
        ["vstr"] = vehicle("V-STR", "Albany", "vstr", 120000, "sports"),
        ["zr350"] = vehicle("ZR350", "Annis", "zr350", 95000, "sports"),
    },
    ["sportsclassic"] = {
        ["ardent"] = vehicle("Ardent", "Ocelot", "ardent", 115000, "sportsclassic"),
        ["btype"] = vehicle("Roosevelt", "Albany", "btype", 130000, "sportsclassic"),
        ["btype2"] = vehicle("Franken Stange", "Albany", "btype2", 140000, "sportsclassic"),
        ["btype3"] = vehicle("Roosevelt Valor", "Albany", "btype3", 150000, "sportsclassic"),
        ["casco"] = vehicle("Casco", "Lampadati", "casco", 90000, "sportsclassic"),
        ["cheburek"] = vehicle("Cheburek", "Rune", "cheburek", 145000, "sportsclassic"),
        ["cheetah2"] = vehicle("Cheetah Classic", "Grotti", "cheetah2", 160000, "sportsclassic"),
        ["cheetah3"] = vehicle("Cheetah (1987)", "Grotti", "cheetah3", 82724, "sportsclassic", nil, "cheetah3.webp"),
        ["coquette2"] = vehicle("Coquette Classic", "Invetero", "coquette2", 90000, "sportsclassic"),
        ["deluxo"] = vehicle("Deluxo", "Imponte", "deluxo", 4721500, "sportsclassic"),
        ["dynasty"] = vehicle("Dynasty", "Weeny", "dynasty", 40000, "sportsclassic"),
        ["fagaloa"] = vehicle("Fagaloa", "Vulcar", "fagaloa", 335000, "sportsclassic"),
        ["feltzer3"] = vehicle("Stirling GT", "Benefactor", "feltzer3", 125000, "sportsclassic"),
        ["gt500"] = vehicle("GT500", "Grotti", "gt500", 130000, "sportsclassic"),
        ["infernus2"] = vehicle("Infernus Classic", "Pegassi", "infernus2", 150000, "sportsclassic"),
        ["jb700"] = vehicle("JB 700", "Dewbauchee", "jb700", 130000, "sportsclassic"),
        ["jb7002"] = vehicle("JB 700W", "Dewbauchee", "jb7002", 1470000, "sportsclassic"),
        ["mamba"] = vehicle("Mamba", "Declasse", "mamba", 125000, "sportsclassic"),
        ["manana"] = vehicle("Manana", "Albany", "manana", 10000, "sportsclassic"),
        ["michelli"] = vehicle("Michelli GT", "Lampadati", "michelli", 1225000, "sportsclassic"),
        ["monroe"] = vehicle("Monroe", "Pegassi", "monroe", 130000, "sportsclassic"),
        ["nebula"] = vehicle("Nebula Turbo", "Vulcar", "nebula", 65000, "sportsclassic"),
        ["peyote"] = vehicle("Peyote", "Vapid", "peyote", 45000, "sportsclassic"),
        ["peyote3"] = vehicle("Peyote Custom", "Vapid", "peyote3", 378000, "sportsclassic"),
        ["pigalle"] = vehicle("Pigalle", "Lampadati", "pigalle", 400000, "sportsclassic"),
        ["rapidgt3"] = vehicle("Rapid GT Classic", "Dewbauchee", "rapidgt3", 110000, "sportsclassic"),
        ["retinue"] = vehicle("Retinue", "Vapid", "retinue", 65000, "sportsclassic"),
        ["retinue2"] = vehicle("Retinue Mk II", "Vapid", "retinue2", 1620000, "sportsclassic"),
        ["savestra"] = vehicle("Savestra", "Annis", "savestra", 80000, "sportsclassic"),
        ["stinger"] = vehicle("Stinger", "Grotti", "stinger", 125000, "sportsclassic"),
        ["stingergt"] = vehicle("Stinger GT", "Grotti", "stingergt", 135000, "sportsclassic"),
        ["stromberg"] = vehicle("Stromberg", "Ocelot", "stromberg", 3185350, "sportsclassic"),
        ["swinger"] = vehicle("Swinger", "Ocelot", "swinger", 120000, "sportsclassic"),
        ["toreador"] = vehicle("Toreador", "Pegassi", "toreador", 3660000, "sportsclassic"),
        ["torero"] = vehicle("Torero", "Pegassi", "torero", 150000, "sportsclassic"),
        ["tornado"] = vehicle("Tornado", "Declasse", "tornado", 30000, "sportsclassic"),
        ["tornado2"] = vehicle("Tornado", "Declasse", "tornado2", 30000, "sportsclassic"),
        ["tornado3"] = vehicle("Tornado", "Declasse", "tornado3", 30000, "sportsclassic"),
        ["tornado4"] = vehicle("Tornado", "Declasse", "tornado4", 30000, "sportsclassic"),
        ["tornado5"] = vehicle("Tornado Custom", "Declasse", "tornado5", 375000, "sportsclassic"),
        ["tornado6"] = vehicle("Tornado Rat Rod", "Declasse", "tornado6", 378000, "sportsclassic"),
        ["turismo2"] = vehicle("Turismo Classic", "Grotti", "turismo2", 160000, "sportsclassic"),
        ["viseris"] = vehicle("Viseris", "Lampadati", "viseris", 875000, "sportsclassic"),
        ["z190"] = vehicle("190z", "Karin", "z190", 90000, "sportsclassic"),
        ["zion3"] = vehicle("Zion Classic", "Ubermacht", "zion3", 70000, "sportsclassic"),
        ["ztype"] = vehicle("Z-Type", "Truffade", "ztype", 950000, "sportsclassic"),
    },
    ["super"] = {
        ["adder"] = vehicle("Adder", "Truffade", "adder", 300000, "super"),
        ["autarch"] = vehicle("Autarch", "Overflod", "autarch", 425000, "super"),
        ["banshee2"] = vehicle("Banshee 900R", "Bravado", "banshee2", 220000, "super"),
        ["banshee3"] = vehicle("Banshee GTS", "Bravado", "banshee3", 100000, "super"),
        ["bullet"] = vehicle("Bullet", "Vapid", "bullet", 180000, "super"),
        ["champion"] = vehicle("Champion", "Dewbauchee", "champion", 550000, "super"),
        ["cheetah"] = vehicle("Cheetah", "Grotti", "cheetah", 240000, "super"),
        ["cyclone"] = vehicle("Cyclone", "Coil", "cyclone", 375000, "super"),
        ["deveste"] = vehicle("Deveste Eight", "Principe", "deveste", 550000, "super"),
        ["emerus"] = vehicle("Emerus", "Progen", "emerus", 550000, "super"),
        ["entity2"] = vehicle("Entity XXR", "Overflod", "entity2", 500000, "super"),
        ["entity3"] = vehicle("Entity MT", "Overflod", "entity3", 100000, "super"),
        ["entityxf"] = vehicle("Entity XF", "Overflod", "entityxf", 320000, "super"),
        ["fmj"] = vehicle("FMJ", "Vapid", "fmj", 380000, "super"),
        ["furia"] = vehicle("Furia", "Grotti", "furia", 100000, "super"),
        ["gp1"] = vehicle("GP1", "Progen", "gp1", 360000, "super"),
        ["ignus"] = vehicle("Ignus", "Pegassi", "ignus", 600000, "super"),
        ["infernus"] = vehicle("Infernus", "Pegassi", "infernus", 260000, "super"),
        ["italigtb"] = vehicle("Itali GTB", "Progen", "italigtb", 340000, "super"),
        ["italigtb2"] = vehicle("Itali GTB Custom", "Progen", "italigtb2", 380000, "super"),
        ["krieger"] = vehicle("Krieger", "Benefactor", "krieger", 600000, "super"),
        ["le7b"] = vehicle("RE-7B", "Annis", "le7b", 450000, "super"),
        ["lm87"] = vehicle("LM87", "Benefactor", "lm87", 100000, "super"),
        ["nero"] = vehicle("Nero", "Truffade", "nero", 420000, "super"),
        ["nero2"] = vehicle("Nero Custom", "Truffade", "nero2", 470000, "super"),
        ["osiris"] = vehicle("Osiris", "Pegassi", "osiris", 360000, "super"),
        ["penetrator"] = vehicle("Penetrator", "Ocelot", "penetrator", 280000, "super"),
        ["pfister811"] = vehicle("811", "Pfister", "pfister811", 360000, "super"),
        ["prototipo"] = vehicle("X80 Proto", "Grotti", "prototipo", 700000, "super"),
        ["reaper"] = vehicle("Reaper", "Pegassi", "reaper", 380000, "super"),
        ["s80"] = vehicle("S80RR", "Annis", "s80", 600000, "super"),
        ["sc1"] = vehicle("SC1", "Ubermacht", "sc1", 320000, "super"),
        ["sheava"] = vehicle("ETR1", "Emperor", "sheava", 1995000, "super"),
        ["sultanrs"] = vehicle("Sultan RS", "Karin", "sultanrs", 795000, "super"),
        ["t20"] = vehicle("T20", "Progen", "t20", 450000, "super"),
        ["taipan"] = vehicle("Taipan", "Cheval", "taipan", 420000, "super"),
        ["tempesta"] = vehicle("Tempesta", "Pegassi", "tempesta", 350000, "super"),
        ["tezeract"] = vehicle("Tezeract", "Pegassi", "tezeract", 650000, "super"),
        ["thrax"] = vehicle("Thrax", "Truffade", "thrax", 550000, "super"),
        ["tigon"] = vehicle("Tigon", "Lampadati", "tigon", 420000, "super"),
        ["torero2"] = vehicle("Torero XO", "Pegassi", "torero2", 2890000, "super"),
        ["turismo3"] = vehicle("Turismo Omaggio", "Grotti", "turismo3", 2845000, "super"),
        ["turismor"] = vehicle("Turismo R", "Grotti", "turismor", 300000, "super"),
        ["tyrant"] = vehicle("Tyrant", "Overflod", "tyrant", 480000, "super"),
        ["tyrus"] = vehicle("Tyrus", "Progen", "tyrus", 500000, "super"),
        ["vacca"] = vehicle("Vacca", "Pegassi", "vacca", 260000, "super"),
        ["vagner"] = vehicle("Vagner", "Dewbauchee", "vagner", 450000, "super"),
        ["virtue"] = vehicle("Virtue", "Ocelot", "virtue", 500000, "super"),
        ["visione"] = vehicle("Visione", "Grotti", "visione", 450000, "super"),
        ["voltic"] = vehicle("Voltic", "Coil", "voltic", 150000, "super"),
        ["xa21"] = vehicle("XA-21", "Ocelot", "xa21", 420000, "super"),
        ["zeno"] = vehicle("Zeno", "Overflod", "zeno", 2820000, "super"),
        ["zentorno"] = vehicle("Zentorno", "Pegassi", "zentorno", 400000, "super"),
        ["zorrusso"] = vehicle("Zorrusso", "Pegassi", "zorrusso", 520000, "super"),
    },
    ["motorcycles"] = {
        ["akuma"] = vehicle("Akuma", "Dinka", "akuma", 25000, "motorcycles"),
        ["avarus"] = vehicle("Avarus", "LCC", "avarus", 30000, "motorcycles"),
        ["bagger"] = vehicle("Bagger", "Western", "bagger", 22000, "motorcycles"),
        ["bati"] = vehicle("Bati 801", "Pegassi", "bati", 32000, "motorcycles"),
        ["bati2"] = vehicle("Bati 801RR", "Pegassi", "bati2", 35000, "motorcycles"),
        ["bf400"] = vehicle("BF400", "Nagasaki", "bf400", 34000, "motorcycles"),
        ["carbonrs"] = vehicle("Carbon RS", "Nagasaki", "carbonrs", 42000, "motorcycles"),
        ["chimera"] = vehicle("Chimera", "Nagasaki", "chimera", 42000, "motorcycles"),
        ["cliffhanger"] = vehicle("Cliffhanger", "Western", "cliffhanger", 225000, "motorcycles"),
        ["daemon"] = vehicle("Daemon", "Western", "daemon", 25000, "motorcycles"),
        ["daemon2"] = vehicle("Daemon Custom", "Western", "daemon2", 145000, "motorcycles"),
        ["defiler"] = vehicle("Defiler", "Shitzu", "defiler", 38000, "motorcycles"),
        ["diablous"] = vehicle("Diablous", "Principe", "diablous", 169000, "motorcycles"),
        ["diablous2"] = vehicle("Diablous Custom", "Principe", "diablous2", 245000, "motorcycles"),
        ["double"] = vehicle("Double-T", "Dinka", "double", 36000, "motorcycles"),
        ["enduro"] = vehicle("Enduro", "Dinka", "enduro", 24000, "motorcycles"),
        ["esskey"] = vehicle("Esskey", "Pegassi", "esskey", 264000, "motorcycles"),
        ["faggio"] = vehicle("Faggio Sport", "Pegassi", "faggio", 12000, "motorcycles"),
        ["faggio2"] = vehicle("Faggio", "Pegassi", "faggio2", 10000, "motorcycles"),
        ["faggio3"] = vehicle("Faggio Mod", "Pegassi", "faggio3", 55000, "motorcycles"),
        ["fcr"] = vehicle("FCR 1000", "Pegassi", "fcr", 135000, "motorcycles"),
        ["fcr2"] = vehicle("FCR 1000 Custom", "Pegassi", "fcr2", 196000, "motorcycles"),
        ["gargoyle"] = vehicle("Gargoyle", "Western", "gargoyle", 42000, "motorcycles"),
        ["hakuchou"] = vehicle("Hakuchou", "Shitzu", "hakuchou", 45000, "motorcycles"),
        ["hakuchou2"] = vehicle("Hakuchou Drag", "Shitzu", "hakuchou2", 60000, "motorcycles"),
        ["hexer"] = vehicle("Hexer", "LCC", "hexer", 25000, "motorcycles"),
        ["innovation"] = vehicle("Innovation", "LCC", "innovation", 32000, "motorcycles"),
        ["lectro"] = vehicle("Lectro", "Principe", "lectro", 700000, "motorcycles"),
        ["manchez"] = vehicle("Manchez", "Maibatsu", "manchez", 30000, "motorcycles"),
        ["manchez2"] = vehicle("Manchez Scout", "Maibatsu", "manchez2", 225000, "motorcycles"),
        ["manchez3"] = vehicle("Manchez Scout C", "Maibatsu", "manchez3", 1995000, "motorcycles"),
        ["nemesis"] = vehicle("Nemesis", "Principe", "nemesis", 26000, "motorcycles"),
        ["nightblade"] = vehicle("Nightblade", "Western", "nightblade", 42000, "motorcycles"),
        ["pcj"] = vehicle("PCJ 600", "Shitzu", "pcj", 24000, "motorcycles"),
        ["powersurge"] = vehicle("Powersurge", "Western", "powersurge", 1605000, "motorcycles"),
        ["ratbike"] = vehicle("Rat Bike", "Western", "ratbike", 48000, "motorcycles"),
        ["reever"] = vehicle("Reever", "Western", "reever", 1900000, "motorcycles"),
        ["ruffian"] = vehicle("Ruffian", "Pegassi", "ruffian", 26000, "motorcycles"),
        ["sanchez"] = vehicle("Sanchez", "Maibatsu", "sanchez", 24000, "motorcycles"),
        ["sanchez2"] = vehicle("Sanchez Livery", "Maibatsu", "sanchez2", 25000, "motorcycles"),
        ["sanctus"] = vehicle("Sanctus", "LCC", "sanctus", 1995000, "motorcycles"),
        ["shinobi"] = vehicle("Shinobi", "Nagasaki", "shinobi", 2480500, "motorcycles"),
        ["sovereign"] = vehicle("Sovereign", "Western", "sovereign", 35000, "motorcycles"),
        ["stryder"] = vehicle("Stryder", "Nagasaki", "stryder", 670000, "motorcycles"),
        ["thrust"] = vehicle("Thrust", "Dinka", "thrust", 75000, "motorcycles"),
        ["vader"] = vehicle("Vader", "Shitzu", "vader", 25000, "motorcycles"),
        ["vindicator"] = vehicle("Vindicator", "Dinka", "vindicator", 630000, "motorcycles"),
        ["vortex"] = vehicle("Vortex", "Pegassi", "vortex", 36000, "motorcycles"),
        ["wolfsbane"] = vehicle("Wolfsbane", "Western", "wolfsbane", 32000, "motorcycles"),
        ["zombiea"] = vehicle("Zombie Bobber", "Western", "zombiea", 99000, "motorcycles"),
        ["zombieb"] = vehicle("Zombie Chopper", "Western", "zombieb", 122000, "motorcycles"),
    },
    ["off-road"] = {
        ["bfinjection"] = vehicle("BF Injection", "BF", "bfinjection", 22000, "off-road"),
        ["bifta"] = vehicle("Bifta", "BF", "bifta", 26000, "off-road"),
        ["blazer"] = vehicle("Blazer", "Nagasaki", "blazer", 16000, "off-road"),
        ["blazer2"] = vehicle("Blazer Lifeguard", "Nagasaki", "blazer2", 8000, "off-road"),
        ["blazer3"] = vehicle("Hot Rod Blazer", "Nagasaki", "blazer3", 69000, "off-road"),
        ["blazer4"] = vehicle("Street Blazer", "Nagasaki", "blazer4", 22000, "off-road"),
        ["blazer5"] = vehicle("Blazer Aqua", "Nagasaki", "blazer5", 75600, "off-road"),
        ["bodhi2"] = vehicle("Bodhi", "Canis", "bodhi2", 26000, "off-road"),
        ["boor"] = vehicle("Boor", "Karin", "boor", 1280000, "off-road"),
        ["brawler"] = vehicle("Brawler", "Coil", "brawler", 70000, "off-road"),
        ["caracara2"] = vehicle("Caracara 4x4", "Vapid", "caracara2", 75000, "off-road"),
        ["dloader"] = vehicle("Duneloader", "Bravado", "dloader", 20000, "off-road"),
        ["draugur"] = vehicle("Draugur", "Declasse", "draugur", 1870000, "off-road"),
        ["dubsta3"] = vehicle("Dubsta 6x6", "Benefactor", "dubsta3", 85000, "off-road"),
        ["dune"] = vehicle("Dune Buggy", "BF", "dune", 20000, "off-road"),
        ["everon"] = vehicle("Everon", "Karin", "everon", 80000, "off-road"),
        ["freecrawler"] = vehicle("Freecrawler", "Canis", "freecrawler", 70000, "off-road"),
        ["hellion"] = vehicle("Hellion", "Annis", "hellion", 58000, "off-road"),
        ["kalahari"] = vehicle("Kalahari", "Canis", "kalahari", 24000, "off-road"),
        ["kamacho"] = vehicle("Kamacho", "Canis", "kamacho", 70000, "off-road"),
        ["mesa3"] = vehicle("Mesa Off-Road", "Canis", "mesa3", 45000, "off-road"),
        ["nightshark"] = vehicle("Nightshark", "HVY", "nightshark", 1245000, "off-road"),
        ["outlaw"] = vehicle("Outlaw", "Nagasaki", "outlaw", 50000, "off-road"),
        ["patriot3"] = vehicle("Patriot Mil-Spec", "Mammoth", "patriot3", 1710000, "off-road"),
        ["rancherxl"] = vehicle("Rancher XL", "Declasse", "rancherxl", 32000, "off-road"),
        ["rebel"] = vehicle("Rusty Rebel", "Karin", "rebel", 15000, "off-road"),
        ["rebel2"] = vehicle("Rebel", "Karin", "rebel2", 22000, "off-road"),
        ["riata"] = vehicle("Riata", "Vapid", "riata", 55000, "off-road"),
        ["sandking"] = vehicle("Sandking XL", "Vapid", "sandking", 50000, "off-road"),
        ["sandking2"] = vehicle("Sandking SWB", "Vapid", "sandking2", 48000, "off-road"),
        ["streiter"] = vehicle("Streiter SX", "Benefactor", "streiter", 500000, "off-road"),
        ["trophytruck"] = vehicle("Trophy Truck", "Vapid", "trophytruck", 90000, "off-road"),
        ["trophytruck2"] = vehicle("Desert Raid", "Vapid", "trophytruck2", 95000, "off-road"),
        ["vagrant"] = vehicle("Vagrant", "Maxwell", "vagrant", 85000, "off-road"),
        ["verus"] = vehicle("Verus", "Dinka", "verus", 26000, "off-road"),
        ["winky"] = vehicle("Winky", "Vapid", "winky", 40000, "off-road"),
        ["yosemite3"] = vehicle("Yosemite Rancher", "Declasse", "yosemite3", 58000, "off-road"),
    },
    ["trucks"] = {
        ["bison"] = vehicle("Bison", "Bravado", "bison", 32000, "trucks"),
        ["bison2"] = vehicle("Bison Civilian", "Bravado", "bison2", 32000, "trucks"),
        ["bobcatxl"] = vehicle("Bobcat XL", "Vapid", "bobcatxl", 30000, "trucks"),
        ["boxville"] = vehicle("Boxville", "Brute", "boxville", 45000, "trucks"),
        ["contender"] = vehicle("Contender", "Vapid", "contender", 250000, "trucks"),
        ["flatbed"] = vehicle("Flatbed", "MTL", "flatbed", 80000, "trucks"),
        ["guardian"] = vehicle("Guardian", "Vapid", "guardian", 85000, "trucks"),
        ["l35"] = vehicle("Walton L35 Offroad", "Declasse", "l35", 64429, "trucks"),
        ["mule"] = vehicle("Mule", "Maibatsu", "mule", 70000, "trucks"),
        ["mule2"] = vehicle("Mule Commercial", "Maibatsu", "mule2", 76000, "trucks"),
        ["packer"] = vehicle("Packer", "MTL", "packer", 120000, "trucks"),
        ["pounder"] = vehicle("Pounder", "MTL", "pounder", 120000, "trucks"),
        ["sadler"] = vehicle("Sadler", "Vapid", "sadler", 32000, "trucks"),
        ["slamtruck"] = vehicle("Slamtruck", "Vapid", "slamtruck", 90000, "trucks"),
        ["stockade"] = vehicle("Stockade", "Brute", "stockade", 130000, "trucks"),
        ["tiptruck"] = vehicle("Tipper", "Brute", "tiptruck", 85000, "trucks"),
        ["tiptruck2"] = vehicle("Tipper II", "Brute", "tiptruck2", 90000, "trucks"),
        ["yosemite1500"] = vehicle("Yosemite 1500", "Declasse", "yosemite1500", 100000, "trucks"),
    },
    ["vans"] = {
        ["bison3"] = vehicle("Bison Utility", "Bravado", "bison3", 34000, "vans"),
        ["burrito"] = vehicle("Burrito", "Declasse", "burrito", 30000, "vans"),
        ["burrito2"] = vehicle("Burrito Utility", "Declasse", "burrito2", 32000, "vans"),
        ["burrito3"] = vehicle("Burrito Work", "Declasse", "burrito3", 32000, "vans"),
        ["burrito4"] = vehicle("Burrito Delivery", "Declasse", "burrito4", 32000, "vans"),
        ["burrito5"] = vehicle("Burrito", "Declasse", "burrito5", 25000, "vans"),
        ["camper"] = vehicle("Camper", "Brute", "camper", 45000, "vans"),
        ["gburrito"] = vehicle("Gang Burrito", "Declasse", "gburrito", 65000, "vans"),
        ["gburrito2"] = vehicle("Gang Burrito", "Declasse", "gburrito2", 65000, "vans"),
        ["journey"] = vehicle("Journey", "Zirconium", "journey", 35000, "vans"),
        ["minivan"] = vehicle("Minivan", "Vapid", "minivan", 28000, "vans"),
        ["minivan2"] = vehicle("Minivan Custom", "Vapid", "minivan2", 40000, "vans"),
        ["paradise"] = vehicle("Paradise", "Bravado", "paradise", 30000, "vans"),
        ["pony"] = vehicle("Pony", "Brute", "pony", 30000, "vans"),
        ["pony2"] = vehicle("Pony Commercial", "Brute", "pony2", 32000, "vans"),
        ["rumpo"] = vehicle("Rumpo", "Bravado", "rumpo", 30000, "vans"),
        ["rumpo2"] = vehicle("Rumpo Commercial", "Bravado", "rumpo2", 32000, "vans"),
        ["rumpo3"] = vehicle("Rumpo Custom", "Bravado", "rumpo3", 50000, "vans"),
        ["speedo"] = vehicle("Speedo", "Vapid", "speedo", 30000, "vans"),
        ["speedo2"] = vehicle("Speedo", "Vapid", "speedo2", 15000, "vans"),
        ["speedo4"] = vehicle("Speedo Custom", "Vapid", "speedo4", 45000, "vans"),
        ["surfer"] = vehicle("Surfer", "BF", "surfer", 26000, "vans"),
        ["surfer2"] = vehicle("Surfer Rusty", "BF", "surfer2", 18000, "vans"),
        ["surfer3"] = vehicle("Surfer Custom", "BF", "surfer3", 90000, "vans"),
        ["taco"] = vehicle("Taco Van", "Declasse", "taco", 25000, "vans"),
        ["youga"] = vehicle("Youga", "Bravado", "youga", 28000, "vans"),
        ["youga2"] = vehicle("Youga Classic", "Bravado", "youga2", 36000, "vans"),
        ["youga3"] = vehicle("Youga Classic 4x4", "Bravado", "youga3", 48000, "vans"),
        ["youga4"] = vehicle("Youga Custom", "Bravado", "youga4", 370000, "vans"),
    },
    ["drift"] = {
        ["driftcypher"] = vehicle("Drift Cypher", "Ubermacht", "driftcypher", 130000, "drift"),
        ["drifteuros"] = vehicle("Drift Euros", "Annis", "drifteuros", 115000, "drift"),
        ["driftfr36"] = vehicle("FR36 (Drift)", "Fathom", "driftfr36", 1990000, "drift"),
        ["driftfuto"] = vehicle("Drift Futo GTX", "Karin", "driftfuto", 90000, "drift"),
        ["driftjester"] = vehicle("Drift Jester RR", "Dinka", "driftjester", 140000, "drift"),
        ["driftremus"] = vehicle("Drift Remus", "Annis", "driftremus", 95000, "drift"),
        ["drifttampa"] = vehicle("Drift Tampa", "Declasse", "drifttampa", 90000, "drift"),
        ["driftyosemite"] = vehicle("Drift Yosemite", "Declasse", "driftyosemite", 85000, "drift"),
        ["driftzr350"] = vehicle("Drift ZR350", "Annis", "driftzr350", 110000, "drift"),
        ["tampa2"] = vehicle("Drift Tampa", "Declasse", "tampa2", 995000, "drift"),
    },
    ["luxury"] = {
        ["baller4"] = vehicle("Baller LE LWB Armored", "Gallivanter", "baller4", 95000, "luxury"),
        ["baller7"] = vehicle("Baller ST", "Gallivanter", "baller7", 890000, "luxury"),
        ["baller8"] = vehicle("Baller ST-D", "Gallivanter", "baller8", 1715000, "luxury"),
        ["cinquemila"] = vehicle("Cinquemila", "Lampadati", "cinquemila", 130000, "luxury"),
        ["cognoscenti"] = vehicle("Cognoscenti", "Enus", "cognoscenti", 95000, "luxury"),
        ["deity"] = vehicle("Deity", "Enus", "deity", 150000, "luxury"),
        ["jubilee"] = vehicle("Jubilee", "Enus", "jubilee", 160000, "luxury"),
        ["paragon"] = vehicle("Paragon R", "Enus", "paragon", 145000, "luxury"),
        ["schafter5"] = vehicle("Schafter V12", "Benefactor", "schafter5", 105000, "luxury"),
        ["schafter6"] = vehicle("Schafter LWB", "Benefactor", "schafter6", 120000, "luxury"),
        ["superd"] = vehicle("Super Diamond", "Enus", "superd", 140000, "luxury"),
        ["tailgater2"] = vehicle("Tailgater S", "Obey", "tailgater2", 105000, "luxury"),
        ["windsor"] = vehicle("Windsor", "Enus", "windsor", 90000, "luxury"),
        ["windsor2"] = vehicle("Windsor Drop", "Enus", "windsor2", 95000, "luxury"),
    },
    ["emergency"] = {
        ["ambulance"] = vehicle("Ambulance", "Brute", "ambulance", 80000, "emergency"),
        ["fbi"] = vehicle("FIB Buffalo", "Bravado", "fbi", 90000, "emergency"),
        ["fbi2"] = vehicle("FIB Granger", "Declasse", "fbi2", 95000, "emergency"),
        ["firetruk"] = vehicle("Fire Truck", "MTL", "firetruk", 150000, "emergency"),
        ["lguard"] = vehicle("Lifeguard Granger", "Declasse", "lguard", 45000, "emergency"),
        ["pbus"] = vehicle("Prison Bus", "Brute", "pbus", 100000, "emergency"),
        ["police"] = vehicle("Police Cruiser", "Vapid", "police", 70000, "emergency"),
        ["police2"] = vehicle("Police Buffalo", "Bravado", "police2", 75000, "emergency"),
        ["police3"] = vehicle("Police Interceptor", "Vapid", "police3", 78000, "emergency"),
        ["police4"] = vehicle("Unmarked Cruiser", "Vapid", "police4", 85000, "emergency"),
        ["policeb"] = vehicle("Police Bike", "Western", "policeb", 45000, "emergency"),
        ["policet"] = vehicle("Police Transporter", "Declasse", "policet", 65000, "emergency"),
        ["pranger"] = vehicle("Park Ranger", "Declasse", "pranger", 65000, "emergency"),
        ["riot"] = vehicle("Riot", "Brute", "riot", 140000, "emergency"),
        ["sheriff"] = vehicle("Sheriff Cruiser", "Vapid", "sheriff", 70000, "emergency"),
        ["sheriff2"] = vehicle("Sheriff SUV", "Declasse", "sheriff2", 80000, "emergency"),
    },
    ["service"] = {
        ["airbus"] = vehicle("Airport Bus", "Brute", "airbus", 80000, "service"),
        ["boxville4"] = vehicle("Post OP Boxville", "Brute", "boxville4", 50000, "service"),
        ["bus"] = vehicle("Bus", "Brute", "bus", 90000, "service"),
        ["coach"] = vehicle("Coach", "Brute", "coach", 110000, "service"),
        ["flatbed"] = vehicle("Flatbed", "MTL", "flatbed", 80000, "service"),
        ["mixer"] = vehicle("Mixer", "HVY", "mixer", 95000, "service"),
        ["rentalbus"] = vehicle("Rental Shuttle Bus", "Brute", "rentalbus", 70000, "service"),
        ["taxi"] = vehicle("Taxi", "Vapid", "taxi", 30000, "service"),
        ["towtruck"] = vehicle("Tow Truck", "Vapid", "towtruck", 65000, "service"),
        ["towtruck2"] = vehicle("Small Tow Truck", "Vapid", "towtruck2", 55000, "service"),
        ["trash"] = vehicle("Trashmaster", "Brute", "trash", 90000, "service"),
        ["trash2"] = vehicle("Trashmaster II", "Brute", "trash2", 95000, "service"),
    },
    ["boats"] = {
        ["dinghy"] = vehicle("Dinghy", "Nagasaki", "dinghy", 45000, "boats", "boat"),
        ["dinghy2"] = vehicle("Dinghy 2-Seater", "Nagasaki", "dinghy2", 40000, "boats", "boat"),
        ["dinghy3"] = vehicle("Dinghy Yacht", "Nagasaki", "dinghy3", 50000, "boats", "boat"),
        ["jetmax"] = vehicle("Jetmax", "Shitzu", "jetmax", 120000, "boats", "boat"),
        ["marquis"] = vehicle("Marquis", "Dinka", "marquis", 160000, "boats", "boat"),
        ["predator"] = {
            name = "Police Predator",
            brand = "Police",
            model = "predator",
            price = 110000,
            category = "boats",
            type = "boat",
            groups = { police = 0 }
        },
        ["seashark"] = vehicle("Seashark", "Speedophile", "seashark", 30000, "boats", "boat"),
        ["seashark2"] = vehicle("Lifeguard Seashark", "Speedophile", "seashark2", 32000, "boats", "boat"),
        ["speeder"] = vehicle("Speeder", "Pegassi", "speeder", 140000, "boats", "boat"),
        ["speeder2"] = vehicle("Speeder Custom", "Pegassi", "speeder2", 150000, "boats", "boat"),
        ["squalo"] = vehicle("Squalo", "Shitzu", "squalo", 95000, "boats", "boat"),
        ["suntrap"] = vehicle("Suntrap", "Shitzu", "suntrap", 70000, "boats", "boat"),
        ["toro"] = vehicle("Toro", "Lampadati", "toro", 180000, "boats", "boat"),
        ["toro2"] = vehicle("Toro Yacht", "Lampadati", "toro2", 190000, "boats", "boat"),
        ["tropic"] = vehicle("Tropic", "Shitzu", "tropic", 80000, "boats", "boat"),
        ["tropic2"] = vehicle("Tropic Yacht", "Shitzu", "tropic2", 90000, "boats", "boat"),
        ["tug"] = vehicle("Tug", "Buckingham", "tug", 160000, "boats", "boat"),
    },
    ["helicopters"] = {
        ["buzzard2"] = vehicle("Buzzard", "Nagasaki", "buzzard2", 850000, "helicopters", "air"),
        ["frogger"] = vehicle("Frogger", "Maibatsu", "frogger", 500000, "helicopters", "air"),
        ["frogger2"] = vehicle("Frogger Executive", "Maibatsu", "frogger2", 540000, "helicopters", "air"),
        ["havok"] = vehicle("Havok", "Nagasaki", "havok", 420000, "helicopters", "air"),
        ["maverick"] = vehicle("Maverick", "Buckingham", "maverick", 450000, "helicopters", "air"),
        ["polmav"] = {
            name = "Police Maverick",
            brand = "Buckingham",
            model = "polmav",
            price = 650000,
            category = "helicopters",
            type = "air",
            groups = { police = 0 }
        },
        ["seasparrow"] = vehicle("Sea Sparrow", "Sparrow", "seasparrow", 620000, "helicopters", "air"),
        ["supervolito"] = vehicle("SuperVolito", "Buckingham", "supervolito", 750000, "helicopters", "air"),
        ["supervolito2"] = vehicle("SuperVolito Carbon", "Buckingham", "supervolito2", 825000, "helicopters", "air"),
        ["swift"] = vehicle("Swift", "Buckingham", "swift", 900000, "helicopters", "air"),
        ["swift2"] = vehicle("Swift Deluxe", "Buckingham", "swift2", 1050000, "helicopters", "air"),
        ["volatus"] = vehicle("Volatus", "Buckingham", "volatus", 1200000, "helicopters", "air"),
    },
    ["planes"] = {
        ["besra"] = vehicle("Besra", "Western", "besra", 950000, "planes", "air"),
        ["cuban800"] = vehicle("Cuban 800", "Western", "cuban800", 310000, "planes", "air"),
        ["dodo"] = vehicle("Dodo", "Mammoth", "dodo", 360000, "planes", "air"),
        ["duster"] = vehicle("Duster", "Western", "duster", 180000, "planes", "air"),
        ["howard"] = vehicle("Howard NX-25", "Buckingham", "howard", 650000, "planes", "air"),
        ["luxor"] = vehicle("Luxor", "Buckingham", "luxor", 1500000, "planes", "air"),
        ["luxor2"] = vehicle("Luxor Deluxe", "Buckingham", "luxor2", 2500000, "planes", "air"),
        ["mammatus"] = vehicle("Mammatus", "Jobuilt", "mammatus", 260000, "planes", "air"),
        ["microlight"] = vehicle("Ultralight", "Nagasaki", "microlight", 220000, "planes", "air"),
        ["nimbus"] = vehicle("Nimbus", "Buckingham", "nimbus", 1900000, "planes", "air"),
        ["shamal"] = vehicle("Shamal", "Buckingham", "shamal", 1350000, "planes", "air"),
        ["stunt"] = vehicle("Mallard", "Western", "stunt", 295000, "planes", "air"),
        ["velum"] = vehicle("Velum", "Jobuilt", "velum", 320000, "planes", "air"),
        ["velum2"] = vehicle("Velum 5-Seater", "Jobuilt", "velum2", 360000, "planes", "air"),
        ["vestra"] = vehicle("Vestra", "Buckingham", "vestra", 875000, "planes", "air"),
    },
}
