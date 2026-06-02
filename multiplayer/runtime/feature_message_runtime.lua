MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local feature_message_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local action_asteroid = action_asteroid
	or function()
		if MP.UI.show_asteroid_hand_level_up then
			MP.UI.show_asteroid_hand_level_up()
		end
	end

local function action_send_phantom(key)
	BALATRO.with_overlay_menu_guard(function()
		local new_card = BALATRO.create_card("Joker", MP.shared, false, nil, nil, nil, key)
		new_card:set_edition("e_mp_phantom")
		new_card:add_to_deck()
		MP.shared:emplace(new_card)
	end)
end

local function get_phantom_joker(key)
	if not MP.shared or not MP.shared.cards then return nil end
	for i = 1, #MP.shared.cards do
		if
			MP.shared.cards[i].ability.name == key
			and MP.shared.cards[i].edition
			and MP.shared.cards[i].edition.type == "mp_phantom"
		then
			return MP.shared.cards[i]
		end
	end
	return nil
end

local function action_remove_phantom(key)
	local card = get_phantom_joker(key)
	if card then
		card:remove_from_deck()
		card:start_dissolve({ G.C.RED }, nil, 1.6)
		MP.shared:remove_card(card)
	end
end

local function action_speedrun()
	MP.PLATFORM.SMODS.calculate_context({ mp_speedrun = true })
end

local function should_show_feature_failure_overlay()
	return MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message and not not (BALATRO.get_root and BALATRO.get_root())
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
	for _, value in pairs(BALATRO.get_joker_cards and BALATRO.get_joker_cards() or {}) do
		if not card or value.sell_cost > card.sell_cost then
			card = value
		end
	end

	if card then
		local candidates = {}
		for _, value in pairs(BALATRO.get_joker_cards and BALATRO.get_joker_cards() or {}) do
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
	local jokers_area = BALATRO.get_jokers_area and BALATRO.get_jokers_area() or nil

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
		BALATRO.get_card_width(),
		BALATRO.get_card_height(),
		BALATRO.get_center("j_joker"),
		BALATRO.get_center("c_base")
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
	local ante = BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("ante", 1) or 1
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
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
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

feature_message_runtime.handle_send_phantom = action_send_phantom
feature_message_runtime.handle_remove_phantom = action_remove_phantom
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

function feature_message_runtime.handle_team_card_sync(parsed_action)
	handle_buffered_team_sync(parsed_action, "buffer_runtime_team_card_sync", MP.SYNC and MP.SYNC.TEAM_CARD)
end

function feature_message_runtime.handle_team_hand_level_sync(parsed_action)
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

MP.NETWORKING_INTERNAL.report_feature_runtime_issue = feature_message_runtime.report_feature_runtime_issue
MP.NETWORKING_INTERNAL.handle_version = feature_message_runtime.handle_version
MP.NETWORKING_INTERNAL.handle_send_phantom = feature_message_runtime.handle_send_phantom
MP.NETWORKING_INTERNAL.handle_remove_phantom = feature_message_runtime.handle_remove_phantom
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
