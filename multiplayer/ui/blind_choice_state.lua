MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_STATE = MP.UI.BLIND_CHOICE_STATE or {}

local blind_choice_state = MP.UI.BLIND_CHOICE_STATE
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local PREVIEW_BLIND_ROWS = { "Small", "Big", "Boss" }

local function can_sync_coop_blind_preview()
	return MP.LOBBY
		and MP.LOBBY.code
		and MP.ACTIONS
		and MP.ACTIONS.blind_preview
		and MP.is_coop_gamemode
		and MP.is_coop_gamemode()
		and MP.uses_shared_sync_group
		and MP.uses_shared_sync_group()
end

local function normalize_preview_key_part(value)
	if value == nil then
		return ""
	end

	return tostring(value)
end

function blind_choice_state.get_preview_key()
	local ante = BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("blind_ante", nil) or nil
	if ante == nil then
		ante = BALATRO.get_ante and BALATRO.get_ante() or nil
	end

	local parts = {
		"ante:" .. normalize_preview_key_part(ante),
		"deck:" .. normalize_preview_key_part(BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck() or nil),
	}
	for _, row in ipairs(PREVIEW_BLIND_ROWS) do
		local blind_key = BALATRO.get_blind_choice and BALATRO.get_blind_choice(row) or nil
		local pvp_flag = BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(row) and "pvp" or "coop"
		parts[#parts + 1] = row .. ":" .. normalize_preview_key_part(blind_key) .. ":" .. pvp_flag
	end

	return table.concat(parts, "|")
end

local function parse_preview_target(value)
	if value == nil then
		return nil
	end
	if BALATRO.to_score_number then
		local numeric_value = BALATRO.to_score_number(value)
		if numeric_value ~= nil then
			return numeric_value
		end
	elseif type(value) == "number" then
		return value
	end

	if type(to_big) == "function" then
		local ok, parsed = pcall(to_big, value)
		if ok and parsed ~= nil then
			local numeric_value = BALATRO.to_score_number and BALATRO.to_score_number(parsed) or nil
			if numeric_value ~= nil then
				return numeric_value
			end
			if type(parsed) ~= "string" then
				return parsed
			end
		end
	end

	return tonumber(value)
end

local function get_server_preview_target(row)
	if not (MP.GAME and row) then
		return nil
	end

	local preview_key = blind_choice_state.get_preview_key and blind_choice_state.get_preview_key() or nil
	if MP.GAME.coop_blind_preview_key ~= preview_key then
		return nil
	end

	local targets = MP.GAME.coop_blind_preview_targets
	return targets and targets[row] or nil
end

local function send_debounced_coop_blind_preview()
	if not (can_sync_coop_blind_preview() and BALATRO.queue_event) then
		return
	end
	if MP.GAME.coop_blind_preview_send_scheduled then
		return
	end

	MP.GAME.coop_blind_preview_send_scheduled = true
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.05,
		func = function()
			if MP.GAME then
				MP.GAME.coop_blind_preview_send_scheduled = false
			end
			if can_sync_coop_blind_preview() and MP.GAME then
				MP.ACTIONS.blind_preview(
					MP.GAME.local_coop_blind_preview_key,
					MP.GAME.local_coop_blind_preview_targets or {}
				)
			end
			return true
		end,
	})
end

local function record_local_coop_blind_preview(row, target)
	if not (MP.GAME and row and target ~= nil and can_sync_coop_blind_preview()) then
		return
	end

	local preview_key = blind_choice_state.get_preview_key()
	if MP.GAME.local_coop_blind_preview_key ~= preview_key then
		MP.GAME.local_coop_blind_preview_key = preview_key
		MP.GAME.local_coop_blind_preview_targets = {}
	end
	MP.GAME.local_coop_blind_preview_targets[row] = target

	send_debounced_coop_blind_preview()
end

local function is_active_lobby_player(player)
	return player and player.is_in_match ~= false and player.is_disconnected ~= true
end

local function get_self_lobby_player()
	local self_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.id == self_id then
			return player
		end
	end
	return nil
end

