-- SERVER_MAIN
local db = exports.oxmysql
local VorpCore = exports.vorp_core:GetCore()
local VorpInv = exports.vorp_inventory:vorp_inventoryApi()


RegisterNetEvent(Events.loadStable, function(charid)
    local src = source
    LoadStableContent(src, charid, true)
end)

RegisterNetEvent(Events.loadStableRuntime, function()
    local src = source
    local id = VorpCore.getUser(src).getUsedCharacter.charIdentifier
    LoadStableContent(src, id, true)
end)

-- Everytime a DB action is made, this function gets called to sync data on the client with data in the DB
function LoadStableContent(src, charId, regInvs)
    db:execute("SELECT * FROM stables WHERE `charidentifier`=? OR `status` LIKE '%\"transferTarget\":?,%' OR `status` LIKE '%\"transferTarget\":?}'", { charId, charId, charId }, function(result)
        -- Retrieve owned rides, and rides transfered to this player
        db:execute("SELECT `complements` FROM horse_complements WHERE `charidentifier`=?", { charId }, function(compsResult)
            local comps
            if (#compsResult == 0) then
                comps = {}
                db:execute("INSERT INTO  horse_complements (`charidentifier`, `complements`, `identifier`) VALUES (?,?,?)", { charId, "[]", tostring(charId) })
            else
                comps = compsResult[1]["complements"]
            end
            local ownedRides = {}
            local waitingRides = {}
            for _, v in ipairs(result) do
                if v.charidentifier == charId then
                    table.insert(ownedRides, 1, v)
                else
                    table.insert(waitingRides, 1, v)
                end
            end
            local out = {
                rides = ownedRides,
                transferedRides = waitingRides,
                availableComps = comps,
                charId = charId
            }
            TriggerClientEvent(Events.onStableLoaded, src, out)
        end)

        if regInvs ~= nil then
            for _, ride in pairs(result) do
                local limit
                if Config.CustomMaxWeight[ride.modelname] then
                    limit = Config.CustomMaxWeight[ride.modelname]
                else
                    limit = Config.DefaultMaxWeight
                end
                local id = ("%s_%s"):format(ride.modelname, charId)
                VorpInv.registerInventory(id, ride.name, limit, true, Config.ShareInv[ride.type], Config.StackInvIgnore[ride.type])
            end
        end
    end)

    db:execute("SELECT charidentifier, firstname, lastname, job FROM characters", function(result)
        TriggerClientEvent("charsLoaded", src, result)
    end)
end

RegisterNetEvent(Events.onBuyRide, function(rideName, rideModel, rideType)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier
    local price = 0

    if rideType == "horse" then
        local value = Data.Horses[rideModel]
        if not value then
            return print("rideModel not found in Data.Horses")
        end
        price = value
    elseif rideType == "cart" then
        local value = Data.Carts[rideModel]
        if not value then
            return print("rideModel not found in Data.Carts")
        end
        price = value
    end

    if price > player.money then
        return TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipCantAfford, 4000)
    end

    player.removeCurrency(0, price)
    db:execute("INSERT INTO stables (`charidentifier`, `name`, `type`, `modelname`, `identifier`) VALUES (?, ?, ?, ?, 'steam:')", { id, rideName, rideType, rideModel },
        function(result)
            if result.affectedRows > 0 then
                TriggerClientEvent("vorp:TipRight", src,
                    Config.Lang.TipRidePurchased:gsub("%{rideName}", rideName):gsub("%{price}", price), 4000)
                local limit
                if Config.CustomMaxWeight[rideModel] ~= nil then
                    limit = Config.CustomMaxWeight[rideModel]
                else
                    limit = Config.DefaultMaxWeight
                end
                local invid = ("%s_%s"):format(rideModel, id)
                VorpInv.registerInventory(invid, rideName, limit, true, Config.ShareInv[rideType], false)
                LoadStableContent(src, id)
            end
        end)
end)

