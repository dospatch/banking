# BC-Banking V2 staging test plan

Do not run these tests on the live server first. Use a staging server and a database backup.

## Preflight
- [ ] Confirm the server uses QBCore, qb-target and oxmysql.
- [ ] Confirm the QBCore `players.money` column contains valid JSON with a numeric `bank` property before testing offline transfers.
- [ ] Import `sql.sql` if the V1 transaction table is missing.
- [ ] Import `sql/v2_migration.sql`.
- [ ] Configure exact job names and grade thresholds in `config/v2.lua`.
- [ ] Configure at least one teller location and confirm the target zone appears.
- [ ] Confirm the V1.0.0 backup and database backup are available.

## Personal banking regression
- [ ] Open the ATM UI and verify player identity and balances.
- [ ] Deposit cash; verify cash decreases and bank increases.
- [ ] Withdraw cash; verify bank decreases and cash increases.
- [ ] Transfer to an online citizen; verify both balances and history rows.
- [ ] Reject zero, negative, decimal, over-limit and insufficient-funds amounts.
- [ ] Reject ATM interaction from outside the configured range.
- [ ] Verify V1 transaction history remains visible.

## Business accounts
- [ ] A configured department employee can view the department account.
- [ ] Deposit from personal bank into the business account.
- [ ] Withdraw from the business account with an authorized grade/permission.
- [ ] Confirm unauthorized employees cannot withdraw.
- [ ] Manager grants view/deposit/withdraw permissions to an online same-job employee.
- [ ] Confirm another job cannot access the account.
- [ ] Confirm manager audit entries appear.

## Debit cards
- [ ] Issue a card with the configured PIN length.
- [ ] Confirm only the last four digits are displayed.
- [ ] Confirm no plaintext PIN is stored in SQL.
- [ ] Change PIN with the correct current PIN.
- [ ] Reject an incorrect current PIN.
- [ ] Confirm repeated incorrect PIN attempts trigger a temporary lock.
- [ ] Lock and unlock the card.

## Offline transfers and tellers
- [ ] Transfer to an existing offline citizen ID.
- [ ] Confirm recipient bank balance changes after next login.
- [ ] Reject unknown citizen IDs and self-transfers.
- [ ] Reject offline transfers over the configured maximum.
- [ ] Use a configured teller to open the banking UI.
- [ ] Deposit and withdraw at a teller; confirm distance checks still apply.

## Final checks
- [ ] Restart the resource and verify business balances, cards and transaction history persist.
- [ ] Review server console for Lua errors and oxmysql errors.
- [ ] Verify no duplicate resource instance is running.
- [ ] Only promote V2 to the live server after all applicable checks pass.
