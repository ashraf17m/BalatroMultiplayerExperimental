-- Consolidated end_game_runtime.lua
-- Combines end_game_view_runtime.lua and end_game_message_runtime.lua

MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}
MP.END_GAME_VIEW = MP.END_GAME_VIEW or {}

local end_game_view_runtime = MP.END_GAME_VIEW
local end_game_message_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

-- ==========================================================================
-- Section 1: End Game View Runtime & Cache State
-- ==========================================================================

local END_GAME_REQUEST_STATES = {
	jokers = {
		cache_payload_key = "end_game_jokers_payload",
		cache_received_key = "end_game_jokers_received",
		cache_requested_key = "end_game_jokers_requested",
		error_key = "end_game_jokers_error_message",
		runtime_payload_key = "jokers_payload",
		runtime_received_key = "jokers_received",
		runtime_pending_key = "pending_end_game_jokers_target_id",
		load_ui_function = "load_end_game_jokers",
		request_action = "get_end_game_jokers",
	},
	deck = {
		cache_payload_key = "nemesis_deck_string",
		cache_received_key = "nemesis_deck_received",
		cache_requested_key = "nemesis_deck_requested",
		error_key = "nemesis_deck_error_message",
		runtime_payload_key = "nemesis_deck_string",
		runtime_received_key = "nemesis_deck_received",
		runtime_pending_key = "pending_nemesis_deck_target_id",
		load_ui_function = "load_nemesis_deck",
		request_action = "get_nemesis_deck",
	},
	summary = {
		cache_payload_key = "end_game_summary_payload",
		cache_received_key = "end_game_summary_received",
		cache_requested_key = "end_game_summary_requested",
		error_key = "end_game_summary_error_message",
		runtime_payload_key = "summary_payload",
		runtime_received_key = "summary_received",
		runtime_pending_key = "pending_end_game_summary_target_id",
		load_ui_function = "load_end_game_summary",
		request_action = "get_end_game_summary",
	},
}

local END_GAME_DOMAIN_METHODS = {
	"ensure_view_state",
	"reset_view_state",
	"get_viewable_players",
	"get_self_player",
	"get_standings_participants",
	"capture_view_players",
	"resolve_view_target",
	"select_view_target",
}

local TARGET_LABEL_FALLBACKS = {
	self = {
		jokers = "Your Jokers",
		deck = "Your Deck",
	},
	enemy = {
		jokers = "Enemy Jokers",
		deck = "Enemy Deck",
	},
	teammate = {
		jokers = "Teammate Jokers",
		deck = "Teammate Deck",
	},
	player = {
		jokers = "Player Jokers",
		deck = "Player Deck",
	},
}

local end_game_domain = MP.UTILS.load_required_domain(
	"END_GAME",
	END_GAME_DOMAIN_METHODS,
	"multiplayer/domain/end_game.lua",
	"Multiplayer end-game domain is missing."
)
if not end_game_domain then
	return nil
end

local function reset_end_game_request_runtime_state(runtime)
	for _, state in pairs(END_GAME_REQUEST_STATES) do
		runtime[state.runtime_payload_key] = ""
		runtime[state.runtime_received_key] = false
		runtime[state.runtime_pending_key] = nil
		runtime[state.error_key] = nil
	end
end

local function get_current_end_game_lobby_code()
	local code = MP.LOBBY and MP.LOBBY.code or nil
	if type(code) == "string" then
		return code
	end
	if code ~= nil then
		return tostring(code)
	end
	return ""
end

local function build_end_game_view_cache()
	local cache = {
		lobby_code = get_current_end_game_lobby_code(),
	}
	for _, state in pairs(END_GAME_REQUEST_STATES) do
		cache[state.cache_payload_key] = ""
		cache[state.cache_received_key] = false
		cache[state.cache_requested_key] = false
		cache[state.error_key] = nil
	end
	return cache
end

local function is_end_game_cache_for_current_lobby(cache)
	if type(cache) ~= "table" then
		return false
	end
	return cache.lobby_code == get_current_end_game_lobby_code()
end

local function load_end_game_request_cache(end_game_view, cache)
	for _, state in pairs(END_GAME_REQUEST_STATES) do
		end_game_view[state.runtime_payload_key] = cache and cache[state.cache_payload_key] or ""
		end_game_view[state.runtime_received_key] = cache and cache[state.cache_received_key] or false
		end_game_view[state.error_key] = cache and cache[state.error_key] or nil
	end
end

local function sync_end_game_view_domain_state(runtime)
	local view_state = end_game_domain.ensure_view_state()
	runtime.players = view_state.players
	runtime.self_player = view_state.self_player
	runtime.standings_participants = view_state.standings_participants
	runtime.target_id = view_state.target_id
	runtime.target_index = view_state.target_index or 1
	return runtime
end

local function get_snapshot_player_by_id(players, player_id)
	for _, player in ipairs(players or {}) do
		if player.id == player_id then
			return player
		end
	end
	return nil
end

local function get_runtime_target_player(runtime)
	local target_id = runtime and runtime.target_id or nil
	if not target_id then
		return nil
	end

	local lobby_player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(target_id) or nil
	return lobby_player or get_snapshot_player_by_id(runtime.players, target_id)
end

