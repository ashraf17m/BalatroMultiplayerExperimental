MP.ACTIONS = MP.ACTIONS or {}

local feature_action_runtime = {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

function feature_action_runtime.modded(modId, modAction, params, target)
	Client.queue_send(MP.FEATURE_WIRE.build_modded_action_payload(modId, modAction, params, target))
end

function feature_action_runtime.team_card_sync(card_key, action_type, card_data)
	if not (MP.is_shared_card_sync_enabled and MP.is_shared_card_sync_enabled()) then
		return false
	end

	return Client.queue_send(MP.FEATURE_WIRE.build_team_card_sync_payload(card_key, action_type, card_data))
end

function feature_action_runtime.team_hand_level_sync(hand, level)
	if not (MP.is_shared_hand_level_sync_enabled and MP.is_shared_hand_level_sync_enabled()) then
		return false
	end

	local payload = MP.FEATURE_WIRE.build_team_hand_level_sync_payload(hand, level)
	if not payload then
		return false
	end

	return Client.queue_send(payload)
end

function feature_action_runtime.send_phantom(key)
	Client.queue_send(MP.FEATURE_WIRE.build_send_phantom_payload(key))
end

function feature_action_runtime.remove_phantom(key)
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
MP.ACTIONS.cache_end_game_state = feature_action_runtime.cache_end_game_state
