MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO

local function get_game_root()
	return G
end

local POKER_HAND_LEVEL_PRIORITY = {
	["Flush Five"] = 1,
	["Flush House"] = 2,
	["Five of a Kind"] = 3,
	["Straight Flush"] = 4,
	["Four of a Kind"] = 5,
	["Full House"] = 6,
	["Flush"] = 7,
	["Straight"] = 8,
	["Three of a Kind"] = 9,
	["Two Pair"] = 11,
	["Pair"] = 12,
	["High Card"] = 13,
}

function BALATRO.get_root()
	return get_game_root()
end

function BALATRO.get_game()
	local root = get_game_root()
	return root and root.GAME or nil
end

function BALATRO.get_stage()
	local root = get_game_root()
	return root and root.STAGE or nil
end

function BALATRO.get_stage_constants()
	local root = get_game_root()
	return root and root.STAGES or nil
end

function BALATRO.get_state()
	local root = get_game_root()
	return root and root.STATE or nil
end

function BALATRO.get_states()
	local root = get_game_root()
	return root and root.STATES or nil
end

function BALATRO.is_stage(stage_value)
	return BALATRO.get_stage() == stage_value
end

function BALATRO.is_main_menu_stage()
	local stages = BALATRO.get_stage_constants()
	return stages and BALATRO.is_stage(stages.MAIN_MENU) or false
end

function BALATRO.is_run_stage()
	local stages = BALATRO.get_stage_constants()
	return stages and BALATRO.is_stage(stages.RUN) or false
end

function BALATRO.is_game_over_or_win()
	local root = get_game_root()
	if not root then
		return false
	end

	return root.STATE == root.STATES.GAME_OVER or root.STATE == root.STATES.GAME_WIN
end

function BALATRO.get_game_value(name, default)
	local game = BALATRO.get_game()
	if game and game[name] ~= nil then
		return game[name]
	end
	return default
end

function BALATRO.set_game_value(name, value)
	local game = BALATRO.get_game()
	if not game or type(name) ~= "string" or name == "" then
		return false
	end

	game[name] = value
	return true
end

function BALATRO.get_current_round()
	local game = BALATRO.get_game()
	return game and game.current_round or nil
end

function BALATRO.get_current_scoring_calculation()
	local game = BALATRO.get_game()
	return game and game.current_scoring_calculation or nil
end

function BALATRO.get_current_round_value(name, default)
	local current_round = BALATRO.get_current_round()
	if current_round and current_round[name] ~= nil then
		return current_round[name]
	end
	return default
end

function BALATRO.get_round_resets()
	local game = BALATRO.get_game()
	return game and game.round_resets or nil
end

function BALATRO.get_round_reset_value(name, default)
	local round_resets = BALATRO.get_round_resets()
	if round_resets and round_resets[name] ~= nil then
		return round_resets[name]
	end
	return default
end

function BALATRO.set_round_reset_value(name, value)
	local round_resets = BALATRO.get_round_resets()
	if not round_resets or type(name) ~= "string" or name == "" then
		return false
	end

	round_resets[name] = value
	return true
end

function BALATRO.get_current_blind()
	local game = BALATRO.get_game()
	return game and game.blind or nil
end

function BALATRO.get_selected_back()
	local game = BALATRO.get_game()
	return game and game.selected_back or nil
end

function BALATRO.get_current_blind_key()
	local blind = BALATRO.get_current_blind()
	return blind and blind.config and blind.config.blind and blind.config.blind.key or blind and blind.name or nil
end

function BALATRO.get_current_blind_mult()
	local blind = BALATRO.get_current_blind()
	return blind and blind.mult or nil
end

function BALATRO.get_current_blind_target_chips()
	local blind = BALATRO.get_current_blind()
	return blind and blind.chips or nil
end

function BALATRO.get_blind_on_deck()
	local game = BALATRO.get_game()
	return game and game.blind_on_deck or nil
end

function BALATRO.set_blind_on_deck(row)
	local game = BALATRO.get_game()
	if not game then
		return false
	end

	game.blind_on_deck = row
	return true
end

function BALATRO.get_blind_states()
	local round_resets = BALATRO.get_round_resets()
	return round_resets and round_resets.blind_states or nil
end

function BALATRO.get_blind_state(row)
	local blind_states = BALATRO.get_blind_states()
	return blind_states and row and blind_states[row] or nil
end

function BALATRO.set_blind_state(row, value)
	local blind_states = BALATRO.get_blind_states()
	if not blind_states or not row then
		return false
	end

	blind_states[row] = value
	return true
end

