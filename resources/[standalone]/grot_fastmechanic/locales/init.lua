Locales = {}

function _(str)
    if Locales[Config.Locale] ~= nil then
        if Locales[Config.Locale][str] ~= nil then
            return Locales[Config.Locale][str]
        else
            return 'Translation [' .. str .. ']'
        end
    else
        return 'Locale [' .. Config.Locale .. '] does not exist'
    end
end
