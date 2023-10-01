CurrentHorse = nil
CurrentCart = nil

function getPositionBehindPlayer(playerX, playerY, playerZ, playerHeading, dist)
    local headingRad = math.rad(playerHeading)

    local newX = playerX - dist * math.cos(headingRad)
    local newY = playerY - dist * math.sin(headingRad)

    return {newX,newY, playerZ}
end

-- //TODO unify CallHorse and CallCart since the functions are very similar
function CallHorse(ride)
    if ride == nil then
        TriggerEvent("vorp:TipRight", Config.Lang.TipNoDefaultHorse, 2000);
        return
    end

    if ride.isDead then
        TriggerEvent("vorp:TipRight", Config.Lang.TipHorseDead, 2000);
        return
    end

    local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))

    if ride.pedId == nil or not DoesEntityExist(ride.pedId) then
        Citizen.CreateThread(function()

            LoadModel(ride.model)
            local spawnX, spawnY, spawnZ = table.unpack(getPositionBehindPlayer(x,y,z, GetEntityHeading(PlayerPedId()), 20))
            local retVal, spawn, spawn2 = GetClosestRoad(spawnX, spawnY , spawnZ, 0.0, 25, true);
            local horsePed = CreatePed(ride.model, spawn[1], spawn[2], spawn[3], 0.0, true, true, false, false);
            ride.pedId = horsePed

            -- Then is only just braindead copy-pasting stripped from Natives that seemed useless

            Citizen.InvokeNative(0x283978A15512B2FE, horsePed, true) -- RandomOutfit(for initialization)
            local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, horsePed) -- SetBlip
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, ride.name) -- SetBlipName
            Citizen.InvokeNative(0x98EFA132A4117BE1, horsePed, ride.name) -- SetDebugName
            Citizen.InvokeNative(0x4A48B6E03BABB4AC, horsePed, ride.name) -- SetPedPromptName

            Citizen.InvokeNative(0xADB3F206518799E8, horsePed, GetHashKey("PLAYER")) -- SetPedRelationship
            Citizen.InvokeNative(0xCC97B29285B1DC3B, horsePed, 1) -- SetAnimalMood (Natives DB says not implemented so idk)

            for compType, comp in pairs(ride.comps) do
                ApplyShopItemToPed(horsePed, comp)
            end

            if Config.ShowTagsOnHorses then

                local tagHorse = Citizen.InvokeNative(0xE961BF23EAB76B12, ride.pedId, ride.name) --CreateMpGamerTagOnEntity
                -- Citizen.InvokeNative(0x53CB4B502E1C57EA, ride.pedId, ride.name, false, false, "", 0) --CreateFakeMpGamerTag
                Citizen.InvokeNative(0x5F57522BC1EB9D9D, tagHorse, GetHashKey("PLAYER_HORSE")) --SetMpGamerTagTopIcon
                Citizen.InvokeNative(0xA0D7CE5F83259663, MPTagHorse, " ") --SetMpGamerTagBigText
            end

            Citizen.InvokeNative(0xFE26E4609B1C3772, horsePed, "HorseCompanion", true) -- DecorSetBool (wtf)
            Citizen.InvokeNative(0xA691C10054275290, PlayerPedId(), horsePed, 0) -- No name (mount, player, dismountedTimeStamp)
            Citizen.InvokeNative(0x931B241409216C1F, PlayerPedId(), horsePed, false) -- setPedOwnsAnimal if true, the horse will follow the player no matter what, and wint be driveable b/c it will still try to go to player
            Citizen.InvokeNative(0xED1C764997A86D5A, PlayerPedId(), horsePed) -- No name (comment on Vespura : Only used in R* Script nb_stalking_hunter)
            Citizen.InvokeNative(0xB8B6430EAD2D2437, horsePed, GetHashKey("PLAYER_HORSE")) -- SetPedPersonality

            Citizen.InvokeNative(0xDF93973251FB2CA5, PlayerId(), true) -- SetPlayerMountStateActive

            Citizen.InvokeNative(0xAEB97D84CDF3C00B, horsePed, false) -- SetAnimalIsWild

            -- https://github.com/Halen84/RDR3-Native-Flags-And-Enums/tree/main/ePedScriptConfigFlags
            local horseFlags = {
                [6] = true,
                [113] = false,
                [136] = false,
                [208] = true,
                [209] = true,
                [211] = true,
                [277] = true,
                [297] = true,
                [300] = false,
                [301] = false,
                [312] = false,
                [319] = true,
                [400] = true,
                [412] = false,
                [419] = false,
                [438] = false,
                [439] = false,
                [440] = false,
                [561] = true
            }
            for flag, val in ipairs(horseFlags) do
                Citizen.InvokeNative(0x1913FE4CBF41C463, horsePed, flag, val); -- SetPedConfigFlag (kind of sets defaultbehavior)
            end

            local horseTunings = {24, 25, 48}
            for k, flag in ipairs(horseTunings) do
                Citizen.InvokeNative(0x1913FE4CBF41C463, horsePed, flag, false); -- SetHorseTuning (no info on Vespura, didn't check any further)
            end

            Citizen.InvokeNative(0xA691C10054275290, horsePed, PlayerId(), 431); -- No name (mount, player, dismountedTimeStamp)

            Citizen.InvokeNative(0x6734F0A6A52C371C, PlayerId(), 431) -- No name (player, horseSlot)
            Citizen.InvokeNative(0x024EC9B649111915, horsePed, true) -- No name, no desc (ped, p1)
            Citizen.InvokeNative(0xEB8886E1065654CD, horsePed, 10, "ALL", 0) -- No name *Washing player's face/hands now* (ped, p1, p2, p3)

            SetModelAsNoLongerNeeded(ride.model)
            SetEntityAsMissionEntity(ride.pedId, true, true);

            ClearPedTasks(ride.pedId, true, true)

            Citizen.InvokeNative(0x6A071245EB0D1882, ride.pedId, PlayerPedId(), -1, 4.0, 100.0, 0, 0) -- GoToEntity

        end)
    end

    if not IsMountSeatFree(ride.pedId) then
        TriggerEvent("vorp:Tip", Config.Lang.TipHorseOccupied, 2000);
        return
    end

    NetworkRequestControlOfEntity(ride.pedId);
    SetEntityAsMissionEntity(ride.pedId, false, false);

    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ride.pedId)) <= Config.DistanceToTeleport and ride ~= nil then
        Citizen.InvokeNative(0x6A071245EB0D1882, ride.pedId, PlayerPedId(), -1, 4.0, 100.0, 0, 0) -- GoToEntity
        -- Citizen.InvokeNative(0x5BC448CB78FA3E88, ride.pedId, x, y, z, 100.0, 0, 0, 0, 0) -- GoToCoordsAnyMeans

    elseif IsMountSeatFree(ride.pedId) then
        DeletePed(CurrentHorse.pedId)
        CurrentHorse.pedId = nil
        CallHorse(CurrentHorse)
    end