local function get_view_target_relation(target)
	if not target then
		return "player"
	end

	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	if self_player and target.id == self_player.id then
		return "self"
	end

	if self_player and MP.lobby_players_share_sync_group and MP.lobby_players_share_sync_group(self_player, target) then
		return "teammate"
	end

	return "enemy"
end

local function localize_or_fallback(key, fallback)
	if type(localize) ~= "function" then
		return fallback
	end

	local ok, value = pcall(localize, key)
	if not ok or type(value) ~= "string" or value == "" or value == key or string.find(value, "ERROR") then
		return fallback
	end

	return value
end

local function localize_hand_or_fallback(hand_key)
	if type(hand_key) ~= "string" or hand_key == "" then
		return localize_or_fallback("k_none", "None")
	end
	if type(localize) ~= "function" then
		return hand_key
	end

	local ok, value = pcall(localize, hand_key, "poker_hands")
	if not ok or type(value) ~= "string" or value == "" or value == hand_key or string.find(value, "ERROR") then
		return hand_key
	end

	return value
end

local function safe_number(value, fallback)
	value = tonumber(value)
	if value == nil then return fallback or 0 end
	return value
end

local function format_summary_number(value)
	return number_format(safe_number(value, 0))
end

local function format_summary_score(value)
	if value == nil or value == "" then
		return "0"
	end
	local number = tonumber(value)
	if number ~= nil then
		return number_format(number)
	end
	return tostring(value)
end

local function format_summary_money(value)
	return localize("$") .. number_format(safe_number(value, 0))
end

