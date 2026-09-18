-- Consolidated feature_runtime.lua
-- Combines feature_action_runtime.lua and feature_message_runtime.lua

MP.ACTIONS = MP.ACTIONS or {}
MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local feature_action_runtime = {}
local feature_message_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

-- ==========================================================================
-- Section 1: Feature Action Senders (MP.ACTIONS)
-- ==========================================================================

function feature_action_runtime.modded(modId, modAction, params, target)
	Client.queue_send(MP.FEATURE_WIRE.build_modded_action_payload(modId, modAction, params, target))
end

-- A spectating client's board is a replay simulation; its card mutations are
-- local-only and must never relay to teammates as if they were real changes.
local function is_spectator_client()
	return not not (MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role))
end

function feature_action_runtime.team_card_sync(card_key, action_type, card_data)
	if is_spectator_client() then
		return false
	end

	return Client.queue_send(MP.FEATURE_WIRE.build_team_card_sync_payload(card_key, action_type, card_data))
end

function feature_action_runtime.team_hand_level_sync(hand, level)
	if is_spectator_client() then
		return false
	end

	local payload = MP.FEATURE_WIRE.build_team_hand_level_sync_payload(hand, level)
	if not payload then
		return false
	end

	return Client.queue_send(payload)
end

function feature_action_runtime.send_phantom(key)
	if is_spectator_client() then
		return false
	end
	Client.queue_send(MP.FEATURE_WIRE.build_send_phantom_payload(key))
end

function feature_action_runtime.remove_phantom(key)
	if is_spectator_client() then
		return false
	end
	Client.queue_send(MP.FEATURE_WIRE.build_remove_phantom_payload(key))
end

function feature_action_runtime.asteroid()
	Client.queue_send(MP.FEATURE_WIRE.build_asteroid_payload())
end

function feature_action_runtime.sold_joker()
	Client.queue_send(MP.FEATURE_WIRE.build_sold_joker_payload())
end

function feature_action_runtime.lets_go_gambling_nemesis()
	Client.queue_send(MP.FEATURE_WIRE.build_lets_go_gambling_nemesis_payload())
end

function feature_action_runtime.eat_pizza(discards)
	Client.queue_send(MP.FEATURE_WIRE.build_eat_pizza_payload(discards))
end

function feature_action_runtime.spent_last_shop(amount)
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating then
		return
	end
	Client.queue_send(MP.FEATURE_WIRE.build_spent_last_shop_payload(amount))
end

function feature_action_runtime.magnet()
	Client.queue_send(MP.FEATURE_WIRE.build_magnet_payload())
end

function feature_action_runtime.magnet_response(key)
	Client.queue_send(MP.FEATURE_WIRE.build_magnet_response_payload(key))
end

function feature_action_runtime.get_end_game_jokers(target_player_id)
	local queued = Client.queue_send(MP.FEATURE_WIRE.build_get_end_game_jokers_payload(target_player_id))
	trace_runtime_event("end_game.jokers_request_send", {
		target_player_id = target_player_id,
		queued = queued,
	})
	return queued
end

function feature_action_runtime.get_nemesis_deck(target_player_id)
	local queued = Client.queue_send(MP.FEATURE_WIRE.build_get_nemesis_deck_payload(target_player_id))
	trace_runtime_event("end_game.deck_request_send", {
		target_player_id = target_player_id,
		queued = queued,
	})
	return queued
end

function feature_action_runtime.get_end_game_summary(target_player_id, options)
	local queued = Client.queue_send(MP.FEATURE_WIRE.build_get_end_game_summary_payload(target_player_id, options))
	trace_runtime_event("end_game.summary_request_send", {
		target_player_id = target_player_id,
		fresh = options and options.fresh == true,
		queued = queued,
	})
	return queued
end

function feature_action_runtime.send_end_game_summary(summary)
	return Client.queue_send(MP.FEATURE_WIRE.build_receive_end_game_summary_payload(summary))
end

function feature_action_runtime.spectator_action_stream(action_data, step_index)
	return Client.queue_send(MP.FEATURE_WIRE.build_spectator_action_stream_payload(action_data, step_index))
end

function feature_action_runtime.spectator_watch_target(target_player_id)
	return Client.queue_send(MP.FEATURE_WIRE.build_spectator_watch_target_payload(target_player_id))
end

