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
}

local END_GAME_DOMAIN_METHODS = {
	"ensure_view_state",
	"reset_view_state",
	"get_viewable_players",
	"get_standings_participants",
	"capture_view_players",
	"resolve_view_target",
	"select_view_target",
}

local TARGET_LABEL_FALLBACKS = {
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

local function get_view_target_label(noun, target)
	local relation = get_view_target_relation(target)
	local fallback = (TARGET_LABEL_FALLBACKS[relation] and TARGET_LABEL_FALLBACKS[relation][noun])
		or (TARGET_LABEL_FALLBACKS.player and TARGET_LABEL_FALLBACKS.player[noun])
		or "Player"
	return localize_or_fallback("k_" .. relation .. "_" .. noun, fallback)
end

local function reset_end_game_view_local_state(runtime)
	runtime.cache = {}
	runtime.jokers_area = nil
	runtime.nemesis_deck_card_count = 0
	runtime.jokers_text = ""
	runtime.showing_own_jokers = false
	reset_end_game_request_runtime_state(runtime)
	return runtime
end

local function build_end_game_view_runtime()
	return reset_end_game_view_local_state({
		players = nil,
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

function end_game_view_runtime.reset_end_game_view_runtime()
	local runtime = end_game_view_runtime.get_end_game_view_runtime()
	end_game_domain.reset_view_state()
	sync_end_game_view_domain_state(runtime)
	return reset_end_game_view_local_state(runtime)
end

local PREFETCH_REQUEST_OPTIONS = { set_pending_target = false }
local SELECTED_TARGET_REQUEST_OPTIONS = { set_pending_target = true }

function end_game_view_runtime.get_viewable_players()
	return end_game_domain.get_viewable_players(
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
	for i = #area.cards, 1, -1 do
		if area.cards[i] then
			area.cards[i]:remove()
		end
	end
	area.cards = {}
end

function end_game_view_runtime.clear_end_game_target_preview()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	clear_preview_card_area(end_game_view.jokers_area)
end

local function request_end_game_view_payload(target_id, request_kind, end_game_view, cache, options)
	options = options or {}
	local set_pending_target = options.set_pending_target == true
	local state = END_GAME_REQUEST_STATES[request_kind]
	if not (state and target_id and cache) then
		trace_runtime_event("end_game.request_blocked", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "missing_state_target_or_cache",
		})
		return false
	end

	local request_action = MP.ACTIONS and MP.ACTIONS[state.request_action] or nil
	if not request_action then
		trace_runtime_event("end_game.request_blocked", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "missing_action",
		})
		return false
	end

	if end_game_view[state.runtime_received_key] then
		trace_runtime_event("end_game.request_cache_load", {
			target_id = target_id,
			request_kind = request_kind,
		})
		BALATRO.call_ui_function(state.load_ui_function)
		return true
	end

	end_game_view[state.runtime_payload_key] = ""
	end_game_view[state.runtime_received_key] = false

	if cache[state.cache_requested_key] then
		trace_runtime_event("end_game.request_already_pending", {
			target_id = target_id,
			request_kind = request_kind,
		})
		return false
	end

	end_game_view_runtime.clear_end_game_view_request_error(target_id, request_kind)
	cache[state.cache_requested_key] = true
	if set_pending_target then
		end_game_view[state.runtime_pending_key] = target_id
	end

	trace_runtime_event("end_game.request_start", {
		target_id = target_id,
		request_kind = request_kind,
		set_pending_target = set_pending_target,
	})
	local queued = request_action(target_id)
	if queued == false then
		cache[state.cache_requested_key] = false
		if end_game_view[state.runtime_pending_key] == target_id then
			end_game_view[state.runtime_pending_key] = nil
		end
		trace_runtime_event("end_game.request_failed", {
			target_id = target_id,
			request_kind = request_kind,
			reason = "queue_failed",
		})
		return false
	end

	return true
end

function end_game_view_runtime.prefetch_end_game_view_players()
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()
	for _, target in ipairs(end_game_view_runtime.get_viewable_players()) do
		local cache = end_game_view_runtime.get_end_game_view_cache(target.id)
		request_end_game_view_payload(target.id, "jokers", end_game_view, cache, PREFETCH_REQUEST_OPTIONS)
	end
end

function end_game_view_runtime.request_end_game_view_target(target)
	if not target then return end
	local end_game_view = end_game_view_runtime.get_end_game_view_runtime()

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

	request_end_game_view_payload(target.id, "jokers", end_game_view, cache, SELECTED_TARGET_REQUEST_OPTIONS)
	request_end_game_view_payload(target.id, "deck", end_game_view, cache, SELECTED_TARGET_REQUEST_OPTIONS)
end

return end_game_view_runtime