local function copy_array_into(target, source)
	for i = #target, 1, -1 do
		target[i] = nil
	end
	for _, value in ipairs(source or {}) do
		target[#target + 1] = value
	end
end

local function build_end_game_summary_display()
	return {
		hand = "0",
		poker_hand = localize_or_fallback("k_none", "None") .. " (0)",
		cards_purchased = "0",
		vouchers_bought_count = "0",
		times_rerolled = "0",
		furthest_ante = "0",
		furthest_round = "0",
		total_money_spent = format_summary_money(0),
		reroll_money_spent = format_summary_money(0),
		seed = "",
		seeded = false,
		vouchers_bought = {},
	}
end

local function reset_end_game_summary_display(display)
	local fresh = build_end_game_summary_display()
	display = display or {}
	display.vouchers_bought = display.vouchers_bought or {}

	for key in pairs(display) do
		if key ~= "vouchers_bought" then
			display[key] = nil
		end
	end

	for key, value in pairs(fresh) do
		if key == "vouchers_bought" then
			copy_array_into(display.vouchers_bought, value)
		else
			display[key] = value
		end
	end

	return display
end

local function apply_summary_to_display(display, summary)
	display = display or build_end_game_summary_display()
	summary = type(summary) == "table" and summary or {}

	local poker_hand_count = safe_number(summary.poker_hand_count, 0)
	display.hand = format_summary_score(summary.hand)
	display.poker_hand = localize_hand_or_fallback(summary.poker_hand) .. " (" .. number_format(poker_hand_count) .. ")"
	display.cards_purchased = format_summary_number(summary.cards_purchased)
	display.times_rerolled = format_summary_number(summary.times_rerolled)
	display.furthest_ante = format_summary_number(summary.furthest_ante)
	display.furthest_round = format_summary_number(summary.furthest_round)
	display.total_money_spent = format_summary_money(summary.total_money_spent)
	display.reroll_money_spent = format_summary_money(summary.reroll_cost_total)
	display.seed = tostring(summary.seed or "")
	display.seeded = summary.seeded == true
	copy_array_into(display.vouchers_bought, summary.vouchers_bought)
	display.vouchers_bought_count = number_format(#display.vouchers_bought)

	return display
end

local function get_view_target_label(noun, target)
	local relation = get_view_target_relation(target)
	local fallback = (TARGET_LABEL_FALLBACKS[relation] and TARGET_LABEL_FALLBACKS[relation][noun])
		or (TARGET_LABEL_FALLBACKS.player and TARGET_LABEL_FALLBACKS.player[noun])
		or "Player"
	return localize_or_fallback("k_" .. relation .. "_" .. noun, fallback)
end

local function reset_end_game_view_local_state(runtime, options)
	options = options or {}
	local preserved_cache = options.preserve_cache == true and runtime.cache or nil
	runtime.cache = preserved_cache or {}
	runtime.jokers_area = nil
	runtime.nemesis_deck_card_count = 0
	runtime.summary = nil
	runtime.summary_display = reset_end_game_summary_display(runtime.summary_display)
	runtime.last_summary_refresh_at = nil
	runtime.loaded_target_id = nil
	runtime.prefetch_started = false
	runtime.jokers_text = ""
	runtime.showing_own_jokers = false
	reset_end_game_request_runtime_state(runtime)
	return runtime
end

local function build_end_game_view_runtime()
	return reset_end_game_view_local_state({
		players = nil,
		self_player = nil,
		standings_participants = nil,
		target_id = nil,
		target_index = 1,
	})
end

function end_game_view_runtime.get_end_game_view_runtime()
	local runtime = MP.UI.get_runtime_store()
	runtime.end_game_view = runtime.end_game_view or build_end_game_view_runtime()
	return sync_end_game_view_domain_state(runtime.end_game_view)
end

function end_game_view_runtime.reset_end_game_view_runtime(options)
	if type(options) ~= "table" then
		options = nil
	end
	local runtime = end_game_view_runtime.get_end_game_view_runtime()
	end_game_domain.reset_view_state()
	sync_end_game_view_domain_state(runtime)
	return reset_end_game_view_local_state(runtime, options)
end

function end_game_view_runtime.get_viewable_players()
	return end_game_domain.get_viewable_players(
		MP.LOBBY and MP.LOBBY.players or nil,
		(G and G.MP_ID or nil)
	)
end

function end_game_view_runtime.get_end_game_self_player()
	return end_game_domain.get_self_player(
		MP.LOBBY and MP.LOBBY.players or nil,
		(G and G.MP_ID or nil)
	)
end

function end_game_view_runtime.get_end_game_standings_participants()
	return end_game_domain.get_standings_participants()
end

function end_game_view_runtime.capture_end_game_view_players()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local standings_players = MP.UI.get_live_match_standings_players
		and MP.UI.get_live_match_standings_players()
		or {}
	local snapshot = end_game_domain.capture_view_players(
		(MP.LOBBY and MP.LOBBY.players) or {},
		(G and G.MP_ID or nil),
		standings_players
	)
	sync_end_game_view_domain_state(end_game_view)

	return snapshot
end

function end_game_view_runtime.get_view_target_state()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local players, target, target_index = end_game_domain.resolve_view_target(
		MP.LOBBY and MP.LOBBY.players or nil,
		(G and G.MP_ID or nil)
	)
	sync_end_game_view_domain_state(end_game_view)

	return players, target, target_index
end

function end_game_view_runtime.get_target_jokers_label(target)
	local runtime = end_game_view_runtime.get_end_game_view_runtime()
	return get_view_target_label("jokers", target or get_runtime_target_player(runtime))
end

function end_game_view_runtime.get_target_deck_label(target)
	local runtime = end_game_view_runtime.get_end_game_view_runtime()
	return get_view_target_label("deck", target or get_runtime_target_player(runtime))
end

function end_game_view_runtime.apply_end_game_summary(summary, target_id)
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	if target_id and end_game_view.target_id and target_id ~= end_game_view.target_id then
		return false
	end

	end_game_view.summary = type(summary) == "table" and summary or {}
	apply_summary_to_display(end_game_view.summary_display, end_game_view.summary)
	trace_runtime_event("end_game.summary_display_applied", {
		target_id = target_id or end_game_view.target_id,
		has_summary = type(summary) == "table",
	})
	return true
end

function end_game_view_runtime.get_end_game_view_cache(target_id)
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	if not target_id then return nil end
	local existing = end_game_view.cache[target_id]
	if existing and not is_end_game_cache_for_current_lobby(existing) then
		end_game_view.cache[target_id] = nil
		existing = nil
	end
	if not existing then
		end_game_view.cache[target_id] = build_end_game_view_cache()
	end
	return end_game_view.cache[target_id]
end

function end_game_view_runtime.load_end_game_view_cache(target_id)
	local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	load_end_game_request_cache(end_game_view, cache)
end

function end_game_view_runtime.clear_end_game_view_request_error(target_id, request_kind)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not state or not target_id then
		return false
	end

	local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	if cache then
		cache[state.error_key] = nil
	end
	if end_game_view.target_id == target_id then
		end_game_view[state.error_key] = nil
	end

	return true
end

function end_game_view_runtime.fail_end_game_view_request(target_id, request_kind, message)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not state or not target_id then
		return false
	end
	trace_runtime_event("end_game.request_failed", {
		target_id = target_id,
		request_kind = request_kind,
		message = message,
	})

	local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()

	if cache then
		cache[state.cache_payload_key] = ""
		cache[state.cache_received_key] = false
		cache[state.cache_requested_key] = false
		cache[state.error_key] = message
	end

	if end_game_view[state.runtime_pending_key] == target_id then
		end_game_view[state.runtime_pending_key] = nil
	end

	if end_game_view.target_id == target_id then
		end_game_view[state.runtime_payload_key] = ""
		end_game_view[state.runtime_received_key] = false
		end_game_view[state.error_key] = message
	end

	return true
end

function end_game_view_runtime.resolve_end_game_view_response_target(request_kind, source_player_id)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not state then
		return nil, nil, nil
	end

	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local target_id = source_player_id
		or end_game_view[state.runtime_pending_key]
		or end_game_view.target_id

	return target_id, end_game_view, state
end

function end_game_view_runtime.apply_end_game_view_response(target_id, request_kind, payload, source_player_id)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not state or not target_id then
		trace_runtime_event("end_game.response_rejected", {
			target_id = target_id,
			request_kind = request_kind,
			source_player_id = source_player_id,
			reason = "invalid_target_or_kind",
		})
		return false, false, nil
	end

	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
	if cache then
		cache[state.cache_payload_key] = payload
		cache[state.cache_received_key] = true
		cache[state.cache_requested_key] = false
		cache[state.error_key] = nil
	end

	if end_game_view[state.runtime_pending_key] == target_id then
		end_game_view[state.runtime_pending_key] = nil
	end

	if source_player_id and target_id ~= end_game_view.target_id then
		trace_runtime_event("end_game.response_cached", {
			target_id = target_id,
			request_kind = request_kind,
			source_player_id = source_player_id,
		})
		return true, false, end_game_view
	end

	end_game_view_runtime.clear_end_game_view_request_error(target_id, request_kind)
	end_game_view[state.runtime_payload_key] = payload
	end_game_view[state.runtime_received_key] = true
	trace_runtime_event("end_game.response_applied", {
		target_id = target_id,
		request_kind = request_kind,
		source_player_id = source_player_id,
	})

	return true, true, end_game_view
end

local function clear_preview_card_area(area)
	if not (area and area.cards) then return end
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or nil
	local function clear_cards()
		for i = #area.cards, 1, -1 do
			if area.cards[i] then
				area.cards[i].mp_end_game_preview = true
				area.cards[i]:remove()
			end
		end
		area.cards = {}
	end
	if content_runtime and content_runtime.with_phantom_sync_suppressed then
		content_runtime.with_phantom_sync_suppressed(clear_cards)
	else
		clear_cards()
	end
end

function end_game_view_runtime.clear_end_game_target_preview()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	clear_preview_card_area(end_game_view.jokers_area)
end

local function has_cached_end_game_payload(cache, state, request_kind)
	if not (cache and state and cache[state.cache_received_key]) then
		return false
	end
	if not is_end_game_cache_for_current_lobby(cache) then
		return false
	end
	if (request_kind == "jokers" or request_kind == "deck") and tostring(cache[state.cache_payload_key] or "") == "" then
		return false
	end
	return true
end

local function load_cached_end_game_view_payload(target_id, request_kind, end_game_view, cache)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not (state and target_id and cache) then
		return false
	end

	if not has_cached_end_game_payload(cache, state, request_kind) then
		end_game_view[state.runtime_payload_key] = ""
		end_game_view[state.runtime_received_key] = false
		trace_runtime_event("end_game.local_cache_missing", {
			target_id = target_id,
			request_kind = request_kind,
		})
		return false
	end

	end_game_view[state.runtime_payload_key] = cache[state.cache_payload_key]
	end_game_view[state.runtime_received_key] = true
	end_game_view[state.error_key] = cache[state.error_key]
	trace_runtime_event("end_game.local_cache_load", {
		target_id = target_id,
		request_kind = request_kind,
	})
	BALATRO.call_ui_function(state.load_ui_function)
	return true
end

local function request_end_game_prefetch_payload(target_id, request_kind, cache)
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not (target_id and state and cache) then
		return false
	end
	if has_cached_end_game_payload(cache, state, request_kind) then
		trace_runtime_event("end_game.prefetch_skipped", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "cache_hit",
		})
		return false
	end
	if cache[state.cache_requested_key] then
		trace_runtime_event("end_game.prefetch_skipped", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "already_requested",
		})
		return false
	end

	local request_action = MP.ACTIONS and state.request_action and MP.ACTIONS[state.request_action] or nil
	if not request_action then
		trace_runtime_event("end_game.prefetch_blocked", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "missing_action",
		})
		return false
	end

	cache[state.cache_requested_key] = true
	local queued = request_action(target_id)
	if queued == false then
		cache[state.cache_requested_key] = false
		trace_runtime_event("end_game.prefetch_blocked", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "queue_failed",
		})
		return false
	end

	trace_runtime_event("end_game.prefetch_requested", {
		target_id = target_id,
		request_kind = request_kind,
	})
	return true
