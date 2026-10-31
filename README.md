# BC-Banking V1

A modern dark-and-orange QBCore ATM banking resource with a custom NUI dashboard, personal account overview, deposits, withdrawals, online citizen-ID transfers, and persistent transaction history.

## V1 features

- BC-BANK branded responsive NUI dashboard.
- Bank and cash balances.
- Deposit cash and withdraw cash.
- Transfer money to another online citizen by citizen ID.
- Recent activity and transaction history stored in MySQL.
- Configurable transaction limits, cooldown, ATM range and optional fees.
- Server-side amount checks, ATM-distance checks, per-player transaction lock and recipient validation.
- Uses QBCore money functions, so balances remain part of the normal QBCore player account.

## Dependencies

Start these resources before `bc-banking`:

- `qb-core`
- `qb-target`
- `oxmysql`

This resource intentionally uses its own NUI and does not require `qb-menu` or `qb-input`.

## Installation

1. Extract the `bc-banking` folder into your server's resources directory, for example `resources/[qb]/bc-banking`.
2. Import `sql.sql` into the same database used by your QBCore server. The table is also safe to create manually with the supplied SQL.
3. Add the following to `server.cfg` after the dependencies:

```cfg
ensure oxmysql
ensure qb-core
ensure qb-target
ensure bc-banking
```

4. Restart the server, or run `refresh` then `ensure bc-banking` in the server console.
5. Walk up to an ATM, use the qb-target eye, and choose **Open BC Banking**.

## Configuration

Edit `config/config.lua`:

- `Config.WithdrawalFee` and `Config.TransferFee` default to `0`.
- `Config.MaximumTransaction` and `Config.MaximumTransfer` control limits.
- `Config.InteractionDistance` is checked server-side against the supplied ATM position.
- `Config.HistoryLimit` controls how many recent transactions are displayed.
- `Config.AtmModels` controls supported ATM props.

## Important V1 scope

- Transfers are online-only in V1. The recipient must be connected.
- This build does not yet include business/shared accounts, debit cards, PIN management, bank tellers, offline transfers, or employee permissions. Those need their own account ownership and authorization model and should be added as a separately tested V1.1/V2 feature set.
- QBCore's built-in `bank` and `cash` balances remain authoritative. The transaction table is an activity ledger, not a second balance store.

## Test checklist

1. Confirm the resource starts without missing dependency errors.
2. Open an ATM and verify player name, citizen ID, bank balance and cash balance.
3. Deposit a small amount and verify cash decreases and bank increases.
4. Withdraw a small amount and verify bank decreases and cash increases.
5. Transfer to a second online player and verify both balances and both activity records.
6. Try zero, negative, decimal, oversized and insufficient-funds amounts; all should be rejected.
7. Try opening the UI away from an ATM; the server should reject it.
8. Restart the resource and verify the transaction history remains in the database.
