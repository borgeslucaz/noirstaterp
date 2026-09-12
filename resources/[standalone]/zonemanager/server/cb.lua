-- Callback transport (server). registerCallback(name, opts, fn) backs the editor
-- fetch/save round-trips. Transport picked by config.callbacks:
--   'internal'  - token-correlated shim over net events. Any framework. Default.
--   'framework' - the framework's native callbacks via the adapter, falling back
--                 to internal when the adapter has none (standalone / custom).
-- The admin gate is applied here for both transports (see registerCallback).

-- Published at load; the request handler guards a missing key so registration order never matters.
cbHandlers = cbHandlers or {}

-- Internal transport: token-correlated request/reply over net events. Reply is
-- (token, ack, value); the application-level ok/denied lives inside value.
CreateThread(function()
	RegisterNetEvent('zonemanager:cb:request', function(name, token, ...)
		local src = source
		local fn = cbHandlers[name]
		if not fn then
			return
		end
		TriggerClientEvent('zonemanager:cb:reply', src, token, true, fn(src, ...))
	end)
end)

-- Transport selection. 'framework' needs the adapter to expose a registerCallback
-- hook; left nil otherwise, so a single truthy check below picks the transport.
---@type fun(name: string, fn: fun(src: number, ...): any)?
local frameworkRegister
if config.callbacks == 'framework' then
	local adapter = loadModule(('server/framework/%s.lua'):format(config.framework))
	if type(adapter.registerCallback) == 'function' then
		frameworkRegister = adapter.registerCallback
	else
		print(("[zonemanager] config.callbacks='framework' but the %q adapter has no callback support -- using internal")
			:format(config.framework))
	end
end

-- Wraps fn with the admin gate when requires='admin', then hands it to the chosen transport.
---@param name string
---@param opts table?
---@param fn fun(src: number, ...): any
function registerCallback(name, opts, fn)
	opts = opts or {}
	local gated = fn
	if opts.requires == 'admin' then
		gated = function(src, ...)
			if not (isAdmin and isAdmin(src)) then
				return { ok = false, error = 'denied' }
			end
			return fn(src, ...)
		end
	end
	if frameworkRegister then
		frameworkRegister(name, gated)
	else
		cbHandlers[name] = gated
	end
end
