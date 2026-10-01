-- change holster clothing when pulling out or hosltering weapon.
-- variation can be found here: https://docs.fivem.net/natives/?_0x67F3780DD425D4FC
-- Male & female keys have these: {holstered, unholstered}

-- PATCH NOIR: os números abaixo são de um pacote de roupa policial (EUP) que o servidor
-- não tem; no jogo base, "Lenços e correntes" 182/186 etc. são correntes comuns, e a troca
-- mudaria a corrente de quem saca a pistola de combate. Desligado até haver coldre de
-- verdade; para ligar, troque `return {}` pelo bloco original (HOLSTERS_EUP).
local HOLSTERS_EUP = {
    {
        weapons = {`weapon_combatpistol`},
        variation = 7,
        male = {182, 186},
    },
    {
        weapons = {`weapon_combatpistol`},
        variation = 7,
        male = {179, 183},
        female = {148, 149}
    },
    {
        weapons = {`weapon_combatpistol`},
        variation = 7,
        male = {187, 188}
    }
}

return {}