end

function end_game_view_runtime.prefetch_end_game_view_players()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	if end_game_view.prefetch_started then
		trace_runtime_event("end_game.prefetch_skipped", {
			reason = "already_started",
		})
		return false
	end

	end_game_view.prefetch_started = true
	local players = end_game_view.players or end_game_view_runtime.get_viewable_players()
	local requested = 0
	for _, player in ipairs(players or {}) do
		local target_id = player and player.id or nil
		if target_id then
			local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
			if request_end_game_prefetch_payload(target_id, "jokers", cache) then requested = requested + 1 end
			if request_end_game_prefetch_payload(target_id, "deck", cache) then requested = requested + 1 end
			if request_end_game_prefetch_payload(target_id, "summary", cache) then requested = requested + 1 end
		end
	end

	trace_runtime_event("end_game.prefetch_complete", {
		player_count = #(players or {}),
		requested = requested,
	})
	return requested > 0
end

function end_game_view_runtime.refresh_end_game_view_target_summary()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local target_id = end_game_view.target_id
	if not target_id then return false end

	local cache = end_game_view_runtime.get_end_game_view_cache(target_id)
	if not cache then return false end
	if load_cached_end_game_view_payload(target_id, "summary", end_game_view, cache) then
		return true
	end
	end_game_view_runtime.apply_end_game_summary({}, target_id)
	return false
end

function end_game_view_runtime.request_end_game_view_target(target)
	if not (target and target.id) then return false end
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	if end_game_view.loaded_target_id == target.id then
		trace_runtime_event("end_game.target_switch_skipped", {
			target_id = target.id,
			reason = "already_loaded",
		})
		return true
	end

	end_game_domain.select_view_target(
		target,
		MP.LOBBY and MP.LOBBY.players or nil,
		(G and G.MP_ID or nil)
	)
	sync_end_game_view_domain_state(end_game_view)
	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = end_game_view_runtime.get_target_jokers_label(target)

	end_game_view_runtime.clear_end_game_target_preview()
	end_game_view_runtime.load_end_game_view_cache(target.id)

	local cache = end_game_view_runtime.get_end_game_view_cache(target.id)
	if end_game_view.end_game_jokers_error_message and not end_game_view.jokers_received then
		end_game_view.jokers_text = end_game_view_runtime.get_target_jokers_label(target) .. " (Unavailable)"
	end

	load_cached_end_game_view_payload(target.id, "jokers", end_game_view, cache)
	load_cached_end_game_view_payload(target.id, "deck", end_game_view, cache)
	if not load_cached_end_game_view_payload(target.id, "summary", end_game_view, cache) then
		end_game_view_runtime.apply_end_game_summary({}, target.id)
	end
	end_game_view.loaded_target_id = target.id
	return true
