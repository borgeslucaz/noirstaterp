---Job names must be lower case (top level table key)
---@type table<string, Job>
-- Noir: salário automático (a cada 30 min, config/server.lua) só para serviço público:
-- police, bcso, sasp, ambulance e judge, que entram no jogo fora de serviço (defaultDuty =
-- false) e só recebem com o ponto batido. Os outros jobs ficam com payment = 0: salário de
-- empresa vai ser feito de outra forma.
-- A polícia fica perto da âncora civil de ~$550/h: recruta $275 por 30 min, ~8% a mais por
-- cargo, chefe $375. O resto da renda do policial é o bônus por apreensão destruída
-- (noir_police).
return {
    ['unemployed'] = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Freelancer',
                payment = 0
            },
        },
    },
    ['police'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 275
            },
            [1] = {
                name = 'Officer',
                payment = 300
            },
            [2] = {
                name = 'Sergeant',
                payment = 325
            },
            [3] = {
                name = 'Lieutenant',
                payment = 350
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 375
            },
        },
    },
    ['bcso'] = {
        label = 'BCSO',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 275
            },
            [1] = {
                name = 'Officer',
                payment = 300
            },
            [2] = {
                name = 'Sergeant',
                payment = 325
            },
            [3] = {
                name = 'Lieutenant',
                payment = 350
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 375
            },
        },
    },
    ['sasp'] = {
        label = 'SASP',
        type = 'leo',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 275
            },
            [1] = {
                name = 'Officer',
                payment = 300
            },
            [2] = {
                name = 'Sergeant',
                payment = 325
            },
            [3] = {
                name = 'Lieutenant',
                payment = 350
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 375
            },
        },
    },
    ['ambulance'] = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Paramedic',
                payment = 75
            },
            [2] = {
                name = 'Doctor',
                payment = 100
            },
            [3] = {
                name = 'Surgeon',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['realestate'] = {
        label = 'Real Estate',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 0
            },
            [1] = {
                name = 'House Sales',
                payment = 0
            },
            [2] = {
                name = 'Business Sales',
                payment = 0
            },
            [3] = {
                name = 'Broker',
                payment = 0
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 0
            },
        },
    },
    ['taxi'] = {
        label = 'Taxi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 0
            },
            [1] = {
                name = 'Driver',
                payment = 0
            },
            [2] = {
                name = 'Event Driver',
                payment = 0
            },
            [3] = {
                name = 'Sales',
                payment = 0
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 0
            },
        },
    },
    ['bus'] = {
        label = 'Bus',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 0
            },
        },
    },
    ['cardealer'] = {
        label = 'Vehicle Dealer',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 0
            },
            [1] = {
                name = 'Showroom Sales',
                payment = 0
            },
            [2] = {
                name = 'Business Sales',
                payment = 0
            },
            [3] = {
                name = 'Finance',
                payment = 0
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 0
            },
        },
    },
    ['mechanic'] = {
        label = 'Mechanic',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 0
            },
            [1] = {
                name = 'Novice',
                payment = 0
            },
            [2] = {
                name = 'Experienced',
                payment = 0
            },
            [3] = {
                name = 'Advanced',
                payment = 0
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 0
            },
        },
    },
    ['judge'] = {
        label = 'Honorary',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Judge',
                payment = 100
            },
        },
    },
    ['lawyer'] = {
        label = 'Law Firm',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Associate',
                payment = 0
            },
        },
    },
    ['reporter'] = {
        label = 'Reporter',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Journalist',
                payment = 0
            },
        },
    },
    ['trucker'] = {
        label = 'Trucker',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 0
            },
        },
    },
    ['tow'] = {
        label = 'Towing',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 0
            },
        },
    },
    ['garbage'] = {
        label = 'Garbage',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Collector',
                payment = 0
            },
        },
    },
    ['vineyard'] = {
        label = 'Vineyard',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Picker',
                payment = 0
            },
        },
    },
    ['hotdog'] = {
        label = 'Hotdog',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sales',
                payment = 0
            },
        },
    },
}