RegisterNetEvent(Events.onBuyComp, function(compModel, compType, price, horseId, horseComps, playerAvailableComps)
    price = tonumber(price)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier

    if price > player.money then
        return TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipCantAfford, 4000)
    end
    compModel = tonumber(compModel)
    local compsForDB = {}
    horseComps[compType] = compModel
    local alreadyHasComp = false

    -- When a comp is bought, check the comps the player already owns
    -- If not owned, add to table, else set alReadyHasComp to true to prevent a DB operation
    for _, compModels in pairs(playerAvailableComps) do
        for _, comps in pairs(compModels) do
            for _, comp in ipairs(comps) do
                local compHash = tonumber(comp)
                table.insert(compsForDB, 1, compHash)
                if comp == compModel then
                    alreadyHasComp = true
                    break
                end
            end
        end
    end

    -- This removes the equipement of the horse if the translation key has changed to avoid doubles
    -- //TODO replace with the current key rather than deleting for QOL (keep in mind that the players keep their stuff in horse_complements)

    for k, _ in pairs(horseComps) do
        if Config.StaticData.Complements[k] == nil then
            horseComps[k] = nil
        end
    end

    db:execute("UPDATE stables SET `gear` = ? WHERE `id` = ?", { json.encode(horseComps), horseId }, function(result)
        if result.affectedRows > 0 then
            player.removeCurrency(0, price)

            TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipSuccessfulBuyComp:gsub("%{0}", compType):gsub("%{1}", price), 4000)
            if not alreadyHasComp then
                table.insert(compsForDB, 1, compModel)
                db:execute("UPDATE horse_complements SET `complements` = ? WHERE `charidentifier` = ?", { json.encode(compsForDB), id }, function(result_)
                    if result_.affectedRows > 0 then
                        TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipAddedToStable, 4000)
                    else
                        TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipErrorOnAdd, 4000)
                    end
                    LoadStableContent(src, id)
                end)
            else
                LoadStableContent(src, id)
            end
        else
            TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipErrorOnPurchase, 4000)
        end
    end)
end)

RegisterNetEvent(Events.onRemoveComps, function(rideId)
    db:execute("UPDATE stables SET `gear` = '{}' WHERE `id` = ?", { rideId })
end)

RegisterNetEvent(Events.onDelete, function(rideId)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier

    -- is player owner of this
    db:execute("SELECT charidentifier FROM stables WHERE `id` = ?", { rideId }, function(result)
        if result[1] then
            if result[1].charidentifier == id then
                db:execute("DELETE FROM stables WHERE `id` = ?", { rideId }, function()
                    TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipHorseFreed, 4000)
                    LoadStableContent(src, id)
                end)
            end
        end
    end)
end)

RegisterNetEvent(Events.onTransfer, function(rideId, targetChar, price, activePlayers)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier
    local targetSource = nil
    -- Check if recieving player is connected so their stable content gets refreshed
    for _, v in ipairs(activePlayers) do
        local u = VorpCore.getUser(v)
        if u ~= nil then
            local p = u.getUsedCharacter
            local i = p.charIdentifier
            if i == targetChar then
                targetSource = v
                break
            end
        end
    end

    -- The ride isn't directly transfered, the offer is stored in the ride status for the recieving player to accept or not
    db:execute("UPDATE stables SET status = ? WHERE `id` = ?", { json.encode({
        transferTarget = targetChar,
        price = price
    }), rideId }, function()
        TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipOfferSent, 4000)
        LoadStableContent(src, id)
        if targetSource ~= nil then
            LoadStableContent(targetSource, targetChar)
        end
    end)
end)