end



-- ==========================================================================
-- Section 2: End Game Message Handlers & Network Serialization
-- ==========================================================================

local load_required_service = MP.UTILS.load_required_service

local last_sent_summary_signature = nil

local function get_true_flag_key(tbl)
	for key, value in pairs(tbl or {}) do
		if value == true or tostring(value) == "true" then
			return key
		end
	end
	return nil
end

local function card_to_string(card)
	if not card or not card.base or not card.base.suit or not card.base.value then return "" end

	local suit = string.sub(card.base.suit, 1, 1)

	local rank_value_map = {
		["10"] = "T",
		Jack = "J",
		Queen = "Q",
		King = "K",
		Ace = "A",
	}
	local rank = rank_value_map[card.base.value] or card.base.value

	local enhancement = "none"
	if card.config.center then
		for key, candidate in pairs(G.P_CENTERS or {}) do
			if candidate == card.config.center then
				enhancement = key
				break
			end
		end
	end
	local edition = get_true_flag_key(card.edition) or "none"
	local seal = card.seal or "none"

	return suit .. "-" .. rank .. "-" .. enhancement .. "-" .. edition .. "-" .. seal
end

local function copy_array(source)
	local result = {}
	for _, value in ipairs(source or {}) do
		result[#result + 1] = value
	end
	return result
end

local function get_round_score_amount(score_key, fallback)
	local round_scores = G and G.GAME and G.GAME.round_scores or nil
	local score = round_scores and round_scores[score_key] or nil
	return tonumber(score and score.amt) or fallback or 0
end

local function get_current_ante()
	return tonumber(G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante)
		or get_round_score_amount("furthest_ante", 0)
end

local function get_current_round()
	return tonumber(G and G.GAME and G.GAME.round) or get_round_score_amount("furthest_round", 0)
end

local function get_current_hand_key()
	local game = G and G.GAME or nil
	local current_hand = game and game.current_round and game.current_round.current_hand or nil
	local hand_key = current_hand and current_hand.handname or nil
	if type(hand_key) == "string" and hand_key ~= "" and game and game.hands and game.hands[hand_key] then
		return hand_key
	end
	return nil
end

local function get_ordered_hand_keys(game)
	local keys = {}
	for _, key in ipairs((G and G.handlist) or {}) do
		if game and game.hands and game.hands[key] then
			keys[#keys + 1] = key
		end
	end
	for key in pairs((game and game.hands) or {}) do
		local seen = false
		for _, existing in ipairs(keys) do
			if existing == key then
				seen = true
				break
			end
		end
		if not seen then keys[#keys + 1] = key end
	end
	return keys
end

local function get_most_played_hand()
	local game = G and G.GAME or nil
	local round = game and game.current_round or nil
	local round_hand = round and round.most_played_poker_hand or nil
	local current_hand = get_current_hand_key()

	local best_hand_key = nil
	local best_hand_count = 0
	for _, key in ipairs(get_ordered_hand_keys(game)) do
		local hand = game.hands[key]
		local count = tonumber(hand and (hand.played or hand.count)) or 0
		if count > best_hand_count
			or (
				count == best_hand_count
				and count > 0
				and (key == current_hand or (not current_hand and key == round_hand))
			)
		then
			best_hand_count = count
			best_hand_key = key
		end
	end
	for key, hand in pairs((game and game.hand_usage) or {}) do
		local count = tonumber(hand and (hand.count or hand.played)) or 0
		if count > best_hand_count then
			best_hand_count = count
			best_hand_key = key
		end
	end
	return best_hand_key, best_hand_count
end

local function build_local_end_game_summary()
	local stats = MP.GAME and MP.GAME.stats or {}
	local poker_hand, poker_hand_count = get_most_played_hand()
	local reroll_count = get_round_score_amount("times_rerolled", tonumber(stats.reroll_count) or 0)
	local reroll_cost_total = tonumber(stats.reroll_cost_total) or 0
	local total_money_spent = tonumber(stats.total_money_spent) or reroll_cost_total

	return {
		version = 1,
		hand = get_round_score_amount("hand", 0),
		poker_hand = poker_hand,
		poker_hand_count = poker_hand_count,
		cards_purchased = get_round_score_amount("cards_purchased", 0),
		times_rerolled = reroll_count,
		furthest_ante = get_current_ante(),
		furthest_round = get_current_round(),
		reroll_cost_total = reroll_cost_total,
		total_money_spent = total_money_spent,
		vouchers_bought = copy_array(stats.vouchers_bought),
		seed = tostring(G and G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed or ""),
		seeded = not not (G and G.GAME and G.GAME.seeded),
	}
end

local function encode_local_end_game_summary(summary)
	return MP.UTILS.str_pack_and_encode(summary or build_local_end_game_summary(), "end_game.summary")
end

local function join_summary_vouchers(vouchers)
	local parts = {}
	for _, voucher in ipairs(vouchers or {}) do
		parts[#parts + 1] = tostring(voucher)
	end
	return table.concat(parts, "|")
end

local function build_summary_signature(summary)
	summary = summary or {}
	return table.concat({
		tostring(summary.version or ""),
		tostring(summary.hand or ""),
		tostring(summary.poker_hand or ""),
		tostring(summary.poker_hand_count or ""),
		tostring(summary.cards_purchased or ""),
		tostring(summary.times_rerolled or ""),
		tostring(summary.furthest_ante or ""),
		tostring(summary.furthest_round or ""),
		tostring(summary.reroll_cost_total or ""),
		tostring(summary.total_money_spent or ""),
		join_summary_vouchers(summary.vouchers_bought),
		tostring(summary.seed or ""),
		tostring(summary.seeded == true),
	}, "\31")
end

local function has_summary_channel()
	return not not (MP.LOBBY and MP.LOBBY.code and MP.GAME)
end

local function ensure_end_game_view_runtime()
	return end_game_view_runtime
end

local function get_target_jokers_label(ui)
	if ui and ui.get_target_jokers_label then
		return ui.get_target_jokers_label()
	end
	return localize("k_enemy_jokers")
end

local function with_phantom_sync_suppressed(callback)
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or nil
	if content_runtime and content_runtime.with_phantom_sync_suppressed then
		return content_runtime.with_phantom_sync_suppressed(callback)
	end
	return callback()
end

local function mark_end_game_preview_cards(card_area)
	if not card_area then return end
	card_area.mp_end_game_preview = true
	for _, card in ipairs(card_area.cards or {}) do
		card.mp_end_game_preview = true
	end
end

local function report_end_game_view_failure(state_kind, issue_kind, target_id, message, details, on_failed_runtime_target)
	trace_runtime_event("end_game.load_failed", {
		target_id = target_id,
		state_kind = state_kind,
		issue_kind = issue_kind,
		details = details,
	})

	local ui = ensure_end_game_view_runtime()
	if ui and ui.fail_end_game_view_request then
		ui.fail_end_game_view_request(target_id, state_kind, message)
	end

	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	if
		end_game_view
		and end_game_view.target_id == target_id
		and on_failed_runtime_target
	then
		on_failed_runtime_target(end_game_view)
	end

	if MP.NETWORKING_INTERNAL.report_feature_runtime_issue then
		MP.NETWORKING_INTERNAL.report_feature_runtime_issue(
			issue_kind,
			message,
			details,
			{ show_overlay = false }
		)
	end
end

local function report_end_game_jokers_failure(target_id, details)
	report_end_game_view_failure(
		"jokers",
		"end_game_jokers",
		target_id,
		"Could not load this player's end-game jokers.",
		details,
		function(end_game_view)
			end_game_view.showing_own_jokers = false
			end_game_view.jokers_text = get_target_jokers_label(ensure_end_game_view_runtime()) .. " (Unavailable)"
		end
	)
end

BALATRO.set_ui_function("load_end_game_jokers", function()
	local ui = ensure_end_game_view_runtime()
	local card_area_save, success, err
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil

	if not end_game_view or not end_game_view.jokers_area or not end_game_view.jokers_payload then
		return
	end
	if end_game_view.jokers_payload == "" then
		return
	end

	end_game_view.jokers_area.mp_end_game_preview = true
	card_area_save, err = MP.UTILS.str_decode_and_unpack(end_game_view.jokers_payload, "end_game.jokers")
	if not card_area_save then
		report_end_game_jokers_failure(target_id, string.format("Failed to unpack player jokers: %s", err))
		return
	end

	success, err = pcall(function()
		return with_phantom_sync_suppressed(function()
			return end_game_view.jokers_area:load(card_area_save)
		end)
	end)
	if not success then
		report_end_game_jokers_failure(target_id, string.format("Failed to load player jokers: %s", err))
		with_phantom_sync_suppressed(function()
			end_game_view.jokers_area:remove()
		end)
		local joker_slots = (G and G.GAME and G.GAME.starting_params and G.GAME.starting_params.joker_slots or nil) or 0
		end_game_view.jokers_area:init(
			---@diagnostic disable-next-line: param-type-mismatch
			0,
			0,
			5 * ((G and G.CARD_W or nil) or 0),
			(G and G.CARD_H or nil) or 0,
			{ card_limit = joker_slots, type = "joker", highlight_limit = 1 }
		)
		end_game_view.jokers_area.mp_end_game_preview = true
		return
	end

	mark_end_game_preview_cards(end_game_view.jokers_area)
	end_game_view.showing_own_jokers = false
	end_game_view.jokers_text = get_target_jokers_label(ui)

	trace_runtime_event("end_game.jokers_load_complete", {
		target_id = target_id,
	})
end)

local function report_nemesis_deck_failure(target_id, details)
	report_end_game_view_failure(
		"deck",
		"nemesis_deck",
		target_id,
		"Could not load this player's deck.",
		details
	)
end

BALATRO.set_ui_function("load_nemesis_deck", function()
	local ui = ensure_end_game_view_runtime()
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil
	if
		not end_game_view
		or not end_game_view.nemesis_deck_string
		or not (MP.LOBBY and MP.LOBBY.code)
	then
		return
	end

	local card_strings = MP.UTILS.string_split(end_game_view.nemesis_deck_string, ";")
	local non_empty_entries = 0
	local invalid_front_keys = 0

	for _, card_str in pairs(card_strings) do
		if card_str == "" then
			goto continue
		end
		non_empty_entries = non_empty_entries + 1

		local card_params = MP.UTILS.string_split(card_str, "-")
		local suit = card_params[1]
		local rank = card_params[2]

		local front_key = tostring(suit) .. "_" .. tostring(rank)
		if not (G and G.P_CARDS and G.P_CARDS[front_key] or nil) then
			sendDebugMessage(string.format("Invalid playing card key: %s", front_key), "MULTIPLAYER")
			invalid_front_keys = invalid_front_keys + 1
		end

		::continue::
	end

	local valid_cards = non_empty_entries - invalid_front_keys
	end_game_view.nemesis_deck_card_count = valid_cards

	if non_empty_entries > 0 and valid_cards == 0 then
		report_nemesis_deck_failure(
			target_id,
			string.format("Nemesis deck payload contained %s entries but none could be loaded.", tostring(non_empty_entries))
		)
		return
	end

	if invalid_front_keys > 0 then
		sendWarnMessage(
			string.format("Nemesis deck skipped %s invalid playing cards.", tostring(invalid_front_keys)),
			"MULTIPLAYER"
		)
	end
	trace_runtime_event("end_game.deck_load_complete", {
		target_id = target_id,
		loaded_cards = valid_cards,
		payload_cards = non_empty_entries,
		invalid_front_keys = invalid_front_keys,
		materialized = false,
	})
end)

BALATRO.set_ui_function("load_end_game_summary", function()
	local ui = ensure_end_game_view_runtime()
	local end_game_view = ui and ui.get_end_game_view_runtime and ui.get_end_game_view_runtime() or nil
	local target_id = end_game_view and end_game_view.target_id or nil
	if
		not end_game_view
		or not end_game_view.summary_payload
		or end_game_view.summary_payload == ""
	then
		return
	end

	local summary, err = MP.UTILS.str_decode_and_unpack(end_game_view.summary_payload, "end_game.summary")
	if not summary then
		report_end_game_view_failure(
			"summary",
			"end_game_summary",
			target_id,
			"Could not load this player's end-game summary.",
			string.format("Failed to unpack player summary: %s", err)
		)
		return
	end

	if ui and ui.apply_end_game_summary then
		ui.apply_end_game_summary(summary, target_id)
	end

	trace_runtime_event("end_game.summary_load_complete", {
		target_id = target_id,
	})
end)

function end_game_message_runtime.cache_local_end_game_state()
	end_game_message_runtime.handle_get_end_game_jokers(nil)
	end_game_message_runtime.handle_get_nemesis_deck(nil)
	end_game_message_runtime.cache_local_end_game_summary()
end

local function cache_local_final_payload(request_kind, payload, source_player_id, requester_player_id)
	if requester_player_id ~= nil then
		return
	end
	if not source_player_id then
		return
	end
	end_game_message_runtime.apply_received_end_game_payload(request_kind, payload, source_player_id)
end

function end_game_message_runtime.cache_local_end_game_summary()
	return end_game_message_runtime.send_end_game_summary_update(true)
end

function end_game_message_runtime.reset_end_game_summary_updates()
	last_sent_summary_signature = nil
end

function end_game_message_runtime.send_end_game_summary_update(force, options)
	options = options or {}
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return false
	end
	local source_player_id = (G and G.MP_ID or nil)
	local summary = build_local_end_game_summary()
	local summary_encoded = encode_local_end_game_summary(summary)
	cache_local_final_payload("summary", summary_encoded, source_player_id, nil)

	local signature = build_summary_signature(summary)
	local changed = force == true or signature ~= last_sent_summary_signature
	if changed then
		last_sent_summary_signature = signature
	end

	local queued = false
	if
		changed
		and options.cache_only ~= true
		and not (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
		and has_summary_channel()
		and MP.ACTIONS
		and MP.ACTIONS.send_end_game_summary
	then
		queued = MP.ACTIONS.send_end_game_summary(summary_encoded) ~= false
	end

	trace_runtime_event("end_game.summary_local_cache", {
		source_player_id = source_player_id,
		has_payload = summary_encoded ~= "",
		changed = changed,
		queued = queued,
	})
	return summary_encoded ~= ""
end

function end_game_message_runtime.handle_get_end_game_jokers(requester_player_id)
	trace_runtime_event("end_game.jokers_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = (G and G.MP_ID or nil)
	local joker_cards = (G and G.jokers and G.jokers.cards or nil)
	if not joker_cards then
		trace_runtime_event("end_game.jokers_response_send", {
			requester_player_id = requester_player_id,
			empty = true,
		})
		cache_local_final_payload("jokers", "", source_player_id, requester_player_id)
		Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
			"",
			source_player_id,
			requester_player_id
		))
		return
	end

	local jokers_save = BALATRO.save_card_area(G and G.jokers or nil)
	local jokers_encoded = MP.UTILS.str_pack_and_encode(jokers_save, "end_game.jokers")

	cache_local_final_payload("jokers", jokers_encoded, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(
		jokers_encoded,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.jokers_response_send", {
		requester_player_id = requester_player_id,
		empty = false,
	})
end

local function apply_received_payload_to_active_view(
	request_kind,
	payload,
	source_player_id,
	received_trace_event,
	not_applied_trace_event
)
	trace_runtime_event(received_trace_event, {
		source_player_id = source_player_id,
		has_payload = payload ~= nil and payload ~= "",
	})
	local applied_to_runtime, active_view, response_outcome = end_game_message_runtime.apply_received_end_game_payload(
		request_kind,
		payload,
		source_player_id
	)
	if not applied_to_runtime then
		if response_outcome ~= "cached" then
			trace_runtime_event(not_applied_trace_event, {
				source_player_id = source_player_id,
				outcome = response_outcome,
			})
		end
		return nil
	end

	return active_view
end

function end_game_message_runtime.handle_receive_end_game_jokers(keys, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"jokers",
		keys,
		source_player_id,
		"end_game.jokers_response_received",
		"end_game.jokers_response_not_applied"
	)
	if not active_view then
		return
	end

	active_view.showing_own_jokers = false
	active_view.jokers_text = get_target_jokers_label(ensure_end_game_view_runtime())
	BALATRO.call_ui_function("load_end_game_jokers")
end

function end_game_message_runtime.apply_received_end_game_payload(request_kind, payload, source_player_id)
	local ui = ensure_end_game_view_runtime()
	if not (ui and ui.resolve_end_game_view_response_target and ui.apply_end_game_view_response) then
		trace_runtime_event("end_game.response_blocked", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			reason = "missing_view_runtime",
		})
		return false, nil, "blocked"
	end

	local target_id = ui.resolve_end_game_view_response_target(request_kind, source_player_id)
	if not target_id then
		trace_runtime_event("end_game.response_blocked", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			reason = "missing_target",
		})
		return false, nil, "blocked"
	end

	local applied, applied_to_runtime, active_view = ui.apply_end_game_view_response(
		target_id,
		request_kind,
		payload,
		source_player_id
	)
	if not applied then
		trace_runtime_event("end_game.response_not_runtime_applied", {
			request_kind = request_kind,
			source_player_id = source_player_id,
			target_id = target_id,
			applied = applied,
			applied_to_runtime = applied_to_runtime,
		})
		return false, active_view, "not_applied"
	end

	if not applied_to_runtime then
		return false, active_view, "cached"
	end

	return true, active_view, "applied"
end

function end_game_message_runtime.handle_get_nemesis_deck(requester_player_id)
	trace_runtime_event("end_game.deck_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = (G and G.MP_ID or nil)
	local deck_str = ""
	for _, card in ipairs(((G and G.playing_cards)) or {}) do
		deck_str = deck_str .. ";" .. card_to_string(card)
	end
	cache_local_final_payload("deck", deck_str, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_nemesis_deck_payload(
		deck_str,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.deck_response_send", {
		requester_player_id = requester_player_id,
		has_payload = deck_str ~= "",
	})
end

function end_game_message_runtime.handle_receive_nemesis_deck(deck_str, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"deck",
		deck_str,
		source_player_id,
		"end_game.deck_response_received",
		"end_game.deck_response_not_applied"
	)
	if not active_view then
		return
	end

	BALATRO.call_ui_function("load_nemesis_deck")
end

function end_game_message_runtime.handle_get_end_game_summary(requester_player_id)
	trace_runtime_event("end_game.summary_request_received", {
		requester_player_id = requester_player_id,
	})
	local source_player_id = (G and G.MP_ID or nil)
	local summary_encoded = encode_local_end_game_summary(build_local_end_game_summary())
	cache_local_final_payload("summary", summary_encoded, source_player_id, requester_player_id)
	Client.send(MP.FEATURE_WIRE.build_receive_end_game_summary_payload(
		summary_encoded,
		source_player_id,
		requester_player_id
	))
	trace_runtime_event("end_game.summary_response_send", {
		requester_player_id = requester_player_id,
		has_payload = summary_encoded ~= "",
	})
end

function end_game_message_runtime.handle_receive_end_game_summary(summary, source_player_id)
	local active_view = apply_received_payload_to_active_view(
		"summary",
		summary,
		source_player_id,
		"end_game.summary_response_received",
		"end_game.summary_response_not_applied"
	)
	if not active_view then
		return
	end

	BALATRO.call_ui_function("load_end_game_summary")
end

MP.NETWORKING_INTERNAL.cache_local_end_game_state = end_game_message_runtime.cache_local_end_game_state
MP.NETWORKING_INTERNAL.reset_end_game_summary_updates = end_game_message_runtime.reset_end_game_summary_updates
MP.NETWORKING_INTERNAL.send_end_game_summary_update = end_game_message_runtime.send_end_game_summary_update
MP.NETWORKING_INTERNAL.handle_get_end_game_jokers = end_game_message_runtime.handle_get_end_game_jokers
MP.NETWORKING_INTERNAL.handle_receive_end_game_jokers = end_game_message_runtime.handle_receive_end_game_jokers
MP.NETWORKING_INTERNAL.handle_get_nemesis_deck = end_game_message_runtime.handle_get_nemesis_deck
MP.NETWORKING_INTERNAL.handle_receive_nemesis_deck = end_game_message_runtime.handle_receive_nemesis_deck
MP.NETWORKING_INTERNAL.handle_get_end_game_summary = end_game_message_runtime.handle_get_end_game_summary
MP.NETWORKING_INTERNAL.handle_receive_end_game_summary = end_game_message_runtime.handle_receive_end_game_summary

return end_game_view_runtime