local function get_active_preview_group_players()
	local players = {}
	if not (MP.LOBBY and MP.LOBBY.players) then
		return players
	end

	if MP.is_coop_lobby_type and MP.is_coop_lobby_type() then
		for _, player in ipairs(MP.LOBBY.players) do
			if is_active_lobby_player(player) then
				players[#players + 1] = player
			end
		end
		return players
	end

	local self_player = get_self_lobby_player()
	for _, player in ipairs(MP.LOBBY.players) do
		if
			is_active_lobby_player(player)
			and MP.lobby_players_share_sync_group
			and MP.lobby_players_share_sync_group(self_player, player)
		then
			players[#players + 1] = player
		end
	end
	return players
end

local function get_current_blind_target_scale()
	local scale = BALATRO.get_starting_ante_scaling and BALATRO.get_starting_ante_scaling() or 1
	local paperback = BALATRO.get_game_value and BALATRO.get_game_value("paperback", nil) or nil
	if paperback and paperback.blind_multiplier ~= nil then
		scale = scale * paperback.blind_multiplier
	end
	return scale
end

local function sync_local_blind_target_scale(scale)
	if MP.ACTIONS and MP.ACTIONS.sync_blind_target_scale then
		MP.ACTIONS.sync_blind_target_scale(scale)
	end
end

local function get_player_blind_target_scale(player, local_scale)
	if player and player.is_self then
		return local_scale
	end
	local scale = tonumber(player and player.blind_target_scale)
	if scale ~= nil then
		return scale
	end
	return nil
end

local function get_locally_predicted_shared_target(base_blind_amt, local_scale)
	if not can_sync_coop_blind_preview() then
		return nil
	end

	local players = get_active_preview_group_players()
	if #players <= 1 then
		return nil
	end

	local total = nil
	for _, player in ipairs(players) do
		local player_scale = get_player_blind_target_scale(player, local_scale)
		if player_scale == nil then
			return nil
		end

		local player_target = base_blind_amt * player_scale
		if MP.scale_coop_blind_amount then
			player_target = MP.scale_coop_blind_amount(player_target)
		end
		total = total and (total + player_target) or player_target
	end

	if not total then
		return nil
	end
	return total / #players
end

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
		if MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active() and MP.GHOST.get_nemesis_name then
			return MP.GHOST.get_nemesis_name()
		end
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

local function build_blind_amount(blind_choice_config, type, is_pvp_blind)
	local base_blind_amt = BALATRO.get_blind_amount(BALATRO.get_round_reset_value("blind_ante", nil))
		* blind_choice_config.mult
	local local_blind_target_scale = get_current_blind_target_scale()
	sync_local_blind_target_scale(local_blind_target_scale)
	local blind_amt = base_blind_amt * local_blind_target_scale

	if is_pvp_blind or (BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(type)) then
		return "????"
	end

	if can_sync_coop_blind_preview() then
		if MP.is_coop_run and MP.is_coop_run() and MP.scale_coop_blind_amount then
			blind_amt = MP.scale_coop_blind_amount(blind_amt)
		end
		record_local_coop_blind_preview(type, blind_amt)
		local preview_target = get_server_preview_target(type)
		if preview_target ~= nil then
			return preview_target
		end
		local predicted_target = get_locally_predicted_shared_target(base_blind_amt, local_blind_target_scale)
		if predicted_target ~= nil then
			return predicted_target
		end
	end

	return blind_amt
end

local function get_preview_score_node(row)
	local box = BALATRO.get_blind_select_option_box and BALATRO.get_blind_select_option_box(row) or nil
	if not (box and box.get_UIE_by_ID) then
		return nil, nil
	end

	return box:get_UIE_by_ID("mp_blind_preview_score_" .. tostring(row)), box
end

function blind_choice_state.refresh_coop_blind_preview_scores()
	for _, row in ipairs(PREVIEW_BLIND_ROWS) do
		local target = get_server_preview_target(row)
		if target ~= nil then
			local score_node, box = get_preview_score_node(row)
			if score_node and score_node.config then
				score_node.config.text = number_format(target)
				score_node.config.scale = score_number_scale(0.9, target)
				BALATRO.recalculate_ui(score_node)
				BALATRO.recalculate_ui(box)
			end
		end
	end
end

function blind_choice_state.handle_coop_blind_preview(preview_key, targets)
	if not MP.GAME then
		return
	end

	local parsed_targets = {}
	if type(targets) == "table" then
		for _, row in ipairs(PREVIEW_BLIND_ROWS) do
			local parsed = parse_preview_target(targets[row])
			if parsed ~= nil then
				parsed_targets[row] = parsed
			end
		end
	end

	MP.GAME.coop_blind_preview_key = tostring(preview_key or "")
	MP.GAME.coop_blind_preview_targets = parsed_targets
	blind_choice_state.refresh_coop_blind_preview_scores()
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
	local uses_duel_ready_flow = MP.is_duel_bye_blind_row and MP.is_duel_bye_blind_row(type)
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
		row = type,
		blind_choice = blind_choice,
		blind_col = BALATRO.get_blind_main_colour and BALATRO.get_blind_main_colour(type) or nil,
		blind_amt = build_blind_amount(blind_choice.config, type, is_pvp_blind),
		blind_state = blind_state,
		loc_name = build_blind_name(blind_choice.config, is_pvp_blind),
		reward = reward,
		run_info_colour = get_run_info_colour(run_info, blind_state),
		stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite(BALATRO.get_stake() or 1, 0.5) or nil,
		text_table = build_blind_text_table(blind_choice.config, type),
		use_mp_ready_flow = uses_pvp_ready_flow or uses_duel_ready_flow or MP.is_teams_mode() or (MP.is_coop_lobby_type and MP.is_coop_lobby_type()),
	}
end
