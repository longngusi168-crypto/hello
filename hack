local myUID = 328662944

threadpool:work(function()
    while true do
        threadpool:wait(0.5)
        pcall(function()
            if Player and Player.changeGameMode then
                Player:changeGameMode(myUID, 1)
            end
            if World and World.setGameMode then
                World:setGameMode(1)
            end
        end)
    end
end)()
