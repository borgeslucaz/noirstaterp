---Uniformes do armário, por departamento. Componentes do GTA:
---  components[id] = { drawable, texture } (3 braços, 4 calça, 6 sapato, 7 acessório,
---  8 camiseta, 9 colete, 10 emblema, 11 camisa)
---  props[id] = { drawable, texture } (0 chapéu, 1 óculos); drawable -1 tira o prop.
---
---Os valores abaixo são o uniforme de polícia do próprio jogo (sem roupa addon).
---Para cadastrar um uniforme novo, vista a roupa e use /noir_police_outfit: o
---comando copia a tabela pronta para a área de transferência.
---
---`grade` e `subunit` restringem quem pode vestir.

return {
    police = {
        {
            label = 'Patrulha (manga longa)',
            grade = 0,
            male = {
                components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 }, [8] = { 58, 0 }, [9] = { 0, 0 }, [11] = { 55, 0 } },
                props = { [0] = { 46, 0 } },
            },
            female = {
                components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 }, [8] = { 35, 0 }, [9] = { 0, 0 }, [11] = { 48, 0 } },
                props = { [0] = { 45, 0 } },
            },
        },
        {
            label = 'Patrulha (sem quepe)',
            grade = 0,
            male = {
                components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 }, [8] = { 58, 0 }, [9] = { 0, 0 }, [11] = { 55, 0 } },
                props = { [0] = { -1, 0 } },
            },
            female = {
                components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [7] = { 0, 0 }, [8] = { 35, 0 }, [9] = { 0, 0 }, [11] = { 48, 0 } },
                props = { [0] = { -1, 0 } },
            },
        },
        {
            label = 'Tático (SWAT)',
            subunit = 'swat',
            male = {
                components = { [3] = { 17, 0 }, [4] = { 31, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [9] = { 16, 0 }, [11] = { 49, 0 } },
                props = { [0] = { 39, 0 } },
            },
            female = {
                components = { [3] = { 18, 0 }, [4] = { 30, 0 }, [6] = { 25, 0 }, [8] = { 14, 0 }, [9] = { 18, 0 }, [11] = { 42, 0 } },
                props = { [0] = { 38, 0 } },
            },
        },
    },
    sasp = {
        {
            label = 'Patrulha rodoviária',
            grade = 0,
            male = {
                components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } },
                props = { [0] = { 10, 6 } },
            },
            female = {
                components = { [3] = { 14, 0 }, [4] = { 34, 0 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } },
                props = { [0] = { 10, 6 } },
            },
        },
    },
    bcso = {
        {
            label = 'Xerife',
            grade = 0,
            male = {
                components = { [3] = { 0, 0 }, [4] = { 35, 2 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } },
                props = { [0] = { 13, 0 } },
            },
            female = {
                components = { [3] = { 14, 0 }, [4] = { 34, 2 }, [6] = { 25, 0 }, [8] = { 35, 0 }, [11] = { 48, 0 } },
                props = { [0] = { 13, 0 } },
            },
        },
    },
}
