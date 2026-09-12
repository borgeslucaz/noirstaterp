-- Callback transport (client). await(name, ...) backs the editor's fetch/save round-trips.
-- Transport picked by config.callbacks: 'internal' (token-correlated shim over net events, any
-- framework, default) or 'framework' (the framework's native callbacks via the adapter's
-- awaitCallback, falling back to internal when absent). Published as a global; blocks until reply,
-- returns result or false.

-- Internal transport: each call gets a token; the server's reply is matched back to the waiting
-- caller by it.
local pending, nextToken = {}, 0

RegisterNetEvent('zonemanager:cb:reply', function(token, ok, res)
	local p = pending[token]
	if p then
		pending[token] = nil
		p(ok, res)
	end
end)

-- Fire the request, block until the matching reply lands.
---@param name string
---@return any
local function awaitInternal(name, ...)
	nextToken = nextToken + 1
	local token = nextToken
	local done, okv, resv = false, false, nil
	pending[token] = function(ok, res)
		done, okv, resv = true, ok, res
	end
	TriggerServerEvent('zonemanager:cb:request', name, token, ...)
	while not done do
		Wait(0)
	end
	return okv and resv or false
end

-- 'framework' needs the adapter to expose an awaitCallback hook; standalone/custom don't, so fall
-- back to internal. Nil here means internal.
---@type fun(name: string, ...): any | nil
local frameworkAwait
if config.callbacks == 'framework' then
	local adapter = loadModule(('client/framework/%s.lua'):format(config.framework))
	if type(adapter.awaitCallback) == 'function' then
		frameworkAwait = adapter.awaitCallback
	else
		print(("[zonemanager] config.callbacks='framework' but the %q adapter has no callback support -- using internal")
			:format(config.framework))
	end
end

-- Dispatches to the framework adapter's awaitCallback when active and supported, else the internal
-- shim.
---@param name string
---@return any
function await(name, ...)
	if frameworkAwait then
		return frameworkAwait(name, ...)
	end
	return awaitInternal(name, ...)
end
