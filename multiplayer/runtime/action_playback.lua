MP.SPECTATOR = MP.SPECTATOR or {}

local json = require("json")
local SPECTATOR = MP.SPECTATOR
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- Vanilla calls save_run() while building the round-eval screen. A spectator
-- has no run of their own, so persisting the spectated board into the local
-- profile is wrong at best and can error mid-event (which kills the queued
-- chain that materializes the eval screen, leaving a blank board).
-- SMODS's handle_card_limit compares card_limits.old_slots with <, but a
-- snapshot-rebuilt hand can leave old_slots nil until the next limit
-- sync. Hanged Man deleting 2 cards then triggers that compare and
-- crashes. This hook makes the compare nil-safe live, fixing the
-- already-broken current game without waiting for the next snapshot.
MP.HOOKS.register_method_hook(CardArea, "CardArea", "update", "mp.spectator.init_card_limits", {
	before = function(ctx, self)
		if self and self.config and self.config.card_limits and self.config.card_limits.old_slots == nil then
			self.config.card_limits.old_slots = self.config.card_limits.total_slots or self.config.card_limit or 0
		end
	end,
})

local save_run_ref = save_run
function save_run(...)
	if SPECTATOR.is_spectating then
		return nil
	end
	return save_run_ref(...)
end

SPECTATOR.is_spectating = false
SPECTATOR.is_spectator_role = false
SPECTATOR.target_player_id = nil
SPECTATOR.target_username = "Player"
SPECTATOR.current_step = 0
SPECTATOR.is_catching_up = false
SPECTATOR.is_executing_action = false
SPECTATOR.pending_actions = {}

function SPECTATOR.set_lobby_role(role)
	local is_spec = (role == "spectator")
	SPECTATOR.is_spectator_role = is_spec
	if not is_spec and SPECTATOR.is_spectating then
		SPECTATOR.stop_spectating()
	end
	if MP.LOBBY and MP.LOBBY.client then
		MP.LOBBY.client.role = role
		MP.LOBBY.client.is_spectator = is_spec
	end
	local self_id = (G and G.MP_ID or nil)
	if self_id and MP.LOBBY and MP.LOBBY.players then
		for _, p in ipairs(MP.LOBBY.players) do
			if p.id == self_id then
				p.role = role
				p.is_spectator = is_spec
				if is_spec then
					p.is_ready = false
				end
				break
			end
		end
	end
end