end

function CallCart(ride)
    if ride == nil then
        TriggerEvent("vorp:TipRight", Config.Lang.TipNoDefaultCart, 2000);
        return
    end

    local x, y, z = table.unpack(GetEntityCoords(PlayerPedId()))

    if ride.pedId == nil or not DoesEntityExist(ride.pedId) then
        LoadModel(ride.model)

        local spawnX, spawnY, spawnZ = table.unpack(getPositionBehindPlayer(x,y,z, GetEntityHeading(PlayerPedId()), 20))
        local retVal, spawn, spawn2 = GetClosestRoad(spawnX, spawnY , spawnZ, 0.0, 25, true);
        ride.pedId = CreateVehicle(ride.model, spawn[1], spawn[2], spawn[3], 0,true, true, false, true)
        Citizen.InvokeNative(0xAF35D0D2583051B0, ride.pedId, true) -- SetPedDefaultOutfit

        local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, horsePed) -- SetBlip
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, ride.name) -- SetBlipName
        Citizen.InvokeNative(0x98EFA132A4117BE1, ride.pedId, ride.name)
        Citizen.InvokeNative(0x4A48B6E03BABB4AC, ride.pedId, ride.name)
        Citizen.InvokeNative(0xADB3F206518799E8, ride.pedId, GetHashKey("PLAYER"))
        Citizen.InvokeNative(0xCC97B29285B1DC3B, ride.pedId, 1)
        Citizen.InvokeNative(0x7549B9E841940695, false) -- SET_VEHICLE_MAY_BE_USED_BY_GOTO_POINT_ANY_MEANS

        SetModelAsNoLongerNeeded(ride.model)
    end

    if not AreVehicleSeatsFree(ride.pedId) then
        TriggerEvent("vorp:Tip", Config.Lang.TipCartOccupied, 2000);
        return
    end

    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ride.pedId)) <= Config.DistanceToTeleport and ride ~= nil then
        -- No real solution to get vehicle to auto drive to player
    else
        DeleteVehicle(CurrentCart.pedId)
        CurrentCart.pedId = nil
        CallCart(CurrentCart)
    end
