local team_card_sync = MP.TEAM_CARD or {}

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local function require_apply_api(name)
	local value = team_card_sync[name]
	if not value then
		error("Team card sync apply API missing: " .. tostring(name))
	end
	return value
end

local is_syncable_playing_card = require_snapshot_api("is_syncable_playing_card")
local assign_card_id = require_snapshot_api("assign_card_id")
local is_main_team_area = require_snapshot_api("is_main_team_area")
local mark_card_ready_for_team_sync = require_snapshot_api("mark_card_ready_for_team_sync")
local can_relay_team_card_changes = require_apply_api("can_relay_changes")
local sync_card = require_apply_api("sync")
local sync_card_list = require_apply_api("sync_card_list")
local relay_team_card_removal = require_apply_api("relay_removal")

local function should_assign_team_card_id_on_init(card)
	return G and G.STAGE == G.STAGES.RUN and is_syncable_playing_card(card)
end

local function is_calculator_dry_run()
	return MP and MP.CALCULATOR_V2 and MP.CALCULATOR_V2.dry_run_active
end

local function handle_team_card_init(card)
	if should_assign_team_card_id_on_init(card) then
		assign_card_id(card)
	end
end

local function handle_team_card_emplace(area, card)
	if is_calculator_dry_run() then return end
	if not can_relay_team_card_changes() or not is_main_team_area(area) or not is_syncable_playing_card(card) then
		return
	end

	assign_card_id(card)
	if not card.mp_synced_as_added then
		mark_card_ready_for_team_sync(card)
		sync_card(card)
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
	MP.HOOKS.register_method_hook(Card, "Card", "init", "mp.team_card_sync.assign_card_id", {
		after = function(ctx, self)
			handle_team_card_init(self)
		end,
	})

	MP.HOOKS.register_method_hook(CardArea, "CardArea", "emplace", "mp.team_card_sync.emplace", {
		after = function(ctx, self)
			local card = ctx.args and ctx.args[1] or nil
			handle_team_card_emplace(self, card)
		end,
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "evaluate_play", "mp.team_card_sync.evaluate_play", {
		before = function(ctx)
			if is_calculator_dry_run() then return end
			ctx.mp_team_card_sync_played_cards = collect_played_team_cards()
		end,
		after = function(ctx)
			if is_calculator_dry_run() then return end
			sync_card_list(ctx.mp_team_card_sync_played_cards or {})
		end,
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "discard_cards_from_highlighted", "mp.team_card_sync.discard_cards", {
		before = function(ctx)
			if is_calculator_dry_run() then return end
			ctx.mp_team_card_sync_discarded_cards = collect_highlighted_team_cards()
		end,
		after = function(ctx)
			if is_calculator_dry_run() then return end
			sync_card_list(ctx.mp_team_card_sync_discarded_cards or {})
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