function feature_action_runtime.spectator_provide_snapshot(spectator_player_id, target_player_id, snapshot_data)
	return Client.queue_send(MP.FEATURE_WIRE.build_spectator_provide_snapshot_payload(spectator_player_id, target_player_id, snapshot_data))
end

function feature_action_runtime.spectator_request_snapshot(target_player_id)
	return Client.queue_send(MP.FEATURE_WIRE.build_spectator_request_snapshot_payload(target_player_id))
end

function feature_action_runtime.spectator_set_role(role)
	return Client.queue_send(MP.FEATURE_WIRE.build_spectator_set_role_payload(role))
end

function feature_action_runtime.cache_end_game_state()
	MP.NETWORKING_INTERNAL.cache_local_end_game_state()
end

MP.ACTIONS.modded = feature_action_runtime.modded
MP.ACTIONS.team_card_sync = feature_action_runtime.team_card_sync
MP.ACTIONS.team_hand_level_sync = feature_action_runtime.team_hand_level_sync
MP.ACTIONS.send_phantom = feature_action_runtime.send_phantom
MP.ACTIONS.remove_phantom = feature_action_runtime.remove_phantom
MP.ACTIONS.asteroid = feature_action_runtime.asteroid
MP.ACTIONS.sold_joker = feature_action_runtime.sold_joker
MP.ACTIONS.lets_go_gambling_nemesis = feature_action_runtime.lets_go_gambling_nemesis
MP.ACTIONS.eat_pizza = feature_action_runtime.eat_pizza
MP.ACTIONS.spent_last_shop = feature_action_runtime.spent_last_shop
MP.ACTIONS.magnet = feature_action_runtime.magnet
MP.ACTIONS.magnet_response = feature_action_runtime.magnet_response
MP.ACTIONS.get_end_game_jokers = feature_action_runtime.get_end_game_jokers
MP.ACTIONS.get_nemesis_deck = feature_action_runtime.get_nemesis_deck
MP.ACTIONS.get_end_game_summary = feature_action_runtime.get_end_game_summary
MP.ACTIONS.send_end_game_summary = feature_action_runtime.send_end_game_summary
MP.ACTIONS.spectator_action_stream = feature_action_runtime.spectator_action_stream
MP.ACTIONS.spectator_watch_target = feature_action_runtime.spectator_watch_target
MP.ACTIONS.spectator_provide_snapshot = feature_action_runtime.spectator_provide_snapshot
MP.ACTIONS.spectator_request_snapshot = feature_action_runtime.spectator_request_snapshot
MP.ACTIONS.spectator_set_role = feature_action_runtime.spectator_set_role
MP.ACTIONS.cache_end_game_state = feature_action_runtime.cache_end_game_state

-- ==========================================================================
-- Section 2: Feature Message Handlers (MP.NETWORKING_INTERNAL)
-- ==========================================================================

local action_asteroid = action_asteroid
	or function()
		if MP.UI.show_asteroid_hand_level_up then
			MP.UI.show_asteroid_hand_level_up()
		end
	end

local function get_card_center_key(card)
	if not (card and card.config) then
		return nil
	end
	if type(card.config.center_key) == "string" and card.config.center_key ~= "" then
		return card.config.center_key
	end

	local center = card.config.center
	if center and type(center.key) == "string" and center.key ~= "" then
		return center.key
	end
	return nil
end

local function is_phantom_joker(card, key, player_id)
	if
		not (
			card
			and card.edition
			and card.edition.type == "mp_phantom"
			and get_card_center_key(card) == key
		)
	then
		return false
	end

	return not player_id or card.mp_phantom_player_id == player_id
end

local function get_phantom_joker(key, player_id)
	if not MP.shared or not MP.shared.cards then return nil end
	for i = 1, #MP.shared.cards do
		if is_phantom_joker(MP.shared.cards[i], key, player_id) then
			return MP.shared.cards[i]
		end
	end
	return nil
end

local remote_phantoms = {}

local function phantom_owner_from_message(payload, envelope)
	if type(payload) == "table" and payload.playerId then
		return payload.playerId
	end
	if type(envelope) == "table" then
		return envelope.playerId or (envelope.payload and envelope.payload.playerId)
	end
	return nil
end

