# BC-Banking V2.0.0

BC-Banking V2 is a QBCore banking resource with a custom BC BANK NUI, personal ATM banking, shared job accounts, debit card controls, offline transfers, configured teller locations, employee permissions and audit history.

## V2 features

- Personal deposits, withdrawals and online transfers (V1 core).
- Offline citizen-ID transfers to existing QBCore player accounts.
- Shared job/business accounts with separate balances.
- Grade-based department access and manager-controlled employee permissions.
- Debit card issuing, card locking/unlocking and PIN changes.
- Salted PIN hashes, failed-attempt tracking and temporary PIN lockouts.
- Configurable bank teller locations using qb-target.
- Business-account audit history.
- Responsive dark-and-orange BC BANK interface.

## Dependencies

Start these before `bc-banking`:

- `qb-core`
- `qb-target`
- `oxmysql`

## Installation and V1 upgrade

1. Back up the server resource folder and database.
2. Keep a copy of the V1.0.0 release for rollback.
3. Install this branch as a folder named `bc-banking` in your resources directory.
4. Confirm the original V1 table exists by importing `sql.sql` if needed.
5. Import `sql/v2_migration.sql`. It creates V2 tables and does not delete V1 transaction history.
6. Edit `config/v2.lua` to match your exact job names, grades and teller coordinates.
7. Ensure dependencies start before this resource:
   ```cfg
   ensure oxmysql
   ensure qb-core
   ensure qb-target
   ensure bc-banking
   ```
8. Start V2 on a separate staging server first. Do not run two copies named `bc-banking` on the same server.

## Configuration

- `config/config.lua`: ATM models, personal transaction limits, fees and branding.
- `config/v2.lua`: business job accounts, grade thresholds, debit card rules, offline transfer limits and teller locations.
- Add your bank teller coordinates to `Config.V2.TellerLocations` as `vector3(x, y, z)` entries. No teller zones are created until you configure at least one location.
- Business job names must exactly match the names in your QBCore jobs configuration.

## Database behavior

- Personal bank/cash balances remain QBCore-managed.
- Business account balances are stored in `bc_banking_accounts`.
- Employee permissions are stored in `bc_banking_account_members`.
- Card PINs are stored as salted SHA-256 hashes; plaintext PINs are not stored.
- V2 security events are stored in `bc_banking_v2_audit`.
- Offline transfers update the standard QBCore `players.money` JSON column. Confirm your server uses that schema before enabling offline transfers.

## Testing status

V2 has been committed to the `v2-development` branch, but it has not been runtime-tested in a FiveM server. Follow `tests/V2_TEST_PLAN.md` on a staging server before production use. V1.0.0 remains on `main`.
