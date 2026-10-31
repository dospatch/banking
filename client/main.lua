local QBCore = exports['qb-core']:GetCoreObject()
local uiOpen = false
local currentAtm = nil

local function notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary')
end

local function closeBank()
    if not uiOpen then return end
    uiOpen = false
    currentAtm = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openBank(coords)
    if uiOpen then return end
    local p = GetEntityCoords(PlayerPedId())
    local atm = coords or { x = p.x, y = p.y, z = p.z }
    currentAtm = atm
    QBCore.Functions.TriggerCallback('bc-banking:server:open', function(result)
        if not result or not result.ok then
            notify(result and result.message or Config.Text.failed, 'error')
            return
        end
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = result.data, brand = Config.Brand })
    end, atm)
end

RegisterNetEvent('bc-banking:client:open', function(data)
    local entity = data and data.entity
    if entity and DoesEntityExist(entity) then
        local c = GetEntityCoords(entity)
        openBank({ x = c.x, y = c.y, z = c.z })
    else
        openBank()
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeBank()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('bc-banking:server:refresh', function(result)
        cb(result or { ok = false, message = Config.Text.failed })
    end, currentAtm)
end)

RegisterNUICallback('transaction', function(data, cb)
    QBCore.Functions.TriggerCallback('bc-banking:server:transaction', function(result)
        cb(result or { ok = false, message = Config.Text.failed })
    end, data, currentAtm)
end)

RegisterNUICallback('transfer', function(data, cb)
    QBCore.Functions.TriggerCallback('bc-banking:server:transfer', function(result)
        cb(result or { ok = false, message = Config.Text.failed })
    end, data, currentAtm)
end)

RegisterNUICallback('offlineTransfer', function(data, cb)
    QBCore.Functions.TriggerCallback('bc-banking:server:v2:offlineTransfer', function(result)
        cb(result or { ok = false, message = Config.Text.failed })
    end, data, currentAtm)
end)

RegisterCommand('bank', function()
    notify('Use an ATM to access BC Banking.', 'primary')
end, false)

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.AtmModels, {
        options = {{
            type = 'client',
            event = 'bc-banking:client:open',
            icon = 'fas fa-building-columns',
            label = 'Open BC Banking'
        }},
        distance = Config.TargetDistance
    })
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', closeBank)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then closeBank() end
end)