local function remember_remote_phantom(owner_id, key, should_exist)
	if type(key) ~= "string" or key == "" then
		return
	end
	if not owner_id then
		return
	end
	remote_phantoms[owner_id] = remote_phantoms[owner_id] or {}
	if should_exist then
		remote_phantoms[owner_id][key] = true
	else
		remote_phantoms[owner_id][key] = nil
	end
end

-- Spectators simulate the watched board. sendPhantom copies belong to the
-- sender; the watched player's own jokers are already on G.jokers.
-- In lobbies with >2 players, restrict phantoms strictly to the target's direct nemesis.
local function should_materialize_phantom(owner_id)
	local spec = MP.SPECTATOR
	if not (spec and spec.is_spectating) then
		return true
	end
	if not owner_id then
		return false
	end
	if owner_id == spec.target_player_id then
		return false
	end

	local nemesis_id = nil
	if MP.OPPONENTS and MP.OPPONENTS.get_nemesis_lobby_player then
		local nemesis = MP.OPPONENTS.get_nemesis_lobby_player()
		nemesis_id = nemesis and nemesis.id
	end
	if not nemesis_id and MP.LOBBY and MP.LOBBY.players then
		for _, player in ipairs(MP.LOBBY.players) do
			if player.id == spec.target_player_id then
				nemesis_id = player.nemesis_player_id
				break
			end
		end
	end
	if nemesis_id then
		return owner_id == nemesis_id
	end
	return true
end

local function action_send_phantom(key, player_id)
	if not (type(key) == "string" and key ~= "" and MP.shared) then
		return
	end
	if get_phantom_joker(key, player_id) then
		return
	end

	local center = (G and G.P_CENTERS and G.P_CENTERS[key]) or nil
	if not center then
		sendWarnMessage("Missing phantom joker center: " .. tostring(key), "MULTIPLAYER")
		return
	end

	BALATRO.with_overlay_menu_guard(function()
		local new_card = BALATRO.create_card_object(
			MP.shared.T.x + MP.shared.T.w / 2,
			MP.shared.T.y,
			(G and G.CARD_W or nil),
			(G and G.CARD_H or nil),
			nil,
			center,
			{
				bypass_discovery_center = true,
				bypass_discovery_ui = true,
				discover = true,
				bypass_back = G and G.GAME and G.GAME.selected_back and G.GAME.selected_back.pos or nil,
			}
		)
		new_card.mp_phantom_player_id = player_id
		new_card:set_edition("e_mp_phantom")
		new_card:add_to_deck()
		MP.shared:emplace(new_card)
	end)
end

local function action_remove_phantom(key, player_id)
	local card = get_phantom_joker(key, player_id)
	if card then
		card:remove_from_deck()
		card:start_dissolve({ G.C.RED }, nil, 1.6)
		MP.shared:remove_card(card)
	end
end

local function clear_shared_phantom_cards()
	if not (MP.shared and MP.shared.cards) then
		return
	end
	for i = #MP.shared.cards, 1, -1 do
		local card = MP.shared.cards[i]
		if card and card.edition and card.edition.type == "mp_phantom" then
			pcall(function()
				card:remove_from_deck()
			end)
			MP.shared:remove_card(card)
			pcall(function()
				card:remove()
			end)
		end
	end
end

function feature_message_runtime.rebuild_spectator_phantoms()
	clear_shared_phantom_cards()
	for owner_id, keys in pairs(remote_phantoms) do
		if should_materialize_phantom(owner_id) and type(keys) == "table" then
			for key, present in pairs(keys) do
				if present then
					action_send_phantom(key, owner_id)
				end
			end
		end
	end
end

function feature_message_runtime.apply_snapshot_phantoms(phantoms)
	if type(phantoms) == "table" then
		for _, info in ipairs(phantoms) do
			local key = info and info.key
			local owner_id = info and info.playerId
			if type(key) == "string" and key ~= "" then
				remember_remote_phantom(owner_id, key, true)
			end
		end
	end
	feature_message_runtime.rebuild_spectator_phantoms()
	if type(phantoms) == "table" then
		for _, info in ipairs(phantoms) do
			local key = info and info.key
			if type(key) == "string" and key ~= "" and should_materialize_phantom(info.playerId) then
				action_send_phantom(key, info.playerId)
			end
		end
	end
end

