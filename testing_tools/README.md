# Multiplayer Testing Tools

This folder is for development-only tools that should not live in normal gameplay modules.

Tools here are loaded only when a hidden developer switch enables them. They are not exposed in the normal SMODS config UI.

Enable with either:

- preferred local developer switch: add `testing_tools=true` to the mod-root `.env`
- legacy hidden saved config field: `testing_tools = true`

Keep tools opt-in, documented, and separate from production paths.

Current tools:

- `rulesets/testing.lua`: testing ruleset with PvP starting at Ante 1.
- `decks/testing_deck.lua`: testing deck that creates sample jokers and sealed cards.
- `decks/testing_2_deck.lua`: testing deck with fixed starting jokers.
- `temp_username_hotkey.lua`: `F8` generates and saves a random testing username.
- `dummy_players_hotkey.lua`: `F9` adds dummy players for lobby/player-list UI testing.
- `diagnostics/calculator.lua`: calculator V2 trace and state-guard audit logging. Loaded by `calculator_trace_logging=true`.
- `diagnostics/team_card_sync.lua`: team playing-card sync trace helpers and observer hooks. Loaded by `runtime_trace_logging=true`.
