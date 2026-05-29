MP.FEATURE_WIRE = MP.FEATURE_WIRE or {}
local trunc_number = MP.PROTOCOL.trunc_number
local normalize_non_negative_integer = MP.PROTOCOL.normalize_non_negative_integer

local function stringify_stat_value(value)
	return tostring(value == nil and "" or value)
end

local function build_feature_event(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("feature", "event", action_name, extra_fields)
end

local function normalize_spent_last_shop_amount(amount)
	return normalize_non_negative_integer(amount)
end

local function build_sync_state(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("sync", "state", action_name, extra_fields)
end

local function build_endgame_state(action_name, extra_fields)
	return MP.PROTOCOL.build_v2_packet_for_schema("endgame", "state", action_name, extra_fields)
end

function MP.FEATURE_WIRE.build_modded_action_payload(mod_id, mod_action, params, target)
	local packet = build_feature_event("moddedAction", {
		modId = mod_id,
		modAction = mod_action,
	})
	local payload = packet.payload

	for key, value in pairs(params or {}) do
		payload[key] = value
	end

	if target ~= nil then
		payload.target = target
	end

	return packet
end

function MP.FEATURE_WIRE.build_team_card_sync_payload(card_key, action_type, card_data)
	return build_sync_state("teamCard", {
		cardKey = card_key,
		actionType = action_type,
		cardData = card_data,
	})
end

function MP.FEATURE_WIRE.build_team_hand_level_sync_payload(hand, level)
	return build_sync_state("teamHandLevel", {
		hand = hand,
		level = trunc_number(level),
	})
end

function MP.FEATURE_WIRE.build_send_phantom_payload(key)
	return build_feature_event("sendPhantom", {
		key = key,
	})
end

function MP.FEATURE_WIRE.build_remove_phantom_payload(key)
	return build_feature_event("removePhantom", {
		key = key,
	})
end

function MP.FEATURE_WIRE.build_asteroid_payload()
	return build_feature_event("asteroid")
end

function MP.FEATURE_WIRE.build_sold_joker_payload()
	return build_feature_event("soldJoker")
end

function MP.FEATURE_WIRE.build_lets_go_gambling_nemesis_payload()
	return build_feature_event("letsGoGamblingNemesis")
end

function MP.FEATURE_WIRE.build_eat_pizza_payload(discards)
	return build_feature_event("eatPizza", {
		whole = normalize_non_negative_integer(discards),
	})
end

function MP.FEATURE_WIRE.build_spent_last_shop_payload(amount)
	return build_feature_event("spentLastShop", {
		amount = normalize_spent_last_shop_amount(amount),
	})
end

function MP.FEATURE_WIRE.build_magnet_payload()
	return build_feature_event("magnet")
end

function MP.FEATURE_WIRE.build_magnet_response_payload(key)
	return build_feature_event("magnetResponse", {
		key = key,
	})
end

function MP.FEATURE_WIRE.build_get_end_game_jokers_payload(target_player_id)
	return build_endgame_state("getEndGameJokers", {
		targetPlayerId = target_player_id,
	})
end

function MP.FEATURE_WIRE.build_get_nemesis_deck_payload(target_player_id)
	return build_endgame_state("getNemesisDeck", {
		targetPlayerId = target_player_id,
	})
end

function MP.FEATURE_WIRE.build_receive_end_game_jokers_payload(keys, source_player_id, requester_player_id)
	return build_endgame_state("receiveEndGameJokers", {
		keys = keys,
		sourcePlayerId = source_player_id,
		requesterPlayerId = requester_player_id,
	})
end

function MP.FEATURE_WIRE.build_receive_nemesis_deck_payload(cards, source_player_id, requester_player_id)
	return build_endgame_state("receiveNemesisDeck", {
		cards = cards,
		sourcePlayerId = source_player_id,
		requesterPlayerId = requester_player_id,
	})
end

function MP.FEATURE_WIRE.build_nemesis_stats_payload(stats)
	stats = type(stats) == "table" and stats or {}
	return build_endgame_state("nemesisEndGameStats", {
		reroll_count = stringify_stat_value(stats.reroll_count or 0),
		reroll_cost_total = stringify_stat_value(stats.reroll_cost_total or 0),
		vouchers = stringify_stat_value(stats.vouchers or ""),
	})
end

function MP.FEATURE_WIRE.build_request_nemesis_stats_payload(target_player_id)
	return build_endgame_state("endGameStatsRequested", {
		targetPlayerId = target_player_id,
	})
end
