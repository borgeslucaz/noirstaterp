CreateThread(function()
	while true do
		if NetworkIsSessionStarted() then
			LoadResource()
			break
		end
		Wait(100)
	end
end)


LoadResource = function()
	ShutdownLoadingScreen()
	ShutdownLoadingScreenNui()
	DisplayRadar(false)
	TriggerServerEvent('Update:RoutingBucket', math.random(1000, 10000))
	Wait(500)
	DoScreenFadeIn(500)
	CharactersMenu()
end
