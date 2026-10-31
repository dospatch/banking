-- BC-Banking V2 configuration
Config.V2 = {
    EnableBusinessAccounts = true,
    EnableDebitCards = true,
    EnableOfflineTransfers = true,
    EnableBankTellers = true,
    EnableEmployeePermissions = true,

    -- PINs are stored as salted hashes in SQL, never as plaintext.
    CardPinLength = 6,
    CardMaxFailedAttempts = 5,
    CardLockMinutes = 15,

    -- Job account permissions are granted by job grade.
    -- Adjust job names and grades to match your server's qb-core/shared/jobs.lua.
    BusinessJobs = {
        police = { label = 'Police Department', minGrade = 0, manageGrade = 4 },
        lspd = { label = 'Los Santos Police Department', minGrade = 0, manageGrade = 4 },
        bcso = { label = 'Blaine County Sheriff Office', minGrade = 0, manageGrade = 4 },
        sast = { label = 'San Andreas State Troopers', minGrade = 0, manageGrade = 4 },
        ambulance = { label = 'Emergency Medical Services', minGrade = 0, manageGrade = 3 },
        safr = { label = 'San Andreas Fire Rescue', minGrade = 0, manageGrade = 3 },
        mechanic = { label = 'Mechanic Shop', minGrade = 0, manageGrade = 3 }
    },

    -- Tellers are usable only at these configured coordinates.
    TellerLocations = {
        -- Example:
        -- { coords = vector3(149.9, -1040.7, 29.4), label = 'Legion Square Teller' }
    },
    TellerDistance = 3.0,

    -- Offline transfers update the standard QBCore players.money JSON column.
    OfflineTransferMaximum = 250000,
    OfflineTransferFee = 0,

    AuditLimit = 25
}