function BALATRO.get_blind_choices()
	local round_resets = BALATRO.get_round_resets()
	return round_resets and round_resets.blind_choices or nil
end

function BALATRO.get_blind_choice(row)
	local blind_choices = BALATRO.get_blind_choices()
	return blind_choices and row and blind_choices[row] or nil
end

function BALATRO.get_pvp_blind_choices()
	local round_resets = BALATRO.get_round_resets()
	return round_resets and round_resets.pvp_blind_choices or nil
end

function BALATRO.get_pvp_blind_choice(row)
	local pvp_blind_choices = BALATRO.get_pvp_blind_choices()
	return pvp_blind_choices and row and pvp_blind_choices[row] or nil
end

function BALATRO.get_blind_select_options()
	local root = get_game_root()
	return root and root.blind_select_opts or nil
end

function BALATRO.get_blind_select_option_box(blind_row)
	local blind_select_opts = BALATRO.get_blind_select_options()
	if not blind_select_opts or not blind_row then
		return nil
	end

	return blind_select_opts[string.lower(blind_row)]
end

function BALATRO.get_play_cards()
	local root = get_game_root()
	return root and root.play and root.play.cards or nil
end

function BALATRO.get_play_area()
	local root = get_game_root()
	return root and root.play or nil
end

function BALATRO.get_hand_cards()
	local root = get_game_root()
	return root and root.hand and root.hand.cards or nil
end

function BALATRO.get_hand_area()
	local root = get_game_root()
	return root and root.hand or nil
end

function BALATRO.get_deck_area()
	local root = get_game_root()
	return root and root.deck or nil
end

function BALATRO.get_discard_area()
	local root = get_game_root()
	return root and root.discard or nil
end

function BALATRO.get_joker_cards()
	local root = get_game_root()
	return root and root.jokers and root.jokers.cards or nil
end

function BALATRO.get_jokers_area()
	local root = get_game_root()
	return root and root.jokers or nil
end

function BALATRO.get_consumeables_area()
	local root = get_game_root()
	return root and root.consumeables or nil
end

function BALATRO.get_playing_cards()
	local root = get_game_root()
	return root and root.playing_cards or nil
end

function BALATRO.get_tags()
	local game = BALATRO.get_game()
	return game and game.tags or nil
end

function BALATRO.get_tag_def(key)
	local root = get_game_root()
	return root and root.P_TAGS and root.P_TAGS[key] or nil
end

function BALATRO.get_hands()
	local game = BALATRO.get_game()
	return game and game.hands or nil
end

function BALATRO.get_or_create_orbital_choices_for_ante(ante)
	local game = BALATRO.get_game()
	if not game or ante == nil then
		return nil
	end

	game.orbital_choices = game.orbital_choices or {}
	game.orbital_choices[ante] = game.orbital_choices[ante] or {}
	return game.orbital_choices[ante]
end

function BALATRO.get_hands_left()
	return BALATRO.get_current_round_value("hands_left", nil)
end

function BALATRO.get_hand_level(hand)
	local hands = BALATRO.get_hands()
	local hand_state = hands and hands[hand] or nil
	return hand_state and hand_state.level or nil
end

function BALATRO.get_highest_level_poker_hand(is_hand_visible)
	local hands = BALATRO.get_hands()
	local hand_type = "High Card"
	local max_level = 0

	for key, hand_state in pairs(hands or {}) do
		local visible = is_hand_visible and is_hand_visible(key, hand_state) or hand_state.visible
		if visible then
			if
				to_big(hand_state.level) > to_big(max_level)
				or (
					to_big(hand_state.level) == to_big(max_level)
					and (POKER_HAND_LEVEL_PRIORITY[key] or math.huge) < (POKER_HAND_LEVEL_PRIORITY[hand_type] or math.huge)
				)
			then
				hand_type = key
				max_level = hand_state.level
			end
		end
	end

	return hand_type, max_level
end

function BALATRO.get_blind_defs()
	local root = get_game_root()
	return root and root.P_BLINDS or nil
end

function BALATRO.get_blind_def(key)
	local blinds = BALATRO.get_blind_defs()
	return blinds and blinds[key] or nil
end

function BALATRO.get_card_front(key)
	local root = get_game_root()
	return root and root.P_CARDS and root.P_CARDS[key] or nil
end

function BALATRO.get_center(key)
	local root = get_game_root()
	return root and root.P_CENTERS and root.P_CENTERS[key] or nil
end

function BALATRO.get_center_key(center)
	local root = get_game_root()
	local centers = root and root.P_CENTERS or nil
	if not centers or center == nil then
		return nil
	end

	for key, candidate in pairs(centers) do
		if candidate == center then
			return key
		end
	end
	return nil
