local team_card_sync = MP.SYNC and MP.SYNC.TEAM_CARD or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local TEAM_CARD_POST_SCORE_NETWORK_GRACE_DELAY = 0.12
local resuming_play_discard = false

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local function require_apply_api(name)
	local value = team_card_sync[name]
	if not value then
		error("Team card sync apply API missing: " .. tostring(name))
	end
	return value
end

local is_syncable_playing_card = require_snapshot_api("is_syncable_playing_card")
local is_main_team_area = require_snapshot_api("is_main_team_area")
local ensure_card_base_runtime = require_snapshot_api("ensure_card_base_runtime")
local is_team_card_sync_active = require_apply_api("is_sync_active")
local sync_new_card = require_apply_api("sync_new_card")
local sync_card = require_apply_api("sync")
local sync_card_list = require_apply_api("sync_card_list")
local relay_team_card_removal = require_apply_api("relay_removal")
local animate_pending_remote_changes_for_played_hand = require_apply_api("animate_pending_remote_changes_for_played_hand")

local function is_calculator_dry_run()
	return MP and MP.CALCULATOR_V2 and MP.CALCULATOR_V2.dry_run_active
end

local function process_arrived_network_messages()
	local process_network_messages = MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.process_network_messages or nil
	if type(process_network_messages) == "function" then
		process_network_messages()
	end
end

local function has_played_cards_waiting_to_discard()
	return G and G.play and type(G.play.cards) == "table" and #G.play.cards > 0
end

local function run_draw_from_play_to_discard()
	if not (G and G.FUNCS and G.FUNCS.draw_from_play_to_discard) then
		return true
	end

	resuming_play_discard = true
	G.FUNCS.draw_from_play_to_discard()
	resuming_play_discard = false
	return true
end

local function animate_or_resume_play_discard()
	process_arrived_network_messages()
	if animate_pending_remote_changes_for_played_hand(run_draw_from_play_to_discard) then
		return true
	end

	return run_draw_from_play_to_discard()
end

local function queue_new_card_sync_after_emplace(card)
	if not card or card.mp_synced_as_added or card.mp_team_card_add_sync_pending then
		return
	end

	card.mp_team_card_add_sync_pending = true
	local function sync_after_addition_settles()
		card.mp_team_card_add_sync_pending = nil
		if not card.mp_synced_as_added then
			sync_new_card(card)
		end
		return true
	end

	if BALATRO.queue_event then
		BALATRO.queue_event({
			trigger = "after",
			delay = 0,
			func = sync_after_addition_settles,
		})
	else
		sync_after_addition_settles()
	end
end

local function handle_team_card_emplace(area, card)
	if is_calculator_dry_run() then return end
	local main_area = is_main_team_area(area)
	local syncable = is_syncable_playing_card(card)
	if not main_area or not syncable then
		return
	end

	ensure_card_base_runtime(card)
	if is_team_card_sync_active() then
		queue_new_card_sync_after_emplace(card)
	end
end

local function ensure_cards_can_be_played(cards)
	if type(cards) ~= "table" then return end

	for _, card in ipairs(cards) do
		ensure_card_base_runtime(card)
	end
end

local function collect_played_team_cards()
	local played_cards = {}
	if G and G.play and G.play.cards then
		for _, card in ipairs(G.play.cards) do
			played_cards[#played_cards + 1] = card
		end
	end
	return played_cards
end

local function collect_highlighted_team_cards()
	local highlighted_cards = {}
	if G and G.hand and G.hand.highlighted then
		for _, card in ipairs(G.hand.highlighted) do
			highlighted_cards[#highlighted_cards + 1] = card
		end
	end
	return highlighted_cards
end

local function register_team_card_syncing_method(method_name)
	MP.HOOKS.register_method_hook(Card, "Card", method_name, "mp.team_card_sync." .. method_name, {
		after = function(ctx, self)
			if is_calculator_dry_run() then return end
			sync_card(self)
		end,
	})
end

local function install_team_card_sync_hooks()
	MP.HOOKS.register_method_hook(CardArea, "CardArea", "emplace", "mp.team_card_sync.emplace", {
		after = function(ctx, self)
			local card = ctx.args and ctx.args[1] or nil
			handle_team_card_emplace(self, card)
		end,
	})


	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "play_cards_from_highlighted", "mp.team_card_sync.ensure_play_runtime", {
		before = function(ctx)
			if is_calculator_dry_run() then return end
			ensure_cards_can_be_played(G and G.hand and G.hand.highlighted)
		end,
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "evaluate_play", "mp.team_card_sync.evaluate_play", {
		before = function(ctx)
			if is_calculator_dry_run() or not is_team_card_sync_active() then return end
			ctx.mp_team_card_sync_played_cards = collect_played_team_cards()
		end,
		after = function(ctx)
			if is_calculator_dry_run() or not is_team_card_sync_active() then return end
			sync_card_list(ctx.mp_team_card_sync_played_cards or {})
		end,
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "discard_cards_from_highlighted", "mp.team_card_sync.discard_cards", {
		before = function(ctx)
			if is_calculator_dry_run() or not is_team_card_sync_active() then return end
			ctx.mp_team_card_sync_discarded_cards = collect_highlighted_team_cards()
		end,
		after = function(ctx)
			if is_calculator_dry_run() or not is_team_card_sync_active() then return end
			sync_card_list(ctx.mp_team_card_sync_discarded_cards or {})
		end,
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "draw_from_play_to_discard", "mp.team_card_sync.flush_before_play_discard", {
		before = function(ctx)
			if is_calculator_dry_run() then return end
			if resuming_play_discard then return end

			process_arrived_network_messages()
			if animate_pending_remote_changes_for_played_hand(run_draw_from_play_to_discard) then
				ctx.skip_original = true
				return
			end

			local shared_sync_enabled = MP.is_shared_card_sync_enabled and MP.is_shared_card_sync_enabled()
			if shared_sync_enabled and is_team_card_sync_active() and has_played_cards_waiting_to_discard() and BALATRO.queue_event then
				ctx.skip_original = true
				BALATRO.queue_event({
					trigger = "after",
					delay = TEAM_CARD_POST_SCORE_NETWORK_GRACE_DELAY,
					func = animate_or_resume_play_discard,
				})
			end
		end,
	})

	register_team_card_syncing_method("set_edition")
	register_team_card_syncing_method("set_seal")
	register_team_card_syncing_method("set_ability")
	register_team_card_syncing_method("set_base")

	MP.HOOKS.register_method_hook(Card, "Card", "remove", "mp.team_card_sync.remove_relay", {
		before = function(ctx, self)
			if is_calculator_dry_run() then return end
			relay_team_card_removal(self)
		end,
	})
end

install_team_card_sync_hooks()
