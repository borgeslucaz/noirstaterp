local shutdown = function ()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end


AddEventHandler('playerSpawned', shutdown)