end

function BALATRO.get_seal(key)
	local root = get_game_root()
	return root and root.P_SEALS and root.P_SEALS[key] or nil
end

function BALATRO.get_used_vouchers()
	local game = BALATRO.get_game()
	return game and game.used_vouchers or nil
end

function BALATRO.get_skips()
	local game = BALATRO.get_game()
	return game and game.skips or nil
end

function BALATRO.get_settings()
	local root = get_game_root()
	return root and root.SETTINGS or nil
end

function BALATRO.get_setting_value(name, default)
	local settings = BALATRO.get_settings()
	if settings and settings[name] ~= nil then
		return settings[name]
	end

	return default
end

function BALATRO.get_game_speed()
	return tonumber(BALATRO.get_setting_value("GAMESPEED", 1)) or 1
end

function BALATRO.set_setting_value(name, value)
	local settings = BALATRO.get_settings()
	if not settings or type(name) ~= "string" or name == "" then
		return false
	end

	settings[name] = value
	return true
end

function BALATRO.set_current_setup(value)
	local settings = BALATRO.get_settings()
	if not settings then
		return false
	end

	settings.current_setup = value
	return true
end

function BALATRO.get_player_id()
	local root = get_game_root()
	return root and root.MP_ID or nil
end

function BALATRO.get_version()
	local root = get_game_root()
	return root and root.VERSION or nil
end

function BALATRO.get_action()
	local root = get_game_root()
	return root and root.action or nil
end

function BALATRO.set_player_id(player_id)
	local root = get_game_root()
	if not root then
		return false
	end

	root.MP_ID = player_id
	return true
end

function BALATRO.clear_player_id()
	return BALATRO.set_player_id(nil)
end

function BALATRO.get_card_width()
	local root = get_game_root()
	return root and root.CARD_W or nil
end

function BALATRO.get_card_height()
	local root = get_game_root()
	return root and root.CARD_H or nil
end

function BALATRO.get_starting_joker_slots()
	local game = BALATRO.get_game()
	return game and game.starting_params and game.starting_params.joker_slots or nil
end

function BALATRO.get_starting_ante_scaling()
	local game = BALATRO.get_game()
	return game and game.starting_params and game.starting_params.ante_scaling or nil
end

function BALATRO.get_ante()
	return BALATRO.get_round_reset_value("ante", nil)
end

function BALATRO.get_chips()
	local game = BALATRO.get_game()
	return game and game.chips or 0
end

function BALATRO.set_chips(value)
	local game = BALATRO.get_game()
	if not game then
		return false
	end

	game.chips = value
	return true
end

function BALATRO.set_chips_text(value)
	local game = BALATRO.get_game()
	if not game then
		return false
	end

	game.chips_text = value
	return true
end

function BALATRO.get_stake()
	local game = BALATRO.get_game()
	return game and game.stake or nil
end

function BALATRO.get_modifiers()
	return BALATRO.get_game_value("modifiers", nil)
end

function BALATRO.get_modifier_value(name, default)
	local modifiers = BALATRO.get_modifiers()
	if modifiers and modifiers[name] ~= nil then
		return modifiers[name]
	end

	return default
end

function BALATRO.get_mp_card_next_id()
	local game = BALATRO.get_game()
	return game and game.mp_card_next_id or nil
end

function BALATRO.set_mp_card_next_id(value)
	local game = BALATRO.get_game()
	if not game then
		return false
	end

	game.mp_card_next_id = value
	return true
end

function BALATRO.get_controller_lock(name)
	local root = get_game_root()
	local locks = root and root.CONTROLLER and root.CONTROLLER.locks or nil
	if not locks or type(name) ~= "string" or name == "" then
		return nil
	end

	return locks[name]
end

function BALATRO.save_object(value)
	return value and value.save and value:save() or nil
end

function BALATRO.is_tag_instance(value)
	local tag_class = rawget(_G, "Tag")
	return not not (tag_class and type(value) == "table" and value.is and value:is(tag_class))
end

function BALATRO.is_card_area_instance(value)
	local card_area_class = rawget(_G, "CardArea")
	return not not (card_area_class and type(value) == "table" and value.is and value:is(card_area_class))
end

function BALATRO.get_state_complete()
	local root = get_game_root()
	return root and root.STATE_COMPLETE or nil
end

function BALATRO.set_state_complete(value)
	local root = get_game_root()
	if not root then
		return false
	end

	root.STATE_COMPLETE = value
	return true
end

function BALATRO.set_state(value)
	local root = get_game_root()
	if not root then
		return false
	end

	root.STATE = value
	return true
end
