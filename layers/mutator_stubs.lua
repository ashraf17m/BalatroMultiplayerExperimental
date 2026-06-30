-- Stubbed mutator layers. Registered but inert.
--
-- These need real hooks, not just data. They exist in the layer system and can
-- be composed/selected, but they currently do nothing.

-- PvP reward draft:
-- Beat a PvP blind, then pick 1 of N rewards (joker / tarot / money / voucher).
-- Intended hook: the endPvP / PvP-blind-win networking and UI path.
MP.Layer("pvp_reward_draft", {})

-- Rubber-band:
-- Losing a life grants an escalating buff for casual lobbies.
-- Intended hook: the life-loss path.
MP.Layer("rubber_band", {})

-- Score tax:
-- Every hand played nudges the opponent's target up slightly.
-- Intended hook: playHand / enemy-score sync.
MP.Layer("score_tax", {})
