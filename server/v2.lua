local QBCore = exports['qb-core']:GetCoreObject()


local v2LastUse = {}

local function checkAccess(src, coords, useCooldown)
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
        return false, Config.Text.tooFar
    end
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false, Config.Text.tooFar end
    local pos = GetEntityCoords(ped)
    if #(pos - vector3(coords.x, coords.y, coords.z)) > Config.InteractionDistance then
        return false, Config.Text.tooFar
    end
    if useCooldown then
        local now = GetGameTimer()
        if v2LastUse[src] and now - v2LastUse[src] < Config.CooldownMs then
            return false, Config.Text.cooldown
        end
        v2LastUse[src] = now
    end
    return true
end

local function addHistory(cid, txType, amount, description, balanceAfter)
    MySQL.insert('INSERT INTO bc_banking_transactions (citizenid, transaction_type, amount, description, balance_after) VALUES (?, ?, ?, ?, ?)', {
        cid, txType, amount, description, balanceAfter
    })
end

local function v2Result(ok, message, data)
    return { ok = ok, message = message, data = data }
end

local function player(src)
    return QBCore.Functions.GetPlayer(src)
end

local function citizenId(Player)
    return Player and Player.PlayerData and Player.PlayerData.citizenid
end

local function validAmount(value, maximum)
    local n = tonumber(value)
    if not n or n ~= math.floor(n) or n < 1 or n > maximum then return nil end
    return n
end

local function audit(cid, accountKey, action, amount, details)
    MySQL.insert('INSERT INTO bc_banking_v2_audit (actor_citizenid, account_key, action, amount, details) VALUES (?, ?, ?, ?, ?)', {
        cid, accountKey, action, amount or 0, tostring(details or ''):sub(1, 255)
    })
end

local function jobAccess(Player)
    local job = Player and Player.PlayerData and Player.PlayerData.job
    if not job then return nil end
    local rule = Config.V2.BusinessJobs[job.name]
    if not rule then return nil end
    local grade = type(job.grade) == 'table' and tonumber(job.grade.level) or tonumber(job.grade) or 0
    if grade < (rule.minGrade or 0) then return nil end
    return job, rule, grade
end

local function ensureJobAccount(job, rule)
    local key = 'job:' .. job.name
    MySQL.insert.await([[
        INSERT IGNORE INTO bc_banking_accounts (account_key, account_type, job_name, label, balance)
        VALUES (?, 'business', ?, ?, 0)
    ]], { key, job.name, rule.label or job.label or job.name })
    return MySQL.single.await('SELECT * FROM bc_banking_accounts WHERE account_key = ? LIMIT 1', { key })
end

local function businessPermission(Player, account, permission)
    local cid = citizenId(Player)
    local job, rule, grade = jobAccess(Player)
    if not cid or not account or not job or account.job_name ~= job.name then return false end

    local member = MySQL.single.await(
        'SELECT can_view, can_deposit, can_withdraw, can_manage FROM bc_banking_account_members WHERE account_id = ? AND citizenid = ? LIMIT 1',
        { account.id, cid }
    )
    if member then return tonumber(member['can_' .. permission]) == 1 end
    if permission == 'view' or permission == 'deposit' then return true end
    if permission == 'withdraw' then return grade >= (rule.withdrawGrade or rule.manageGrade or 999) end
    if permission == 'manage' then return grade >= (rule.manageGrade or 999) end
    return false
end