end

function IsMountSeatFree(entity)
    return Citizen.InvokeNative(0xAAB0FE202E9FC9F0, entity, -1)
end

function AreVehicleSeatsFree(entity)
    local maxSeats = Citizen.InvokeNative(0xA9C55F1C15E62E06, entity)
    for i = 1, maxSeats, 1 do
        if not Citizen.InvokeNative(0xE052C1B1CAA4ECE4, entity, i) then
            return false
        end
    end
    return true
end

function BrushHorse(targetHorse)
    Citizen.InvokeNative(0xCD181A959CFDD7F4, PlayerPedId(), targetHorse, GetHashKey("Interaction_Brush"),
        GetHashKey("p_brushHorse02x"), 1)
    Citizen.Wait(5000)
    ClearPedEnvDirt(targetHorse)
    ClearPedBloodDamage(targetHorse)
    ClearPedDecorations(targetHorse)
    ClearPedWetness(targetHorse)
end

function ActionsOnKeyPress()

    -- On horse actions : https://github.com/femga/rdr3_discoveries/tree/master/tasks/TASK_HORSE_ACTION
    -- Citizen.InvokeNative(0xA09CFD29100F06C3,horse_ped_id, 2, 0, 0)  -- horse throw off rider and passenger

    if IsControlJustPressed(0, Keys.H) then
        CallHorse(CurrentHorse)
    end
    if IsControlJustPressed(0, Keys.J) then
        CallCart(CurrentCart)
    end

    -- Prancing horse (458)
    if IsControlPressed(0, Keys.HorseStop) and IsControlPressed(0, Keys.ContextA) then

        local rnd = math.random(100);
        if (rnd > Config.HorseSkillPullUpFailPercent) then
            Citizen.InvokeNative(0xA09CFD29100F06C3, GetMount(PlayerPedId()), 1, 0, 0)
        else
            Citizen.InvokeNative(0xA09CFD29100F06C3, GetMount(PlayerPedId()), 2, 0, 0)
        end
        Citizen.Wait(6000)
    end

    -- Order flee
    local retval, aim = GetEntityPlayerIsFreeAimingAt(PlayerId())
    if IsControlJustPressed(0, Keys.HorseCommandFlee) then
        Citizen.InvokeNative(0xFD45175A6DFD7CE9, aim, PlayerPedId(), 3, 0, -1.0, -1, 0);
        Citizen.Wait(10000)
        DeletePed(aim);
    end

    if IsDisabledControlJustPressed(0, Keys.InteractHorseBrush) then
        BrushHorse(aim)
    end
    -- Open inventories
    -- //TODO let anyone open if set in Config
    if CurrentHorse ~= nil and CurrentHorse.pedId and
        #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(CurrentHorse.pedId)) <= 5.0 and
        IsControlJustPressed(0, Keys.U) then
        TriggerServerEvent(Events.openInventory, CurrentHorse.name)
    elseif CurrentCart ~= nil and CurrentCart.pedId and
        #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(CurrentCart.pedId)) <= 5.0 and
        IsControlJustPressed(0, Keys.U) then
        TriggerServerEvent(Events.openInventory, CurrentCart.name)
    end
end

function DeathManager()
    if CurrentHorse == nil or CurrentHorse.isDead or not CurrentHorse.pedId then
        return
    end
    if IsPedDeadOrDying(CurrentHorse.pedId, false) and GetPedCauseOfDeath(CurrentHorse.pedId) ~= 0 then
        Citizen.CreateThread(function()
            CurrentHorse.isDead = true
            local killerHash = GetPedCauseOfDeath(CurrentHorse.pedId)
            TriggerServerEvent(Events.onHorseDown, CurrentHorse.id, killerHash)
            Citizen.Wait(Config.SecondsToRespawn * 1000)
            DeletePed(CurrentHorse.pedId)
            -- Wait otherwise gets set to false before the ped despawns and the loop reruns
            Citizen.Wait(5000)
            CurrentHorse.isDead = false
        end)
    end
end

function ControlChecker()
    --Dev function to print key names on press
    for k, v in pairs(Keys) do
        if IsControlJustPressed(0, v) then
            print("Control 0 pressed : " .. k)
        elseif IsDisabledControlJustPressed(0, v) then
            print("Disabled Control pressed : " .. k)
        end
    end
end

function Interactions()
    while true do
        Citizen.Wait(0)
        ActionsOnKeyPress()
        DeathManager()
        -- ControlChecker()
    end
end

Citizen.CreateThread(Interactions)