function feature_message_runtime.handle_send_phantom(payload, envelope)
	local key = type(payload) == "table" and payload.key or payload
	local player_id = phantom_owner_from_message(type(payload) == "table" and payload or nil, envelope)
	remember_remote_phantom(player_id, key, true)
	if should_materialize_phantom(player_id) then
		action_send_phantom(key, player_id)
	end
end

function feature_message_runtime.handle_remove_phantom(payload, envelope)
	local key = type(payload) == "table" and payload.key or payload
	local player_id = phantom_owner_from_message(type(payload) == "table" and payload or nil, envelope)
	remember_remote_phantom(player_id, key, false)
	action_remove_phantom(key, player_id)
end

local function action_speedrun()
	MP.PLATFORM.SMODS.calculate_context({ mp_speedrun = true })
end

local function should_show_feature_failure_overlay()
	return MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message and not not (G)
end

function feature_message_runtime.report_feature_runtime_issue(feature_name, message, details, options)
	options = options or {}

	local summary = message or ("Multiplayer feature failed: " .. tostring(feature_name))
	sendWarnMessage(summary, "MULTIPLAYER")
	if details and details ~= summary then
		sendTraceMessage("[" .. tostring(feature_name) .. "] " .. tostring(details), "MULTIPLAYER")
	end

	if options.show_overlay and should_show_feature_failure_overlay() then
		MP.UI.UTILS.overlay_message(options.overlay_message or summary, options.no_back)
	end
end

local function action_magnet()
	local card = nil
	for _, value in pairs((G and G.jokers and G.jokers.cards or nil) or {}) do
		if not card or value.sell_cost > card.sell_cost then
			card = value
		end
	end

	if card then
		local candidates = {}
		for _, value in pairs((G and G.jokers and G.jokers.cards or nil) or {}) do
			if value.sell_cost == card.sell_cost then
				table.insert(candidates, value)
			end
		end

		local random_index = math.random(1, #candidates)
		local chosen_card = candidates[random_index]

		local card_save = chosen_card:save()
		local card_encoded = MP.UTILS.str_pack_and_encode(card_save, "feature.magnet_joker")
		MP.ACTIONS.magnet_response(card_encoded)
	end
end

local function report_magnet_receive_failure(details)
	feature_message_runtime.report_feature_runtime_issue(
		"magnet_response",
		"Failed to receive magnet joker.",
		details,
		{ show_overlay = true }
	)
end

local function action_magnet_response(key)
	local card_save, success, err
	local jokers_area = (G and G.jokers or nil)

	card_save, err = MP.UTILS.str_decode_and_unpack(key, "feature.magnet_joker")
	if not card_save then
		report_magnet_receive_failure(string.format("Failed to unpack magnet joker: %s", err))
		return
	end

	if not jokers_area then
		report_magnet_receive_failure("Missing joker area while receiving magnet joker.")
		return
	end

	local card = BALATRO.create_card_object(
		jokers_area.T.x + jokers_area.T.w / 2,
		jokers_area.T.y,
		(G and G.CARD_W or nil),
		(G and G.CARD_H or nil),
		(G and G.P_CENTERS and G.P_CENTERS["j_joker"] or nil),
		(G and G.P_CENTERS and G.P_CENTERS["c_base"] or nil)
	)
	success, err = pcall(card.load, card, card_save)
	if not success then
		report_magnet_receive_failure(string.format("Failed to load magnet joker: %s", err))
		return
	end

	card:hard_set_VT()
	card.added_to_deck = nil

	card:add_to_deck()
	jokers_area:emplace(card)
end

local function action_sold_joker(player_id)
	local enemy = MP.GAME.enemies[player_id]
	if not enemy then
		return
	end
	enemy.sells = enemy.sells + 1
	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["ante"] or 1)
	enemy.sells_per_ante[ante] = (enemy.sells_per_ante[ante] or 0) + 1
	MP.OPPONENTS.refresh_primary_enemy_view(enemy)
end

local function action_lets_go_gambling_nemesis()
	local card = get_phantom_joker("j_mp_lets_go_gambling")
	if card then
		card:juice_up()
	end
	BALATRO.ease_dollars(card and card.ability and card.ability.extra and card.ability.extra.nemesis_dollars or 5)
end

