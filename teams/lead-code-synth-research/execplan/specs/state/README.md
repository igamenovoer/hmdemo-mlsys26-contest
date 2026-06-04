# State Specs

## Purpose

This generated directory defines durable bookkeeping state authority, initialization, invariants, and SQL schema for the loop.

## Contents

- `state-overview.md`: readable state authority, boundaries, transitions, scheduling queries, and non-state content contract.
- `schema.sql`: sqlite schema for durable control-plane state.
- `seed.toml`: deterministic initial state values.
- `invariants.toml`: validation-visible state invariants.