RegisterNetEvent(Events.onTransferRecieve, function(rideId, targetChar, accepted, index, activePlayers)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter -- seller ?
    local id = player.charIdentifier
    local targetSource = nil

    for _, v in ipairs(activePlayers) do
        local u = VorpCore.getUser(v)
        if u then
            local p = u.getUsedCharacter
            local i = p.charIdentifier
            if i == targetChar then
                targetSource = v
                break
            end
        end
    end

    -- get horsemodel from riderid
    db:execute("SELECT modelname FROM stables WHERE `id` = ?", { rideId }, function(result)
        if result[1] then
            local horseModel = result[1].modelname
            local value = Config.Stables[index]
            if not value then
                return print("stable not found: ", index)
            end

            local horsePrice = value.horses[horseModel]
            if not horsePrice then
                return print("horse not found: ", horseModel)
            end

            if not accepted then
                db:execute("UPDATE stables SET status = NULL WHERE `id` = ?", { rideId }, function()
                    TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipOfferDeclined, 4000)
                    LoadStableContent(src, id)
                end)
            elseif player.money >= horsePrice then
                db:execute("UPDATE stables SET status = NULL, charidentifier = ? WHERE `id` = ?", { id, rideId }, function()
                    TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipOfferAccepted:gsub("%{price}", horsePrice), 4000)
                    LoadStableContent(src, id)
                    player.removeCurrency(0, horsePrice)
                    if targetSource then
                        local tPlayer = VorpCore.getUser(targetSource).getUsedCharacter
                        tPlayer.addCurrency(0, horsePrice)
                        LoadStableContent(targetSource, targetChar)
                    end
                    -- //TODO add currency to seller if disconnected
                end)
            else
                TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipCantAfford .. " " .. Config.Lang.TipOfferStillOn, 4000)
            end
        end
    end)
end)

local defaultHorse = {}
RegisterNetEvent(Events.openInventory, function(rideModel, newRide)
    local src = source
    local user = VorpCore.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local charId = character.charIdentifier
    local id = ("%s_%s"):format(rideModel, charId)

    local isRegistered = exports.vorp_inventory:isCustomInventoryRegistered(id)
    if not isRegistered then
        TriggerClientEvent("vorp:TipRight", src, "This inventory is not registered id: " .. id, 4000)
        return
    end

    if defaultHorse[src] and not defaultHorse[src] == newRide then
        return TriggerClientEvent("vorp:TipRight", src, "cant open inventory of a horse that is not your default", 4000)
    end

    exports.vorp_inventory:openInventory(src, id)
end)

RegisterNetEvent(Events.setDefault, function(newRide, prevRide)
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier
    db:execute("UPDATE stables SET `isDefault` = 1 WHERE `id` = ?", { newRide }, function(updated)
        if updated.affectedRows > 0 and prevRide ~= nil then
            db:execute("UPDATE stables SET `isDefault` = 0 WHERE `id` = ?", { prevRide }, function(secondUpdate)
                if secondUpdate.affectedRows > 0 then
                    TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipChanged, 4000)
                    LoadStableContent(src, id)
                else
                    TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipErrorOnUpdate, 4000)
                    LoadStableContent(src, id)
                end
            end)
        elseif updated.affectedRows > 0 then
            TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipChanged, 4000)
            LoadStableContent(src, id)
        else
            TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipErrorOnUpdate, 4000)
        end

        defaultHorse[src] = newRide -- id of the horse
    end)
end)

RegisterNetEvent(Events.onHorseDown, function(rideId, killerObjectHash)
    -- HardDeath management
    if not Config.HardDeath then return end
    local src = source
    local player = VorpCore.getUser(src).getUsedCharacter
    local id = player.charIdentifier

    local LTDamages = DeathReasons[killerObjectHash] or DeathReasons.Default
    db:execute("UPDATE stables SET injured = injured + ? WHERE `id` = ?", { LTDamages, rideId }, function(updated)
        if updated.affectedRows > 0 then
            db:execute("SELECT injured FROM stables WHERE `id` = ?", { rideId }, function(result)
                if result[1].injured >= Config.LongTermHealth then
                    db:execute("DELETE FROM stables WHERE `id` = ?", { rideId }, function(deleted)
                        if deleted.affectedRows > 0 then
                            TriggerClientEvent("vorp:TipRight", src, Config.Lang.TipHorseDeadDefinitive, 4000)
                            LoadStableContent(src, id)
                        end
                    end)
                end
            end)
        end
    end)
end)
