local QBCore = exports['qb-core']:GetCoreObject()

local function notify(message, kind)
    QBCore.Functions.Notify(message, kind or 'primary')
end

local function serverCallback(name, data, cb)
    QBCore.Functions.TriggerCallback(name, cb, data)
end

RegisterNUICallback('v2Business', function(_, cb)
    serverCallback('bc-banking:server:v2:business', nil, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2BusinessTransaction', function(data, cb)
    serverCallback('bc-banking:server:v2:businessTransaction', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2BusinessMember', function(data, cb)
    serverCallback('bc-banking:server:v2:businessMember', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2CardStatus', function(_, cb)
    serverCallback('bc-banking:server:v2:cardStatus', nil, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2IssueCard', function(data, cb)
    serverCallback('bc-banking:server:v2:issueCard', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2ChangePin', function(data, cb)
    serverCallback('bc-banking:server:v2:changePin', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2VerifyPin', function(data, cb)
    serverCallback('bc-banking:server:v2:verifyPin', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2LockCard', function(data, cb)
    serverCallback('bc-banking:server:v2:lockCard', data, function(result) cb(result or { ok = false }) end)
end)

RegisterNUICallback('v2Audit', function(_, cb)
    serverCallback('bc-banking:server:v2:audit', nil, function(result) cb(result or { ok = false }) end)
end)

RegisterNetEvent('bc-banking:client:tellerOpen', function()
    QBCore.Functions.TriggerCallback('bc-banking:server:v2:tellerOpen', function(result)
        if not result or not result.ok then
            notify(result and result.message or 'Unable to access teller.', 'error')
            return
        end
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', data = result.data, brand = Config.Brand, teller = true })
    end)
end)

CreateThread(function()
    Wait(1000)
    for index, teller in ipairs(Config.V2.TellerLocations or {}) do
        local coords = teller.coords
        if coords then
            exports['qb-target']:AddBoxZone('bc-banking-teller-' .. index, coords, 1.4, 1.4, {
                name = 'bc-banking-teller-' .. index,
                heading = teller.heading or 0,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 1.5
            }, {
                options = {{
                    type = 'client',
                    event = 'bc-banking:client:tellerOpen',
                    icon = 'fas fa-cash-register',
                    label = teller.label or 'Use Bank Teller'
                }},
                distance = Config.V2.TellerDistance or 3.0
            })
        end
    end
end)
