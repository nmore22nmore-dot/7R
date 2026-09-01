# N Wallet Production Hardening

- Removed the development `n_add_test_coins` RPC from the production schema.
- Coin balance changes must come from trusted server-side purchase/ledger flows.
- Gift sending remains an atomic SECURITY DEFINER operation with row locking on the sender balance.
- Gift catalog is read-only to normal authenticated users.
- Coin transactions and gift sends are readable only by participants/owners through RLS.
- A real payment provider is still required before selling coins for real money.
