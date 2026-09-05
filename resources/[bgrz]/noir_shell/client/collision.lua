-- Requests collision around an entity and blocks until it is loaded or the timeout expires.
-- Returns true once collision is ready, false on timeout.
local function requestCollision(entity, timeout)
    timeout = timeout or Config.CollisionTimeout

    local coords = GetEntityCoords(entity)

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    local start = GetGameTimer()

    while not HasCollisionLoadedAroundEntity(entity) do
        if GetGameTimer() - start > timeout then
            return false
        end

        RequestCollisionAtCoord(coords.x, coords.y, coords.z)

        Wait(0)
    end

    return true
end

Collision = {
    request = requestCollision,
}
