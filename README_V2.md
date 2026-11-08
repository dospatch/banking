# BC-Banking V2.0.0 (development)

V2 is developed on the `v2-development` branch. The released V1.0.0 code remains on `main` and is not overwritten by this work.

## V2 feature scope

- Personal ATM banking and V1 transaction history.
- Job/business accounts with grade-based access.
- Employee account membership permissions.
- Debit card issuing, locking and PIN management.
- Salted PIN hashes, failed-attempt limits and temporary lockouts.
- Online and offline citizen transfers.
- Configurable bank teller locations.
- Separate V2 audit history.
- Updated BC BANK interface.

## Upgrade from V1

1. Back up your database and resource folder.
2. Keep the V1.0.0 resource folder as a rollback copy.
3. Install the V2 resource files from this branch.
4. Import the original `sql.sql` only if the V1 transaction table does not already exist.
5. Import `sql/v2_migration.sql`. It creates only V2 tables and does not delete or rewrite V1 history.
6. Review `config/v2.lua`; change the sample job names and grades to match your server.
7. Ensure `oxmysql`, `qb-core`, and `qb-target` start before `bc-banking`.
8. Test on a separate FiveM test server before replacing the live V1 resource.

## Important notes

- Never run two copies with the same resource name on one server.
- Job account balances are stored separately from personal QBCore bank balances.
- Offline transfers require the standard QBCore `players` table with a JSON `money` column.
- Tellers require coordinates to be configured in `Config.V2.TellerLocations`.
- PINs must never be logged or stored in plaintext.
- This development branch is not a claim of FiveM runtime testing. Complete the test checklist on a staging server before production use.
