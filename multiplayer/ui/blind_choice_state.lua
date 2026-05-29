MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_STATE = MP.UI.BLIND_CHOICE_STATE or {}

local blind_choice_state = MP.UI.BLIND_CHOICE_STATE

local function get_blind_choice_poker_hands()
	local poker_hands = {}
	if MP.should_use_the_order() then
		return MP.sorted_hand_list()
	end

	for key in pairs(G.GAME.hands) do
		if MP.PLATFORM.SMODS.is_poker_hand_visible(key) then
			poker_hands[#poker_hands + 1] = key
		end
	end
	return poker_hands
end

function blind_choice_state.ensure_orbital_choice_for_blind(type)
	G.GAME.orbital_choices = G.GAME.orbital_choices or {}
	G.GAME.orbital_choices[G.GAME.round_resets.ante] = G.GAME.orbital_choices[G.GAME.round_resets.ante] or {}

	if not G.GAME.orbital_choices[G.GAME.round_resets.ante][type] then
		G.GAME.orbital_choices[G.GAME.round_resets.ante][type] =
			pseudorandom_element(get_blind_choice_poker_hands(), pseudoseed("orbital"))
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
		blind_pos = G.P_BLINDS[pvp_blind_key].pos
	end

	local animation = AnimatedSprite(0, 0, 1.4, 1.4, G.ANIMATION_ATLAS[blind_atlas], blind_pos)
	animation:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})

	return animation
end

local function build_blind_name(blind_choice_config, is_pvp_blind)
	if is_pvp_blind then
		return ((MP.get_nemesis_lobby_player and MP.get_nemesis_lobby_player() or {}).username or localize("k_nemesis"))
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
					and localize(G.GAME.current_round.most_played_poker_hand, "poker_hands")
				or "",
		},
	})

	if G.GAME.round_resets.pvp_blind_choices[type] then
		loc_target[#loc_target + 1] = localize("k_bl_mostchips")
	end

	return loc_target
end

local function build_blind_amount(blind_choice_config, type, is_pvp_blind)
	local blind_amt = get_blind_amount(G.GAME.round_resets.blind_ante)
		* blind_choice_config.mult
		* G.GAME.starting_params.ante_scaling

	if is_pvp_blind or G.GAME.round_resets.pvp_blind_choices[type] then
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
	local blind_key = G.GAME.round_resets.blind_choices[type]
	local is_pvp_blind = blind_key == "bl_mp_nemesis"
	local uses_pvp_ready_flow = is_pvp_blind or G.GAME.round_resets.pvp_blind_choices[type]
	local pvp_blind_key = is_pvp_blind and MP.UTILS.get_pvp_blind_key()
	local blind_choice = {
		config = G.P_BLINDS[blind_key],
	}

	blind_choice.animation = build_blind_choice_animation(blind_choice.config, pvp_blind_key, is_pvp_blind)

	blind_choice_state.ensure_orbital_choice_for_blind(type)
	G.GAME.round_resets.blind_ante = G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante

	local blind_state = G.GAME.round_resets.blind_states[type]
	local reward = true
	if G.GAME.modifiers.no_blind_reward and G.GAME.modifiers.no_blind_reward[type] then
		reward = nil
	end
	if blind_state == "Select" then
		blind_state = "Current"
	end

	return {
		blind_choice = blind_choice,
		blind_col = get_blind_main_colour(type),
		blind_amt = build_blind_amount(blind_choice.config, type, is_pvp_blind),
		blind_state = blind_state,
		loc_name = build_blind_name(blind_choice.config, is_pvp_blind),
		reward = reward,
		run_info_colour = get_run_info_colour(run_info, blind_state),
		stake_sprite = get_stake_sprite(G.GAME.stake or 1, 0.5),
		text_table = build_blind_text_table(blind_choice.config, type),
		use_mp_ready_flow = uses_pvp_ready_flow or MP.is_teams_mode() or (MP.is_coop_gamemode and MP.is_coop_gamemode()),
	}
end

MP.UI.ensure_orbital_choice_for_blind = blind_choice_state.ensure_orbital_choice_for_blind
MP.UI.get_blind_choice_context = blind_choice_state.build_context
