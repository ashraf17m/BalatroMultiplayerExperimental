-- Extra Credit Utilities Module
-- Shared utility functions for Extra Credit jokers ported to Sandbox
-- This file is prefixed with underscore to ensure it loads before the joker files

local content_runtime = MP.CONTENT.RUNTIME

MP.EC = MP.EC or {}

local function copy_shallow(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = value
	end
	return copy
end

function MP.EC.register_sandbox_joker(definition)
	local joker_definition = copy_shallow(definition)
	local config = copy_shallow(joker_definition.config)

	joker_definition.no_collection = MP.sandbox_no_collection
	joker_definition.unlocked = true
	joker_definition.discovered = true
	joker_definition.atlas = joker_definition.atlas or "ec_jokers_sandbox"
	joker_definition.mp_include = MP.SANDBOX.include_joker
	config.mp_sticker_extra_credit = true
	joker_definition.config = config

	return SMODS.Joker(joker_definition)
end

function MP.EC.destroy_joker(card)
	MP.SANDBOX.destroy_joker(card, true)
end

function MP.EC.queue_tag(tag_key_or_factory)
	G.E_MANAGER:add_event(Event({
		func = function()
			local tag_key = type(tag_key_or_factory) == "function" and tag_key_or_factory() or tag_key_or_factory
			add_tag(Tag(tag_key))
			play_sound("generic1", 0.9 + math.random() * 0.1, 0.8)
			play_sound("holo1", 1.2 + math.random() * 0.1, 0.4)
			return true
		end,
	}))
end

local function reset_round_selection(state_key, field_key, pool, in_pool_args, seed)
	local state = G.GAME.current_round[state_key] or {}
	local current_value = state[field_key]
	local valid_keys = {}

	G.GAME.current_round[state_key] = state

	for key, entry in pairs(pool) do
		if key ~= current_value and (type(entry.in_pool) ~= "function" or entry:in_pool(in_pool_args)) then
			valid_keys[#valid_keys + 1] = key
		end
	end

	state[field_key] = pseudorandom_element(valid_keys, pseudoseed(seed))
end

local function reset_tuxedo_card()
	reset_round_selection("tuxedo_card", "suit", SMODS.Suits, { rank = "" }, "tux")
end

local function reset_farmer_card()
	reset_round_selection("farmer_card", "suit", SMODS.Suits, { rank = "" }, "farm")
end

local function reset_fish_rank()
	reset_round_selection("fish_rank", "rank", SMODS.Ranks, { suit = "" }, "fish")
end

--- Hook into game globals reset to initialize EC round state
--- Called at start of each round
local original_reset_game_globals = reset_game_globals
function reset_game_globals(run_start)
	if original_reset_game_globals then original_reset_game_globals(run_start) end

	-- Only initialize EC state when sandbox ruleset is active
	if content_runtime.is_ruleset_active("sandbox") then
		reset_tuxedo_card()
		reset_farmer_card()
		reset_fish_rank()
	end
end

-- Hoarder joker: gain sell value each time we earn money
local original_ease_dollars = ease_dollars
function ease_dollars(mod, x)
	original_ease_dollars(mod, x)

	if content_runtime.is_ruleset_active("sandbox") and to_big(mod) > to_big(0) and G.jokers and G.jokers.cards then
		for i = 1, #G.jokers.cards do
			local card = G.jokers.cards[i]
			if card.config.center.key == "j_mp_hoarder_sandbox" and not card.debuffed then
				card.ability.extra_value = card.ability.extra_value + card.ability.extra
				card:set_cost()
				card_eval_status_text(card, "extra", nil, nil, nil, {
					message = localize("k_val_up"),
					colour = G.C.MONEY,
					card = card,
				})
			end
		end
	end
end
