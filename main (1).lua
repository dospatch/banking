local QBCore = exports['qb-core']:GetCoreObject()
local lastUse = {}
local busy = {}

local function result(ok, message, data)
    return { ok = ok, message = message, data = data }
end

local function validCoords(coords)
    return type(coords) == 'table'
        and type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number'
        and math.abs(coords.x) < 10000 and math.abs(coords.y) < 10000 and math.abs(coords.z) < 2000
end

local function checkAccess(src, coords, useCooldown)
    if not validCoords(coords) then return false, Config.Text.tooFar end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false, Config.Text.tooFar end
    local pos = GetEntityCoords(ped)
    if #(pos - vector3(coords.x, coords.y, coords.z)) > Config.InteractionDistance then
        return false, Config.Text.tooFar
    end
    if useCooldown then
        local now = GetGameTimer()
        if lastUse[src] and now - lastUse[src] < Config.CooldownMs then
            return false, Config.Text.cooldown
        end
        lastUse[src] = now
    end
    return true
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function validAmount(value, maximum)
    local amount = tonumber(value)
    if not amount or amount ~= math.floor(amount) or amount < 1 or amount > maximum then return nil end
    return amount
end

local function addHistory(citizenid, txType, amount, description, balanceAfter)
    MySQL.insert('INSERT INTO bc_banking_transactions (citizenid, transaction_type, amount, description, balance_after) VALUES (?, ?, ?, ?, ?)', {
        citizenid, txType, amount, description, balanceAfter
    })
end

local function getDashboard(src, coords, cooldown)
    local allowed, message = checkAccess(src, coords, cooldown)
    if not allowed then return result(false, message) end
    local Player = getPlayer(src)
    if not Player then return result(false, Config.Text.failed) end
    local pd = Player.PlayerData
    local bank = Player.Functions.GetMoney('bank') or 0
    local cash = Player.Functions.GetMoney('cash') or 0
    local history = MySQL.query.await('SELECT id, transaction_type, amount, description, balance_after, created_at FROM bc_banking_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT ?', {
        pd.citizenid, Config.HistoryLimit
    }) or {}
    return result(true, nil, {
        player = ((pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or '')),
        citizenid = pd.citizenid,
        bank = bank,
        cash = cash,
        history = history,
        fees = { withdrawal = Config.WithdrawalFee, transfer = Config.TransferFee }
    })
end

QBCore.Functions.CreateCallback('bc-banking:server:open', function(src, cb, coords)
    cb(getDashboard(src, coords, true))
end)

QBCore.Functions.CreateCallback('bc-banking:server:refresh', function(src, cb, coords)
    cb(getDashboard(src, coords, false))
end)

QBCore.Functions.CreateCallback('bc-banking:server:transaction', function(src, cb, data, coords)
    if busy[src] then cb(result(false, Config.Text.cooldown)); return end
    busy[src] = true
    local function finish(response) busy[src] = nil; cb(response) end
    local allowed, message = checkAccess(src, coords, true)
    if not allowed then finish(result(false, message)); return end
    local Player = getPlayer(src)
    if not Player then finish(result(false, Config.Text.failed)); return end
    local amount = validAmount(data and data.amount, Config.MaximumTransaction)
    local action = data and data.action
    if not amount or (action ~= 'deposit' and action ~= 'withdraw') then
        finish(result(false, Config.Text.invalidAmount)); return
    end
    local cid = Player.PlayerData.citizenid
    if action == 'deposit' then
        if Player.Functions.GetMoney('cash') < amount then finish(result(false, Config.Text.insufficientFunds)); return end
        if not Player.Functions.RemoveMoney('cash', amount, 'bc-banking-deposit') then finish(result(false, Config.Text.failed)); return end
        Player.Functions.AddMoney('bank', amount, 'bc-banking-deposit')
        local balance = Player.Functions.GetMoney('bank')
        addHistory(cid, 'deposit', amount, 'Cash deposit', balance)
        finish(result(true, Config.Text.depositSuccess, { bank = balance, cash = Player.Functions.GetMoney('cash') }))
        return
    end
    local fee = math.max(0, math.floor(tonumber(Config.WithdrawalFee) or 0))
    if Player.Functions.GetMoney('bank') < amount + fee then finish(result(false, Config.Text.insufficientFunds)); return end
    if not Player.Functions.RemoveMoney('bank', amount + fee, 'bc-banking-withdrawal') then finish(result(false, Config.Text.failed)); return end
    Player.Functions.AddMoney('cash', amount, 'bc-banking-withdrawal')
    local balance = Player.Functions.GetMoney('bank')
    addHistory(cid, 'withdrawal', amount, fee > 0 and ('ATM withdrawal (fee $' .. fee .. ')') or 'ATM withdrawal', balance)
    finish(result(true, Config.Text.withdrawSuccess, { bank = balance, cash = Player.Functions.GetMoney('cash') }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:transfer', function(src, cb, data, coords)
    if busy[src] then cb(result(false, Config.Text.cooldown)); return end
    busy[src] = true
    local function finish(response) busy[src] = nil; cb(response) end
    local allowed, message = checkAccess(src, coords, true)
    if not allowed then finish(result(false, message)); return end
    local Player = getPlayer(src)
    if not Player then finish(result(false, Config.Text.failed)); return end
    local amount = validAmount(data and data.amount, Config.MaximumTransfer)
    local citizenid = type(data and data.citizenid) == 'string' and data.citizenid:match('^[%w%-]+$') or nil
    if not amount then finish(result(false, Config.Text.invalidAmount)); return end
    if not citizenid or #citizenid < 3 or #citizenid > 50 then finish(result(false, Config.Text.invalidCitizenId)); return end
    if not Config.AllowSelfTransfer and citizenid == Player.PlayerData.citizenid then finish(result(false, Config.Text.invalidCitizenId)); return end
    local recipient = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not recipient then finish(result(false, Config.Text.invalidCitizenId)); return end
    local fee = math.max(0, math.floor(tonumber(Config.TransferFee) or 0))
    if Player.Functions.GetMoney('bank') < amount + fee then finish(result(false, Config.Text.insufficientFunds)); return end
    if not Player.Functions.RemoveMoney('bank', amount + fee, 'bc-banking-transfer-sent') then finish(result(false, Config.Text.failed)); return end
    recipient.Functions.AddMoney('bank', amount, 'bc-banking-transfer-received')
    local senderBalance = Player.Functions.GetMoney('bank')
    local recipientBalance = recipient.Functions.GetMoney('bank')
    addHistory(Player.PlayerData.citizenid, 'transfer_out', amount, 'Transfer to ' .. citizenid, senderBalance)
    addHistory(citizenid, 'transfer_in', amount, 'Transfer from ' .. Player.PlayerData.citizenid, recipientBalance)
    finish(result(true, Config.Text.transferSuccess, { bank = senderBalance, cash = Player.Functions.GetMoney('cash') }))
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
    busy[source] = nil
end)