local function tellerAccess(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, teller in ipairs(Config.V2.TellerLocations or {}) do
        local c = teller.coords
        if c and #(pos - c) <= (Config.V2.TellerDistance or 3.0) then return true end
    end
    return false
end

QBCore.Functions.CreateCallback('bc-banking:server:v2:business', function(src, cb)
    if not Config.V2.EnableBusinessAccounts then cb(v2Result(false, 'Business accounts are disabled.')); return end
    local Player = player(src)
    local job, rule = jobAccess(Player)
    if not job then cb(v2Result(false, 'Your job is not configured for a business account.')); return end
    local account = ensureJobAccount(job, rule)
    if not account or not businessPermission(Player, account, 'view') then
        cb(v2Result(false, 'You do not have access to this account.')); return
    end
    cb(v2Result(true, nil, {
        account = { key = account.account_key, label = account.label, balance = tonumber(account.balance) or 0, type = account.account_type },
        canDeposit = businessPermission(Player, account, 'deposit'),
        canWithdraw = businessPermission(Player, account, 'withdraw'),
        canManage = businessPermission(Player, account, 'manage')
    }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:businessTransaction', function(src, cb, data)
    if not Config.V2.EnableBusinessAccounts then cb(v2Result(false, 'Business accounts are disabled.')); return end
    local Player = player(src)
    local job, rule = jobAccess(Player)
    if not job then cb(v2Result(false, 'Your job is not configured for a business account.')); return end
    local account = ensureJobAccount(job, rule)
    local action = data and data.action
    local permission = action == 'deposit' and 'deposit' or action == 'withdraw' and 'withdraw' or nil
    local amount = validAmount(data and data.amount, Config.MaximumTransaction)
    if not permission or not amount then cb(v2Result(false, Config.Text.invalidAmount)); return end
    if not businessPermission(Player, account, permission) then cb(v2Result(false, 'You do not have permission for this transaction.')); return end

    local cid = citizenId(Player)
    if action == 'deposit' then
        if Player.Functions.GetMoney('bank') < amount then cb(v2Result(false, Config.Text.insufficientFunds)); return end
        if not Player.Functions.RemoveMoney('bank', amount, 'bc-banking-business-deposit') then cb(v2Result(false, Config.Text.failed)); return end
        local changed = MySQL.update.await('UPDATE bc_banking_accounts SET balance = balance + ? WHERE id = ?', { amount, account.id })
        if not changed or changed < 1 then
            Player.Functions.AddMoney('bank', amount, 'bc-banking-business-deposit-refund')
            cb(v2Result(false, Config.Text.failed)); return
        end
    else
        local changed = MySQL.update.await('UPDATE bc_banking_accounts SET balance = balance - ? WHERE id = ? AND balance >= ?', { amount, account.id, amount })
        if not changed or changed < 1 then cb(v2Result(false, 'The business account has insufficient funds.')); return end
        Player.Functions.AddMoney('bank', amount, 'bc-banking-business-withdrawal')
    end

    local updated = MySQL.scalar.await('SELECT balance FROM bc_banking_accounts WHERE id = ?', { account.id }) or 0
    audit(cid, account.account_key, 'business_' .. action, amount, job.name)
    cb(v2Result(true, 'Business account ' .. action .. ' completed.', { balance = tonumber(updated) or 0, bank = Player.Functions.GetMoney('bank') }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:businessMember', function(src, cb, data)
    if not Config.V2.EnableEmployeePermissions then cb(v2Result(false, 'Employee permissions are disabled.')); return end
    local Player = player(src)
    local job, rule = jobAccess(Player)
    if not job then cb(v2Result(false, 'Not authorized.')); return end
    local account = ensureJobAccount(job, rule)
    if not businessPermission(Player, account, 'manage') then cb(v2Result(false, 'Only authorized account managers can change employee permissions.')); return end

    local targetCid = type(data and data.citizenid) == 'string' and data.citizenid:match('^[%w%-]+$') or nil
    if not targetCid or #targetCid < 3 or #targetCid > 50 or targetCid == citizenId(Player) then
        cb(v2Result(false, 'Enter a valid employee citizen ID.')); return
    end
    local target = QBCore.Functions.GetPlayerByCitizenId(targetCid)
    if not target or not target.PlayerData.job or target.PlayerData.job.name ~= job.name then
        cb(v2Result(false, 'The employee must be online and in your department.')); return
    end
    local perms = data.permissions or {}
    local canView = perms.view == true
    local canDeposit = perms.deposit == true
    local canWithdraw = perms.withdraw == true
    local canManage = false -- managers cannot delegate management authority
    MySQL.insert.await([[
        INSERT INTO bc_banking_account_members (account_id, citizenid, can_view, can_deposit, can_withdraw, can_manage)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE can_view = VALUES(can_view), can_deposit = VALUES(can_deposit),
          can_withdraw = VALUES(can_withdraw), can_manage = VALUES(can_manage)
    ]], { account.id, targetCid, canView and 1 or 0, canDeposit and 1 or 0, canWithdraw and 1 or 0, canManage and 1 or 0 })
    audit(citizenId(Player), account.account_key, 'employee_permissions', 0, 'Updated permissions for ' .. targetCid)
    cb(v2Result(true, 'Employee permissions updated.'))
end)

local function makeSalt(src)
    -- Per-card salt; the PIN itself is never stored in the database.
    return string.format('%08x%08x%08x%08x', math.random(0, 0x7fffffff), os.time(), GetGameTimer() or 0, src)
end

local function pinHash(pin, salt)
    return MySQL.scalar.await('SELECT SHA2(CONCAT(?, ?), 256)', { pin, salt })
end

QBCore.Functions.CreateCallback('bc-banking:server:v2:cardStatus', function(src, cb)
    if not Config.V2.EnableDebitCards then cb(v2Result(false, 'Debit cards are disabled.')); return end
    local Player = player(src)
    local cid = citizenId(Player)
    if not cid then cb(v2Result(false, Config.Text.failed)); return end
    local card = MySQL.single.await('SELECT card_last4, is_locked, failed_attempts, locked_until FROM bc_banking_cards WHERE citizenid = ? LIMIT 1', { cid })
    cb(v2Result(true, nil, { exists = card ~= nil, card = card and {
        last4 = card.card_last4, locked = tonumber(card.is_locked) == 1, failedAttempts = tonumber(card.failed_attempts) or 0,
        lockedUntil = card.locked_until
    } or nil }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:issueCard', function(src, cb, data)
    if not Config.V2.EnableDebitCards then cb(v2Result(false, 'Debit cards are disabled.')); return end
    local Player = player(src)
    local cid = citizenId(Player)
    local pin = tostring(data and data.pin or '')
    if not cid or #pin ~= Config.V2.CardPinLength or not pin:match('^%d+$') then
        cb(v2Result(false, 'Your PIN must be exactly ' .. Config.V2.CardPinLength .. ' digits.')); return
    end
    local existing = MySQL.scalar.await('SELECT id FROM bc_banking_cards WHERE citizenid = ?', { cid })
    if existing then cb(v2Result(false, 'You already have a debit card.')); return end
    local salt = makeSalt(src)
    local hash = pinHash(pin, salt)
    local last4 = string.format('%04d', math.random(0, 9999))
    MySQL.insert.await('INSERT INTO bc_banking_cards (citizenid, card_last4, pin_salt, pin_hash) VALUES (?, ?, ?, ?)', { cid, last4, salt, hash })
    audit(cid, nil, 'card_issued', 0, 'Card ending ' .. last4)
    cb(v2Result(true, 'Debit card issued.', { last4 = last4 }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:changePin', function(src, cb, data)
    local Player = player(src)
    local cid = citizenId(Player)
    local currentPin = tostring(data and data.currentPin or '')
    local newPin = tostring(data and data.newPin or '')
    if not cid or #newPin ~= Config.V2.CardPinLength or not newPin:match('^%d+$') then
        cb(v2Result(false, 'Your new PIN must be exactly ' .. Config.V2.CardPinLength .. ' digits.')); return
    end
    local card = MySQL.single.await('SELECT * FROM bc_banking_cards WHERE citizenid = ? LIMIT 1', { cid })
    if not card then cb(v2Result(false, 'Issue a debit card first.')); return end
    if tonumber(card.is_locked) == 1 then cb(v2Result(false, 'Your debit card is locked.')); return end
    if card.locked_until and tostring(card.locked_until) > os.date('%Y-%m-%d %H:%M:%S') then
        cb(v2Result(false, 'Your card is temporarily locked.')); return
    end
    if pinHash(currentPin, card.pin_salt) ~= card.pin_hash then
        local attempts = (tonumber(card.failed_attempts) or 0) + 1
        local lockUntil = attempts >= Config.V2.CardMaxFailedAttempts and os.date('%Y-%m-%d %H:%M:%S', os.time() + Config.V2.CardLockMinutes * 60) or nil
        MySQL.update.await('UPDATE bc_banking_cards SET failed_attempts = ?, locked_until = ? WHERE citizenid = ?', { attempts, lockUntil, cid })
        cb(v2Result(false, 'Current PIN is incorrect.')); return
    end
    local salt = makeSalt(src)
    local hash = pinHash(newPin, salt)
    MySQL.update.await('UPDATE bc_banking_cards SET pin_salt = ?, pin_hash = ?, failed_attempts = 0, locked_until = NULL WHERE citizenid = ?', { salt, hash, cid })
    audit(cid, nil, 'card_pin_changed', 0, 'PIN changed')
    cb(v2Result(true, 'Debit card PIN updated.'))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:verifyPin', function(src, cb, data)
    local Player = player(src)
    local cid = citizenId(Player)
    local pin = tostring(data and data.pin or '')
    local card = cid and MySQL.single.await('SELECT * FROM bc_banking_cards WHERE citizenid = ? LIMIT 1', { cid })
    if not card then cb(v2Result(false, 'No debit card found.')); return end
    if tonumber(card.is_locked) == 1 then cb(v2Result(false, 'Your debit card is locked.')); return end
    if card.locked_until and tostring(card.locked_until) > os.date('%Y-%m-%d %H:%M:%S') then
        cb(v2Result(false, 'Your card is temporarily locked.')); return
    end
    if pinHash(pin, card.pin_salt) ~= card.pin_hash then
        local attempts = (tonumber(card.failed_attempts) or 0) + 1
        local lockUntil = attempts >= Config.V2.CardMaxFailedAttempts and os.date('%Y-%m-%d %H:%M:%S', os.time() + Config.V2.CardLockMinutes * 60) or nil
        MySQL.update.await('UPDATE bc_banking_cards SET failed_attempts = ?, locked_until = ? WHERE citizenid = ?', { attempts, lockUntil, cid })
        audit(cid, nil, 'card_pin_failed', 0, 'Failed PIN attempt')
        cb(v2Result(false, 'Incorrect PIN.')); return
    end
    MySQL.update.await('UPDATE bc_banking_cards SET failed_attempts = 0, locked_until = NULL WHERE citizenid = ?', { cid })
    cb(v2Result(true, 'PIN verified.'))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:lockCard', function(src, cb, data)
    local Player = player(src)
    local cid = citizenId(Player)
    local locked = data and data.locked == true
    if not cid then cb(v2Result(false, Config.Text.failed)); return end
    local changed = MySQL.update.await('UPDATE bc_banking_cards SET is_locked = ?, failed_attempts = 0, locked_until = NULL WHERE citizenid = ?', { locked and 1 or 0, cid })
    if not changed or changed < 1 then cb(v2Result(false, 'No debit card was found.')); return end
    audit(cid, nil, locked and 'card_locked' or 'card_unlocked', 0, 'Card state changed')
    cb(v2Result(true, locked and 'Debit card locked.' or 'Debit card unlocked.'))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:offlineTransfer', function(src, cb, data, coords)
    if not Config.V2.EnableOfflineTransfers then cb(v2Result(false, 'Offline transfers are disabled.')); return end
    local Player = player(src)
    if not Player then cb(v2Result(false, Config.Text.failed)); return end
    local allowed, message = checkAccess(src, coords, true)
    if not allowed then cb(v2Result(false, message)); return end
    local amount = validAmount(data and data.amount, Config.V2.OfflineTransferMaximum)
    local targetCid = type(data and data.citizenid) == 'string' and data.citizenid:match('^[%w%-]+$') or nil
    if not amount then cb(v2Result(false, Config.Text.invalidAmount)); return end
    if not targetCid or #targetCid < 3 or #targetCid > 50 or targetCid == citizenId(Player) then
        cb(v2Result(false, Config.Text.invalidCitizenId)); return
    end
    local fee = math.max(0, math.floor(tonumber(Config.V2.OfflineTransferFee) or 0))
    if Player.Functions.GetMoney('bank') < amount + fee then cb(v2Result(false, Config.Text.insufficientFunds)); return end

    local onlineRecipient = QBCore.Functions.GetPlayerByCitizenId(targetCid)
    local offlineExists = not onlineRecipient and MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { targetCid })
    if not onlineRecipient and not offlineExists then cb(v2Result(false, Config.Text.invalidCitizenId)); return end
    if not Player.Functions.RemoveMoney('bank', amount + fee, 'bc-banking-offline-transfer') then cb(v2Result(false, Config.Text.failed)); return end

    local recipientBalance
    local success = true
    if onlineRecipient then
        onlineRecipient.Functions.AddMoney('bank', amount, 'bc-banking-offline-transfer-received')
        recipientBalance = onlineRecipient.Functions.GetMoney('bank')
    else
        local changed = MySQL.update.await([[
            UPDATE players
            SET money = JSON_SET(money, '$.bank',
                CAST(COALESCE(JSON_UNQUOTE(JSON_EXTRACT(money, '$.bank')), '0') AS SIGNED) + ?)
            WHERE citizenid = ?
        ]], { amount, targetCid })
        success = changed and changed > 0
    end

    if not success then
        Player.Functions.AddMoney('bank', amount + fee, 'bc-banking-transfer-refund')
        cb(v2Result(false, Config.Text.failed)); return
    end

    local senderBalance = Player.Functions.GetMoney('bank')
    addHistory(citizenId(Player), 'transfer_out', amount, 'Transfer to ' .. targetCid, senderBalance)
    if onlineRecipient then
        addHistory(targetCid, 'transfer_in', amount, 'Transfer from ' .. citizenId(Player), recipientBalance)
    else
        MySQL.insert.await('INSERT INTO bc_banking_transactions (citizenid, transaction_type, amount, description, balance_after) VALUES (?, ?, ?, ?, 0)', {
            targetCid, 'transfer_in', amount, 'Offline transfer from ' .. citizenId(Player)
        })
    end
    audit(citizenId(Player), nil, 'offline_transfer', amount, 'To ' .. targetCid)
    cb(v2Result(true, 'Transfer completed.', { bank = senderBalance, cash = Player.Functions.GetMoney('cash') }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:tellerOpen', function(src, cb)
    if not Config.V2.EnableBankTellers or not tellerAccess(src) then
        cb(v2Result(false, 'You must be at a configured bank teller.')); return
    end
    local Player = player(src)
    if not Player then cb(v2Result(false, Config.Text.failed)); return end
    local pd = Player.PlayerData
    local history = MySQL.query.await('SELECT id, transaction_type, amount, description, balance_after, created_at FROM bc_banking_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT ?', {
        pd.citizenid, Config.HistoryLimit
    }) or {}
    cb(v2Result(true, nil, {
        player = ((pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or '')),
        citizenid = pd.citizenid,
        bank = Player.Functions.GetMoney('bank') or 0,
        cash = Player.Functions.GetMoney('cash') or 0,
        history = history,
        fees = { withdrawal = Config.WithdrawalFee, transfer = Config.TransferFee },
        teller = true
    }))
end)

QBCore.Functions.CreateCallback('bc-banking:server:v2:audit', function(src, cb)
    local Player = player(src)
    local job, rule = jobAccess(Player)
    if not job then cb(v2Result(false, 'Not authorized.')); return end
    local account = ensureJobAccount(job, rule)
    if not businessPermission(Player, account, 'manage') then cb(v2Result(false, 'Only account managers can view the audit log.')); return end
    local rows = MySQL.query.await('SELECT actor_citizenid, action, amount, details, created_at FROM bc_banking_v2_audit WHERE account_key = ? ORDER BY id DESC LIMIT ?', {
        account.account_key, Config.V2.AuditLimit
    }) or {}
    cb(v2Result(true, nil, { rows = rows }))
end)
