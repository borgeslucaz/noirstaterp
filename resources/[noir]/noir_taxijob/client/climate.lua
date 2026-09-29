-- Ar-condicionado / FAN: simulação local da temperatura, sincronizada e validada no servidor.
--
-- Modelo: a cada segundo a temperatura interna (T) se aproxima da externa (deriva, sempre)
-- e do alvo da FAN (frio com calor lá fora, quente com frio lá fora), proporcional ao nível:
--   dT = (Tfora − T) · DriftRate + (Talvo − T) · FanRate · nível
-- Com isso a FAN no máximo pode passar do ponto de conforto (21–24 °C): o taxista precisa dosar.
Climate = {
    temp = 22.0,
    fan = 0,
    outside = 22.0,
}

local C = Config.Climate
local running = false
local weatherByHash = {}
for name, temp in pairs(C.WeatherTemps) do
    weatherByHash[joaat(name)] = temp
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---@return number
function Climate.outsideTemp()
    local hash = GetPrevWeatherTypeHashName()
    return weatherByHash[hash] or C.DefaultOutsideTemp
end

---@return 'cool'|'heat'
function Climate.mode()
    return Climate.outside >= C.ModeSwitchTemp and 'cool' or 'heat'
end

function Climate.reset()
    Climate.outside = Climate.outsideTemp()
    Climate.temp = clamp(Climate.outside, 18.0, 28.0)
    Climate.fan = 0
end

---@param dt number segundos
function Climate.step(dt)
    local outside = Climate.outsideTemp()
    Climate.outside = outside
    local target = outside >= C.ModeSwitchTemp and C.ACTarget or C.HeaterTarget
    local t = Climate.temp
    t = t + (outside - t) * C.DriftRate * dt + (target - t) * C.FanRate * Climate.fan * dt
    Climate.temp = clamp(t, C.MinTemp, C.MaxTemp)
end

function Climate.sync()
    TriggerServerEvent('noir_taxijob:server:climate', math.floor(Climate.temp * 10 + 0.5) / 10, Climate.fan)
end

---Tecla FAN: 0 → 1 → … → MaxFan → 0
function Climate.cycleFan()
    Climate.fan = (Climate.fan + 1) % (C.MaxFan + 1)
    UI.updateClimate(Climate.temp, Climate.fan)
    Climate.sync()
end

function Climate.start()
    if running then return end
    running = true
    Climate.reset()
    UI.updateClimate(Climate.temp, Climate.fan)
    Climate.sync()
    CreateThread(function()
        local lastSync = GetGameTimer()
        while running do
            Wait(1000)
            if not running then break end
            Climate.step(1.0)
            UI.updateClimate(Climate.temp, Climate.fan)
            if GetGameTimer() - lastSync >= C.SyncInterval then
                lastSync = GetGameTimer()
                Climate.sync()
            end
        end
    end)
end

function Climate.stop()
    running = false
end
