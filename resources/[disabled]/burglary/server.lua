local robbers = {}

-- functions
function onNet (name, func)
    RegisterNetEvent(name)
    return AddEventHandler(name, func)
end

function insert(id, item)
    if not robbers[id] then
        robbers[id] = {}
    end

    table.insert(robbers[id], item)
end

-- events
onNet('burglary:collected', function (item, house)
	item = tonumber(item)
	house = tonumber(house)

	if not item or not house or not houses[house] or not houses[house].pickups[item] then
		return
	end

	insert(source, { item = item, house = house })
end)

onNet('burglary:ended', function (failed, alert, door, street)
	if not failed then
		if robbers[source] then
			local sum = 0
			
			for _,v in pairs(robbers[source]) do
				-- get price from houses/pickups table
				local item = houses[v.house].pickups[v.item]
			
				if tonumber(item.value) ~= nil then
					sum = sum + item.value
				end
			end

			sum = math.floor(sum + 0.5)
			
			print("[Burglary] " .. GetPlayerName(source) ..  " stole " .. #robbers[source] .. " items with a value of $" .. sum)
			robbers[source] = nil
			
			-- tell the client how much money he made
			TriggerClientEvent("burglary:finished", source, sum)
			
			-- resources can listen for this event to give money using their own framework
			-- sum = amount of money
			-- source = source of player
			TriggerEvent("burglary:money", sum, source)
		end
	else
		if alert and doors[door] then
			-- resources can listen for this event to for example alert cops
			-- house = houseid
			-- coords = door coordinates of house
			-- source = source of player failing
			TriggerEvent("burglary:failed", doors[door].house, doors[door].coords, source, street)
		end
		
		if robbers[source] then
			robbers[source] = nil
		end
	end
end)

AddEventHandler('burglary:money', function(sum, playerId)
	local player = exports.qbx_core:GetPlayer(playerId)
	if not player then return end

	player.Functions.AddMoney('cash', sum, 'burglary-reward')
end)

AddEventHandler('burglary:failed', function(_, _, playerId, street)
	local message = 'Invasão a residência em andamento'
	if street and street ~= '' then
		message = ('Invasão a residência na %s'):format(street)
	end

	TriggerEvent('police:server:policeAlert', message, nil, playerId)
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	if robbers[playerId] then
		robbers[playerId] = nil
    end
end)
