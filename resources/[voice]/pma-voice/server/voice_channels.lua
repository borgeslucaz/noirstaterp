-- GTAV Enhanced voice channels are owned by the server.  Do not expose their
-- IDs to clients: doing so would reintroduce the client-controlled-channel
-- security issue that this API is designed to prevent.

local proximityChannel
local radioVoiceChannels = {}
local callVoiceChannels = {}

local function createChannel(mode, distance)
	local channel = CreateVoiceChannel(mode, distance)
	if channel == 65535 then
		error('Failed to create a voice channel: the server channel limit has been reached')
	end
	return channel
end

local function getOrCreateChannel(channels, key)
	local channel = channels[key]
	if not channel then
		channel = createChannel(0, 0.0) -- non-spatial: radios and calls
		channels[key] = channel
	end
	return channel
end

function initializeVoiceChannels()
	if proximityChannel then return end

	-- The new API applies one maximum distance per spatial channel.  Keep every
	-- player in one proximity channel so players using different voice modes can
	-- still hear one another.  The maximum retains pma-voice's default shout
	-- range; radio and call channels are independent of it.
	proximityChannel = createChannel(1, GetConvarInt('voice_proximityDistance', 15) + 0.0)
	for _, player in ipairs(GetPlayers()) do
		AddPlayerToVoiceChannel(proximityChannel, tonumber(player))
	end
end

function addPlayerToProximityVoice(source)
	initializeVoiceChannels()
	AddPlayerToVoiceChannel(proximityChannel, source)
end

function addPlayerToRadioVoice(source, radioChannel)
	local channel = getOrCreateChannel(radioVoiceChannels, radioChannel)
	AddPlayerToVoiceChannel(channel, source)
	-- Members listen continuously, but only transmit while holding the radio key.
	SetPlayerMutedInVoiceChannel(channel, source, true)
end

function removePlayerFromRadioVoice(source, radioChannel)
	local channel = radioVoiceChannels[radioChannel]
	if channel then
		RemovePlayerFromVoiceChannel(channel, source)
	end
end

function setPlayerTalkingOnRadioVoice(source, radioChannel, talking)
	local channel = radioVoiceChannels[radioChannel]
	if channel then
		SetPlayerMutedInVoiceChannel(channel, source, not talking or Player(source).state.muted == true)
	end
end

function setPlayerMutedInVoiceChannels(source, muted)
	initializeVoiceChannels()
	SetPlayerMutedInVoiceChannel(proximityChannel, source, muted)
	for radioChannel, channel in pairs(radioVoiceChannels) do
		local isTalking = radioData[radioChannel] and radioData[radioChannel][source] == true
		SetPlayerMutedInVoiceChannel(channel, source, muted or not isTalking)
	end
	for _, channel in pairs(callVoiceChannels) do
		SetPlayerMutedInVoiceChannel(channel, source, muted)
	end
end

exports('setPlayerMutedInVoiceChannels', setPlayerMutedInVoiceChannels)

RegisterNetEvent('pma-voice:setSelfMuted', function(muted)
	muted = muted == true
	Player(source).state.muted = muted
	setPlayerMutedInVoiceChannels(source, muted)
end)

function addPlayerToCallVoice(source, callChannel)
	AddPlayerToVoiceChannel(getOrCreateChannel(callVoiceChannels, callChannel), source)
end

function removePlayerFromCallVoice(source, callChannel)
	local channel = callVoiceChannels[callChannel]
	if channel then
		RemovePlayerFromVoiceChannel(channel, source)
	end
end

AddEventHandler('onResourceStart', function(resource)
	if resource == GetCurrentResourceName() then
		initializeVoiceChannels()
	end
end)

AddEventHandler('playerJoining', function()
	addPlayerToProximityVoice(source)
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then return end

	if proximityChannel then DeleteVoiceChannel(proximityChannel) end
	for _, channel in pairs(radioVoiceChannels) do DeleteVoiceChannel(channel) end
	for _, channel in pairs(callVoiceChannels) do DeleteVoiceChannel(channel) end
end)
