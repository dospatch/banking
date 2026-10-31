Config = {}

Config.Debug = false
Config.TargetDistance = 1.6
Config.InteractionDistance = 4.0
Config.CooldownMs = 900
Config.MaximumTransaction = 1000000
Config.MaximumTransfer = 500000
Config.WithdrawalFee = 0
Config.TransferFee = 0
Config.HistoryLimit = 15
Config.TransferOnlineOnly = true
Config.AllowSelfTransfer = false

Config.AtmModels = {
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03',
    'prop_fleeca_atm'
}

Config.Brand = {
    name = 'BC BANK',
    subtitle = 'SECURE DIGITAL BANKING',
    accent = '#f28c28'
}

Config.Text = {
    tooFar = 'You must be near an ATM to use BC Banking.',
    cooldown = 'Please wait before making another request.',
    invalidAmount = 'Enter a valid whole-dollar amount.',
    invalidCitizenId = 'That citizen ID could not be found.',
    insufficientFunds = 'You do not have enough available funds.',
    failed = 'The transaction could not be completed.',
    depositSuccess = 'Cash deposited successfully.',
    withdrawSuccess = 'Withdrawal completed successfully.',
    transferSuccess = 'Transfer completed successfully.'
}
