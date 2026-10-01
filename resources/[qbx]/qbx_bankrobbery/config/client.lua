return {
    useTarget = false,

    debugPoly = false,

    fingerprintChance = 50, -- Chance of dropping a fingerprint if not wearing gloves

    -- Os mínimos de policiais vêm da tabela pública do noir_scoreboard (`bankrobbery`,
    -- `paleto`, `pacific`; a termite da usina usa o do `pacific`). O servidor manda no
    -- login; até lá ficam fechados.
    minPaletoPolice = 999,
    minPacificPolice = 999,
    minFleecaPolice = 999,
    minThermitePolice = 999,

    outlawCooldown = 5 -- The amount of minutes it takes for the cops to be able to be called again after they were called
}