local function action_eat_pizza(discards)
	discards = math.max(0, math.floor(tonumber(discards) or 0))
	if discards <= 0 then
		return
	end
	if match_domain.increment_pizza_discards then
		match_domain.increment_pizza_discards(discards)
	end
	local round_resets = (G and G.GAME and G.GAME.round_resets) or nil
	if round_resets then
		round_resets.discards = (round_resets.discards or 0) + discards
	end
	ease_discard(discards)
end

local function action_spent_last_shop(player_id, amount)
	local enemy = MP.GAME.enemies[player_id]
	if not enemy then
		return
	end
	enemy.spent_in_shop[#enemy.spent_in_shop + 1] = tonumber(amount)
	MP.OPPONENTS.refresh_primary_enemy_view(enemy)
end

local function normalize_jimbo_position(action_name, pos)
	pos = tonumber(pos)
	if not pos or pos < 1 or pos > 4 then
		sendDebugMessage(action_name .. ": invalid pos: " .. tostring(pos), "MULTIPLAYER")
		return nil
	end

	return pos
end

local function action_jimbo_appear(pos, text)
	pos = normalize_jimbo_position("jimboAppear", pos)
	if not pos then
		return
	end
	if text and type(text) ~= "string" then
		sendDebugMessage("jimboAppear: invalid text type: " .. type(text), "MULTIPLAYER")
		return
	end
	MP.UI.create_jimbo(pos)
	if text and text ~= "" then
		MP.UI.jimbo_say(text)
	end
end

local function action_jimbo_talk(text)
	if not text or type(text) ~= "string" or text == "" then
		sendDebugMessage("jimboTalk: invalid or empty text", "MULTIPLAYER")
		return
	end
	MP.UI.jimbo_say(text)
end

local function action_jimbo_move(pos)
	pos = normalize_jimbo_position("jimboMove", pos)
	if not pos then
		return
	end
	MP.UI.move_jimbo(pos)
end

local function action_jimbo_remove()
	MP.UI.remove_jimbo()
end

local function handle_buffered_team_sync(parsed_action, buffer_method_name, sync_owner)
	if MP.RESUME and MP.RESUME[buffer_method_name] and MP.RESUME[buffer_method_name](parsed_action) then
		return
	end

	if sync_owner and sync_owner.handle_sync then
		sync_owner.handle_sync(parsed_action)
	end
end

function feature_message_runtime.handle_version()
	MP.ACTIONS.version()
end

feature_message_runtime.handle_speedrun = action_speedrun
feature_message_runtime.handle_asteroid = action_asteroid
feature_message_runtime.handle_magnet = action_magnet
feature_message_runtime.handle_magnet_response = action_magnet_response

function feature_message_runtime.handle_modded_action(parsed_action)
	local registry = MP.MOD_ACTIONS[parsed_action.modId]
	if registry and registry[parsed_action.modAction] then
		registry[parsed_action.modAction](parsed_action)
	end
end

function feature_message_runtime.handle_team_card_sync(parsed_action, envelope)
	if type(parsed_action) == "table" and parsed_action.playerId == nil and type(envelope) == "table" then
		parsed_action.playerId = envelope.playerId
			or (envelope.payload and envelope.payload.playerId)
	end
	-- Spectating clients are not in the resume-buffer path. Buffering here
	-- swallowed teammate card syncs and never applied them to the board.
	if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) then
		if MP.SYNC and MP.SYNC.TEAM_CARD and MP.SYNC.TEAM_CARD.handle_sync then
			MP.SYNC.TEAM_CARD.handle_sync(parsed_action)
		end
		return
	end
	handle_buffered_team_sync(parsed_action, "buffer_runtime_team_card_sync", MP.SYNC and MP.SYNC.TEAM_CARD)
end

function feature_message_runtime.handle_team_hand_level_sync(parsed_action, envelope)
	if type(parsed_action) == "table" and parsed_action.playerId == nil and type(envelope) == "table" then
		parsed_action.playerId = envelope.playerId
			or (envelope.payload and envelope.payload.playerId)
	end
	handle_buffered_team_sync(parsed_action, "buffer_runtime_team_hand_level_sync", MP.SYNC and MP.SYNC.TEAM_HAND_LEVEL)
end

feature_message_runtime.handle_sold_joker = action_sold_joker
feature_message_runtime.handle_lets_go_gambling_nemesis = action_lets_go_gambling_nemesis
feature_message_runtime.handle_eat_pizza = action_eat_pizza
feature_message_runtime.handle_spent_last_shop = action_spent_last_shop
feature_message_runtime.handle_jimbo_appear = action_jimbo_appear
feature_message_runtime.handle_jimbo_talk = action_jimbo_talk
feature_message_runtime.handle_jimbo_move = action_jimbo_move
feature_message_runtime.handle_jimbo_remove = action_jimbo_remove