-- Canonical definition of "who can be spectated": another lobby member that is
-- not a spectator and still has lives (nil lives counts as alive).
function SPECTATOR.get_spectatable_players()
	local spectatable = {}
	local players = MP.LOBBY and MP.LOBBY.players or {}
	local self_id = ((G and G.MP_ID or nil))
		or (MP.LOBBY and MP.LOBBY.client and (MP.LOBBY.client.id or MP.LOBBY.client.player_id))
		or (G and G.MP_ID)

	for _, player in ipairs(players) do
		local is_spec = (player.is_spectator or player.role == "spectator")
		local enemy = MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player.id]
		local lives = (enemy and enemy.lives ~= nil and enemy.lives) or player.lives
		if player.id ~= self_id and not is_spec and (lives == nil or tonumber(lives) > 0) then
			spectatable[#spectatable + 1] = player
		end
	end

	if #spectatable == 0 and MP.GAME and MP.GAME.enemies then
		for enemy_id, enemy in pairs(MP.GAME.enemies) do
			if enemy_id ~= self_id and (enemy.lives == nil or tonumber(enemy.lives) > 0) then
				spectatable[#spectatable + 1] = {
					id = enemy_id,
					username = enemy.username or "Player",
					lives = enemy.lives,
				}
			end
		end
	end

	return spectatable
end

local SAFE_REMOVED_BOOSTER = {
	REMOVED = true,
	remove = function() end,
	alignment = { offset = {} },
}

local function remove_ui_box_safely(box_field)
	if G and G[box_field] then
		pcall(function()
			G[box_field]:remove()
		end)
		if box_field == "booster_pack" then
			G.booster_pack = SAFE_REMOVED_BOOSTER
			if G.E_MANAGER and G.E_MANAGER.add_event and Event then
				G.E_MANAGER:add_event(Event({
					trigger = "after",
					delay = 0.3,
					blocking = false,
					blockable = false,
					func = function()
						if G and G.booster_pack == SAFE_REMOVED_BOOSTER then
							G.booster_pack = nil
						end
						return true
					end,
				}))
			end
		else
			G[box_field] = nil
		end
	end
end

local function remove_named(name)
	if G and G[name] then
		pcall(function()
			G[name]:remove()
		end)
		G[name] = nil
	end
end

local function is_booster_pack_state(state)
	local states = G and G.STATES
	if not states then
		return false
	end
	state = tonumber(state) or state
	return state == states.TAROT_PACK
		or state == states.SPECTRAL_PACK
		or state == states.STANDARD_PACK
		or state == states.BUFFOON_PACK
		or state == states.PLANET_PACK
		or state == states.SMODS_BOOSTER_OPENED
end

-- Pack sparkles/stars keep easing after the UIBox is gone; skip_booster
-- is what vanilla uses to fade them. A switch never runs that.
local function teardown_pack_fx()
	remove_ui_box_safely("booster_pack")
	remove_named("booster_pack_sparkles")
	remove_named("booster_pack_stars")
	remove_named("booster_pack_meteors")
	if G then
		G.TAROT_INTERRUPT = nil
	end
	booster_obj = nil
end

-- EventManager stores work in queues.base / unlock / etc. There is no
-- G.E_MANAGER.queue. Checking that made sim_busy always false.
local function count_e_manager_events()
	local queues = G and G.E_MANAGER and G.E_MANAGER.queues
	if type(queues) ~= "table" then
		return 0
	end
	local total = 0
	for _, q in pairs(queues) do
		if type(q) == "table" then
			total = total + #q
		end
	end
	return total
end

local function remove_attention_texts()
	if not (G and G.I and G.I.UIBOX) then
		return
	end
	for i = #G.I.UIBOX, 1, -1 do
		local box = G.I.UIBOX[i]
		if box and box.attention_text then
			pcall(function()
				box:remove()
			end)
		end
	end
end

local function opened_booster_center()
	return SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config and SMODS.OPENED_BOOSTER.config.center
end

-- Vanilla pack colour is not ease_background_colour_blind(G.STATE). SMODS
-- packs live in SMODS_BOOSTER_OPENED, which that helper treats as a blind
-- (shop-like). Arcana/Celestial/etc. call the center's ease, which maps to
-- TAROT_PACK / PLANET_PACK / ...

local function ease_spectated_pack_background(state)
	local center = opened_booster_center()
	if center and type(center.ease_background_colour) == "function" then
		pcall(function()
			center:ease_background_colour()
		end)
		return
	end
	if ease_background_colour_blind then
		pcall(ease_background_colour_blind, state or (G and G.STATE))
	end
end

-- Must run after the last clear_queue on a switch. Vanilla eases from
-- G.GAME.blind.name; parking with set_blind(nil) is what drops the old boss.
local function refresh_spectated_blind_backdrop(state)
	remove_attention_texts()
	state = tonumber(state) or state or (G and G.STATE)
	if is_booster_pack_state(state) then
		ease_spectated_pack_background(state)
		return
	end
	if ease_background_colour_blind then
		pcall(ease_background_colour_blind, state)
	end
end

-- Pack-return is per snapshot/target. G.GAME.PACK_INTERRUPT survives a
-- switch even after SPECTATOR.pack_interrupt is cleared, and the viewport
-- tick then rebuilds a shop onto whoever we switched to.
local function clear_pack_return_latch()
	SPECTATOR.pack_interrupt = nil
	SPECTATOR.cached_pack_return_shop_cards = nil
	SPECTATOR.cached_pack_return_round = nil
	SPECTATOR._handling_pack_exit = nil
	if G and G.GAME then
		G.GAME.PACK_INTERRUPT = nil
	end
end

-- Removes overlay surfaces on a target switch. A pack snapshot keeps an
-- already-open shop so vanilla can park/unpark it instead of rolling a new one.
local function teardown_spectated_overlays(opts)
	if not G then
		return
	end
	opts = opts or {}
	remove_attention_texts()
	teardown_pack_fx()
	if SMODS then
		SMODS.OPENED_BOOSTER = nil
	end
	remove_ui_box_safely("deck_preview")
	remove_ui_box_safely("round_eval")
	if not opts.keep_shop then
		remove_ui_box_safely("shop")
		remove_ui_box_safely("SHOP_SIGN")
	end
	remove_ui_box_safely("blind_select")
	remove_ui_box_safely("blind_prompt_box")
	if G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_end_game_overlay then
		pcall(function()
			G.OVERLAY_MENU:remove()
		end)
		G.OVERLAY_MENU = nil
	end
end

-- Vanilla parks the plaque with set_blind(nil), which also clears the
-- previous boss name so the room colour is no longer that blind.
local function park_blind_hud()
	if G and G.GAME and G.GAME.blind and G.GAME.blind.set_blind then
		pcall(function()
			G.GAME.blind:set_blind(nil, nil, true)
		end)
	end
end

local function wipe_card_area(area)
	if not (area and area.cards) then
		return
	end
	for i = #area.cards, 1, -1 do
		local card = area.cards[i]
		pcall(function()
			if card and card.remove then
				card:remove()
			end
		end)
	end
	area.cards = {}
	if area.highlighted then
		area.highlighted = {}
	end
end

local DEFAULT_HANDS = {
	["Flush Five"] = { level = 1, order = 1, mult = 14, chips = 160, s_mult = 3, s_chips = 50, l_mult = 3, l_chips = 50, played = 0, played_this_round = 0, visible = false },
	["Flush House"] = { level = 1, order = 2, mult = 14, chips = 140, s_mult = 4, s_chips = 40, l_mult = 4, l_chips = 40, played = 0, played_this_round = 0, visible = false },
	["Five of a Kind"] = { level = 1, order = 3, mult = 12, chips = 120, s_mult = 3, s_chips = 35, l_mult = 3, l_chips = 35, played = 0, played_this_round = 0, visible = false },
	["Straight Flush"] = { level = 1, order = 4, mult = 8, chips = 100, s_mult = 4, s_chips = 40, l_mult = 4, l_chips = 40, played = 0, played_this_round = 0, visible = false },
	["Four of a Kind"] = { level = 1, order = 5, mult = 7, chips = 60, s_mult = 3, s_chips = 30, l_mult = 3, l_chips = 30, played = 0, played_this_round = 0, visible = true },
	["Full House"] = { level = 1, order = 6, mult = 4, chips = 40, s_mult = 2, s_chips = 25, l_mult = 2, l_chips = 25, played = 0, played_this_round = 0, visible = true },
	["Flush"] = { level = 1, order = 7, mult = 4, chips = 35, s_mult = 2, s_chips = 15, l_mult = 2, l_chips = 15, played = 0, played_this_round = 0, visible = true },
	["Straight"] = { level = 1, order = 8, mult = 4, chips = 30, s_mult = 3, s_chips = 30, l_mult = 3, l_chips = 30, played = 0, played_this_round = 0, visible = true },
	["Three of a Kind"] = { level = 1, order = 9, mult = 3, chips = 30, s_mult = 2, s_chips = 20, l_mult = 2, l_chips = 20, played = 0, played_this_round = 0, visible = true },
	["Two Pair"] = { level = 1, order = 10, mult = 2, chips = 20, s_mult = 1, s_chips = 20, l_mult = 1, l_chips = 20, played = 0, played_this_round = 0, visible = true },
	["Pair"] = { level = 1, order = 11, mult = 2, chips = 10, s_mult = 1, s_chips = 15, l_mult = 1, l_chips = 15, played = 0, played_this_round = 0, visible = true },
	["High Card"] = { level = 1, order = 12, mult = 1, chips = 5, s_mult = 1, s_chips = 10, l_mult = 1, l_chips = 10, played = 0, played_this_round = 0, visible = true },
}

local function get_default_hands()
	if G and G.init_game_object then
		local ok, obj = pcall(function() return G:init_game_object() end)
		if ok and type(obj) == "table" and type(obj.hands) == "table" then
			return obj.hands
		end
	end
	return DEFAULT_HANDS
end

local function reset_hands_to_base()
	if not (G and G.GAME) then
		return
	end
	local base_hands = get_default_hands()
	G.GAME.hands = G.GAME.hands or {}
	for k in pairs(G.GAME.hands) do
		if not base_hands[k] then
			G.GAME.hands[k] = nil
		end
	end
	for name, data in pairs(base_hands) do
		G.GAME.hands[name] = G.GAME.hands[name] or {}
		for k, v in pairs(data) do
			G.GAME.hands[name][k] = v
		end
	end
end

local function reset_spectator_game_state()
	if not (G and G.STAGE == G.STAGES.RUN) then
		return
	end

	-- 1. Wipe all active card areas
	if G.play then wipe_card_area(G.play) end
	if G.hand then wipe_card_area(G.hand) end
	if G.jokers then wipe_card_area(G.jokers) end
	if G.consumeables then wipe_card_area(G.consumeables) end
	if G.discard then wipe_card_area(G.discard) end
	if G.deck then wipe_card_area(G.deck) end

	-- 2. Reset poker hands to clean baseline
	reset_hands_to_base()

	-- 3. Reset card slot limits
	if G.consumeables and G.consumeables.config then
		G.consumeables.config.card_limit = 2
		if G.consumeables.config.card_limits then
			G.consumeables.config.card_limits.total_slots = 2
			G.consumeables.config.card_limits.old_slots = 2
		end
	end
	if G.jokers and G.jokers.config then
		G.jokers.config.card_limit = 5
		if G.jokers.config.card_limits then
			G.jokers.config.card_limits.total_slots = 5
			G.jokers.config.card_limits.old_slots = 5
		end
	end
	if G.hand and G.hand.config then
		G.hand.config.card_limit = 8
		if G.hand.config.card_limits then
			G.hand.config.card_limits.total_slots = 8
			G.hand.config.card_limits.old_slots = 8
			G.hand.config.card_limits.base = 8
			G.hand.config.card_limits.mod = 0
		end
	end

	-- 4. Reset round resets, probabilities, discounts, interest cap, vouchers, tags
	if G.GAME then
		if G.GAME.round_resets then
			G.GAME.round_resets.hands = 4
			G.GAME.round_resets.discards = 3
			G.GAME.round_resets.temp_handsize = nil
		end
		if G.GAME.probabilities then
			G.GAME.probabilities.normal = 1
		end
		G.GAME.discount_percent = 0
		G.GAME.interest_cap = 25
		G.GAME.used_vouchers = {}
		if G.GAME.tags then
			for i = #G.GAME.tags, 1, -1 do
				local t = G.GAME.tags[i]
				pcall(function()
					if t and t.remove then
						t:remove()
					end
				end)
			end
		end
		G.GAME.tags = {}
		G.GAME.last_tarot_planet = nil
		if G.GAME.current_round then
			G.GAME.current_round.discards_used = 0
			G.GAME.current_round.hands_played = 0
			G.GAME.current_round.discards_left = G.GAME.round_resets and G.GAME.round_resets.discards or 3
			G.GAME.current_round.hands_left = G.GAME.round_resets and G.GAME.round_resets.hands or 4
			G.GAME.current_round.ancient_card = nil
			G.GAME.current_round.idol_card = nil
			G.GAME.current_round.mail_card = nil
			G.GAME.current_round.castle_card = nil
			G.GAME.current_round.used_packs = {}
		end
	end

	-- 5. Clear pending team hand level syncs
	local team_hand_sync = MP.SYNC and MP.SYNC.TEAM_HAND_LEVEL
	if team_hand_sync and team_hand_sync.clear_pending_syncs then
		pcall(team_hand_sync.clear_pending_syncs)
	end

	-- 6. Clean SMODS draw globals & engine interrupts
	if SMODS then
		SMODS.cards_to_draw = nil
		SMODS.draw_queued = nil
		SMODS.drawn_cards = nil
	end
	if G then
		G.TAROT_INTERRUPT = nil
		G.STATE_COMPLETE = false
		if G.CONTROLLER and G.CONTROLLER.interrupt then
			G.CONTROLLER.interrupt.focus = false
		end
	end
	clear_pack_return_latch()

	-- 7. Unstick animation / state and reset hand text HUD
	if G.STATES and (G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND) then
		G.STATE = G.STATES.SELECTING_HAND
		G.STATE_COMPLETE = false
	end
	if update_hand_text then
		pcall(update_hand_text, { delay = 0 }, { mult = 0, StatusText = true, chips = 0, handname = "", level = "" })
	end
end

-- set_blind(silent=true) can leave delayed pop-in events queued that may be
-- wiped by clear_pending_game_events(). show_blind_hud_plaque guarantees
-- the HUD blind plaque, name, chip counter, and dollars are immediately visible at offset.y = 0.
local function show_blind_hud_plaque()
	if not (G and G.HUD_blind) then
		return
	end
	if G.HUD_blind.alignment then
		G.HUD_blind.alignment.offset = G.HUD_blind.alignment.offset or {}
		G.HUD_blind.alignment.offset.y = 0
	end
	if G.HUD_blind.states then
		G.HUD_blind.states.visible = true
	end
	local name_elem = G.HUD_blind.get_UIE_by_ID and G.HUD_blind:get_UIE_by_ID("HUD_blind_name")
	if name_elem and name_elem.states then
		name_elem.states.visible = true
	end
	local count_elem = G.HUD_blind.get_UIE_by_ID and G.HUD_blind:get_UIE_by_ID("HUD_blind_count")
	if count_elem and count_elem.states then
		count_elem.states.visible = true
	end
	local dollars_elem = G.HUD_blind.get_UIE_by_ID and G.HUD_blind:get_UIE_by_ID("dollars_to_be_earned")
	if dollars_elem then
		if dollars_elem.states then
			dollars_elem.states.visible = true
		end
		if dollars_elem.parent and dollars_elem.parent.parent and dollars_elem.parent.parent.states then
			dollars_elem.parent.parent.states.visible = true
		end
	end
	if G.GAME and G.GAME.blind then
		G.GAME.blind.dissolve = 0
		G.GAME.blind.blind_set = true
		if G.GAME.blind.children and G.GAME.blind.children.animatedSprite and G.GAME.blind.config and G.GAME.blind.config.blind then
			pcall(function()
				G.GAME.blind.children.animatedSprite:set_sprite_pos(G.GAME.blind.config.blind.pos or (G.P_BLINDS and G.P_BLINDS.bl_small and G.P_BLINDS.bl_small.pos))
			end)
		end
	end
	if G.HUD_blind.recalculate then
		pcall(function()
			G.HUD_blind:recalculate(false)
		end)
	end
end

local function should_show_blind_hud(state)
	if not (G and G.STATES and state) then
		return false
	end
	state = tonumber(state) or state
	return state == G.STATES.SELECTING_HAND
		or state == G.STATES.HAND_PLAYED
		or state == G.STATES.DRAW_TO_HAND
		or state == G.STATES.PLAY_TAROT
end

-- Skip-tag / shop packs can still be on screen when the stream already
-- selected a blind. Leaving the overlay up hides the PvP score table.
local function dismiss_leftover_pack()
	if not (G and G.booster_pack and not G.booster_pack.REMOVED) then
		return false
	end
	teardown_pack_fx()
	if SMODS then
		SMODS.OPENED_BOOSTER = nil
	end
	local interrupt = G.GAME and G.GAME.PACK_INTERRUPT
	if G.STATES and interrupt then
		G.STATE = interrupt
	elseif G.STATES then
		G.STATE = G.STATES.BLIND_SELECT
	end
	G.STATE_COMPLETE = false
	return true
end

-- Mid-round draws/scores live in G.E_MANAGER. Switching targets without
-- clearing it lets the previous player's draw events keep firing into the
-- new board (wrong cards, RNG looking "broken").
local function clear_pending_game_events()
	if G and G.E_MANAGER and G.E_MANAGER.clear_queue then
		G.E_MANAGER:clear_queue()
	end
	if G and G.booster_pack == SAFE_REMOVED_BOOSTER then
		G.booster_pack = nil
	end
	if G and G.GAME then
		G.GAME.STOP_USE = 0
	end
	if SMODS then
		SMODS.cards_to_draw = nil
		SMODS.draw_queued = nil
		SMODS.drawn_cards = nil
	end
	if G then
		G.TAROT_INTERRUPT = nil
		G.STATE_COMPLETE = false
		if G.CONTROLLER and G.CONTROLLER.interrupt then
			G.CONTROLLER.interrupt.focus = false
		end
	end
end

local function is_playing_round_state(state)
	if not (G and G.STATES and state) then
		return false
	end
	state = tonumber(state) or state
	return state == G.STATES.SELECTING_HAND
		or state == G.STATES.HAND_PLAYED
		or state == G.STATES.DRAW_TO_HAND
		or state == G.STATES.PLAY_TAROT
		or state == G.STATES.ROUND_EVAL
end

local function apply_snapshot_hand_size(board_state)
	if not (G and G.hand and G.hand.config) then
		return
	end
	local limits = G.hand.config.card_limits
	local base = tonumber(board_state.hand_size_base)
		or (G.GAME.starting_params and tonumber(G.GAME.starting_params.hand_size))
		or 8
	local mod = tonumber(board_state.hand_size_mod)
	local stamped = tonumber(board_state.hand_size)
	if mod == nil then
		if stamped then
			mod = stamped - base
		else
			mod = 0
		end
	end
	if limits then
		limits.base = base
		limits.mod = mod
		limits.total_slots = (limits.extra_slots or 0) + base + mod
		limits.display_slots = math.max(0, limits.total_slots)
		limits.old_slots = limits.total_slots
	end
	G.hand.config.card_limit = stamped or (base + mod)
	if G.GAME and G.GAME.round_resets then
		local temp = tonumber(board_state.temp_handsize)
		if temp and temp ~= 0 then
			G.GAME.round_resets.temp_handsize = temp
		else
			G.GAME.round_resets.temp_handsize = nil
		end
	end
end

local function reset_inherited_round_latch()
	if not MP.GAME then
		return
	end
	MP.GAME.round_ended = false
	MP.GAME.duplicate_end = false
	MP.GAME.prevent_eval = false
	if MP.DOMAIN and MP.DOMAIN.MATCH and MP.DOMAIN.MATCH.begin_new_round then
		MP.DOMAIN.MATCH.begin_new_round()
	end
end

local function clear_pending_replay_state()
	SPECTATOR.pending_replay_queue = {}
	SPECTATOR.pending_actions = {}
	SPECTATOR.is_catching_up = false
	SPECTATOR.last_applied_snapshot = nil
	SPECTATOR.shop_joker_queue = nil
	SPECTATOR.eval_hold = false
end

local CATCH_UP_TIMEOUT = 8

local function schedule_catch_up_timeout_check()
	if not (BALATRO and BALATRO.queue_event) then
		return
	end
	BALATRO.queue_event({
		trigger = "after",
		delay = 1,
		func = function()
			if SPECTATOR.is_catching_up then
				local requested_at = tonumber(SPECTATOR.catch_up_requested_at)
				if requested_at and (os.clock() - requested_at) > CATCH_UP_TIMEOUT then
					-- Snapshot never arrived. Re-request once (the first push
					-- may have raced the target loading), then give up and
					-- resume direct execution from the latest seen step.
					SPECTATOR.catch_up_retries = (SPECTATOR.catch_up_retries or 0) + 1
					if SPECTATOR.catch_up_retries <= 1
						and MP.ACTIONS and MP.ACTIONS.spectator_request_snapshot
						and SPECTATOR.target_player_id then
						SPECTATOR.catch_up_requested_at = os.clock()
						MP.ACTIONS.spectator_request_snapshot(SPECTATOR.target_player_id)
						schedule_catch_up_timeout_check()
					else
					if SPECTATOR.finish_catch_up then
						SPECTATOR.finish_catch_up()
					else
						SPECTATOR.is_catching_up = false
					end
					end
				else
					schedule_catch_up_timeout_check()
				end
			end
			return true
		end,
	})
end

-- Enter catch-up mode. `send_request` should be false when the server is
-- already about to push a snapshot request to the target (watchTarget and
-- history both trigger a server-side push): sending our own request as well
-- used to produce 2-3 full board rebuilds per switch.
local function request_catch_up_snapshot(send_request)
	SPECTATOR.is_catching_up = true
	SPECTATOR.catch_up_retries = 0
	SPECTATOR.catch_up_requested_at = os.clock()
	if send_request
		and MP.ACTIONS and MP.ACTIONS.spectator_request_snapshot
		and SPECTATOR.target_player_id then
		MP.ACTIONS.spectator_request_snapshot(SPECTATOR.target_player_id)
	end
	schedule_catch_up_timeout_check()
end

local function finish_catch_up()
	local pending = SPECTATOR.pending_actions
	SPECTATOR.is_catching_up = false
	SPECTATOR.pending_actions = {}
	table.sort(pending, function(a, b)
		return (tonumber(a.step) or 0) < (tonumber(b.step) or 0)
	end)
	-- Snapshot is the board after the target's last action. Streamed
	-- steps already covered by that pickup must not run again (a second
	-- reroll is the usual desync).
	for _, action_obj in ipairs(pending) do
		local step = tonumber(action_obj.step)
		if not step or step > SPECTATOR.current_step then
			SPECTATOR.execute_action(action_obj)
		end
	end
end
SPECTATOR.finish_catch_up = finish_catch_up

-- The Cash Out button is NOT part of G.round_eval: vanilla builds it as an
-- anonymous standalone UIBox major'd onto round_eval and keeps no reference
-- (functions/common_events.lua, add_round_eval_row 'bottom'). Removing
-- round_eval therefore orphans it, and its creation event is delayed, so it
-- can even appear AFTER a switch tore the eval screen down. Enforced every
-- tick while spectating: outside eval states neither surface may exist.
function SPECTATOR.remove_stale_eval_surfaces()
	if not G or not G.I then
		return
	end

	-- The mod's lovely patch latches MP.GAME.prevent_eval after the first
	-- eval build of a round and only clears it in player round transitions —
	-- which never run on a spectator, so the latch would block every later
	-- eval screen (blank resolve state). Vanilla's own G.STATE_COMPLETE flag
	-- already scopes the setup to once per entry; the latch is redundant for
	-- a viewer, so it is released every tick while spectating.
	if MP.GAME then
		MP.GAME.prevent_eval = false
	end

	local in_eval_state = G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND
	if in_eval_state then
		return
	end

	if G.round_eval then
		pcall(function()
			G.round_eval:remove()
		end)
		G.round_eval = nil
	end

	if G.I.UIBOX then
		for i = #G.I.UIBOX, 1, -1 do
			local box = G.I.UIBOX[i]
			if box ~= G.round_eval and not box.REMOVED and box.get_UIE_by_ID and box:get_UIE_by_ID("cash_out_button") then
				pcall(function()
					box:remove()
				end)
			end
		end
	end
end

-- Canonical way to leave a round-eval state we inherited from a previous
-- target or replay. Vanilla re-creates the round-eval overlay every tick
-- while G.STATE is an eval state with pending setup, so removing the surface
-- alone would let a stale cash-in button resurrect; the state itself must
-- move. Parks quietly in BLIND_SELECT without building any UI — the real
-- screen is always driven by snapshot/stream data, never fabricated here.
local function exit_round_eval_to_blind_select()
	if not (G and G.GAME) then
		return false
	end
	if G.STATE ~= G.STATES.ROUND_EVAL and G.STATE ~= G.STATES.NEW_ROUND then
		return false
	end

	remove_ui_box_safely("blind_select")
	remove_ui_box_safely("blind_prompt_box")
	remove_ui_box_safely("shop")
	remove_ui_box_safely("SHOP_SIGN")
	teardown_pack_fx()
	if SMODS then
		SMODS.OPENED_BOOSTER = nil
	end
	remove_ui_box_safely("deck_preview")
	remove_ui_box_safely("round_eval")
	G.STATE = G.STATES.BLIND_SELECT
	G.STATE_COMPLETE = true
	-- The orphaned Cash Out button (standalone UIBox, no vanilla reference)
	-- must go too, or it keeps floating over whatever comes next.
	SPECTATOR.remove_stale_eval_surfaces()
	return true
end

-- Release an eval hold (see apply_live_board_state): the stream has moved
-- past the target's cash-out, so park in BLIND_SELECT. Do not kick
-- update_blind_select here — that is what stacked overlapping UIs.
local function release_eval_hold_to_blind_select()
	SPECTATOR.eval_hold = false
	if not (G and G.STATES) then
		return false
	end
	if G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND then
		remove_ui_box_safely("round_eval")
		G.STATE = G.STATES.BLIND_SELECT
	end
	return G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil
end

local WATCH_SWITCH_GAP = 0.35

function SPECTATOR.flush_queued_watch()
	local queued = SPECTATOR.queued_watch
	if not queued then
		return
	end
	local last = tonumber(SPECTATOR.last_watch_sent_at)
	if last and (os.clock() - last) < WATCH_SWITCH_GAP then
		return
	end
	SPECTATOR.queued_watch = nil
	if queued.id ~= SPECTATOR.target_player_id then
		SPECTATOR.start_spectating(queued.id, queued.username)
	end
end

function SPECTATOR.start_spectating(target_player_id, username)
	-- Same target: the option cycle / history handshake used to call this
	-- again and tear the board down for a second snapshot.
	if SPECTATOR.is_spectating and SPECTATOR.target_player_id == target_player_id then
		SPECTATOR.queued_watch = nil
		if MP.UI and MP.UI.show_spectator_viewport then
			MP.UI.show_spectator_viewport(target_player_id, username)
		end
		return
	end

	-- Rapid A↔B↔A switches: update UI immediately so cycling feels instant,
	-- debounce the network watch request by WATCH_SWITCH_GAP.
	local last = tonumber(SPECTATOR.last_watch_sent_at)
	if last and (os.clock() - last) < WATCH_SWITCH_GAP then
		SPECTATOR.queued_watch = {
			id = target_player_id,
			username = username or "Player",
		}
		if MP.UI and MP.UI.show_spectator_viewport then
			MP.UI.show_spectator_viewport(target_player_id, username)
		end
		return
	end

	-- Clean transition: drop every queued replay action and tear down the
	-- previous target's UI before attaching to the new target, so stale
	-- retries and half-removed overlays can never leak across the switch.
	clear_pending_replay_state()
	reset_inherited_round_latch()
	if G and G.STAGE == G.STAGES.RUN then
		clear_pending_game_events()
		park_blind_hud()
		teardown_spectated_overlays()
		refresh_spectated_blind_backdrop(G.STATES and G.STATES.BLIND_SELECT)
		-- Quietly park engine in BLIND_SELECT with STATE_COMPLETE = true so vanilla
		-- never fabricates shop/pack/blind UI while waiting for the target snapshot.
		exit_round_eval_to_blind_select()
		reset_spectator_game_state()
		if G.STATES then
			G.STATE = G.STATES.BLIND_SELECT
			G.STATE_COMPLETE = true
		end
	end

	SPECTATOR.is_spectating = true
	SPECTATOR.target_player_id = target_player_id
	SPECTATOR.target_username = username or "Player"
	SPECTATOR.current_step = 0
	SPECTATOR.last_watch_sent_at = os.clock()
	SPECTATOR.queued_watch = nil
	SPECTATOR.target_invalid_since = nil

	if MP.TESTING and MP.TESTING.log_spectator then
		MP.TESTING.log_spectator("SPEC", "switch", string.format("target=%s (%s)",
			tostring(target_player_id):sub(1, 8), tostring(username or "Player")))
	end

	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.rebuild_spectator_phantoms then
		pcall(MP.NETWORKING_INTERNAL.rebuild_spectator_phantoms)
	end

	if MP.RECORDER and MP.RECORDER.stop then
		MP.RECORDER.stop()
	end

	if MP.ACTIONS and MP.ACTIONS.spectator_watch_target then
		MP.ACTIONS.spectator_watch_target(target_player_id)
	end

	if MP.UI and MP.UI.show_spectator_viewport then
		MP.UI.show_spectator_viewport(target_player_id, username)
	end

	if G and G.SETTINGS and G.SETTINGS.paused then
		G.SETTINGS.paused = false
	end

	if MP.PLATFORM and MP.PLATFORM.BALATRO and MP.PLATFORM.BALATRO.set_paused then
		MP.PLATFORM.BALATRO.set_paused(false)
	end

	if MP.GAME then
		MP.GAME.won = false
		MP.GAME.end_game_result = nil
		MP.GAME.round_failed = false
		MP.GAME.round_loss_processed = false
	end

	if not SPECTATOR.is_spectator_role then
		SPECTATOR.is_spectator_role = true
		if MP.ACTIONS and MP.ACTIONS.spectator_set_role then
			MP.ACTIONS.spectator_set_role("spectator")
		end
		if MP.LOBBY and MP.LOBBY.client then
			MP.LOBBY.client.role = "spectator"
			MP.LOBBY.client.is_spectator = true
		end
		local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player()
		if self_player then
			self_player.role = "spectator"
			self_player.is_spectator = true
		end
	end

	if MP.UI and MP.UI.refresh_lives_hud_binding then
		MP.UI.refresh_lives_hud_binding({ force = true })
	end

	-- Mid-run spectating: resync through a live snapshot from the target.
	if G and G.STAGE == G.STAGES.RUN then
		request_catch_up_snapshot(true)
	end

end

function SPECTATOR.stop_spectating()
	SPECTATOR.is_spectating = false
	SPECTATOR.applying_snapshot = false
	clear_pack_return_latch()
	SPECTATOR.shop_joker_queue = nil
	SPECTATOR.locked_jokers = nil
	SPECTATOR.queued_watch = nil
	SPECTATOR.last_watch_sent_at = nil
	SPECTATOR.target_invalid_since = nil
	SPECTATOR.target_player_id = nil
	SPECTATOR.target_username = "Player"
	SPECTATOR.current_step = 0
	clear_pending_replay_state()
	if G and G.STAGE == G.STAGES.RUN then
		clear_pending_game_events()
		park_blind_hud()
		teardown_spectated_overlays()
		refresh_spectated_blind_backdrop(G.STATES and G.STATES.BLIND_SELECT)
		-- Same quiet park as start_spectating: never leave the local game in
		-- an eval state (vanilla would keep rebuilding the cash-in overlay),
		-- and never fabricate UI that does not belong to anyone.
		exit_round_eval_to_blind_select()
		reset_spectator_game_state()
	end

	if MP.UI and MP.UI.hide_spectator_viewport then
		MP.UI.hide_spectator_viewport()
	end
	if MP.UI and MP.UI.restore_spectator_input then
		MP.UI.restore_spectator_input()
	end
end

local function get_card_area_by_name(area_name)
	if not G then return nil end
	if area_name == "jokers" then return G.jokers end
	if area_name == "consumeables" or area_name == "consumables" then return G.consumeables end
	if area_name == "hand" then return G.hand end
	if area_name == "deck" then return G.deck end
	if area_name == "discard" then return G.discard end
	if area_name == "shop_jokers" then return G.shop_jokers end
	if area_name == "shop_booster" then return G.shop_booster end
	if area_name == "shop_vouchers" then return G.shop_vouchers end
	if area_name == "pack_cards" then return G.pack_cards end
	return nil
end

-- Build a Card from a wire descriptor. Playing cards (suit/value present)
-- use the matching base card; jokers/consumables use the empty base with
-- their center. Returns an unemplaced card.
local function build_card_from_info(info, area)
	if not (G and info) then
		return nil
	end
	local center_key = info.center_key or info.key
	local center = (center_key and G.P_CENTERS and G.P_CENTERS[center_key]) or nil
	local is_non_playing = center and center.set
		and center.set ~= "Enhanced" and center.set ~= "Default"

	local p_card
	local use_center
	if is_non_playing or not info.suit then
		p_card = (G.P_CARDS and G.P_CARDS.empty) or {}
		use_center = center or G.P_CENTERS.c_base
	else
		local suit_prefix = string.sub(info.suit, 1, 1)
		local val_char = string.sub(tostring(info.value or "A"), 1, 1)
		if tostring(info.value) == "10" then
			val_char = "T"
		end
		p_card = (G.P_CARDS and G.P_CARDS[suit_prefix .. "_" .. val_char]) or G.P_CARDS.S_A
		use_center = center or G.P_CENTERS.c_base
	end

	-- Shop boosters are 1.27× playing-card size (Game:update_shop /
	-- SMODS.add_booster_to_shop). Building them at CARD_W makes packs look
	-- like jokers after a spectator rebuild.
	local card_w, card_h = G.CARD_W, G.CARD_H
	if area == G.shop_booster or (center and center.set == "Booster") then
		card_w, card_h = G.CARD_W * 1.27, G.CARD_H * 1.27
	end

	local extra = nil
	if area == G.shop_jokers or area == G.shop_vouchers or area == G.shop_booster then
		extra = { bypass_discovery_center = true, bypass_discovery_ui = true }
	end
	-- create_card spawns at the destination area, not (0,0). Cards created
	-- at the origin lerp their VT down into the pack/hand and look dragged
	-- from the top-left corner.
	local spawn_x, spawn_y = 0, 0
	if area and area.T then
		spawn_x = area.T.x + (area.T.w or 0) / 2
		spawn_y = area.T.y
	end
	local card = Card(spawn_x, spawn_y, card_w, card_h, p_card, use_center, extra)
	if info.sort_id then
		card.sort_id = tonumber(info.sort_id) or info.sort_id
	end
	if info.edition and card.set_edition then
		local ed = info.edition
		local ok = pcall(card.set_edition, card, ed, true)
		if not ok and type(ed) == "string" and not string.find(ed, "^e_") then
			pcall(card.set_edition, card, "e_" .. ed, true)
		end
	end
	if info.seal and card.set_seal then
		pcall(card.set_seal, card, info.seal, true)
	end
	if info.debuff and card.set_debuff then
		pcall(card.set_debuff, card, true)
	end
	if info.cost then
		card.cost = info.cost
	end
	return card
end

local function rebuild_area_cards(area, card_infos)
	if not (G and area and area.cards and card_infos) then
		return false
	end
	wipe_card_area(area)
	-- Deck emplace inserts at index 1; walk captured order backwards so
	-- cards[#] stays the draw pile (vanilla pops G.deck.cards[#]).
	local start_i, end_i, step_i = 1, #card_infos, 1
	if area == G.deck then
		start_i, end_i, step_i = #card_infos, 1, -1
	end
	for i = start_i, end_i, step_i do
		local card = build_card_from_info(card_infos[i], area)
		if card then
			-- Keep the target's team-sync id so later sync deltas resolve
			-- against the rebuilt board instead of creating duplicates.
			local info_id = card_infos[i].mp_card_id
			if type(info_id) == "string" and info_id ~= "" then
				card.mp_card_id = info_id
				card.mp_synced_as_added = true
			end
			if area == G.deck then
				card.facing = "back"
				card.sprite_facing = "back"
			end
			if area == G.shop_booster and card.ability then
				card.ability.booster_pos = i
			end
			area:emplace(card)
		end
	end
	if area.align_cards then
		pcall(area.align_cards, area)
	end
	if area.hard_set_cards then
		pcall(area.hard_set_cards, area)
	end
	return true
end

local function refresh_playing_cards()
	G.playing_cards = {}
	G.playing_card = 0
	for _, area in ipairs({ G.deck, G.hand, G.discard, G.play }) do
		if area and area.cards then
			for _, card in ipairs(area.cards) do
				G.playing_card = G.playing_card + 1
				card.playing_card = G.playing_card
				G.playing_cards[#G.playing_cards + 1] = card
			end
		end
	end
end

local function shop_card_lists_by_area(shop_cards)
	local sparse = {
		shop_jokers = {},
		shop_vouchers = {},
		shop_booster = {},
	}
	for _, item in ipairs(shop_cards) do
		local area_name = item.area or "shop_jokers"
		if sparse[area_name] then
			local idx = tonumber(item.index) or (#sparse[area_name] + 1)
			sparse[area_name][idx] = item
		end
	end
	local packed = {}
	for area_name, slots in pairs(sparse) do
		local list = {}
		local max_i = 0
		for i, _ in pairs(slots) do
			if type(i) == "number" and i > max_i then
				max_i = i
			end
		end
		for i = 1, max_i do
			if slots[i] then
				list[#list + 1] = slots[i]
			end
		end
		packed[area_name] = list
	end
	return packed
end

function SPECTATOR.take_queued_shop_joker(area)
	local queue = SPECTATOR.shop_joker_queue
	if not (queue and #queue > 0) then
		return nil
	end
	local info = table.remove(queue, 1)
	local card = build_card_from_info(info, area or G.shop_jokers)
	if card and create_shop_card_ui then
		local shop_type = card.ability and card.ability.set or nil
		pcall(create_shop_card_ui, card, shop_type, area or G.shop_jokers)
	end
	return card
end

local function clear_shop_area(area)
	if not (area and area.cards) then
		return
	end
	for i = #area.cards, 1, -1 do
		pcall(function()
			area.cards[i]:remove()
		end)
	end
	area.cards = {}
end

local function copy_info_list(list)
	local out = {}
	if not list then
		return out
	end
	for i, item in ipairs(list) do
		out[i] = item
	end
	return out
end

local function pending_reroll_waiting()
	for _, entry in ipairs(SPECTATOR.pending_replay_queue or {}) do
		if entry.type == "REROLL_SHOP" then
			return true
		end
	end
	return false
end

-- The snapshot is the authoritative board: every apply rebuilds all shop
-- rows from it. There is deliberately no "already matches" shortcut — a
-- sampled equality check silently skips legitimate stamps whenever any
-- un-compared attribute differs.

local function apply_shop_card_extras(card, info)
	if not (card and info) then
		return
	end
	if info.sort_id then
		card.sort_id = tonumber(info.sort_id) or info.sort_id
	end
	if info.edition and card.set_edition then
		local ed = info.edition
		local ok = pcall(card.set_edition, card, ed, true)
		if not ok and type(ed) == "string" and not string.find(ed, "^e_") then
			pcall(card.set_edition, card, "e_" .. ed, true)
		end
	end
	if info.cost then
		card.cost = info.cost
	end
end

local function emplace_queued_shop_jokers(juice)
	if not (G and G.shop_jokers and create_card_for_shop) then
		return
	end
	local n = #(SPECTATOR.shop_joker_queue or {})
	for _ = 1, n do
		local card = create_card_for_shop(G.shop_jokers)
		if card then
			G.shop_jokers:emplace(card)
			if juice then
				pcall(function()
					card:juice_up()
				end)
			end
		end
	end
end

local function spawn_shop_vouchers(infos)
	if not (SMODS and SMODS.add_voucher_to_shop) then
		return
	end
	for _, info in ipairs(infos or {}) do
		if info.key then
			local ok, card = pcall(SMODS.add_voucher_to_shop, info.key, true)
			if ok then
				apply_shop_card_extras(card, info)
			end
		end
	end
end

local function spawn_shop_boosters(infos)
	if not (SMODS and SMODS.add_booster_to_shop) then
		return
	end
	for idx, info in ipairs(infos or {}) do
		if info.key then
			local ok, card = pcall(SMODS.add_booster_to_shop, info.key)
			if ok and card then
				apply_shop_card_extras(card, info)
				if card.ability then
					card.ability.booster_pos = info.index or idx
				end
			end
		end
	end
end

-- Place the target's shop once, using the same constructors vanilla uses
-- (create_card_for_shop, SMODS.add_voucher_to_shop, SMODS.add_booster_to_shop).
-- Called from snapshots only — never from the viewport tick.
-- Called from snapshots only — never from the viewport tick.
local function apply_stream_shop(shop_cards, round)
	if not (G and shop_cards and #shop_cards > 0) then
		return false
	end
	local packed = shop_card_lists_by_area(shop_cards)

	if pending_reroll_waiting() then
		-- A queued reroll will replace this offer; do not stamp it, and do
		-- not leave the queue half-filled for later unhooked callers.
		SPECTATOR.shop_joker_queue = {}
		return true
	end
	if not (G.shop and G.shop_jokers) then
		return false
	end

	clear_shop_area(G.shop_jokers)
	clear_shop_area(G.shop_vouchers)
	clear_shop_area(G.shop_booster)
	SPECTATOR.shop_joker_queue = copy_info_list(packed.shop_jokers)

	emplace_queued_shop_jokers(false)
	spawn_shop_vouchers(packed.shop_vouchers)
	spawn_shop_boosters(packed.shop_booster)
	return true
end

-- Same as use_card: only park an already-open shop. Never build one under a pack.
local function park_shop_for_pack()
	if not (G and G.shop and not G.shop.REMOVED and G.shop.alignment and G.shop.alignment.offset) then
		return false
	end
	if G.shop.alignment.offset.py == nil then
		G.shop.alignment.offset.py = G.shop.alignment.offset.y
	end
	G.shop.alignment.offset.y = G.ROOM.T.y + 29
	return true
end

-- Switch snapshots need the opened pack's center so SMODS create_UIBox
-- can size G.pack_cards. Live opens keep the real Card from use_card.
local function restore_opened_booster(board_state)
	local key = board_state and board_state.opened_booster_key
	local center = key and G.P_CENTERS and G.P_CENTERS[key] or nil
	if not (SMODS and center) then
		return center
	end
	local extra = tonumber(board_state.pack_size) or 0
	local n_cards = board_state.pack_cards and #board_state.pack_cards or 0
	if extra < n_cards then
		extra = n_cards
	end
	if extra < 1 then
		extra = (center.config and center.config.extra) or 3
	end
	SMODS.OPENED_BOOSTER = {
		ability = {
			extra = extra,
			set = "Booster",
			name = center.name,
			choose = tonumber(board_state.pack_choices) or (center.config and center.config.choose) or 1,
		},
		config = { center = center, center_key = key },
	}
	booster_obj = center
	return center
end

local function get_pack_ui_builder(state)
	local states = G and G.STATES
	if not states then
		return nil
	end
	if state == states.TAROT_PACK then
		return create_UIBox_arcana_pack
	elseif state == states.PLANET_PACK then
		return create_UIBox_celestial_pack
	elseif state == states.SPECTRAL_PACK then
		return create_UIBox_spectral_pack
	elseif state == states.STANDARD_PACK then
		return create_UIBox_standard_pack
	elseif state == states.BUFFOON_PACK then
		return create_UIBox_buffoon_pack
	elseif state == states.SMODS_BOOSTER_OPENED then
		local opened = SMODS and SMODS.OPENED_BOOSTER
		local center = opened and opened.config and opened.config.center
		if center and center.create_UIBox then
			return function()
				return center:create_UIBox()
			end
		end
		-- Skip tags open owned vanilla packs through SMODS_BOOSTER_OPENED.
		-- If the fake OPENED_BOOSTER lost create_UIBox, use the same
		-- builders Game:update_*_pack uses. Match name or p_* key
		-- (Charm is p_arcana_*, Buffoon is p_buffoon_*).
		local name = string.lower(tostring(
			(center and (center.name or center.key))
				or (opened and opened.config and opened.config.center_key)
				or ""
		))
		if string.find(name, "arcana") then
			return create_UIBox_arcana_pack
		elseif string.find(name, "celestial") or string.find(name, "planet") then
			return create_UIBox_celestial_pack
		elseif string.find(name, "spectral") then
			return create_UIBox_spectral_pack
		elseif string.find(name, "standard") then
			return create_UIBox_standard_pack
		elseif string.find(name, "buffoon") then
			return create_UIBox_buffoon_pack
		end
	end
	return nil
end

-- Rebuild the booster pack overlay from a snapshot: the pack UI (which also
-- recreates the G.pack_cards area) plus the target's real pack contents, so
-- switching to someone mid-pack shows their pack instead of a blank screen.
local function rebuild_pack_ui(state, board_state)
	-- OPENED_BOOSTER must exist before the builder lookup: SMODS packs
	-- resolve create_UIBox from the opened center, not from G.STATE alone.
	restore_opened_booster(board_state)
	local builder = get_pack_ui_builder(state)
	if not (G and G.GAME and builder) then
		return false
	end
	teardown_pack_fx()
	restore_opened_booster(board_state)
	if G.buttons then
		pcall(function()
			G.buttons:remove()
		end)
		G.buttons = nil
	end
	local n = math.max(
		tonumber(board_state.pack_size) or 0,
		board_state.pack_cards and #board_state.pack_cards or 0,
		1
	)
	G.GAME.pack_size = n
	G.GAME.pack_choices = tonumber(board_state.pack_choices) or 1
	if SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.ability then
		SMODS.OPENED_BOOSTER.ability.extra = n
	end
	-- Same order as SMODS.Booster.update_pack: particles, then the overlay.
	local center = opened_booster_center()
	if center and type(center.particles) == "function" then
		pcall(function()
			center:particles()
		end)
	end
	local ok_def, definition = pcall(builder)
	if not (ok_def and definition) then
		return false
	end
	G.booster_pack = UIBox({
		definition = definition,
		config = {
			align = "tmi",
			offset = { x = 0, y = -2.2 },
			major = G.hand or G.ROOM,
			bond = "Weak",
		},
	})
	pcall(function()
		if G.booster_pack.align_to_major then
			G.booster_pack:align_to_major()
		end
		if G.booster_pack.T and G.booster_pack.VT then
			G.booster_pack.VT.x = G.booster_pack.T.x
			G.booster_pack.VT.y = G.booster_pack.T.y
			G.booster_pack.VT.w = G.booster_pack.T.w
			G.booster_pack.VT.h = G.booster_pack.T.h
		end
		if G.booster_pack.UIRoot and G.booster_pack.UIRoot.initialize_VT then
			G.booster_pack.UIRoot:initialize_VT(true)
		end
	end)
	if G.pack_cards then
		G.pack_cards.config.card_limit = n
		-- UIBox already sized G.pack_cards from the booster extra. Pin VT to
		-- that slot before emplace so cards are created where vanilla
		-- create_card would (area.T), not at the CardArea constructor pose
		-- (ROOM.T.x + 9), which is what made skip-tag Buffoon packs look empty.
		if G.pack_cards.hard_set_T then
			pcall(function()
				G.pack_cards:hard_set_T()
			end)
		end
		if G.pack_cards.T and G.pack_cards.VT then
			G.pack_cards.VT.x = G.pack_cards.T.x
			G.pack_cards.VT.y = G.pack_cards.T.y
			G.pack_cards.VT.w = G.pack_cards.T.w
			G.pack_cards.VT.h = G.pack_cards.T.h
		end
		if board_state.pack_cards then
			rebuild_area_cards(G.pack_cards, board_state.pack_cards)
		end
	end
	if state then
		G.STATE = state
	end
	if G.hand and G.hand.cards and #G.hand.cards > 0 then
		if G.hand.align_cards then
			pcall(G.hand.align_cards, G.hand)
		end
		if G.hand.hard_set_cards then
			pcall(G.hand.hard_set_cards, G.hand)
		end
	end
	return true
end

local function normalize_blind_row(data)
	local blind_row = (type(data) == "table" and data.blind_row) or tostring(data or "Small")
	local lower_row = string.lower(tostring(blind_row or "small"))
	local norm_key = "small"
	local norm_title = "Small"
	if string.find(lower_row, "big") or lower_row == "2" then
		norm_key = "big"
		norm_title = "Big"
	elseif string.find(lower_row, "boss") or lower_row == "3" or (not string.find(lower_row, "small") and lower_row ~= "1") then
		norm_key = "boss"
		norm_title = "Boss"
	end
	return norm_key, norm_title
end

local function resolve_blind_def(data, norm_key, norm_title)
	local blind_key = type(data) == "table" and (data.key or (data.blind and data.blind.key))
	if blind_key and G.P_BLINDS and G.P_BLINDS[blind_key] then
		return G.P_BLINDS[blind_key]
	end

	local blind_name = type(data) == "table" and data.name
	if blind_name and G.P_BLINDS then
		for _, b in pairs(G.P_BLINDS) do
			if b and (b.name == blind_name or b.label == blind_name or b.key == blind_name) then
				return b
			end
		end
	end

	if G.GAME.round_resets and G.GAME.round_resets.blind_choices then
		local key = G.GAME.round_resets.blind_choices[norm_title]
			or G.GAME.round_resets.blind_choices[norm_key]
		if key and G.P_BLINDS and G.P_BLINDS[key] then
			return G.P_BLINDS[key]
		end
		if norm_key == "big" and G.P_BLINDS and G.P_BLINDS.bl_big then
			return G.P_BLINDS.bl_big
		end
	end

	if G.GAME.round_resets and G.GAME.round_resets.blind then
		return G.GAME.round_resets.blind
	end
	return nil
end

local function ensure_blind_select_ui_ready()
	if SPECTATOR.eval_hold then
		release_eval_hold_to_blind_select()
	end
	if G.blind_select and G.blind_prompt_box then
		return true
	end
	return false
end

local function invoke_g_func(func_name, e)
	local fn = G.FUNCS and G.FUNCS[func_name]
	if not fn then
		return false
	end
	SPECTATOR.is_executing_action = true
	local ok
	if e ~= nil then
		ok = pcall(fn, e)
	else
		ok = pcall(fn)
	end
	SPECTATOR.is_executing_action = false
	return ok
end

local function find_uie_by_id(id, preferred_box)
	if preferred_box and preferred_box.get_UIE_by_ID then
		local node = preferred_box:get_UIE_by_ID(id)
		if node then
			return node
		end
	end
	if G and G.I and G.I.UIBOX then
		for i = 1, #G.I.UIBOX do
			local box = G.I.UIBOX[i]
			if box and not box.REMOVED and box.get_UIE_by_ID then
				local node = box:get_UIE_by_ID(id)
				if node then
					return node
				end
			end
		end
	end
	return nil
end

function SPECTATOR.perform_select_blind(data)
	if not (G and G.GAME) then return false end
	if dismiss_leftover_pack() then
		return false
	end
	if not ensure_blind_select_ui_ready() then
		return false
	end

	local norm_key, norm_title = normalize_blind_row(data)
	local blind_def = resolve_blind_def(data, norm_key, norm_title)

	local box = ((G and G.blind_select_opts and G.blind_select_opts[string.lower(norm_title)] or nil) or (G and G.blind_select_opts and G.blind_select_opts[string.lower(norm_key)] or nil))
		or (G.blind_select_opts and (G.blind_select_opts[norm_key] or G.blind_select_opts[norm_title]))

	local button = box and box.get_UIE_by_ID and box:get_UIE_by_ID("select_blind_button")
	if button and G.FUNCS and G.FUNCS.select_blind then
		button.config = button.config or {}
		button.config.func = nil
		button.config.button = "select_blind"
		button.config.one_press = true
		if blind_def then
			button.config.ref_table = blind_def
		end
		if invoke_g_func("select_blind", button) then
			SPECTATOR.pending_select_blind = nil
			return true
		end
	end

	return false
end

function SPECTATOR.perform_skip_blind(data)
	if not (G and G.GAME) then return false end
	if not ensure_blind_select_ui_ready() then
		return false
	end

	local norm_key, norm_title = normalize_blind_row(data)

	local box = ((G and G.blind_select_opts and G.blind_select_opts[string.lower(norm_title)] or nil) or (G and G.blind_select_opts and G.blind_select_opts[string.lower(norm_key)] or nil))
		or (G.blind_select_opts and (G.blind_select_opts[norm_key] or G.blind_select_opts[norm_title]))

	local button = box and box.get_UIE_by_ID and (box:get_UIE_by_ID("skip_blind_button") or box:get_UIE_by_ID("tag_" .. norm_key) or box:get_UIE_by_ID("tag_" .. norm_title))

	if button and G.FUNCS and G.FUNCS.skip_blind then
		button.config = button.config or {}
		button.config.button = "skip_blind"
		if invoke_g_func("skip_blind", button) then
			SPECTATOR.pending_skip_blind = nil
			return true
		end
	end

	return false
end

function SPECTATOR.perform_play_hand(data)
	local cards_idx = {}
	if type(data) == "table" and type(data.cards) == "table" then
		for _, ci in ipairs(data.cards) do cards_idx[#cards_idx + 1] = tostring(ci) end
	end
	local idx_str = table.concat(cards_idx, ",")
	local cur_hand_count = (G and G.hand and G.hand.cards and #G.hand.cards) or 0

	if dismiss_leftover_pack() then
		return false
	end
	if not (G and G.hand and G.hand.cards and #G.hand.cards > 0) then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("ACT", "play_wait", string.format("[%s] no hand cards", idx_str))
		end
		return false
	end
	if G.play and G.play.cards and #G.play.cards > 0 then
		wipe_card_area(G.play)
	end
	if G.STATE ~= G.STATES.SELECTING_HAND then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("ACT", "play_wait", string.format("[%s] st=%s", idx_str, tostring(G.STATE)))
		end
		return false
	end

	G.hand:unhighlight_all()
	local highlighted_any = false
	for _, idx in ipairs((data and data.cards) or {}) do
		local card = G.hand.cards[idx]
		if card then
			G.hand:add_to_highlighted(card)
			highlighted_any = true
		end
	end

	if not highlighted_any or not (G.hand.highlighted and #G.hand.highlighted > 0) then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("FAIL", "play_miss", string.format("[%s] hand=%d (indices out of bounds)", idx_str, cur_hand_count))
		end
		return false
	end

	if G.FUNCS and G.FUNCS.play_cards_from_highlighted then
		local ok = invoke_g_func("play_cards_from_highlighted")
		if ok then
			SPECTATOR.pending_play_hand = nil
		end
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator(ok and "EXEC" or "FAIL", ok and "play_ok" or "play_err",
				string.format("[%s] hl=%d hand=%d", idx_str, #G.hand.highlighted, cur_hand_count))
		end
		return ok
	end
	return false
end

function SPECTATOR.perform_discard(data)
	local cards_idx = {}
	if type(data) == "table" and type(data.cards) == "table" then
		for _, ci in ipairs(data.cards) do cards_idx[#cards_idx + 1] = tostring(ci) end
	end
	local idx_str = table.concat(cards_idx, ",")
	local cur_hand_count = (G and G.hand and G.hand.cards and #G.hand.cards) or 0

	if not (G and G.hand and G.hand.cards and #G.hand.cards > 0) then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("ACT", "discard_wait", string.format("[%s] no hand cards", idx_str))
		end
		return false
	end
	if G.STATE ~= G.STATES.SELECTING_HAND then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("ACT", "discard_wait", string.format("[%s] st=%s", idx_str, tostring(G.STATE)))
		end
		return false
	end

	G.hand:unhighlight_all()
	local highlighted_any = false
	for _, idx in ipairs((data and data.cards) or {}) do
		local card = G.hand.cards[idx]
		if card then
			G.hand:add_to_highlighted(card)
			highlighted_any = true
		end
	end

	if not highlighted_any or not (G.hand.highlighted and #G.hand.highlighted > 0) then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("FAIL", "discard_miss", string.format("[%s] hand=%d (indices out of bounds)", idx_str, cur_hand_count))
		end
		return false
	end

	if G.FUNCS and G.FUNCS.discard_cards_from_highlighted then
		local ok = invoke_g_func("discard_cards_from_highlighted")
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator(ok and "EXEC" or "FAIL", ok and "discard_ok" or "discard_err",
				string.format("[%s] hl=%d hand=%d", idx_str, #G.hand.highlighted, cur_hand_count))
		end
		return ok
	end
	return false
end

local function cash_out_already_passed()
	if not (G and G.STATES) then
		return false
	end
	return G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT
end

local function in_pvp_hand()
	if not (G and G.STATES) then
		return false
	end
	local in_hand = G.STATE == G.STATES.SELECTING_HAND
		or G.STATE == G.STATES.HAND_PLAYED
		or G.STATE == G.STATES.DRAW_TO_HAND
	if not in_hand then
		return false
	end
	return (MP.is_pvp_boss and MP.is_pvp_boss())
		or (G.GAME.blind and G.GAME.blind.pvp)
		or (MP.is_server_resolved_blind and MP.is_server_resolved_blind())
end

function SPECTATOR.perform_end_pvp(data)
	if not (G and G.GAME) then
		return false
	end
	local lost = not not (data and data.lost)
	local pvp_timer_lost = not not (data and data.pvp_timer_lost)
	if MP.GAME then
		MP.GAME.end_pvp = true
		MP.GAME.round_failed = lost

		-- Decrement and animate lives on defeat
		local prev = tonumber(MP.GAME.lives)
		local new_lives = nil
		if data and data.lives ~= nil and tonumber(data.lives) ~= nil then
			local d_lives = tonumber(data.lives)
			if prev and d_lives < prev then
				new_lives = d_lives
			elseif lost and prev then
				new_lives = math.max(0, prev - 1)
			else
				new_lives = d_lives
			end
		elseif lost and prev then
			new_lives = math.max(0, prev - 1)
		end

		local life_lost = false
		if new_lives ~= nil then
			if prev and new_lives < prev then
				life_lost = true
			elseif lost and prev and prev > 0 then
				life_lost = true
			end
			MP.GAME.lives = new_lives
			MP.GAME.team_lives = new_lives
			if life_lost and MP.UI and MP.UI.ease_lives then
				MP.UI.ease_lives(new_lives - (prev or (new_lives + 1)))
			end
		end

		local gold_on_loss = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gold_on_life_loss
		if gold_on_loss == nil then gold_on_loss = true end
		if (life_lost or lost) and gold_on_loss and (not prev or prev > 0) then
			MP.GAME.comeback_bonus_given = false
			MP.GAME.comeback_eval_pending = true
			MP.GAME.comeback_bonus = (tonumber(MP.GAME.comeback_bonus) or 0) + 1
		end
		if lost and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.no_gold_on_round_loss and BALATRO.set_current_blind_dollars then
			BALATRO.set_current_blind_dollars(0)
		end
	end
	local trigger_loss = trigger_pvp_timer_loss_context or (MP and MP.trigger_pvp_timer_loss_context)
	if lost and pvp_timer_lost and trigger_loss then
		trigger_loss()
	end
	if G.GAME and G.GAME.blind and MP.UI and MP.UI.get_pvp_score_to_beat then
		local pvp_int, pvp_text = MP.UI.get_pvp_score_to_beat()
		if pvp_text and pvp_text ~= "" and pvp_text ~= "0" then
			G.GAME.blind.chip_text = pvp_text
			if pvp_int and MP.INSANE_INT then
				G.GAME.blind.chips = MP.INSANE_INT.to_safe_number(pvp_int) or G.GAME.blind.chips
			else
				local num = tonumber((string.gsub(tostring(pvp_text), ",", "")))
				if num then G.GAME.blind.chips = num end
			end
		end
	end
	if MP.enter_pvp_new_round and (G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.HAND_PLAYED or G.STATE == G.STATES.DRAW_TO_HAND) then
		MP.enter_pvp_new_round({ unhighlight_hand = true, draw_to_deck = true, state_complete = false })
	elseif MP.DOMAIN and MP.DOMAIN.MATCH and MP.DOMAIN.MATCH.mark_end_pvp then
		MP.DOMAIN.MATCH.mark_end_pvp()
	end
	return true
end

function SPECTATOR.perform_cash_out()
	if not (G and G.GAME) then return false end
	if cash_out_already_passed() then
		return true
	end
	if in_pvp_hand() and not (MP.GAME and MP.GAME.end_pvp) then
		if MP.enter_pvp_new_round then
			MP.enter_pvp_new_round({ unhighlight_hand = true, draw_to_deck = true, state_complete = false })
		elseif MP.DOMAIN and MP.DOMAIN.MATCH and MP.DOMAIN.MATCH.mark_end_pvp then
			MP.DOMAIN.MATCH.mark_end_pvp()
		end
		return false
	end
	-- Wait for round evaluation to land and present its Cash Out button naturally
	local button = find_uie_by_id("cash_out_button", G.round_eval)
	if not G.round_eval or not button then
		-- Fallback: if round_eval is already present and active, but the anonymous
		-- bottom row UIBox is delayed, dispatch cash_out directly rather than stalling
		-- the replay queue.
		if G.round_eval and (G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND) then
			local queue = SPECTATOR.pending_replay_queue
			local head = queue and queue[1]
			if head and head.type == "CASH_OUT" and (head.attempts or 0) > 30 then
				SPECTATOR.eval_hold = false
				return invoke_g_func("cash_out", { config = {} })
			end
		end
		return false
	end
	-- Handy can mark insta-cash-out as already skipped on this client;
	-- that early-return would eat the spectator replay of the real click.
	if Handy and Handy.insta_cash_out then
		Handy.insta_cash_out.is_skipped = false
	end
	SPECTATOR.eval_hold = false
	return invoke_g_func("cash_out", button)
end

function SPECTATOR.perform_toggle_shop()
	if not (G and G.GAME) then return false end
	if G.STATE == G.STATES.SHOP or G.shop then
		-- Vanilla shop "Next" is next_round_button, bound to toggle_shop.
		local button = find_uie_by_id("next_round_button", G.shop)
		if not button then
			return false
		end
		return invoke_g_func("toggle_shop", button)
	end
	return false
end

local function card_center_key(card)
	return (card and card.config and card.config.center and card.config.center.key)
		or (card and card.config and card.config.center_key)
		or (card and card.ability and card.ability.name)
end

local function find_card_in_area(area, index, card_key)
	if not (area and area.cards and #area.cards > 0) then
		return nil
	end
	index = tonumber(index)
	local card = index and area.cards[index]

	-- 1. Exact slot match
	if card and (not card_key or card_center_key(card) == card_key) then
		return card
	end

	-- 2. If slot shifted, search area for matching card_key
	if card_key then
		for _, candidate in ipairs(area.cards) do
			if card_center_key(candidate) == card_key then
				return candidate
			end
		end
	end

	-- 3. Pure deterministic fallback: buy/use what simulation put in that slot
	if card then
		return card
	end

	return nil
end

local function find_card_by_sort_id(area, sort_id)
	if not (area and area.cards and sort_id ~= nil) then
		return nil
	end
	for _, card in ipairs(area.cards) do
		if card and tostring(card.sort_id or card.ID) == tostring(sort_id) then
			return card
		end
	end
	return nil
end

local function consumeable_needs_targets(card)
	local ability = card and card.ability and card.ability.consumeable
	if type(ability) == "table" and (ability.max_highlighted or ability.min_highlighted) then
		return true
	end
	local cfg = card and card.config and card.config.center and card.config.center.config
	if type(cfg) == "table" and (cfg.max_highlighted or cfg.min_highlighted) then
		return true
	end
	return false
end

-- Vanilla Card:use_consumeable closes over G.hand.highlighted[1] (Talisman
-- family) or reads it later from a delayed event (Aura/Cryptid). If the
-- spectator invokes use without those highlights, those events crash.
local function apply_consumeable_targets(data)
	local indices = (data and data.target_indices) or {}
	local ids = (data and data.target_ids) or {}
	if #indices == 0 and #ids == 0 then
		return true
	end
	local area = get_card_area_by_name((data and data.target_area) or "hand") or G.hand
	if not (area and area.cards) then
		return false
	end
	pcall(function()
		area:unhighlight_all()
	end)
	local n = math.max(#indices, #ids)
	for i = 1, n do
		local card = nil
		if ids[i] ~= nil then
			card = find_card_by_sort_id(area, ids[i])
		end
		if not card and indices[i] then
			card = area.cards[indices[i]]
		end
		if not card then
			return false
		end
		area:add_to_highlighted(card)
	end
	return area.highlighted and #area.highlighted == n
end

local function prepare_consumeable_use(card, data)
	local applied = apply_consumeable_targets(data)
	if not consumeable_needs_targets(card) then
		return applied
	end
	if not applied then
		local has_payload = (data and ((data.target_indices and #data.target_indices > 0) or (data.target_ids and #data.target_ids > 0)))
		if not has_payload then
			-- Old stream with no targets: skip rather than queue a crash.
			return "skip"
		end
		return false
	end
	local area = get_card_area_by_name((data and data.target_area) or "hand") or G.hand
	if not (area and area.highlighted and #area.highlighted > 0) then
		return false
	end
	return true
end

function SPECTATOR.perform_buy_card(data)
	if not (G and G.GAME) then return false end
	local area_name = (data and data.area) or "shop_jokers"
	local area = get_card_area_by_name(area_name)
	if not (area and area.cards and #area.cards > 0) then
		return false
	end

	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end

	-- Morphing the shop card to the recorded key was a board-stamp. Buy the
	-- card that simulation actually put in that slot.

	if G.FUNCS and G.FUNCS.buy_from_shop then
		return invoke_g_func("buy_from_shop", {
			config = { ref_table = card, id = "buy" },
		})
	end
	return false
end

function SPECTATOR.perform_buy_and_use(data)
	if not (G and G.GAME) then return false end
	local area_name = (data and data.area) or "shop_jokers"
	local area = get_card_area_by_name(area_name)
	if not (area and area.cards and #area.cards > 0) then
		return false
	end

	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end

	local prepared = prepare_consumeable_use(card, data)
	if prepared == "skip" then
		return true
	end
	if prepared == false then
		return false
	end

	-- Vanilla's buy_and_use is a full purchase that never emplaces the card:
	-- it pays, removes the shop slot, and re-enters use_card internally.
	-- Calling use_card directly here skipped payment, left the shop card in
	-- place, and desynced hand levels for planets/tarots bought this way.
	if G.FUNCS and G.FUNCS.buy_from_shop then
		return invoke_g_func("buy_from_shop", {
			config = { ref_table = card, id = "buy_and_use" },
		})
	end
	return false
end

function SPECTATOR.perform_reroll_shop()
	if not (G and G.FUNCS and G.FUNCS.reroll_shop) then
		return false
	end
	if not (G.STATE == G.STATES.SHOP or G.shop) then
		return false
	end
	-- Vanilla reroll draws from the shared seed. Do not wait for a stamped
	-- offer and do not skip the RNG spawn.
	SPECTATOR.is_executing_action = true
	local ok = pcall(G.FUNCS.reroll_shop)
	SPECTATOR.is_executing_action = false
	return ok
end

local function has_editionless_joker()
	if not (G and G.jokers and G.jokers.cards) then
		return false
	end
	for i = 1, #G.jokers.cards do
		local joker = G.jokers.cards[i]
		if joker and not joker.edition then
			return true
		end
	end
	return false
end

function SPECTATOR.perform_use_card(data)
	if not (G and G.GAME) then
		return false
	end
	local area = get_card_area_by_name((data and data.area) or "consumeables")
	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end

	-- Wheel / Ectoplasm pick a random editionless joker in a delayed event.
	-- Vanilla crashes if that list is empty (card.lua eligible_card = nil).
	local key = card_center_key(card)
	if (key == "c_wheel_of_fortune" or key == "c_ectoplasm") and not has_editionless_joker() then
		return true
	end

	local prepared = prepare_consumeable_use(card, data)
	if prepared == "skip" then
		return true
	end
	if prepared == false then
		return false
	end

	if card.check_use and card:check_use() then
		return false
	end
	if not (G.FUNCS and G.FUNCS.use_card) then
		return false
	end
	return invoke_g_func("use_card", { config = { ref_table = card } })
end

function SPECTATOR.perform_sell_card(data)
	if not (G and data) then
		return false
	end
	local area = get_card_area_by_name(data.area or "jokers")
	local card = find_card_in_area(area, data.index or 1, data.card_key)
	if not card then
		return false
	end
	if G.FUNCS and G.FUNCS.sell_card then
		return invoke_g_func("sell_card", { config = { ref_table = card } })
	end
	return false
end

local function remember_pack_interrupt()
	if not (G and G.GAME and G.STATES) then
		return
	end
	if G.GAME.PACK_INTERRUPT ~= nil then
		SPECTATOR.pack_interrupt = G.GAME.PACK_INTERRUPT
		return
	end
	if SPECTATOR.pack_interrupt then
		G.GAME.PACK_INTERRUPT = SPECTATOR.pack_interrupt
		return
	end
	if G.shop and not G.shop.REMOVED then
		G.GAME.PACK_INTERRUPT = G.STATES.SHOP
	elseif G.blind_select and not G.blind_select.REMOVED then
		G.GAME.PACK_INTERRUPT = G.STATES.BLIND_SELECT
	end
	SPECTATOR.pack_interrupt = G.GAME.PACK_INTERRUPT
end

function SPECTATOR.perform_buy_booster(data)
	if not (G and G.FUNCS and G.FUNCS.use_card) then
		return false
	end
	local area = get_card_area_by_name("shop_booster")
	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end
	local ok = invoke_g_func("use_card", { config = { ref_table = card } })
	remember_pack_interrupt()
	return ok
end

function SPECTATOR.perform_select_pack_card(data)
	if not (G and G.FUNCS and G.FUNCS.use_card) then
		return false
	end
	remember_pack_interrupt()
	local area = get_card_area_by_name("pack_cards")
	local card = find_card_in_area(area, (data and data.index) or 1, data and data.card_key)
	if not card then
		return false
	end
	local prepared = prepare_consumeable_use(card, data)
	if prepared == "skip" then
		return true
	end
	if prepared == false then
		return false
	end
	return invoke_g_func("use_card", { config = { ref_table = card } })
end

function SPECTATOR.perform_skip_pack()
	remember_pack_interrupt()
	if not (G and G.FUNCS and G.FUNCS.skip_booster) then
		return false
	end
	if not (G.booster_pack and not G.booster_pack.REMOVED) then
		return false
	end
	return invoke_g_func("skip_booster")
end

function SPECTATOR.handle_pack_closed(return_state)
	if not (SPECTATOR.is_spectating and G and G.STATES) then
		return
	end
	if SPECTATOR._handling_pack_exit then
		return
	end
	SPECTATOR._handling_pack_exit = true

	return_state = tonumber(return_state) or return_state or SPECTATOR.pack_interrupt or (G.GAME and G.GAME.PACK_INTERRUPT)

	-- Live follow: vanilla end_consumeable already closed the pack and slid
	-- shop back. Doing that again is the shake. Only fill a missing screen
	-- after a switch-onto-pack snapshot, which never had a parked shop.
	if return_state == G.STATES.SHOP and (not G.shop or G.shop.REMOVED) then
		G.STATE = G.STATES.SHOP
		G.STATE_COMPLETE = false
		local prev = SPECTATOR.applying_snapshot
		SPECTATOR.applying_snapshot = true
		if G.update_shop then
			pcall(function()
				G:update_shop(0.016)
			end)
		end
		local cards = SPECTATOR.cached_pack_return_shop_cards
		if cards and #cards > 0 then
			apply_stream_shop(cards, SPECTATOR.cached_pack_return_round or (G.GAME and G.GAME.round))
		end
		SPECTATOR.applying_snapshot = prev
	elseif return_state == G.STATES.BLIND_SELECT and (not G.blind_select or G.blind_select.REMOVED) then
		G.STATE = G.STATES.BLIND_SELECT
		G.STATE_COMPLETE = false
	end

	clear_pack_return_latch()
end

-- One-shot after a pack actually ends. Must not run while waiting in
-- BLIND_SELECT for a switch snapshot (STATE_COMPLETE is true on purpose).
function SPECTATOR.ensure_post_pack_ui()
	if not (SPECTATOR.is_spectating and G and G.STATES) then
		return
	end
	if SPECTATOR.applying_snapshot or SPECTATOR._handling_pack_exit then
		return
	end
	if not SPECTATOR.pack_interrupt then
		return
	end
	if is_booster_pack_state(G.STATE) or (G.booster_pack and not G.booster_pack.REMOVED) then
		return
	end
	SPECTATOR.handle_pack_closed(SPECTATOR.pack_interrupt)
end

function SPECTATOR.perform_sort_hand(data)
	if not (G and G.FUNCS) then
		return false
	end
	local func = (data and data.mode == "value") and G.FUNCS.sort_hand_value or G.FUNCS.sort_hand_suit
	if not func then
		return false
	end
	SPECTATOR.is_executing_action = true
	local ok = pcall(func)
	SPECTATOR.is_executing_action = false
	return ok
end

function SPECTATOR.perform_reroll_boss()
	if not (G and G.FUNCS and G.FUNCS.reroll_boss) then
		return false
	end
	if not (G.STATE == G.STATES.BLIND_SELECT or G.blind_select) then
		return false
	end
	SPECTATOR.is_executing_action = true
	local ok = pcall(G.FUNCS.reroll_boss)
	SPECTATOR.is_executing_action = false
	return ok
end

function SPECTATOR.perform_reorder_cards(data)
	if not (G and data) then
		return false
	end
	local area = get_card_area_by_name(data.area)
	if not (area and area.cards and data.order) then
		return false
	end
	local new_cards = {}
	for _, old_idx in ipairs(data.order) do
		if area.cards[old_idx] then
			new_cards[#new_cards + 1] = area.cards[old_idx]
		end
	end
	if #new_cards ~= #area.cards then
		return false
	end
	area.cards = new_cards
	-- align_cards writes each card's target T from the new list order.
	-- Leave VT alone: Moveable eases VT toward T the same way a live drag
	-- settle does. hard_set_cards would copy T onto VT and teleport.
	for i, card in ipairs(area.cards) do
		if card then
			card.rank = i
		end
	end
	if area.align_cards then
		pcall(area.align_cards, area)
	end
	return true
end

function SPECTATOR.perform_team_card_sync(data)
	local sync = MP.SYNC and MP.SYNC.TEAM_CARD
	if not (sync and sync.handle_sync and data and data.cardKey) then
		return true
	end
	sync.handle_sync({
		cardKey = data.cardKey,
		actionType = data.actionType,
		cardData = data.cardData,
		playerId = data.sourcePlayerId,
		sourcePlayerId = data.sourcePlayerId,
	})
	return true
end

-- Central dispatch: one entry point for every replayable action type.
-- Returns true (done), false (not ready — caller may queue), or nil
-- (unknown type).
function SPECTATOR.perform_action(action_type, data)
	if action_type == "START_RUN" then
		return SPECTATOR.perform_start_run(data)
	elseif action_type == "PLAY_HAND" then
		return SPECTATOR.perform_play_hand(data)
	elseif action_type == "DISCARD" then
		return SPECTATOR.perform_discard(data)
	elseif action_type == "SELECT_BLIND" then
		return SPECTATOR.perform_select_blind(data)
	elseif action_type == "SKIP_BLIND" then
		return SPECTATOR.perform_skip_blind(data)
	elseif action_type == "END_PVP" then
		return SPECTATOR.perform_end_pvp(data)
	elseif action_type == "CASH_OUT" then
		return SPECTATOR.perform_cash_out()
	elseif action_type == "TOGGLE_SHOP" then
		return SPECTATOR.perform_toggle_shop()
	elseif action_type == "BUY_CARD" then
		return SPECTATOR.perform_buy_card(data)
	elseif action_type == "BUY_AND_USE" then
		return SPECTATOR.perform_buy_and_use(data)
	elseif action_type == "BUY_BOOSTER" then
		return SPECTATOR.perform_buy_booster(data)
	elseif action_type == "SELECT_PACK_CARD" then
		return SPECTATOR.perform_select_pack_card(data)
	elseif action_type == "SKIP_PACK" then
		return SPECTATOR.perform_skip_pack()
	elseif action_type == "REROLL_SHOP" then
		return SPECTATOR.perform_reroll_shop()
	elseif action_type == "USE_CARD" then
		return SPECTATOR.perform_use_card(data)
	elseif action_type == "SELL_CARD" then
		return SPECTATOR.perform_sell_card(data)
	elseif action_type == "REORDER_CARDS" then
		return SPECTATOR.perform_reorder_cards(data)
	elseif action_type == "SORT_HAND" then
		return SPECTATOR.perform_sort_hand(data)
	elseif action_type == "REROLL_BOSS" then
		return SPECTATOR.perform_reroll_boss()
	elseif action_type == "TEAM_CARD_SYNC" then
		return SPECTATOR.perform_team_card_sync(data)
	end
	return nil
end

-- Pending replay queue: actions whose perform returned false wait here and
-- are drained by the spectator viewport update cycle. Nothing is silently
-- dropped anymore — entries expire (with a flaw log) after too many ticks.
SPECTATOR.pending_replay_queue = SPECTATOR.pending_replay_queue or {}
local PENDING_MAX_ATTEMPTS = 200

-- Some actions only ever make sense on a specific game surface. Once that
-- surface is gone the entry can never become ready again (e.g. CASH_OUT
-- after its eval hold was released because the stream moved on), so it is
-- dropped immediately instead of blocking the queue head with futile retries.
local ACTION_WINDOW_CLOSED = {
	CASH_OUT = function()
		if not G then
			return true
		end
		-- SELECTING_HAND is "eval has not opened yet", not "eval is gone".
		-- Dropping here threw away CASH_OUT while two hands were still left
		-- and then timed out every shop/pack action behind it.
		if cash_out_already_passed() then
			return false
		end
		if G.STATES and (
			G.STATE == G.STATES.GAME_OVER
			or G.STATE == G.STATES.MENU
			or G.STATE == G.STATES.SPLASH
		) then
			return true
		end
		return false
	end,
}

function SPECTATOR.enqueue_replay_action(action_type, data, step, board_state)
	SPECTATOR.pending_replay_queue[#SPECTATOR.pending_replay_queue + 1] = {
		type = action_type,
		data = data,
		step = step,
		board_state = board_state,
		target = SPECTATOR.target_player_id,
		attempts = 0,
	}
	table.sort(SPECTATOR.pending_replay_queue, function(a, b)
		local sa = tonumber(a.step) or 0
		local sb = tonumber(b.step) or 0
		return sa < sb
	end)
end

-- Replay commands must observe a settled simulation: vanilla lands gameplay
-- effects through queued E_MANAGER events, and executing the next command
-- mid-chain reads state the target never saw. A leftover ease/idle event
-- that never drains used to look "busy" forever; treat a stuck small queue
-- as settled instead of waiting 600 ticks then logging a fake timeout.
local SETTLE_MAX_TICKS = 180
local SETTLE_STUCK_TICKS = 45
SPECTATOR._settle_ticks = 0
SPECTATOR._settle_stuck = 0
SPECTATOR._settle_last_n = 0
local function sim_busy(action_type)
	if G and G.STATES then
		if G.STATE == G.STATES.DRAW_TO_HAND then
			return true
		end
		if G.STATE == G.STATES.HAND_PLAYED then
			-- In server-resolved blinds (PvP boss), when the player finishes their hands
			-- (or is waiting for enemy), the game idles in HAND_PLAYED with an empty event queue.
			-- Treating HAND_PLAYED as busy when card scoring animations have finished
			-- permanently deadlocks the replay queue, preventing END_PVP or CASH_OUT from ever executing.
			local is_phase_action = action_type == "END_PVP" or action_type == "CASH_OUT"
			if not is_phase_action and SPECTATOR.pending_replay_queue and SPECTATOR.pending_replay_queue[1] then
				local head = SPECTATOR.pending_replay_queue[1]
				if head.type == "END_PVP" or head.type == "CASH_OUT" then
					is_phase_action = true
				end
			end
			if not is_phase_action then
				return true
			end
		end
	end
	if SMODS and SMODS.cards_to_draw and SMODS.cards_to_draw > 0 then
		return true
	end
	local n = count_e_manager_events()
	if n <= 0 then
		SPECTATOR._settle_ticks = 0
		SPECTATOR._settle_stuck = 0
		SPECTATOR._settle_last_n = 0
		return false
	end
	if n == SPECTATOR._settle_last_n then
		SPECTATOR._settle_stuck = (SPECTATOR._settle_stuck or 0) + 1
	else
		SPECTATOR._settle_stuck = 0
		SPECTATOR._settle_last_n = n
	end
	SPECTATOR._settle_ticks = (SPECTATOR._settle_ticks or 0) + 1
	-- One or two events sitting at the same count are almost always an
	-- ambient ease that will never empty the queue.
	if n <= 2 and (SPECTATOR._settle_stuck or 0) >= SETTLE_STUCK_TICKS then
		SPECTATOR._settle_ticks = 0
		return false
	end
	if SPECTATOR._settle_ticks > SETTLE_MAX_TICKS then
		SPECTATOR._settle_ticks = 0
		SPECTATOR._settle_stuck = 0
		return false
	end
	return true
end

-- Drains at most one ready action per call (called from the update cycle).
function SPECTATOR.drain_pending_replay_actions()
	if not SPECTATOR.is_spectating or SPECTATOR.is_catching_up then
		return
	end
	local queue = SPECTATOR.pending_replay_queue
	if not queue or #queue == 0 then
		return
	end

	local entry = queue[1]
	if entry.target ~= SPECTATOR.target_player_id then
		table.remove(queue, 1)
		return
	end

	if sim_busy(entry.type) then
		return
	end

	entry.attempts = entry.attempts + 1
	local is_phase_action = entry.type == "CASH_OUT"
		or entry.type == "SELECT_BLIND"
		or entry.type == "TOGGLE_SHOP"
		or entry.type == "END_PVP"

	local max_attempts = is_phase_action and 1000 or PENDING_MAX_ATTEMPTS
	if entry.attempts > max_attempts then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("QUEUE", "drop_timeout", string.format("%s #%s (try=%d)", entry.type, tostring(entry.step or "?"), entry.attempts))
		end
		table.remove(queue, 1)
		return
	end

	local window_closed = ACTION_WINDOW_CLOSED[entry.type]
	if window_closed and window_closed() then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("QUEUE", "drop_window", string.format("%s #%s", entry.type, tostring(entry.step or "?")))
		end
		table.remove(queue, 1)
		return
	end

	if not SPECTATOR.is_executing_action then
		local ok, result = pcall(SPECTATOR.perform_action, entry.type, entry.data)
		if ok and result == true then
			if entry.step and tonumber(entry.step) then
				SPECTATOR.current_step = math.max(SPECTATOR.current_step, tonumber(entry.step))
			end
			if MP.TESTING and MP.TESTING.log_spectator then
				MP.TESTING.log_spectator("QUEUE", "exec_ok", string.format("%s #%s (try=%d)", entry.type, tostring(entry.step or "?"), entry.attempts))
			end
			table.remove(queue, 1)
		end
	end
end

function SPECTATOR.execute_action(action)
	if not action or type(action) ~= "table" then
		return
	end

	-- In-order pipeline: if earlier actions are waiting in the replay queue,
	-- or the engine is busy processing animation chains, enqueue this action
	-- so actions execute strictly in sequential step order.
	local queue = SPECTATOR.pending_replay_queue or {}
	if #queue > 0 or sim_busy(action.type) then
		SPECTATOR.enqueue_replay_action(action.type, action.data, tonumber(action.step))
		return
	end

	local step = tonumber(action.step)
	if step then
		if step <= SPECTATOR.current_step then
			return
		end
		SPECTATOR.current_step = math.max(SPECTATOR.current_step, step)
	else
		SPECTATOR.current_step = SPECTATOR.current_step + 1
	end

	local action_type = action.type
	local data = action.data or {}

	SPECTATOR.is_executing_action = true
	local ok, result = pcall(SPECTATOR.perform_action, action_type, data)
	SPECTATOR.is_executing_action = false
	if ok and result == false then
		SPECTATOR.enqueue_replay_action(action_type, data, step)
	end
end

local function to_game_number(value, fallback)
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		return tonumber(value) or fallback
	end
	if value == nil then
		return fallback
	end
	if to_big then
		local ok, n = pcall(to_big, value)
		if ok and n then
			return n
		end
	end
	return tonumber(value) or fallback
end

local function resolve_snapshot_blind_def(blind_info, board_state)
	local row = (blind_info and blind_info.blind_on_deck)
		or (board_state and board_state.blind_on_deck)
	local choices = (board_state and board_state.blind_choices)
		or (G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices)
	local key = blind_info and blind_info.key
	if (not key or key == "") and row and choices then
		key = choices[row]
	end
	if key and G.P_BLINDS and G.P_BLINDS[key] then
		return G.P_BLINDS[key]
	end
	if row == "Small" and G.P_BLINDS then
		return G.P_BLINDS.bl_small
	end
	if row == "Big" and G.P_BLINDS then
		return G.P_BLINDS.bl_big
	end
	if row == "Boss" and choices and choices.Boss and G.P_BLINDS and G.P_BLINDS[choices.Boss] then
		return G.P_BLINDS[choices.Boss]
	end
	return nil
end

-- Stamp the target's blind onto this client so vanilla evaluate_round()
-- sees the same name, chip target, and dollar reward. After defeat() the
-- snapshot chips are 0; identity comes from P_BLINDS / round_resets, not
-- those zeros.
local function restore_blind_from_snapshot(blind_info, board_state)
	if not (G and G.GAME) then
		return
	end
	local def = resolve_snapshot_blind_def(blind_info, board_state)
	if not G.GAME.blind and Blind then
		G.GAME.blind = Blind(0, 0, 2, 1)
	end
	if not G.GAME.blind then
		return
	end
	if def and G.GAME.blind.set_blind then
		-- reset=nil ensures Balatro configures name, chips, sprite, colours,
		-- and dollars. Passing reset=true skipped the entire setup in set_blind.
		-- Any Water/Needle/Manacle side effects are overwritten by the
		-- authoritative board_state values.
		local already_in_round = is_playing_round_state(board_state and board_state.state)
		G.GAME.blind:set_blind(def, nil, true)
		if already_in_round then
			G.GAME.blind.config = G.GAME.blind.config or {}
			G.GAME.blind.config.blind = def
			if should_show_blind_hud(board_state and board_state.state) then
				show_blind_hud_plaque()
			end
		end
	end
	local row = (blind_info and blind_info.blind_on_deck)
		or (board_state and board_state.blind_on_deck)
		or (G.GAME and G.GAME.blind_on_deck)
	local pvp_choices = board_state and board_state.pvp_blind_choices
	local is_pvp = (def and def.key == "bl_mp_nemesis")
		or (G.GAME.blind and (G.GAME.blind.pvp or G.GAME.blind.name == "bl_mp_nemesis"))
		or (row and pvp_choices and pvp_choices[row])
		or (MP.is_pvp_boss and MP.is_pvp_boss())
		or (MP.is_pvp and MP.is_pvp())
		or (MP.GAME and (MP.GAME.end_pvp or MP.GAME.pvp))
	if is_pvp and G.GAME.blind then
		G.GAME.blind.pvp = true
	end
	-- PvP does not use vanilla "score at least N". Filling get_blind_amount
	-- here is what painted 800 after skip/switch.
	if not is_pvp then
		if (not G.GAME.blind.chips or to_game_number(G.GAME.blind.chips, 0) == 0) and def and get_blind_amount then
			local ante = (G.GAME.round_resets and (G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante)) or 1
			local mult = def.mult or 1
			local scaling = (G.GAME.starting_params and G.GAME.starting_params.ante_scaling) or 1
			G.GAME.blind.chips = get_blind_amount(ante) * mult * scaling
		end
	end
	local snap_chips = blind_info and to_game_number(blind_info.chips, nil)
	local snap_text = blind_info and blind_info.chip_text
	local chips_from_snap = type(snap_chips) == "number" and snap_chips > 0
	local text_from_snap = type(snap_text) == "string" and snap_text ~= "" and snap_text ~= "0"
	if chips_from_snap then
		G.GAME.blind.chips = snap_chips
	end
	if text_from_snap then
		G.GAME.blind.chip_text = snap_text
	elseif G.GAME.blind.chips and number_format then
		G.GAME.blind.chip_text = number_format(G.GAME.blind.chips)
	end
	if is_pvp and (not text_from_snap or G.GAME.blind.chip_text == "0") and MP.UI and MP.UI.get_pvp_score_to_beat then
		local score_int, score_text = MP.UI.get_pvp_score_to_beat()
		if score_text and score_text ~= "" and score_text ~= "0" then
			G.GAME.blind.chip_text = score_text
			if not chips_from_snap and score_int then
				G.GAME.blind.chips = (MP.INSANE_INT and MP.INSANE_INT.to_safe_number(score_int)) or G.GAME.blind.chips
			elseif not chips_from_snap and score_text then
				local num = tonumber((string.gsub(tostring(score_text), ",", "")))
				if num then G.GAME.blind.chips = num end
			end
		end
	end
	local snap_dollars = blind_info and tonumber(blind_info.dollars)
	if snap_dollars and snap_dollars > 0 then
		G.GAME.blind.dollars = snap_dollars
	end
	if G.GAME.current_round and G.GAME.blind.dollars then
		local loc_dollar = (type(localize) == "function" and localize('$')) or "$"
		G.GAME.current_round.dollars_to_be_earned = G.GAME.blind.dollars > 0 and string.rep(loc_dollar, G.GAME.blind.dollars) or ""
	end
	if blind_info and blind_info.name and blind_info.name ~= "" then
		G.GAME.blind.name = blind_info.name
	end
	if def and G.GAME.round_resets then
		G.GAME.round_resets.blind = def
	end
end

-- After a switch snapshot rebuild, put the sim inputs vanilla uses for
-- the next shop roll. Painting cards consumes local RNG and can leave
-- the previous target's owned-joker set / rates in place.
local original_get_current_pool = nil

local function install_spectator_pool_unlock_wrap()
	if original_get_current_pool or type(get_current_pool) ~= "function" then
		return
	end
	original_get_current_pool = get_current_pool
	function get_current_pool(_type, _rarity, _legendary, _append)
		if not (SPECTATOR.is_spectating and type(SPECTATOR.locked_jokers) == "table") then
			return original_get_current_pool(_type, _rarity, _legendary, _append)
		end
		local changed = {}
		local pool = G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker
		if type(pool) == "table" then
			for _, center in ipairs(pool) do
				if center and center.key then
					local want = not SPECTATOR.locked_jokers[center.key]
					if center.unlocked ~= want then
						changed[#changed + 1] = { center = center, unlocked = center.unlocked }
						center.unlocked = want
					end
				end
			end
		end
		local pool_result, pool_key = original_get_current_pool(_type, _rarity, _legendary, _append)
		for i = 1, #changed do
			changed[i].center.unlocked = changed[i].unlocked
		end
		return pool_result, pool_key
	end
end

-- Last-writer-wins RNG restore. UI rebuilds during a snapshot apply can
-- consume keyed streams (update_shop's event chain, blind select, packs);
-- running this AFTER those rebuilds discards that consumption so the sim's
-- stream position stays identical to the target's.
local function restore_shop_pseudorandom(board_state)
	if not (G and G.GAME and type(board_state) == "table") then
		return
	end

	local rng = board_state.pseudorandom
	if type(rng) == "table" and rng.seed ~= nil then
		local restored = {}
		for k, v in pairs(rng) do
			if type(v) == "string" then
				if k == "seed" then
					restored[k] = v
				else
					-- %.17g strings round-trip doubles exactly
					restored[k] = tonumber(v) or v
				end
			elseif type(v) == "number" then
				restored[k] = v
			end
		end
		G.GAME.pseudorandom = restored
	end
end

local function restore_shop_sim_inputs(board_state)
	if not (G and G.GAME and type(board_state) == "table") then
		return
	end
	install_spectator_pool_unlock_wrap()
	if type(board_state.used_jokers) == "table" then
		local used = {}
		for k, v in pairs(board_state.used_jokers) do
			if v then
				used[tostring(k)] = true
			end
		end
		G.GAME.used_jokers = used
	end
	if board_state.joker_rate ~= nil then
		G.GAME.joker_rate = tonumber(board_state.joker_rate) or G.GAME.joker_rate
	end
	if board_state.tarot_rate ~= nil then
		G.GAME.tarot_rate = tonumber(board_state.tarot_rate) or G.GAME.tarot_rate
	end
	if board_state.planet_rate ~= nil then
		G.GAME.planet_rate = tonumber(board_state.planet_rate) or G.GAME.planet_rate
	end
	if board_state.spectral_rate ~= nil then
		G.GAME.spectral_rate = tonumber(board_state.spectral_rate) or G.GAME.spectral_rate
	end
	if board_state.playing_card_rate ~= nil then
		G.GAME.playing_card_rate = tonumber(board_state.playing_card_rate) or G.GAME.playing_card_rate
	end
	if board_state.edition_rate ~= nil then
		G.GAME.edition_rate = tonumber(board_state.edition_rate) or G.GAME.edition_rate
	end
	if board_state.shop_joker_max ~= nil then
		G.GAME.shop = G.GAME.shop or {}
		G.GAME.shop.joker_max = tonumber(board_state.shop_joker_max) or G.GAME.shop.joker_max
	end
	if type(board_state.banned_keys) == "table" then
		local banned = {}
		for k, v in pairs(board_state.banned_keys) do
			if v then
				banned[tostring(k)] = true
			end
		end
		G.GAME.banned_keys = banned
	end
	if type(board_state.pool_flags) == "table" then
		local flags = {}
		for k, v in pairs(board_state.pool_flags) do
			if type(v) == "boolean" then
				flags[tostring(k)] = v
			end
		end
		G.GAME.pool_flags = flags
	end
	G.GAME.modifiers = G.GAME.modifiers or {}
	if board_state.enable_eternals_in_shop ~= nil then
		G.GAME.modifiers.enable_eternals_in_shop = not not board_state.enable_eternals_in_shop
	end
	if board_state.enable_perishables_in_shop ~= nil then
		G.GAME.modifiers.enable_perishables_in_shop = not not board_state.enable_perishables_in_shop
	end
	if board_state.enable_rentals_in_shop ~= nil then
		G.GAME.modifiers.enable_rentals_in_shop = not not board_state.enable_rentals_in_shop
	end
	if board_state.first_shop_buffoon ~= nil then
		G.GAME.first_shop_buffoon = not not board_state.first_shop_buffoon
	end
	if type(board_state.locked_jokers) == "table" then
		local locked = {}
		for k, v in pairs(board_state.locked_jokers) do
			if v then
				locked[tostring(k)] = true
			end
		end
		SPECTATOR.locked_jokers = locked
	else
		SPECTATOR.locked_jokers = nil
	end
end

-- START_RUN carries the target's pool / shop-roll inputs captured once at
-- its run start (collection unlocks, used_jokers, rates, bans, pool flags).
-- Applying them keeps seeded shop rolls identical to the target's WITHOUT
-- any snapshot — snapshots stay reserved for switching watched players.
function SPECTATOR.perform_start_run(data)
	if not (G and G.GAME) then
		return false
	end

	local sim_inputs = data and data.sim_inputs
	if type(sim_inputs) == "table" then
		restore_shop_sim_inputs(sim_inputs)
	end
	if data and data.sort_id ~= nil then
		G.sort_id = tonumber(data.sort_id) or G.sort_id
	end
	return true
end

-- Comeback $ (Total Lives Lost / sandbox comeback money) is stored on
-- MP.GAME, not G.GAME. The spectator client's flags stay at the initial
-- "already given" state unless we copy the target's values before
-- evaluate_round builds the cash-out rows.
--
-- Game:update_round_eval queues create-then-wait-for-VT-then-evaluate_round.
-- A switch snapshot never finishes that ease (same as skip packs), so the
-- first row never appears. Build the overlay on-screen and call
-- evaluate_round the same way vanilla does after the panel lands.
local function rebuild_round_eval_ui()
	if not (G and G.GAME) then
		return
	end
	remove_ui_box_safely("round_eval")
	clear_pending_game_events()
	if G.HUD_blind and G.HUD_blind.alignment and G.HUD_blind.alignment.offset then
		G.HUD_blind.alignment.offset.y = -10
	end
	if G.I and G.I.UIBOX then
		for i = #G.I.UIBOX, 1, -1 do
			local box = G.I.UIBOX[i]
			if box and not box.REMOVED and box.get_UIE_by_ID and box:get_UIE_by_ID("cash_out_button") then
				pcall(function()
					box:remove()
				end)
			end
		end
	end
	if G.buttons then
		pcall(function()
			G.buttons:remove()
		end)
		G.buttons = nil
	end
	if stop_use then
		pcall(stop_use)
	end
	if MP.GAME then
		MP.GAME.prevent_eval = true
	end
	G.STATE_COMPLETE = true
	G.GAME.facing_blind = nil
	if ease_background_colour_blind then
		pcall(ease_background_colour_blind, G.STATES.ROUND_EVAL)
	end
	if not create_UIBox_round_evaluation then
		return
	end
	local pack_major = G.hand
	if not (pack_major and pack_major.T) then
		pack_major = G.ROOM_ATTACH or G.ROOM
	end
	G.round_eval = UIBox({
		definition = create_UIBox_round_evaluation(),
		config = {
			align = "bm",
			offset = { x = 0, y = -7.8 },
			major = pack_major,
			bond = "Weak",
		},
	})
	pcall(function()
		if G.round_eval.align_to_major then
			G.round_eval:align_to_major()
		end
		if G.round_eval.T and G.round_eval.VT then
			G.round_eval.VT.x = G.round_eval.T.x
			G.round_eval.VT.y = G.round_eval.T.y
			G.round_eval.VT.w = G.round_eval.T.w
			G.round_eval.VT.h = G.round_eval.T.h
		end
		if G.round_eval.UIRoot and G.round_eval.UIRoot.initialize_VT then
			G.round_eval.UIRoot:initialize_VT(true)
		end
	end)
	local is_pvp = (G.GAME.blind and (G.GAME.blind.pvp or G.GAME.blind.name == "bl_mp_nemesis"))
		or (MP.is_pvp_boss and MP.is_pvp_boss())
		or (MP.is_pvp and MP.is_pvp())
		or (MP.GAME and (MP.GAME.end_pvp or MP.GAME.pvp))
	if is_pvp and G.GAME.blind and (not G.GAME.blind.chip_text or G.GAME.blind.chip_text == "" or G.GAME.blind.chip_text == "0") and MP.UI and MP.UI.get_pvp_score_to_beat then
		local score_int, score_text = MP.UI.get_pvp_score_to_beat()
		if score_text and score_text ~= "" and score_text ~= "0" then
			G.GAME.blind.chip_text = score_text
			if (not G.GAME.blind.chips or G.GAME.blind.chips == 0) and score_int then
				G.GAME.blind.chips = (MP.INSANE_INT and MP.INSANE_INT.to_safe_number(score_int)) or G.GAME.blind.chips
			elseif (not G.GAME.blind.chips or G.GAME.blind.chips == 0) and score_text then
				local num = tonumber((string.gsub(tostring(score_text), ",", "")))
				if num then G.GAME.blind.chips = num end
			end
		end
	end
	if G.FUNCS and G.FUNCS.evaluate_round then
		pcall(G.FUNCS.evaluate_round)
	end
end

function SPECTATOR.apply_comeback_state(data)
	if not (MP.GAME and data) then
		return
	end
	if data.lives ~= nil then
		MP.GAME.lives = tonumber(data.lives) or MP.GAME.lives
		MP.GAME.team_lives = MP.GAME.lives
	end
	if data.comeback_bonus ~= nil then
		MP.GAME.comeback_bonus = tonumber(data.comeback_bonus) or 0
	end
	if data.round_failed ~= nil then
		MP.GAME.round_failed = not not data.round_failed
		if not data.round_failed then
			MP.GAME.round_loss_processed = false
		end
	end
	local gold_on_loss = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gold_on_life_loss
	local bonus = tonumber(MP.GAME.comeback_bonus) or 0
	local pending = data.comeback_eval_pending
	if pending == nil then
		pending = data.comeback_bonus_given == false
			or (gold_on_loss and data.round_failed and bonus > 0)
	end
	MP.GAME.comeback_eval_pending = not not pending
	-- Switch rebuild: evaluate_round consumes comeback_bonus_given, so a
	-- snapshot taken on the cash-out screen has given=true. Pending means
	-- this eval still owes the lives-lost gold row.
	local target_state = tonumber(data.state) or data.state
	local eval_state = G and G.STATES and (
		target_state == G.STATES.ROUND_EVAL or target_state == G.STATES.NEW_ROUND
	)
	if pending and (eval_state or data.comeback_bonus_given == false) then
		MP.GAME.comeback_bonus_given = false
	elseif data.comeback_bonus_given ~= nil then
		MP.GAME.comeback_bonus_given = not not data.comeback_bonus_given
	end
end

function SPECTATOR.apply_live_board_state(board_state)
	if not board_state or not G or not G.GAME then
		return
	end

	SPECTATOR.applying_snapshot = true

	pcall(function()

	local apply_state = tonumber(board_state.state) or board_state.state
	local keep_shop_for_pack = is_booster_pack_state(apply_state)
		and G.shop
		and not G.shop.REMOVED

	clear_pending_game_events()
	reset_inherited_round_latch()
	teardown_spectated_overlays({ keep_shop = keep_shop_for_pack })
	if not is_booster_pack_state(apply_state) then
		clear_pack_return_latch()
	end

	-- Only an eval-state snapshot (handled in step 6 below) keeps the hold.
	SPECTATOR.eval_hold = false

	if G.play then
		wipe_card_area(G.play)
	end
	if G.hand and G.hand.unhighlight_all then
		pcall(function() G.hand:unhighlight_all() end)
	end

	-- 1. Sync Game Values & HUD
	local eval_pre = board_state.eval_pre
	local restoring_eval = G.STATES and apply_state == G.STATES.ROUND_EVAL
	G.GAME.dollars = to_game_number(
		(restoring_eval and eval_pre and eval_pre.dollars) or board_state.dollars,
		G.GAME.dollars
	)
	G.GAME.chips = to_game_number(board_state.chips, G.GAME.chips)
	SPECTATOR.apply_comeback_state(board_state)
	-- Never clear a received/streamed PvP end from a lagging snapshot.
	if board_state.end_pvp and MP.GAME then
		MP.GAME.end_pvp = true
	end
	if board_state.timer ~= nil and MP.GAME then
		MP.GAME.timer = tonumber(board_state.timer) or MP.GAME.timer
	end
	if board_state.nemesis_timer_started ~= nil and MP.GAME then
		MP.GAME.nemesis_timer_started = not not board_state.nemesis_timer_started
	end
	if MP.UI and MP.UI.refresh_lives_hud_binding then
		MP.UI.refresh_lives_hud_binding({ force = true })
	end
	if board_state.reroll_cost ~= nil then
		G.GAME.reroll_cost = tonumber(board_state.reroll_cost) or G.GAME.reroll_cost
	end
	if G.GAME.current_round then
		G.GAME.current_round.hands_left = tonumber(board_state.hands_left) or G.GAME.current_round.hands_left
		if board_state.hands_played ~= nil then
			G.GAME.current_round.hands_played = tonumber(board_state.hands_played) or G.GAME.current_round.hands_played
		end
		G.GAME.current_round.discards_left = tonumber(board_state.discards_left) or G.GAME.current_round.discards_left
		G.GAME.current_round.hands_sub = tonumber(board_state.hands_sub) or G.GAME.current_round.hands_sub
		G.GAME.current_round.discards_sub = tonumber(board_state.discards_sub) or G.GAME.current_round.discards_sub
		if board_state.used_packs then
			local used_packs = {}
			for pack_pos, pack_key in pairs(board_state.used_packs) do
				local pos = tonumber(pack_pos) or pack_pos
				used_packs[pos] = tostring(pack_key)
			end
			G.GAME.current_round.used_packs = used_packs
		end
	end
	if G.GAME.round_resets then
		if board_state.ante ~= nil then
			G.GAME.round_resets.ante = to_game_number(board_state.ante, G.GAME.round_resets.ante)
		end
		if board_state.blind_ante ~= nil then
			G.GAME.round_resets.blind_ante = to_game_number(board_state.blind_ante, G.GAME.round_resets.blind_ante)
		elseif board_state.ante ~= nil then
			G.GAME.round_resets.blind_ante = to_game_number(board_state.ante, G.GAME.round_resets.ante)
		end
		if board_state.ante_disp then
			G.GAME.round_resets.ante_disp = tostring(board_state.ante_disp)
		elseif G.GAME.round_resets.ante and number_format then
			G.GAME.round_resets.ante_disp = number_format(G.GAME.round_resets.ante)
		end
		if board_state.round ~= nil then
			G.GAME.round = to_game_number(board_state.round, G.GAME.round)
		end
		if board_state.ante_scaling ~= nil then
			G.GAME.starting_params = G.GAME.starting_params or {}
			G.GAME.starting_params.ante_scaling = to_game_number(
				board_state.ante_scaling,
				G.GAME.starting_params.ante_scaling
			)
		end
		-- HUD DynaText reads round_resets.ante_disp by ref; force a layout
		-- pass so a switch onto a later ante does not keep the old glyphs.
		if G.HUD and G.HUD.recalculate then
			pcall(function()
				G.HUD:recalculate()
			end)
		end
		if board_state.blind_choices then
			G.GAME.round_resets.blind_choices = board_state.blind_choices
		end
		if board_state.pvp_blind_choices then
			G.GAME.round_resets.pvp_blind_choices = board_state.pvp_blind_choices
		end
		if board_state.blind_states then
			G.GAME.round_resets.blind_states = board_state.blind_states
		end
		if board_state.blind_tags then
			G.GAME.round_resets.blind_tags = board_state.blind_tags
		end
		if board_state.orbital_choices then
			G.GAME.orbital_choices = board_state.orbital_choices
		end
		if board_state.base_hands ~= nil then
			G.GAME.round_resets.hands = tonumber(board_state.base_hands) or G.GAME.round_resets.hands
		end
		if board_state.base_discards ~= nil then
			G.GAME.round_resets.discards = tonumber(board_state.base_discards) or G.GAME.round_resets.discards
		end
		if board_state.temp_handsize ~= nil then
			G.GAME.round_resets.temp_handsize = tonumber(board_state.temp_handsize) or G.GAME.round_resets.temp_handsize
		end
	end

	if board_state.probabilities_normal ~= nil and G.GAME and G.GAME.probabilities then
		G.GAME.probabilities.normal = tonumber(board_state.probabilities_normal) or 1
	end
	if board_state.discount_percent ~= nil and G.GAME then
		G.GAME.discount_percent = tonumber(board_state.discount_percent) or 0
	end
	if board_state.interest_cap ~= nil and G.GAME then
		G.GAME.interest_cap = tonumber(board_state.interest_cap) or 25
	end
	if board_state.last_tarot_planet and G.GAME then
		G.GAME.last_tarot_planet = board_state.last_tarot_planet
	end

	-- Sync Poker Hands
	if board_state.hands and G.GAME then
		reset_hands_to_base()
		G.GAME.hands = G.GAME.hands or {}
		for name, h_info in pairs(board_state.hands) do
			if G.GAME.hands[name] then
				if h_info.level ~= nil then G.GAME.hands[name].level = to_game_number(h_info.level, G.GAME.hands[name].level) end
				if h_info.chips ~= nil then G.GAME.hands[name].chips = to_game_number(h_info.chips, G.GAME.hands[name].chips) end
				if h_info.mult ~= nil then G.GAME.hands[name].mult = to_game_number(h_info.mult, G.GAME.hands[name].mult) end
				if h_info.s_chips ~= nil then G.GAME.hands[name].s_chips = to_game_number(h_info.s_chips, G.GAME.hands[name].s_chips) end
				if h_info.s_mult ~= nil then G.GAME.hands[name].s_mult = to_game_number(h_info.s_mult, G.GAME.hands[name].s_mult) end
				if h_info.l_chips ~= nil then G.GAME.hands[name].l_chips = to_game_number(h_info.l_chips, G.GAME.hands[name].l_chips) end
				if h_info.l_mult ~= nil then G.GAME.hands[name].l_mult = to_game_number(h_info.l_mult, G.GAME.hands[name].l_mult) end
				if h_info.played ~= nil then G.GAME.hands[name].played = tonumber(h_info.played) or 0 end
				if h_info.played_this_round ~= nil then G.GAME.hands[name].played_this_round = tonumber(h_info.played_this_round) or 0 end
				if h_info.visible ~= nil then G.GAME.hands[name].visible = not not h_info.visible end
				if h_info.order ~= nil then G.GAME.hands[name].order = tonumber(h_info.order) or G.GAME.hands[name].order end
			else
				G.GAME.hands[name] = {
					level = to_game_number(h_info.level, 1),
					chips = to_game_number(h_info.chips, 0),
					mult = to_game_number(h_info.mult, 0),
					s_chips = to_game_number(h_info.s_chips, 0),
					s_mult = to_game_number(h_info.s_mult, 0),
					l_chips = to_game_number(h_info.l_chips, 0),
					l_mult = to_game_number(h_info.l_mult, 0),
					played = tonumber(h_info.played) or 0,
					played_this_round = tonumber(h_info.played_this_round) or 0,
					visible = not not h_info.visible,
					order = tonumber(h_info.order) or 1,
				}
			end
		end
	end

	-- Collected skip tags (Investment etc.) must be B's before the select
	-- UI spawns. Leaving A's tags here is what made B still "use" A's skips.
	-- evaluate_round's Tag:yep removes Investment; eval_pre is the list from
	-- the start of that call so the spectator still has a row to show.
	local tag_source = board_state.tags
	if restoring_eval and eval_pre and type(eval_pre.tags) == "table" then
		tag_source = eval_pre.tags
	end
	if tag_source then
		if G.GAME.tags then
			for i = #G.GAME.tags, 1, -1 do
				local existing = G.GAME.tags[i]
				pcall(function()
					if existing and existing.remove then
						existing:remove()
					end
				end)
			end
		end
		G.GAME.tags = {}
		for _, tag_info in ipairs(tag_source) do
			if tag_info and tag_info.key and not tag_info.triggered then
				pcall(function()
					local tag = Tag(tag_info.key)
					tag.from_load = true
					if add_tag then
						add_tag(tag)
					else
						G.GAME.tags[#G.GAME.tags + 1] = tag
					end
				end)
			end
		end
	end

	-- 2. Sync Jokers (cleanly remove old cards and instantiate player's exact cards)
	if G.jokers then
		wipe_card_area(G.jokers)
		for _, j_info in ipairs(board_state.jokers or {}) do
			if j_info.key and G.P_CENTERS[j_info.key] then
				local empty_card = (G.P_CARDS and G.P_CARDS.empty) or {}
				local card = Card(G.jokers.T.x, G.jokers.T.y, G.CARD_W, G.CARD_H, empty_card, G.P_CENTERS[j_info.key])
				if j_info.sort_id then card.sort_id = tonumber(j_info.sort_id) or j_info.sort_id end
				if j_info.edition then card:set_edition(j_info.edition, true) end
				if j_info.eternal then card:set_eternal(true) end
				if j_info.pinned then card.pinned = true end
				if j_info.rental then card:set_rental(true) end
				if j_info.perishable then card:set_perishable(true) end
				if j_info.extra and card.ability then card.ability.extra = j_info.extra end
				if j_info.mult and card.ability then card.ability.mult = j_info.mult end
				if j_info.h_mult and card.ability then card.ability.h_mult = j_info.h_mult end
				if j_info.h_chips and card.ability then card.ability.h_chips = j_info.h_chips end
				if j_info.x_mult and card.ability then card.ability.x_mult = j_info.x_mult end
				if j_info.hands_played and card.ability then card.ability.hands_played = j_info.hands_played end
				if j_info.discards_used and card.ability then card.ability.discards_used = j_info.discards_used end
				G.jokers:emplace(card)
			end
		end
		if G.jokers.align_cards then
			G.jokers:align_cards()
		end
		if G.jokers.hard_set_cards then
			G.jokers:hard_set_cards()
		end
	end

	-- 3. Sync Consumables
	if G.consumeables and board_state.consumeables then
		for i = #G.consumeables.cards, 1, -1 do
			local c = G.consumeables.cards[i]
			c:remove()
		end
		G.consumeables.cards = {}
		for _, c_info in ipairs(board_state.consumeables) do
			if c_info.key and G.P_CENTERS[c_info.key] then
				local empty_card = (G.P_CARDS and G.P_CARDS.empty) or {}
				local card = Card(G.consumeables.T.x, G.consumeables.T.y, G.CARD_W, G.CARD_H, empty_card, G.P_CENTERS[c_info.key])
				if c_info.sort_id then card.sort_id = tonumber(c_info.sort_id) or c_info.sort_id end
				if c_info.edition then card:set_edition(c_info.edition, true) end
				G.consumeables:emplace(card)
			end
		end
		G.consumeables:align_cards()
		G.consumeables:hard_set_cards()
	end

	-- Determine target state and pack status early so CardArea alignments
	-- (especially G.hand during booster packs) know the correct layout branch.
	local target_state = tonumber(board_state.state) or board_state.state
	local is_pack_state = is_booster_pack_state(target_state)
	if is_pack_state then
		restore_opened_booster(board_state)
		local has_cards = board_state.pack_cards and #board_state.pack_cards > 0
		if not opened_booster_center() and not has_cards then
			teardown_pack_fx()
			if SMODS then
				SMODS.OPENED_BOOSTER = nil
			end
			is_pack_state = false
			target_state = tonumber(board_state.pack_interrupt)
				or ((board_state.shop_cards and #board_state.shop_cards > 0) and G.STATES.SHOP)
				or G.STATES.BLIND_SELECT
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			clear_pack_return_latch()
		end
	end

	-- Snap G.hand to resting or round-play position before syncing hand cards
	if G.hand and G.hand.T and G.hand.VT and G.TILE_H and G.hand.T.h then
		local in_round = not G.deck_preview and (target_state == G.STATES.SELECTING_HAND or target_state == G.STATES.DRAW_TO_HAND)
		local desired_y = G.TILE_H - G.hand.T.h - 1.9 * (in_round and 1 or 0)
		G.hand.T.y = desired_y
		G.hand.VT.y = desired_y
	end

	if target_state then
		G.STATE = target_state
	end

	-- 4. Sync Hand Cards
	if G.hand and board_state.hand then
		rebuild_area_cards(G.hand, board_state.hand)
	end

	-- 5. Sync Blind (must be the target's identity before ROUND_EVAL rebuilds).
	-- set_blind queues HUD slide-in events; only do that while they are
	-- actually in a round. On blind select / shop, park the HUD like vanilla.
	if board_state.blind_on_deck then
		G.GAME.blind_on_deck = board_state.blind_on_deck
	end
	if is_playing_round_state(board_state.state) then
		restore_blind_from_snapshot(board_state.blind, board_state)
		if restoring_eval and G.GAME.blind then
			if eval_pre and eval_pre.blind_dollars ~= nil then
				G.GAME.blind.dollars = to_game_number(eval_pre.blind_dollars, G.GAME.blind.dollars)
			end
			if eval_pre and eval_pre.blind_chips ~= nil and eval_pre.blind_chips ~= 0 then
				G.GAME.blind.chips = to_game_number(eval_pre.blind_chips, G.GAME.blind.chips)
			end
			if eval_pre and eval_pre.chip_text and eval_pre.chip_text ~= "" and eval_pre.chip_text ~= "0" then
				G.GAME.blind.chip_text = eval_pre.chip_text
			end
			local is_pvp = (G.GAME.blind and (G.GAME.blind.pvp or G.GAME.blind.name == "bl_mp_nemesis"))
				or (MP.is_pvp_boss and MP.is_pvp_boss())
				or (MP.is_pvp and MP.is_pvp())
				or (MP.GAME and (MP.GAME.end_pvp or MP.GAME.pvp))
			if is_pvp and (not G.GAME.blind.chip_text or G.GAME.blind.chip_text == "" or G.GAME.blind.chip_text == "0") and MP.UI and MP.UI.get_pvp_score_to_beat then
				local score_int, score_text = MP.UI.get_pvp_score_to_beat()
				if score_text and score_text ~= "" and score_text ~= "0" then
					G.GAME.blind.chip_text = score_text
					if (not G.GAME.blind.chips or G.GAME.blind.chips == 0) and score_int then
						G.GAME.blind.chips = (MP.INSANE_INT and MP.INSANE_INT.to_safe_number(score_int)) or G.GAME.blind.chips
					elseif (not G.GAME.blind.chips or G.GAME.blind.chips == 0) and score_text then
						local num = tonumber((string.gsub(tostring(score_text), ",", "")))
						if num then G.GAME.blind.chips = num end
					end
				end
			end
		end
		local last = (eval_pre and {
			boss = eval_pre.last_blind_boss,
			name = eval_pre.last_blind_name,
		}) or board_state.last_blind
		if last then
			G.GAME.last_blind = {
				boss = not not last.boss,
				name = last.name,
			}
		end
	else
		park_blind_hud()
	end
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		pcall(MP.OPPONENTS.refresh_primary_enemy_view)
	end

	-- Pool/shop-roll inputs must land BEFORE the state UI transitions below:
	-- create_UIBox_shop sizes G.shop_jokers from G.GAME.shop.joker_max, so
	-- restoring inputs after the rebuild crams overstocked rows into a
	-- two-slot-wide area. Vanilla applies these values during start_run,
	-- long before any shop UI exists. The RNG state itself is restored
	-- AFTER those rebuilds (see restore_shop_pseudorandom).
	pcall(restore_shop_sim_inputs, board_state)

	-- 6. State UI Transition & Cleanup
	-- G.blind_select and G.blind_prompt_box are managed as a pair: vanilla
	-- indexes both whenever either exists, so they are only ever removed
	-- together.
	if not is_pack_state then
		teardown_pack_fx()
		if SMODS then
			SMODS.OPENED_BOOSTER = nil
		end
	end
	remove_ui_box_safely("deck_preview")

	if target_state then
		G.STATE = target_state
		if
			target_state == G.STATES.SELECTING_HAND
			or target_state == G.STATES.HAND_PLAYED
			or target_state == G.STATES.DRAW_TO_HAND
			or target_state == G.STATES.PLAY_TAROT
		then
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			remove_ui_box_safely("round_eval")
			if target_state == G.STATES.HAND_PLAYED or target_state == G.STATES.DRAW_TO_HAND then
				G.STATE = G.STATES.SELECTING_HAND
				G.STATE_COMPLETE = false
			end
		elseif target_state == G.STATES.BLIND_SELECT then
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			remove_ui_box_safely("round_eval")
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			-- Do not call update_blind_select here. Vanilla Game:update
			-- builds the overlay once when STATE_COMPLETE is false. Kicking
			-- it ourselves stacked with that update and with failed HUD
			-- majors that retry every tick.
			G.STATE_COMPLETE = false
		elseif target_state == G.STATES.SHOP then
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			remove_ui_box_safely("round_eval")
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			if G.update_shop then
				G.STATE_COMPLETE = false
				pcall(function()
					G:update_shop(0.016)
				end)
			end
		elseif is_pack_state then
			local interrupt = tonumber(board_state.pack_interrupt) or board_state.pack_interrupt
			if not interrupt then
				if board_state.shop_cards and #board_state.shop_cards > 0 then
					interrupt = G.STATES.SHOP
				else
					interrupt = G.STATES.BLIND_SELECT
				end
			end
			SPECTATOR.pack_interrupt = interrupt
			if board_state.shop_cards and #board_state.shop_cards > 0 then
				SPECTATOR.cached_pack_return_shop_cards = board_state.shop_cards
				SPECTATOR.cached_pack_return_round = board_state.round
			end
			remove_ui_box_safely("round_eval")
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			park_shop_for_pack()
			if G and G.GAME then
				G.GAME.PACK_INTERRUPT = interrupt
			end
			local pack_ok = rebuild_pack_ui(target_state, board_state)
			G.STATE = target_state
			G.STATE_COMPLETE = not not pack_ok
		elseif target_state == G.STATES.ROUND_EVAL or target_state == G.STATES.NEW_ROUND then
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			remove_ui_box_safely("deck_preview")
			remove_ui_box_safely("round_eval")
			SPECTATOR.eval_hold = true
			if target_state == G.STATES.ROUND_EVAL then
				rebuild_round_eval_ui()
			else
				G.STATE = G.STATES.BLIND_SELECT
				G.STATE_COMPLETE = true
			end
		end
	end

	-- 7. Stamp shop cards only onto an actual shop screen. Pack snapshots
	-- park the existing shop; blind select must never inherit shop_cards.
	if target_state == G.STATES.SHOP
		and board_state.shop_cards
		and #board_state.shop_cards > 0
	then
		apply_stream_shop(board_state.shop_cards, board_state.round)
	end

	-- 8. Deep state (only present in full snapshots)
	if board_state.deck and G.deck then
		rebuild_area_cards(G.deck, board_state.deck)
	end
	if board_state.discard and G.discard then
		rebuild_area_cards(G.discard, board_state.discard)
	end
	refresh_playing_cards()
	if board_state.vouchers_used then
		G.GAME.used_vouchers = board_state.vouchers_used
	end
	if board_state.used_packs and G.GAME.current_round then
		local used_packs = {}
		for pack_pos, pack_key in pairs(board_state.used_packs) do
			local pos = tonumber(pack_pos) or pack_pos
			used_packs[pos] = tostring(pack_key)
		end
		G.GAME.current_round.used_packs = used_packs
	end
	if board_state.joker_slots and G.jokers and G.jokers.config then
		G.jokers.config.card_limit = tonumber(board_state.joker_slots) or G.jokers.config.card_limit
	end
	if board_state.consumeable_slots and G.consumeables and G.consumeables.config then
		G.consumeables.config.card_limit = tonumber(board_state.consumeable_slots) or G.consumeables.config.card_limit
	end
	if G.hand and G.hand.config then
		apply_snapshot_hand_size(board_state)
		-- SMODS tracks hand limits in card_limits.old_slots / total_slots.
		-- A snapshot rebuild that only sets card_limit leaves old_slots nil,
		-- and Hanged Man's deletion then crashes handle_card_limit on
		-- `nil < number`. Ensure the table is coherent.
		if G.hand.config.card_limits then
			if G.hand.config.card_limits.total_slots == nil then
				G.hand.config.card_limits.total_slots = G.hand.config.card_limits.base or G.hand.config.card_limit or 8
			end
			if G.hand.config.card_limits.old_slots == nil then
				G.hand.config.card_limits.old_slots = G.hand.config.card_limits.total_slots
			end
		end
	end
	if G.jokers and G.jokers.config and G.jokers.config.card_limits and G.jokers.config.card_limits.old_slots == nil then
		G.jokers.config.card_limits.old_slots = G.jokers.config.card_limits.total_slots or G.jokers.config.card_limit
	end
	if G.consumeables and G.consumeables.config and G.consumeables.config.card_limits then
		if G.consumeables.config.card_limits.total_slots == nil or board_state.consumeable_slots ~= nil then
			G.consumeables.config.card_limits.total_slots = G.consumeables.config.card_limit or 2
		end
		if G.consumeables.config.card_limits.old_slots == nil or board_state.consumeable_slots ~= nil then
			G.consumeables.config.card_limits.old_slots = G.consumeables.config.card_limits.total_slots
		end
	end
	if board_state.round_special_cards and G.GAME and G.GAME.current_round then
		for k, v in pairs(board_state.round_special_cards) do
			G.GAME.current_round[k] = v
		end
	end

	-- 9. Recalculate HUD & Blind HUD
	if G.HUD and G.HUD.recalculate then
		G.HUD:recalculate()
	end
	if G.HUD_blind and G.HUD_blind.recalculate then
		G.HUD_blind:recalculate()
	end
	if target_state ~= G.STATES.ROUND_EVAL and MP.UI and MP.UI.update_blind_HUD then
		MP.UI.update_blind_HUD()
	end
	if should_show_blind_hud(target_state) then
		show_blind_hud_plaque()
	end
	if board_state.location and MP.GAME then
		MP.GAME.location = board_state.location
	end
	-- In a round the dollars/chips row is the score. Location belongs on
	-- shop / blind-select. Always showing location here is why PvP switches
	-- replaced the score with "Playing …".
	if should_show_blind_hud(target_state)
		or (G.STATES and (target_state == G.STATES.ROUND_EVAL or target_state == G.STATES.NEW_ROUND))
	then
		if MP.UI and MP.UI.hide_enemy_location then
			MP.UI.hide_enemy_location()
		end
	else
		if MP.UI and MP.UI.show_enemy_location then
			MP.UI.show_enemy_location()
		end
		if MP.UI and MP.UI.refresh_enemy_location_ui then
			pcall(MP.UI.refresh_enemy_location_ui)
		end
	end

	end)

	-- After the last clear_queue (round-eval rebuild), snap colours so a
	-- deleted ease cannot leave the previous boss room colour stuck.
	refresh_spectated_blind_backdrop(board_state.state or (G and G.STATE))

	if MP.UI and MP.UI.reapply_active_multiplayer_blind_ui then
		pcall(MP.UI.reapply_active_multiplayer_blind_ui)
	end

	SPECTATOR.current_step = board_state.step or SPECTATOR.current_step
	pcall(restore_shop_pseudorandom, board_state)
	if board_state.sort_id ~= nil then
		G.sort_id = tonumber(board_state.sort_id) or G.sort_id
	end
	SPECTATOR.shop_joker_queue = nil
	SPECTATOR.applying_snapshot = false

	if MP.TESTING and MP.TESTING.log_spectator then
		local h_count = (G and G.hand and G.hand.cards and #G.hand.cards) or 0
		local d_count = (G and G.deck and G.deck.cards and #G.deck.cards) or 0
		local disc_left = (G and G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left) or "?"
		MP.TESTING.log_spectator("SNAP", "applied", string.format("step=%s st=%s hand=%d deck=%d disc=%s",
			tostring(board_state.step or ""), tostring(board_state.state or ""),
			h_count, d_count, tostring(disc_left)))
	end
	if MP.SYNC and MP.SYNC.TEAM_CARD and MP.SYNC.TEAM_CARD.flush_startup_remote_changes then
		pcall(MP.SYNC.TEAM_CARD.flush_startup_remote_changes)
	end
	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.apply_snapshot_phantoms then
		pcall(MP.NETWORKING_INTERNAL.apply_snapshot_phantoms, board_state.phantoms)
	elseif MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.rebuild_spectator_phantoms then
		pcall(MP.NETWORKING_INTERNAL.rebuild_spectator_phantoms)
	end
	if SPECTATOR.is_catching_up then
		finish_catch_up()
	end
end

function SPECTATOR.handle_spectator_history(payload)
	if not payload then
		return
	end

	local previous_target = SPECTATOR.target_player_id
	if previous_target ~= payload.targetPlayerId then
		-- History for a different target: drop anything queued for the old
		-- one so no replay action crosses the switch.
		clear_pending_replay_state()
		SPECTATOR.current_step = 0
	end

	SPECTATOR.is_spectating = true
	SPECTATOR.target_player_id = payload.targetPlayerId

	local seed = payload.seed
	local stake = payload.stake or 1
	local back = payload.back or "Red Deck"
	local challenge = payload.challenge
	local sleeve = payload.sleeve
	local cocktail = payload.cocktail

	local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY
	local update = {
		back = back,
		stake = tostring(stake),
		challenge = challenge,
		sleeve = sleeve,
		cocktail = cocktail,
	}
	if lobby_domain and lobby_domain.apply_option_update then
		lobby_domain.apply_option_update(update)
	elseif lobby_domain and lobby_domain.update_run_deck then
		lobby_domain.update_run_deck(update)
	end
	if MP.UTILS and MP.UTILS.get_deck_key_from_name then
		local deck_key = MP.UTILS.get_deck_key_from_name(back)
		if deck_key and G and G.GAME then
			G.GAME["viewed_back"] = (G and G.P_CENTERS and G.P_CENTERS[deck_key] or nil)
		end
	end

	-- Snapshots are only for switching onto a player. watchTarget already
	-- put start_spectating into catch-up; do not request another because
	-- history arrived, a reroll happened, or a step was skipped.
	if G and G.STAGE == G.STAGES.RUN then
		if previous_target ~= payload.targetPlayerId and not SPECTATOR.is_catching_up then
			request_catch_up_snapshot(false)
		end
		return
	end

	-- Initial game startup when first joining a match
	if BALATRO.start_lobby_run then
		BALATRO.start_lobby_run({
			seed = seed,
			stake = stake,
		})
	end
end

function SPECTATOR.handle_spectator_action_stream(parsed_action)
	if not SPECTATOR.is_spectating then
		return
	end
	if parsed_action.playerId and parsed_action.playerId ~= SPECTATOR.target_player_id then
		return
	end

	local raw_data = parsed_action.actionData
	if not raw_data or raw_data == "" then
		return
	end

	local ok, action_obj = pcall(json.decode, raw_data)
	if not ok or not action_obj then
		return
	end

	local step = tonumber(action_obj.step or parsed_action.stepIndex)
	if step and step <= SPECTATOR.current_step then
		return
	end

	if SPECTATOR.is_catching_up then
		SPECTATOR.pending_actions[#SPECTATOR.pending_actions + 1] = action_obj
		return
	end

	local queue = SPECTATOR.pending_replay_queue or {}
	if #queue > 0 or sim_busy(action_obj.type) or (step and step > SPECTATOR.current_step + 1) then
		SPECTATOR.enqueue_replay_action(action_obj.type, action_obj.data, step)
		return
	end

	SPECTATOR.execute_action(action_obj)
end

function SPECTATOR.handle_spectator_receive_snapshot(payload)
	if not payload or not payload.snapshotData then
		return
	end
	if payload.targetPlayerId and payload.targetPlayerId ~= SPECTATOR.target_player_id then
		return
	end

	-- The run has not spawned yet (spectator still booting). Hold the
	-- snapshot; marking it applied here would discard the only catch-up
	-- board and leave us generating blind-select UI forever.
	if not (G and G.GAME and G.STAGE == G.STAGES.RUN) then
		SPECTATOR.pending_snapshot_payload = payload
		return
	end
	SPECTATOR.pending_snapshot_payload = nil

	local ok, board_state = pcall(json.decode, payload.snapshotData)
	if not (ok and board_state) then
		return
	end

	-- Applying a snapshot rebuilds the whole board; duplicates (server push
	-- racing a client request) and stale steps are dropped so a single
	-- switch applies exactly one snapshot.
	local snapshot_step = tonumber(board_state.step)
	local fingerprint = {
		target = tostring(payload.targetPlayerId or SPECTATOR.target_player_id),
		step = snapshot_step,
		len = #payload.snapshotData,
	}
	local last = SPECTATOR.last_applied_snapshot
	if last
		and last.target == fingerprint.target
		and last.step == fingerprint.step
		and last.len == fingerprint.len then
		return
	end
	if snapshot_step and snapshot_step < SPECTATOR.current_step then
		return
	end

	-- Discard invalid mid-animation snapshots (HAND_PLAYED or DRAW_TO_HAND)
	-- to prevent corrupting local state with missing/drawing cards.
	local raw_st = tonumber(board_state.state) or board_state.state
	if G and G.STATES and (raw_st == G.STATES.HAND_PLAYED or raw_st == G.STATES.DRAW_TO_HAND) then
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("SNAP", "reject_mid_anim", string.format("st=%s hand=%d",
				tostring(raw_st), (board_state.hand and #board_state.hand) or 0))
		end
		return
	end

	-- The snapshot is the target's authoritative post-action board, so any
	-- streamed action still waiting to become replayable is already baked
	-- into it; keeping them would only replay stale work on top.
	if SPECTATOR.pending_replay_queue and #SPECTATOR.pending_replay_queue > 0 then
		SPECTATOR.pending_replay_queue = {}
	end

	if MP.TESTING and MP.TESTING.log_spectator then
		local tgt_short = tostring(payload.targetPlayerId or SPECTATOR.target_player_id):sub(1, 8)
		local h_count = (board_state.hand and #board_state.hand) or 0
		local d_count = (board_state.deck and #board_state.deck) or 0
		local disc_left = board_state.discards_left or "?"
		MP.TESTING.log_spectator("SNAP", "recv", string.format("tgt=%s step=%s st=%s hand=%d deck=%d disc=%s",
			tgt_short, tostring(snapshot_step or ""), tostring(board_state.state or ""),
			h_count, d_count, tostring(disc_left)))
	end

	SPECTATOR.apply_live_board_state(board_state)
	SPECTATOR.last_applied_snapshot = fingerprint
end

function SPECTATOR.flush_pending_snapshot()
	local pending = SPECTATOR.pending_snapshot_payload
	if not pending then
		return
	end
	if not (G and G.GAME and G.STAGE == G.STAGES.RUN) then
		return
	end
	SPECTATOR.handle_spectator_receive_snapshot(pending)
end

-- Called from the spectator viewport update cycle: if the current target is
-- gone, eliminated, or disconnected, switch to the next spectatable player
-- (or stop spectating when nobody is left) instead of freezing on a dead
-- board.
function SPECTATOR.ensure_target_valid()
	if not (SPECTATOR.is_spectating and SPECTATOR.target_player_id and ((MP.LOBBY and MP.LOBBY.players) or (MP.GAME and MP.GAME.enemies))) then
		return
	end

	local target = nil
	if MP.LOBBY and MP.LOBBY.players then
		for _, player in ipairs(MP.LOBBY.players) do
			if player.id == SPECTATOR.target_player_id then
				target = player
				break
			end
		end
	end
	if not target and MP.GAME and MP.GAME.enemies then
		target = MP.GAME.enemies[SPECTATOR.target_player_id]
	end

	local reason = nil
	if not target then
		reason = "left"
	elseif target.is_disconnected then
		reason = "disconnected"
	else
		local enemy = MP.GAME and MP.GAME.enemies and MP.GAME.enemies[target.id]
		local lives = (enemy and enemy.lives ~= nil and enemy.lives) or target.lives
		if lives ~= nil and tonumber(lives) <= 0 then
			reason = "eliminated"
		end
	end
	if not reason then
		SPECTATOR.target_invalid_since = nil
		return
	end

	-- Lobby snapshots can briefly omit a player. Wait a beat before hopping
	-- so we do not A↔B snapshot-spam on a flicker.
	local now = os.clock()
	SPECTATOR.target_invalid_since = SPECTATOR.target_invalid_since or now
	if (now - SPECTATOR.target_invalid_since) < 1 then
		return
	end
	SPECTATOR.target_invalid_since = nil

	local spectatable = SPECTATOR.get_spectatable_players()
	local next_target = nil
	for _, candidate in ipairs(spectatable) do
		if candidate.id ~= SPECTATOR.target_player_id then
			next_target = candidate
			break
		end
	end

	if next_target then
		SPECTATOR.start_spectating(next_target.id, next_target.username)
	else
		SPECTATOR.stop_spectating()
	end
end

-- The watched match finished (server 'matchEnded'): leave the board and show
-- the end-game overlay, which offers Spectate-again and Return to Lobby.
function SPECTATOR.handle_match_ended()
	SPECTATOR.stop_spectating()
	if MP.NETWORKING_INTERNAL and MP.NETWORKING_INTERNAL.handle_match_ended_runtime then
		MP.NETWORKING_INTERNAL.handle_match_ended_runtime()
	end
end

return SPECTATOR
