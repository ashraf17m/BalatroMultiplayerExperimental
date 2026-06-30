local end_game_view_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

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

local function build_end_game_view_cache()
	local cache = {}
	for _, state in pairs(END_GAME_REQUEST_STATES) do
		cache[state.cache_payload_key] = ""
		cache[state.cache_received_key] = false
		cache[state.cache_requested_key] = false
		cache[state.error_key] = nil
	end
	return cache
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
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
	)
end

function end_game_view_runtime.get_end_game_self_player()
	return end_game_domain.get_self_player(
		MP.LOBBY and MP.LOBBY.players or nil,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
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
		BALATRO.get_player_id and BALATRO.get_player_id() or nil,
		standings_players
	)
	sync_end_game_view_domain_state(end_game_view)

	return snapshot
end

function end_game_view_runtime.get_view_target_state()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	local players, target, target_index = end_game_domain.resolve_view_target(
		MP.LOBBY and MP.LOBBY.players or nil,
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
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
	if not end_game_view.cache[target_id] then
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
		BALATRO.get_player_id and BALATRO.get_player_id() or nil
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

return end_game_view_runtime
