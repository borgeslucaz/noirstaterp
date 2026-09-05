Config = {}

Config.locales = {}

Config.Locale = "en"

Config.Interaction = "target"

Config.PricePerMile = 5

Config.Job = false

Config.Security = {
    StartDistance = 7.5,
    FinishDistance = 8.0,
    InvoiceDistance = 8.0,
    MinJobSeconds = 5,
    MaxMetersPerSecond = 200.0,
    MinTripMeters = 0.0,
    MinTripSeconds = 5,
    RL_StartJobMs = 3000,
    RL_UpdateStateMs = 250,
    RL_InvoiceMs = 1500,
    RL_TripMs = 1500,
    RL_FinishJobMs = 3000,
    RL_PayBillMs = 1500,
    MaxMeterTargets = 6,
}

Config.Keys = {
    ["mouse"] = {
        desc = "Enable mouse cursor",
        key = "m"
    },
    ["taximeter"] = {
        desc = "Open taximeter",
        key = "n"
    },
    ["air"] = {
        desc = "Open air conditioner",
        key = "h"
    },
}

Config.Peds = {
    "a_f_m_beach_01",
    "a_f_m_fatbla_01",
    "a_f_m_prolhost_01",
    "a_f_o_soucent_01",
    "a_f_y_juggalo_01",
    "a_m_m_afriamer_01",
    "a_m_m_og_boss_01",
    "a_m_m_prolhost_01",
    "a_m_m_trampbeac_01",
    "a_m_y_beach_03",
    "a_m_y_business_02",
}

Config.Levels = {
    [1] = {
        min = 0,
        max = 500,
    },
    [2] = {
        min = 501,
        max = 1000,
    },
    [3] = {
        min = 1001,
        max = 1500,
    },
    [4] = {
        min = 1501,
        max = 2000,
    },
    [5] = {
        min = 2001,
        max = 2500,
    },
    [6] = {
        min = 2501,
        max = "∞",
    },
}

Config.ReturnVehicle = {
    coords = vec3(915.83, -162.81, 74.69),
}

Config.CabLocations = {
    [1] = {
        blip = { -- or false
            sprite = 198,
            color = 46,
            name = "TAXI JOB",
            scale = 0.7,
        },
        AccesCoord = vec4(894.9, -179.17, 74.7, 242.89),
        PedModel = "a_m_m_eastsa_02",
        FinishJob = vec3(915.83, -162.81, 74.69),
        VehicleCoords = {
            vec4(906.53, -185.91, 74.01, 60.35),
            vec4(908.81, -183.34, 74.21, 61.0),
            vec4(921.74, -163.52, 74.86, 96.21),
            vec4(913.71, -159.83, 74.76, 201.9),
        }
    }
}

Config.Vehicles = {
    [1] = {
        label = "Normal Taksi",
        model = "taxi",
        level = 1,
        priceMultiplier = 1,
        photo = "./img/icons/taxi.png",
    },
    [2] = {
        label = "High Class",
        model = "tailgater",
        level = 3,
        priceMultiplier = 1.2,
        photo = "./img/icons/tailgater.png",
    },
    [3] = {
        label = "Limousine",
        model = "stretch",
        level = 6,
        priceMultiplier = 1.5,
        photo = "./img/icons/stretch.png",
    },
}

