MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_STATE = MP.UI.BLIND_CHOICE_STATE or {}

local blind_choice_state = MP.UI.BLIND_CHOICE_STATE
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_blind_choice_poker_hands()
	local poker_hands = {}
	if MP.should_use_the_order() then
		return MP.sorted_hand_list()
	end

	for key in pairs(BALATRO.get_hands and BALATRO.get_hands() or {}) do
		if MP.PLATFORM.SMODS.is_poker_hand_visible(key) then
			poker_hands[#poker_hands + 1] = key
		end
	end
	return poker_hands
end

function blind_choice_state.ensure_orbital_choice_for_blind(type)
	local ante = BALATRO.get_ante and BALATRO.get_ante() or nil
	local choices = BALATRO.get_or_create_orbital_choices_for_ante
		and BALATRO.get_or_create_orbital_choices_for_ante(ante) or nil
	if not choices then
		return
	end

	if not choices[type] then
		choices[type] = pseudorandom_element(get_blind_choice_poker_hands(), pseudoseed("orbital"))
	end
end

local function build_blind_choice_animation(blind_choice_config, pvp_blind_key, is_pvp_blind)
	local blind_atlas = "blind_chips"
	local blind_pos = blind_choice_config.pos
	if blind_choice_config and blind_choice_config.atlas then
		blind_atlas = blind_choice_config.atlas
	end
	if is_pvp_blind then
		blind_atlas = "mp_player_blind_col"
		local pvp_blind = BALATRO.get_blind_def and BALATRO.get_blind_def(pvp_blind_key) or nil
		blind_pos = pvp_blind and pvp_blind.pos or blind_pos
	end

	local animation = BALATRO.create_animated_sprite(0, 0, 1.4, 1.4, BALATRO.get_animation_atlas(blind_atlas), blind_pos)
	animation:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})

	return animation
end

local function build_blind_name(blind_choice_config, is_pvp_blind)
	if is_pvp_blind then
		local opponents = MP.OPPONENTS or {}
		return ((opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player() or {}).username or localize("k_nemesis"))
	end

	return localize({ type = "name_text", key = blind_choice_config.key, set = "Blind" })
end

local function build_blind_text_table(blind_choice_config, type)
	local loc_target = localize({
		type = "raw_descriptions",
		key = blind_choice_config.key,
		set = "Blind",
		vars = {
			blind_choice_config.key == "bl_ox"
					and localize(BALATRO.get_current_round_value("most_played_poker_hand", nil), "poker_hands")
				or "",
		},
	})

	if BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(type) then
		loc_target[#loc_target + 1] = localize("k_bl_mostchips")
	end

	return loc_target
end

local function apply_runtime_blind_amount_modifiers(blind_amt)
	local paperback = BALATRO.get_game_value and BALATRO.get_game_value("paperback", nil) or nil
	if paperback and paperback.blind_multiplier ~= nil then
		blind_amt = blind_amt * paperback.blind_multiplier
	end

	return blind_amt
end

local function build_blind_amount(blind_choice_config, type, is_pvp_blind)
	local blind_amt = BALATRO.get_blind_amount(BALATRO.get_round_reset_value("blind_ante", nil))
		* blind_choice_config.mult
		* (BALATRO.get_starting_ante_scaling and BALATRO.get_starting_ante_scaling() or 1)
	blind_amt = apply_runtime_blind_amount_modifiers(blind_amt)

	if is_pvp_blind or (BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(type)) then
		return "????"
	end

	if MP.is_coop_gamemode and MP.is_coop_gamemode() then
		blind_amt = MP.scale_coop_blind_amount(blind_amt)
	end

	return blind_amt
end

local function get_run_info_colour(run_info, blind_state)
	if not run_info then
		return nil
	end

	return blind_state == "Defeated" and G.C.GREY
		or blind_state == "Skipped" and G.C.BLUE
		or blind_state == "Upcoming" and G.C.ORANGE
		or blind_state == "Current" and G.C.RED
		or G.C.GOLD
end

function blind_choice_state.build_context(type, run_info)
	local blind_key = BALATRO.get_blind_choice and BALATRO.get_blind_choice(type) or nil
	local is_pvp_blind = blind_key == "bl_mp_nemesis"
	local uses_pvp_ready_flow = is_pvp_blind or (BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(type))
	local pvp_blind_key = is_pvp_blind and MP.UTILS.get_pvp_blind_key()
	local blind_choice = {
		config = BALATRO.get_blind_def and BALATRO.get_blind_def(blind_key) or nil,
	}

	blind_choice.animation = build_blind_choice_animation(blind_choice.config, pvp_blind_key, is_pvp_blind)

	blind_choice_state.ensure_orbital_choice_for_blind(type)
	if BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("blind_ante", nil) == nil then
		BALATRO.set_round_reset_value("blind_ante", BALATRO.get_ante and BALATRO.get_ante() or nil)
	end

	local blind_state = BALATRO.get_blind_state and BALATRO.get_blind_state(type) or nil
	local reward = true
	local no_blind_reward = BALATRO.get_modifier_value and BALATRO.get_modifier_value("no_blind_reward", nil) or nil
	if no_blind_reward and no_blind_reward[type] then
		reward = nil
	end
	if blind_state == "Select" then
		blind_state = "Current"
	end

	return {
		blind_choice = blind_choice,
		blind_col = BALATRO.get_blind_main_colour and BALATRO.get_blind_main_colour(type) or nil,
		blind_amt = build_blind_amount(blind_choice.config, type, is_pvp_blind),
		blind_state = blind_state,
		loc_name = build_blind_name(blind_choice.config, is_pvp_blind),
		reward = reward,
		run_info_colour = get_run_info_colour(run_info, blind_state),
		stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite(BALATRO.get_stake() or 1, 0.5) or nil,
		text_table = build_blind_text_table(blind_choice.config, type),
		use_mp_ready_flow = uses_pvp_ready_flow or MP.is_teams_mode() or (MP.is_coop_lobby_type and MP.is_coop_lobby_type()),
	}
end
