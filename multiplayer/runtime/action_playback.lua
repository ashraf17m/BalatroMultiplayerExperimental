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
	local self_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
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
	local self_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil

	for _, player in ipairs(players) do
		local is_spec = (player.is_spectator or player.role == "spectator")
		if player.id ~= self_id and not is_spec and (player.lives == nil or tonumber(player.lives) > 0) then
			spectatable[#spectatable + 1] = player
		end
	end

	return spectatable
end

local function remove_ui_box_safely(box_field)
	if G and G[box_field] then
		pcall(function()
			G[box_field]:remove()
		end)
		G[box_field] = nil
	end
end

-- EventManager stores work in queues.base / unlock / etc. There is no
-- G.E_MANAGER.queue. Checking that made sim_busy always false and made us
-- think a blind-select build had finished when it was still in queues.base.
local function count_e_manager_events()
	local queues = G and G.E_MANAGER and G.E_MANAGER.queues
	if type(queues) ~= "table" then
		return 0, "no-queues"
	end
	local total = 0
	local parts = {}
	for name, q in pairs(queues) do
		local n = type(q) == "table" and #q or 0
		total = total + n
		if n > 0 then
			parts[#parts + 1] = tostring(name) .. "=" .. tostring(n)
		end
	end
	return total, (#parts > 0 and table.concat(parts, ",") or "empty")
end

local function spec_blind_log(event, detail, is_flaw)
	local msg = tostring(detail or "")
	if is_flaw and MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.flaw then
		MP.SPECTATOR_DIAG.flaw(event, msg)
	elseif MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.log then
		MP.SPECTATOR_DIAG.log(event, msg)
	end
	if MP.SPECTATOR_DIAG and MP.SPECTATOR_DIAG.flush_buffer then
		pcall(MP.SPECTATOR_DIAG.flush_buffer)
	end
	if MP.TESTING and MP.TESTING.log_spectator then
		MP.TESTING.log_spectator("BLIND", event, msg)
	else
		print("[SPEC BLIND] " .. tostring(event) .. " " .. msg)
	end
end

local function blind_select_debug_snapshot(reason)
	local state_name = "?"
	if G and G.STATE and G.STATES then
		for k, v in pairs(G.STATES) do
			if v == G.STATE then
				state_name = tostring(k)
				break
			end
		end
	end
	local n, parts = count_e_manager_events()
	local uiboxes = G and G.I and G.I.UIBOX and #G.I.UIBOX or 0
	return string.format(
		"%s state=%s complete=%s catchup=%s has_select=%s has_prompt=%s events=%d [%s] uiboxes=%d hud_row=%s",
		tostring(reason or ""),
		state_name,
		tostring(G and G.STATE_COMPLETE),
		tostring(SPECTATOR.is_catching_up),
		tostring(not not (G and G.blind_select)),
		tostring(not not (G and G.blind_prompt_box)),
		n,
		parts,
		uiboxes,
		tostring(G and G.HUD and G.HUD.get_UIE_by_ID and G.HUD:get_UIE_by_ID("row_blind") ~= nil)
	)
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

-- Must run after the last clear_queue on a switch. Vanilla eases from
-- G.GAME.blind.name; parking with set_blind(nil) is what drops the old boss.
local function refresh_spectated_blind_backdrop(state)
	remove_attention_texts()
	if ease_background_colour_blind then
		pcall(ease_background_colour_blind, state or (G and G.STATE))
	end
end

-- Removes every overlay surface that belongs to the spectated run so a
-- target switch (or stop) never leaves half-torn UI behind. G.blind_select
-- and G.blind_prompt_box are always removed as a pair: vanilla indexes both
-- whenever either exists.
local function teardown_spectated_overlays()
	if not G then
		return
	end
	remove_attention_texts()
	remove_ui_box_safely("booster_pack")
	remove_ui_box_safely("deck_preview")
	remove_ui_box_safely("round_eval")
	remove_ui_box_safely("shop")
	remove_ui_box_safely("SHOP_SIGN")
	remove_ui_box_safely("blind_select")
	remove_ui_box_safely("blind_prompt_box")
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

-- Mid-round draws/scores live in G.E_MANAGER. Switching targets without
-- clearing it lets the previous player's draw events keep firing into the
-- new board (wrong cards, RNG looking "broken").
local function clear_pending_game_events()
	if G and G.E_MANAGER and G.E_MANAGER.clear_queue then
		G.E_MANAGER:clear_queue()
	end
	if G and G.GAME then
		G.GAME.STOP_USE = 0
	end
end

local function is_playing_round_state(state)
	if not (G and G.STATES and state) then
		return false
	end
	return state == G.STATES.SELECTING_HAND
		or state == G.STATES.HAND_PLAYED
		or state == G.STATES.DRAW_TO_HAND
		or state == G.STATES.PLAY_TAROT
		or state == G.STATES.ROUND_EVAL
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
						spec_blind_log(
							"catchup_timeout",
							string.format("giving up after %ss, finishing with buffered actions", tostring(CATCH_UP_TIMEOUT)),
							true
						)
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
	spec_blind_log(
		"catchup_done",
		string.format("pending_actions=%d current_step=%s", #pending, tostring(SPECTATOR.current_step))
	)
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
	remove_ui_box_safely("booster_pack")
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

local WATCH_SWITCH_GAP = 0.55

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

	-- Rapid A↔B↔A switches each pulled a full snapshot. Keep the latest
	-- request and send one watch after the gap.
	local last = tonumber(SPECTATOR.last_watch_sent_at)
	if last and (os.clock() - last) < WATCH_SWITCH_GAP then
		SPECTATOR.queued_watch = {
			id = target_player_id,
			username = username or "Player",
		}
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
		-- If the previous target left us parked in a round-eval state, leave
		-- it quietly: vanilla must never rebuild the old cash-in screen over
		-- the new target's game, and no blind select is fabricated here —
		-- the incoming snapshot decides what is actually on screen.
		exit_round_eval_to_blind_select()
	end

	SPECTATOR.is_spectating = true
	SPECTATOR.hide_blind_loc_debuff = true
	SPECTATOR._blind_select_spawns = 0
	SPECTATOR._select_wait_logs = 0
	SPECTATOR.target_player_id = target_player_id
	SPECTATOR.target_username = username or "Player"
	SPECTATOR.current_step = 0
	SPECTATOR.last_watch_sent_at = os.clock()
	SPECTATOR.queued_watch = nil
	SPECTATOR.target_invalid_since = nil
	if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
		MP.SPECTATOR_LOG.emit("watch_start", {
			username = SPECTATOR.target_username,
		})
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

	-- Mid-run spectating: resync through a live snapshot from the target.
	-- The server pushes a snapshot request to the target on watchTarget, so
	-- no client-side request is needed here.
	if G and G.STAGE == G.STAGES.RUN then
		request_catch_up_snapshot(false)
	end

end

function SPECTATOR.stop_spectating()
	SPECTATOR.is_spectating = false
	SPECTATOR.hide_blind_loc_debuff = false
	SPECTATOR.applying_snapshot = false
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
	local card = Card(0, 0, card_w, card_h, p_card, use_center, extra)
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
	for i = #area.cards, 1, -1 do
		pcall(function()
			area.cards[i]:remove()
		end)
	end
	area.cards = {}
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
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("SHOP", "defer", "reroll queued after capture")
		end
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
	if MP.TESTING and MP.TESTING.log_spectator then
		local stamped_keys = {}
		for _, item in ipairs(packed.shop_jokers) do
			stamped_keys[#stamped_keys + 1] = tostring(item.key)
				.. (item.edition and ("+" .. tostring(item.edition)) or "")
		end
		MP.TESTING.log_spectator("SHOP", "stamp", string.format(
			"jokers=%d vouchers=%d boosters=%d [%s]",
			#packed.shop_jokers,
			#packed.shop_vouchers,
			#packed.shop_booster,
			table.concat(stamped_keys, ", ")
		))
	end
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
	local extra = tonumber(board_state.pack_size)
	if not extra or extra < 1 then
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
		local center = SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config and SMODS.OPENED_BOOSTER.config.center
		if center and center.create_UIBox then
			return function()
				return center:create_UIBox()
			end
		end
	end
	return nil
end

-- Rebuild the booster pack overlay from a snapshot: the pack UI (which also
-- recreates the G.pack_cards area) plus the target's real pack contents, so
-- switching to someone mid-pack shows their pack instead of a blank screen.
local function rebuild_pack_ui(state, board_state)
	if not (G and G.GAME) then
		return false
	end
	local builder = get_pack_ui_builder(state)
	if not builder then
		return false
	end

	remove_ui_box_safely("booster_pack")
	G.GAME.pack_size = tonumber(board_state.pack_size)
		or (board_state.pack_cards and #board_state.pack_cards)
		or 2
	G.GAME.pack_choices = tonumber(board_state.pack_choices) or 1

	local ok_def, definition = pcall(builder)
	if not (ok_def and definition) then
		return false
	end

	G.booster_pack = UIBox({
		definition = definition,
		config = {
			align = "tmi",
			offset = { x = 0, y = G.ROOM.T.y + 9 },
			major = G.hand,
			bond = "Weak",
		},
	})

	if board_state.pack_cards and G.pack_cards then
		rebuild_area_cards(G.pack_cards, board_state.pack_cards)
	end
	if ease_background_colour_blind then
		pcall(ease_background_colour_blind, state)
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
		SPECTATOR._select_wait_logs = 0
		return true
	end
	SPECTATOR._select_wait_logs = (SPECTATOR._select_wait_logs or 0) + 1
	local n = SPECTATOR._select_wait_logs
	if n <= 3 or n % 60 == 0 then
		spec_blind_log("select_wait", blind_select_debug_snapshot("waiting for vanilla UI #" .. tostring(n)))
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
	if not ensure_blind_select_ui_ready() then
		return false
	end

	local norm_key, norm_title = normalize_blind_row(data)
	local blind_def = resolve_blind_def(data, norm_key, norm_title)

	local box = (BALATRO.get_blind_select_option_box and (BALATRO.get_blind_select_option_box(norm_title) or BALATRO.get_blind_select_option_box(norm_key)))
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
			spec_blind_log("select_ok", blind_select_debug_snapshot("G.FUNCS.select_blind"))
			return true
		end
	end

	spec_blind_log("select_no_button", blind_select_debug_snapshot("UI up but no select_blind_button"))
	return false
end

function SPECTATOR.perform_skip_blind(data)
	if not (G and G.GAME) then return false end
	if not ensure_blind_select_ui_ready() then
		return false
	end

	local norm_key, norm_title = normalize_blind_row(data)

	local box = (BALATRO.get_blind_select_option_box and (BALATRO.get_blind_select_option_box(norm_title) or BALATRO.get_blind_select_option_box(norm_key)))
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
	if not (G and G.hand and G.hand.cards and #G.hand.cards > 0) then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("play_hand_fail", { reason = "empty_hand", cards = data and data.cards and #data.cards })
		end
		return false
	end
	if G.STATE ~= G.STATES.SELECTING_HAND then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("play_hand_fail", { reason = "wrong_state" })
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
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("play_hand_fail", {
				reason = "bad_indices",
				want = data and data.cards and table.concat(data.cards, ","),
			})
		end
		return false
	end

	if G.FUNCS and G.FUNCS.play_cards_from_highlighted then
		if invoke_g_func("play_cards_from_highlighted") then
			SPECTATOR.pending_play_hand = nil
			if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
				MP.SPECTATOR_LOG.emit("play_hand_ok")
			end
			return true
		end
	end
	if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
		MP.SPECTATOR_LOG.emit("play_hand_fail", { reason = "invoke_failed" })
	end
	return false
end

function SPECTATOR.perform_discard(data)
	if not (G and G.hand and G.hand.cards and #G.hand.cards > 0) then
		return false
	end
	if G.STATE ~= G.STATES.SELECTING_HAND then
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
		return false
	end

	if G.FUNCS and G.FUNCS.discard_cards_from_highlighted then
		return invoke_g_func("discard_cards_from_highlighted")
	end
	return false
end

function SPECTATOR.perform_cash_out()
	if not (G and G.GAME) then return false end
	-- Vanilla cash_out does everything inside `if G.round_eval then`; before
	-- the evaluation screen has materialized (it slides in via queued events)
	-- a replay would silently do nothing and burn the step, so wait for it.
	if not G.round_eval then
		return false
	end
	-- The Cash Out control is a delayed standalone UIBox major'd onto
	-- round_eval, not a child of G.round_eval. Look it up by id.
	local button = find_uie_by_id("cash_out_button", G.round_eval)
	if not button then
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
	if not index or index < 1 or index > #area.cards then
		return nil
	end
	local card = area.cards[index]
	if not card then
		return nil
	end
	if card_key and card_center_key(card) ~= card_key then
		return nil
	end
	return card
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

function SPECTATOR.perform_use_card(data)
	if not (G and G.GAME) then
		return false
	end
	local area = get_card_area_by_name((data and data.area) or "consumeables")
	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end

	local target_area_name = (data and data.target_area) or "hand"
	local target_area = get_card_area_by_name(target_area_name) or G.hand
	if target_area and data and data.target_indices and #data.target_indices > 0 then
		pcall(function()
			target_area:unhighlight_all()
		end)
		for _, idx in ipairs(data.target_indices) do
			local target_card = target_area.cards and target_area.cards[idx]
			if not target_card then
				return false
			end
			target_area:add_to_highlighted(target_card)
		end
		if not (target_area.highlighted and #target_area.highlighted == #data.target_indices) then
			return false
		end
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

function SPECTATOR.perform_buy_booster(data)
	if not (G and G.FUNCS and G.FUNCS.use_card) then
		return false
	end
	local area = get_card_area_by_name("shop_booster")
	local card = find_card_in_area(area, data and data.index, data and data.card_key)
	if not card then
		return false
	end
	return invoke_g_func("use_card", { config = { ref_table = card } })
end

function SPECTATOR.perform_select_pack_card(data)
	if not (G and G.FUNCS and G.FUNCS.use_card) then
		return false
	end
	local area = get_card_area_by_name("pack_cards")
	local card = find_card_in_area(area, (data and data.index) or 1, data and data.card_key)
	if not card then
		return false
	end
	return invoke_g_func("use_card", { config = { ref_table = card } })
end

function SPECTATOR.perform_skip_pack()
	if not (G and G.FUNCS and G.FUNCS.skip_booster) then
		return false
	end
	if not (G.booster_pack and not G.booster_pack.REMOVED) then
		return false
	end
	return invoke_g_func("skip_booster")
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
	area.cards = new_cards
	if area.realign_indices then
		pcall(area.realign_indices, area)
	end
	return true
end

function SPECTATOR.perform_team_card_sync(data)
	if MP.TESTING and MP.TESTING.log_team_card then
		MP.TESTING.log_team_card("STREAM", string.format(
			"%s %s from=%s",
			tostring(data and data.actionType or "?"),
			tostring(data and data.cardKey or "?"),
			tostring(data and data.sourcePlayerId or "?")
		))
	end
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
		local in_eval = G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND or G.round_eval ~= nil
		return not in_eval
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
local function sim_busy()
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
		spec_blind_log(
			"settle_timeout",
			string.format("forcing idle after %d ticks with %d events still queued", SPECTATOR._settle_ticks, n),
			true
		)
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
	if sim_busy() then
		return
	end
	local queue = SPECTATOR.pending_replay_queue
	if #queue == 0 then
		return
	end

	local entry = queue[1]
	if entry.target ~= SPECTATOR.target_player_id then
		table.remove(queue, 1)
		return
	end

	entry.attempts = entry.attempts + 1
	if entry.attempts > PENDING_MAX_ATTEMPTS then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("replay_drop_timeout", { type = entry.type, step = entry.step })
		end
		table.remove(queue, 1)
		return
	end

	local window_closed = ACTION_WINDOW_CLOSED[entry.type]
	if window_closed and window_closed() then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("replay_drop_window", { type = entry.type, step = entry.step })
		end
		table.remove(queue, 1)
		return
	end

	if not SPECTATOR.is_executing_action then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and (entry.type == "PLAY_HAND" or entry.type == "CASH_OUT") then
			MP.SPECTATOR_LOG.emit("replay_try", { type = entry.type, step = entry.step, attempts = entry.attempts })
		end
		local ok, result = pcall(SPECTATOR.perform_action, entry.type, entry.data)
		if ok and result == true then
			if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and (entry.type == "PLAY_HAND" or entry.type == "CASH_OUT") then
				MP.SPECTATOR_LOG.emit("replay_ok", { type = entry.type, step = entry.step })
			end
			table.remove(queue, 1)
		elseif MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and (entry.type == "PLAY_HAND" or entry.type == "CASH_OUT") then
			MP.SPECTATOR_LOG.emit("replay_retry", {
				type = entry.type,
				step = entry.step,
				ok = ok,
				result = tostring(result),
			})
		end
	end
end

function SPECTATOR.execute_action(action)
	if not action or type(action) ~= "table" then
		return
	end

	-- Same settle rule as the drain path (see sim_busy): commands queued by
	-- catch-up replay must not run against half-applied event chains.
	if sim_busy() then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and (action.type == "PLAY_HAND" or action.type == "CASH_OUT") then
			MP.SPECTATOR_LOG.emit("exec_busy_enqueue", { type = action.type, step = action.step })
		end
		SPECTATOR.enqueue_replay_action(action.type, action.data, tonumber(action.step))
		return
	end

	local step = tonumber(action.step)
	if step then
		if step <= SPECTATOR.current_step then
			if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and (action.type == "PLAY_HAND" or action.type == "CASH_OUT") then
				MP.SPECTATOR_LOG.emit("exec_skip_old_step", { type = action.type, step = step })
			end
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
	if action_type == "PLAY_HAND" or action_type == "CASH_OUT" or action_type == "SKIP_BLIND" or action_type == "SELECT_BLIND" then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("exec_result", {
				type = action_type,
				ok = ok,
				result = tostring(result),
				step = step,
			})
		end
	end
	if ok and result == false then
		SPECTATOR.enqueue_replay_action(action_type, data, step)
	end
	if MP.TESTING and MP.TESTING.RNG_TRACER and MP.TESTING.RNG_TRACER.active then
		local mods = G and G.GAME and G.GAME.modifiers
		MP.TESTING.RNG_TRACER.act("S", step, action_type, string.format(
			"res=%s stake=%s et=%s per=%s jr=%s tr=%s pr=%s sr=%s pcr=%s",
			tostring(result),
			tostring(G and G.GAME and G.GAME.stake),
			tostring(mods and mods.enable_eternals_in_shop),
			tostring(mods and mods.enable_perishables_in_shop),
			tostring(G and G.GAME and G.GAME.joker_rate),
			tostring(G and G.GAME and G.GAME.tarot_rate),
			tostring(G and G.GAME and G.GAME.planet_rate),
			tostring(G and G.GAME and G.GAME.spectral_rate),
			tostring(G and G.GAME and G.GAME.playing_card_rate)
		))
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

local function resolve_blind_def(blind_info, board_state)
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
	local def = resolve_blind_def(blind_info, board_state)
	if not G.GAME.blind and Blind then
		G.GAME.blind = Blind(0, 0, 2, 1)
	end
	if not G.GAME.blind then
		return
	end
	if def and G.GAME.blind.set_blind then
		SPECTATOR.hide_blind_loc_debuff = true
		G.GAME.blind:set_blind(def, nil, true)
	end
	if (not G.GAME.blind.chips or to_game_number(G.GAME.blind.chips, 0) == 0) and def and get_blind_amount then
		local ante = (G.GAME.round_resets and G.GAME.round_resets.ante) or 1
		local mult = def.mult or 1
		local scaling = (G.GAME.starting_params and G.GAME.starting_params.ante_scaling) or 1
		G.GAME.blind.chips = get_blind_amount(ante) * mult * scaling
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
	local snap_dollars = blind_info and tonumber(blind_info.dollars)
	if snap_dollars and snap_dollars > 0 then
		G.GAME.blind.dollars = snap_dollars
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
	return true
end

-- Comeback $ (Total Lives Lost / sandbox comeback money) is stored on
-- MP.GAME, not G.GAME. The spectator client's flags stay at the initial
-- "already given" state unless we copy the target's values before
-- Game:update_round_eval builds the cash-out rows.
--
-- Vanilla queues two events after the kick: one creates G.round_eval, the
-- next indexes it to slide the panel in. Removing the UIBox without
-- clearing that queue is game.lua:3534 (round_eval is nil).
local function rebuild_round_eval_ui()
	if not (G and G.update_round_eval) then
		return
	end
	clear_pending_game_events()
	remove_ui_box_safely("round_eval")
	if MP.GAME then
		MP.GAME.prevent_eval = false
	end
	G.STATE_COMPLETE = false
	pcall(function()
		G:update_round_eval(0.016)
	end)
end

function SPECTATOR.apply_comeback_state(data)
	if not (MP.GAME and data) then
		return
	end
	if data.lives ~= nil then
		MP.GAME.lives = tonumber(data.lives) or MP.GAME.lives
	end
	if data.comeback_bonus ~= nil then
		MP.GAME.comeback_bonus = tonumber(data.comeback_bonus) or 0
	end
	if data.round_failed ~= nil then
		MP.GAME.round_failed = not not data.round_failed
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
	local target_state = data.state
	local eval_state = G and G.STATES and (
		target_state == G.STATES.ROUND_EVAL or target_state == G.STATES.NEW_ROUND
	)
	if pending and (eval_state or data.comeback_bonus_given == false) then
		MP.GAME.comeback_bonus_given = false
	elseif data.comeback_bonus_given ~= nil then
		MP.GAME.comeback_bonus_given = not not data.comeback_bonus_given
	end
end

-- Copy the watched player's lives onto the spectated board. A drop is a
-- life loss on their client (PvP or otherwise) and must arm comeback gold
-- the same way apply_local_player_info does, or evaluate_round never draws
-- the "Total Lives Lost" row.
function SPECTATOR.sync_watched_player_lives()
	if not (SPECTATOR.is_spectating and SPECTATOR.target_player_id and MP.GAME) then
		return false
	end
	local target = nil
	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player.id == SPECTATOR.target_player_id then
			target = player
			break
		end
	end
	if not target or target.lives == nil then
		return false
	end
	local new_lives = tonumber(target.lives)
	if new_lives == nil then
		return false
	end
	local prev = tonumber(MP.GAME.lives)
	local armed_comeback = false
	if prev ~= nil and new_lives < prev then
		if MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.gold_on_life_loss then
			MP.GAME.comeback_bonus_given = false
			MP.GAME.comeback_eval_pending = true
			MP.GAME.comeback_bonus = (tonumber(MP.GAME.comeback_bonus) or 0) + (prev - new_lives)
			armed_comeback = true
		end
	end
	if MP.GAME.lives ~= new_lives then
		MP.GAME.lives = new_lives
		if MP.UI and MP.UI.refresh_lives_hud_binding then
			MP.UI.refresh_lives_hud_binding({ recalculate = true })
		end
	end
	if armed_comeback and G and G.STATES and (
		G.STATE == G.STATES.ROUND_EVAL or G.STATE == G.STATES.NEW_ROUND or G.round_eval
	) then
		rebuild_round_eval_ui()
	end
	return armed_comeback
end

function SPECTATOR.apply_live_board_state(board_state)
	if not board_state or not G or not G.GAME then
		return
	end

	SPECTATOR.applying_snapshot = true
	SPECTATOR.hide_blind_loc_debuff = true

	pcall(function()

	clear_pending_game_events()
	reset_inherited_round_latch()

	-- Only an eval-state snapshot (handled in step 6 below) keeps the hold.
	SPECTATOR.eval_hold = false

	-- 1. Sync Game Values & HUD
	G.GAME.dollars = to_game_number(board_state.dollars, G.GAME.dollars)
	G.GAME.chips = to_game_number(board_state.chips, G.GAME.chips)
	SPECTATOR.apply_comeback_state(board_state)
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
	end
	if G.GAME.round_resets then
		G.GAME.round_resets.ante = tonumber(board_state.ante) or G.GAME.round_resets.ante
		if board_state.blind_choices then
			G.GAME.round_resets.blind_choices = board_state.blind_choices
		end
		if board_state.pvp_blind_choices then
			G.GAME.round_resets.pvp_blind_choices = board_state.pvp_blind_choices
		end
		if board_state.blind_states then
			G.GAME.round_resets.blind_states = board_state.blind_states
		end
	end

	-- 2. Sync Jokers (cleanly remove old cards and instantiate player's exact cards)
	if G.jokers and board_state.jokers then
		for i = #G.jokers.cards, 1, -1 do
			local c = G.jokers.cards[i]
			c:remove()
		end
		G.jokers.cards = {}
		for _, j_info in ipairs(board_state.jokers) do
			if j_info.key and G.P_CENTERS[j_info.key] then
				local empty_card = (G.P_CARDS and G.P_CARDS.empty) or {}
				local card = Card(G.jokers.T.x, G.jokers.T.y, G.CARD_W, G.CARD_H, empty_card, G.P_CENTERS[j_info.key])
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
		G.jokers:align_cards()
		G.jokers:hard_set_cards()
	end

	-- 3. Sync Consumables
	if G.consumeables and board_state.consumeables then
		for i = #G.consumeables.cards, 1, -1 do
			local c = G.consumeables.cards[i]
			c:remove()
		end
		G.consumeables.cards = {}
		local consumable_keys = {}
		for _, c_info in ipairs(board_state.consumeables) do
			if c_info.key and G.P_CENTERS[c_info.key] then
				local empty_card = (G.P_CARDS and G.P_CARDS.empty) or {}
				local card = Card(G.consumeables.T.x, G.consumeables.T.y, G.CARD_W, G.CARD_H, empty_card, G.P_CENTERS[c_info.key])
				if c_info.edition then card:set_edition(c_info.edition, true) end
				G.consumeables:emplace(card)
				consumable_keys[#consumable_keys + 1] = tostring(c_info.key)
					.. (c_info.edition and ("+" .. tostring(c_info.edition)) or "")
			end
		end
		G.consumeables:align_cards()
		G.consumeables:hard_set_cards()
		if MP.TESTING and MP.TESTING.log_spectator then
			MP.TESTING.log_spectator("CONSUMABLES", "stamp", string.format(
				"count=%d [%s]",
				#consumable_keys,
				table.concat(consumable_keys, ", ")
			))
		end
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
	else
		park_blind_hud()
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
	local target_state = board_state.state
	if target_state and G.STATES and target_state == G.STATES.SMODS_BOOSTER_OPENED then
		restore_opened_booster(board_state)
	end
	local is_pack_state = get_pack_ui_builder(target_state) ~= nil

	if not is_pack_state then
		remove_ui_box_safely("booster_pack")
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
			spec_blind_log("snap_leave_select", blind_select_debug_snapshot("snapshot BLIND_SELECT, wait for vanilla"))
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
			-- Target is mid-pack: rebuild their pack overlay with their real
			-- contents instead of leaving a blank pack state.
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			remove_ui_box_safely("round_eval")
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			rebuild_pack_ui(target_state, board_state)
			-- update_pack / update_*_pack would spawn a second overlay if
			-- STATE_COMPLETE is still false after we already built one.
			G.STATE_COMPLETE = true
		elseif target_state == G.STATES.ROUND_EVAL or target_state == G.STATES.NEW_ROUND then
			remove_ui_box_safely("blind_select")
			remove_ui_box_safely("blind_prompt_box")
			remove_ui_box_safely("shop")
			remove_ui_box_safely("SHOP_SIGN")
			remove_ui_box_safely("booster_pack")
			remove_ui_box_safely("deck_preview")
			remove_ui_box_safely("round_eval")
			SPECTATOR.eval_hold = true
			if target_state == G.STATES.ROUND_EVAL then
				-- Same kick as shop / blind select: vanilla only builds the
				-- cash-out rows from Game:update_round_eval when
				-- STATE_COMPLETE is false. The MP prevent_eval latch would
				-- skip that after the first eval this client ever saw.
				rebuild_round_eval_ui()
				park_blind_hud()
			else
				G.STATE = G.STATES.BLIND_SELECT
				G.STATE_COMPLETE = true
			end
		end
	end

	-- 7. On a switch snapshot only: place the captured shop through vanilla
	-- constructors. Live cash-out / reroll roll their own shop from the seed.
	if board_state.shop_cards and #board_state.shop_cards > 0 then
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
	if board_state.tags then
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
		G.GAME.tags = G.GAME.tags or {}
		for _, tag_info in ipairs(board_state.tags) do
			if tag_info and tag_info.key then
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
	if board_state.vouchers_used then
		G.GAME.used_vouchers = board_state.vouchers_used
	end
	if board_state.used_packs and G.GAME.current_round then
		local used_packs = {}
		for pack_pos, pack_key in pairs(board_state.used_packs) do
			used_packs[tostring(pack_pos)] = tostring(pack_key)
		end
		G.GAME.current_round.used_packs = used_packs
	end
	if board_state.joker_slots and G.jokers and G.jokers.config then
		G.jokers.config.card_limit = tonumber(board_state.joker_slots) or G.jokers.config.card_limit
	end
	if G.hand and G.hand.config then
		if board_state.hand_size then
			G.hand.config.card_limit = tonumber(board_state.hand_size) or G.hand.config.card_limit
		end
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
	if G.consumeables and G.consumeables.config and G.consumeables.config.card_limits and G.consumeables.config.card_limits.old_slots == nil then
		G.consumeables.config.card_limits.old_slots = G.consumeables.config.card_limits.total_slots or G.consumeables.config.card_limit
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
	if board_state.location and MP.GAME then
		MP.GAME.location = board_state.location
		local location_kind = tostring(board_state.location):match("^([^-]+)") or board_state.location
		if location_kind == "loc_playing" then
			if MP.UI and MP.UI.hide_enemy_location then
				MP.UI.hide_enemy_location()
			end
		elseif MP.UI and MP.UI.show_enemy_location then
			MP.UI.show_enemy_location()
		end
	end

	end)

	-- After the last clear_queue (round-eval rebuild), snap colours so a
	-- deleted ease cannot leave the previous boss room colour stuck.
	refresh_spectated_blind_backdrop(board_state.state or (G and G.STATE))

	SPECTATOR.current_step = board_state.step or SPECTATOR.current_step
	pcall(restore_shop_pseudorandom, board_state)
	SPECTATOR.shop_joker_queue = nil
	SPECTATOR.applying_snapshot = false
	if MP.SYNC and MP.SYNC.TEAM_CARD and MP.SYNC.TEAM_CARD.flush_startup_remote_changes then
		pcall(MP.SYNC.TEAM_CARD.flush_startup_remote_changes)
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
	SPECTATOR.hide_blind_loc_debuff = true
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
	if BALATRO.set_game_value and MP.UTILS and MP.UTILS.get_deck_key_from_name then
		local deck_key = MP.UTILS.get_deck_key_from_name(back)
		if deck_key and BALATRO.get_center then
			BALATRO.set_game_value("viewed_back", BALATRO.get_center(deck_key))
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
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and action_obj.type == "PLAY_HAND" then
			MP.SPECTATOR_LOG.emit("stream_drop_old_step", { type = action_obj.type, step = step })
		end
		return
	end

	if SPECTATOR.is_catching_up then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit and action_obj.type == "PLAY_HAND" then
			MP.SPECTATOR_LOG.emit("stream_buffer_catchup", { type = action_obj.type, step = step })
		end
		SPECTATOR.pending_actions[#SPECTATOR.pending_actions + 1] = action_obj
		return
	end

	if step and step > SPECTATOR.current_step + 1 then
		-- A dropped packet desyncs the sim. Do not snapshot because a step
		-- was skipped — snapshots are only for switching targets.
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
		SPECTATOR._snap_hold_logs = (SPECTATOR._snap_hold_logs or 0) + 1
		local n = SPECTATOR._snap_hold_logs
		if n <= 3 or n % 30 == 0 then
			spec_blind_log("snap_hold", "run not ready, holding snapshot #" .. tostring(n))
		end
		SPECTATOR.pending_snapshot_payload = payload
		return
	end
	SPECTATOR._snap_hold_logs = 0
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
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("snap_reject_dup", { snap_step = snapshot_step })
		end
		return
	end
	if snapshot_step and snapshot_step < SPECTATOR.current_step then
		if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
			MP.SPECTATOR_LOG.emit("snap_reject_stale", { snap_step = snapshot_step })
		end
		return
	end

	if MP.TESTING and MP.TESTING.RNG_TRACER then
		local mods = G and G.GAME and G.GAME.modifiers
		MP.TESTING.RNG_TRACER.act("S", snapshot_step, "SNAPSHOT_APPLY", string.format(
			"tgt=%s stake=%s et=%s per=%s jr=%s tr=%s pr=%s sr=%s pcr=%s",
			tostring(payload.targetPlayerId):sub(1, 8),
			tostring(G and G.GAME and G.GAME.stake),
			tostring(mods and mods.enable_eternals_in_shop),
			tostring(mods and mods.enable_perishables_in_shop),
			tostring(G and G.GAME and G.GAME.joker_rate),
			tostring(G and G.GAME and G.GAME.tarot_rate),
			tostring(G and G.GAME and G.GAME.planet_rate),
			tostring(G and G.GAME and G.GAME.spectral_rate),
			tostring(G and G.GAME and G.GAME.playing_card_rate)
		))
	end

	if MP.TESTING and MP.TESTING.log_spectator then
		MP.TESTING.log_spectator("SNAP", "apply", string.format(
			"target=%s step=%s shop_cards=%d",
			tostring(payload.targetPlayerId):sub(1, 8),
			tostring(snapshot_step),
			board_state.shop_cards and #board_state.shop_cards or 0
		))
	end

	-- The snapshot is the target's authoritative post-action board, so any
	-- streamed action still waiting to become replayable is already baked
	-- into it; keeping them would only replay stale work on top.
	if SPECTATOR.pending_replay_queue and #SPECTATOR.pending_replay_queue > 0 then
		SPECTATOR.pending_replay_queue = {}
	end

	SPECTATOR.apply_live_board_state(board_state)
	SPECTATOR.last_applied_snapshot = fingerprint
	spec_blind_log("snap_apply", blind_select_debug_snapshot("step=" .. tostring(snapshot_step)))
	if MP.SPECTATOR_LOG and MP.SPECTATOR_LOG.emit then
		MP.SPECTATOR_LOG.emit("snap_applied", {
			snap_step = snapshot_step,
			snap_state = board_state.state,
			snap_hands = board_state.hands_left,
		})
	end
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
	if not (SPECTATOR.is_spectating and SPECTATOR.target_player_id and MP.LOBBY and MP.LOBBY.players) then
		return
	end

	local target = nil
	for _, player in ipairs(MP.LOBBY.players) do
		if player.id == SPECTATOR.target_player_id then
			target = player
			break
		end
	end

	local reason = nil
	if not target then
		reason = "left"
	elseif target.is_disconnected then
		reason = "disconnected"
	elseif target.lives ~= nil and tonumber(target.lives) <= 0 then
		reason = "eliminated"
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