function feature_message_runtime.handle_spectator_action_stream(parsed_action)
	if MP.SPECTATOR and MP.SPECTATOR.handle_spectator_action_stream then
		MP.SPECTATOR.handle_spectator_action_stream(parsed_action)
	end
end

function feature_message_runtime.handle_spectator_history(parsed_action)
	if MP.SPECTATOR and MP.SPECTATOR.handle_spectator_history then
		MP.SPECTATOR.handle_spectator_history(parsed_action)
	end
end

function feature_message_runtime.handle_spectator_request_snapshot(parsed_action)
	if MP.RECORDER and MP.RECORDER.handle_spectator_request_snapshot then
		MP.RECORDER.handle_spectator_request_snapshot(parsed_action)
	end
end

function feature_message_runtime.handle_spectator_receive_snapshot(parsed_action)
	if MP.SPECTATOR and MP.SPECTATOR.handle_spectator_receive_snapshot then
		MP.SPECTATOR.handle_spectator_receive_snapshot(parsed_action)
	end
end

MP.NETWORKING_INTERNAL.report_feature_runtime_issue = feature_message_runtime.report_feature_runtime_issue
MP.NETWORKING_INTERNAL.handle_version = feature_message_runtime.handle_version
MP.NETWORKING_INTERNAL.handle_send_phantom = feature_message_runtime.handle_send_phantom
MP.NETWORKING_INTERNAL.handle_remove_phantom = feature_message_runtime.handle_remove_phantom
MP.NETWORKING_INTERNAL.apply_snapshot_phantoms = feature_message_runtime.apply_snapshot_phantoms
MP.NETWORKING_INTERNAL.rebuild_spectator_phantoms = feature_message_runtime.rebuild_spectator_phantoms
MP.NETWORKING_INTERNAL.handle_speedrun = feature_message_runtime.handle_speedrun
MP.NETWORKING_INTERNAL.handle_asteroid = feature_message_runtime.handle_asteroid
MP.NETWORKING_INTERNAL.handle_magnet = feature_message_runtime.handle_magnet
MP.NETWORKING_INTERNAL.handle_magnet_response = feature_message_runtime.handle_magnet_response
MP.NETWORKING_INTERNAL.handle_modded_action = feature_message_runtime.handle_modded_action
MP.NETWORKING_INTERNAL.handle_team_card_sync = feature_message_runtime.handle_team_card_sync
MP.NETWORKING_INTERNAL.handle_team_hand_level_sync = feature_message_runtime.handle_team_hand_level_sync
MP.NETWORKING_INTERNAL.handle_sold_joker = feature_message_runtime.handle_sold_joker
MP.NETWORKING_INTERNAL.handle_lets_go_gambling_nemesis = feature_message_runtime.handle_lets_go_gambling_nemesis
MP.NETWORKING_INTERNAL.handle_eat_pizza = feature_message_runtime.handle_eat_pizza
MP.NETWORKING_INTERNAL.handle_spent_last_shop = feature_message_runtime.handle_spent_last_shop
MP.NETWORKING_INTERNAL.handle_jimbo_appear = feature_message_runtime.handle_jimbo_appear
MP.NETWORKING_INTERNAL.handle_jimbo_talk = feature_message_runtime.handle_jimbo_talk
MP.NETWORKING_INTERNAL.handle_jimbo_move = feature_message_runtime.handle_jimbo_move
MP.NETWORKING_INTERNAL.handle_jimbo_remove = feature_message_runtime.handle_jimbo_remove
MP.NETWORKING_INTERNAL.handle_spectator_action_stream = feature_message_runtime.handle_spectator_action_stream
MP.NETWORKING_INTERNAL.handle_spectator_history = feature_message_runtime.handle_spectator_history
MP.NETWORKING_INTERNAL.handle_spectator_request_snapshot = feature_message_runtime.handle_spectator_request_snapshot
MP.NETWORKING_INTERNAL.handle_spectator_receive_snapshot = feature_message_runtime.handle_spectator_receive_snapshot



return feature_message_runtime
