-- Loads a framework adapter from files{}. cfx require() can't resolve a
-- files{}-only module, so read the packed file off the resource and eval it.

---@param path string resource-relative path, e.g. 'server/framework/standalone.lua'
---@return table the adapter's returned table
function loadModule(path)
	local src = LoadResourceFile(GetCurrentResourceName(), path)
	return load(src, '@' .. path)()
end