Config.WorkZones = {
    ["downtown"] = {
        label = "DOWNTOWN",
        bg = "./img/icons/downtownbg.png",
        desc = "The Downtown Cab Area is a busy urban zone at the city’s core, ideal for players seeking fast-paced taxi jobs in a vibrant, high-traffic environment.",
        minLevel = 1,
        price = {
            min = 10,
            max = 150,
        },
        xp = {
            min = 10,
            max = 100,
        },
        coords = {
            vec4(413.85, 133.6, 101.43, 205.55),
            vec4(116.34, -11.63, 67.7, 201.15),
            vec4(-15.48, -114.36, 56.86, 178.45),
            vec4(112.34, -939.13, 29.72, 254.85),
            vec4(196.74, -1087.24, 29.29, 279.85),
            vec4(-325.23, 264.51, 86.59, 202.99),
            vector4(257.61, -380.57, 44.71, 340.5),
            vector4(-48.58, -790.12, 44.22, 340.5),
            vector4(240.06, -862.77, 29.73, 341.5),
            vector4(826.0, -1885.26, 29.32, 81.5),
            vector4(350.84, -1974.13, 24.52, 318.5),
            vector4(-229.11, -2043.16, 27.75, 233.5),
            vector4(-774.04, -1277.25, 5.15, 171.5),
            vector4(-1184.3, -1304.16, 5.24, 293.5),
            vector4(-1321.28, -833.8, 16.95, 140.5),
            vector4(-1613.99, -1015.82, 13.12, 342.5),
            vector4(-1392.74, -584.91, 30.24, 32.5),
            vector4(-515.19, -260.29, 35.53, 201.5),
            vector4(-760.84, -34.35, 37.83, 208.5),
            vector4(-1284.06, 297.52, 64.93, 148.5),
            vector4(-808.29, 828.88, 202.89, 200.5),
        }
    },
    ["paleto bay"] = {
        label = "Paleto Bay",
        bg = "./img/icons/paletobg.png",
        desc = "Paleto Bay is a quiet northern region, great for long scenic rides and relaxed taxi jobs.",
        minLevel = 2,
        price = {
            min = 20,
            max = 250,
        },
        xp = {
            min = 20,
            max = 200,
        },
        coords = {
            vec4(1725.94, 6405.64, 34.34, 150.57),
            vec4(1307.95, 6502.82, 20.1, 185.6),
            vec4(417.57, 6587.04, 27.16, 181.9),
            vec4(204.72, 6590.57, 31.62, 164.33),
            vec4(46.2, 6595.32, 31.65, 225.03),
            vec4(-113.93, 6437.38, 31.59, 178.04),
            vec4(-203.14, 6453.16, 31.17, 253.96),
            vec4(-390.32, 6274.2, 29.98, 46.52),
            vec4(-424.74, 6028.98, 31.49, 296.89),
            vec4(-809.04, 5410.89, 34.08, 16.65),
            vec4(-572.18, 5350.75, 70.23, 324.77),
            vec4(-784.28, 5556.99, 33.46, 165.04),
        }
    },
    ["sandy shores"] = {
        label = "Sandy Shores",
        bg = "./img/icons/sandybg.png",
        desc = "Sandy Shores offers rugged, open landscapes and off-road experiences for adventurous taxi missions.",
        minLevel = 3,
        price = {
            min = 30,
            max = 350,
        },
        xp = {
            min = 30,
            max = 300,
        },
        coords = {
            vec4(2444.21, 4611.59, 36.83, 178.09),
            vec4(2510.72, 4145.19, 38.74, 245.24),
            vec4(2002.28, 3759.94, 32.18, 219.82),
            vec4(1583.73, 3650.02, 34.41, 25.25),
            vec4(921.15, 3591.25, 33.13, 278.83),
            vec4(754.93, 4189.9, 40.81, 11.12),
            vec4(1417.47, 4393.36, 43.8, 73.71),
            vec4(1680.86, 4823.27, 42.05, 107.33),
            vec4(1929.66, 5152.73, 44.23, 195.74),
        }
    },
}

Config.Tasks = {
    [1] = {
        id = 1,
        Name = "City Cruiser",
        xp = 10,
        desc = "Take control of your taxi and drive a total of 10 kilometers across bustling city streets. Follow traffic laws, enjoy the scenery, and make sure to avoid any collisions to keep your record clean.",
        Current = 0,
        Need = 10000,
        taken = false,
    },
    [2] = {
        id = 2,
        Name = "Passenger Pro",
        xp = 15,
        desc = "Pick up and safely transport 3 passengers to their destinations. Provide them with smooth, comfortable rides, ensuring they arrive happy and satisfied every time.",
        Current = 0,
        Need = 3,
        taken = false,
    },
    [3] = {
        id = 3,
        Name = "Job Mastery",
        xp = 20,
        desc = "Complete 2 taxi jobs with excellence by navigating through traffic and reaching your customers’ requested locations quickly and efficiently. Show off your driving skills!",
        Current = 0,
        Need = 2,
        taken = false,
    },
    [4] = {
        id = 4,
        Name = "Fare Collector",
        xp = 25,
        desc = "Earn a total of $500 from fares by offering exceptional service to your customers. Drive through the city’s vibrant streets, building your reputation and boosting your income.",
        Current = 0,
        Need = 500,
        taken = false,
    },
}

weatherTemps = {
    [GetHashKey("EXTRASUNNY")] = 30,   
    [GetHashKey("CLEAR")] = 28,        
    [GetHashKey("NEUTRAL")] = 25,    
    [GetHashKey("SMOG")] = 25,          
    [GetHashKey("FOGGY")] = 17,         
    [GetHashKey("OVERCAST")] = 18,     
    [GetHashKey("CLOUDY")] = 22,    
    [GetHashKey("CLEARIN")] = 20,    
    [GetHashKey("RAIN")] = 15,
    [GetHashKey("THUNDER")] = 14, 
    [GetHashKey("BLIZZARD")] = 5, 
    [GetHashKey("SNOW")] = 0,
    [GetHashKey("XMAS")] = 0,
}

GetWeather = function()
    local type1, type2, percent = GetWeatherTypeTransition()
    return weatherTemps[type1] or 20
end