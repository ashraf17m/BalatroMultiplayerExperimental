local BALATRO = MP.PLATFORM.BALATRO
local ROW_VIEW_MODEL = MP.UI and MP.UI.PLAYER_ROW_VIEW_MODEL or {}
local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
local parse_score_int = score_shared.try_parse_score_int

local function build_lobby_player_row_model(player, index, opts)
	return ROW_VIEW_MODEL.build_lobby_player_row_model(player, index, opts)
end

local function create_kick_action(row_model, suffix, button)
	return ROW_VIEW_MODEL.create_kick_action(row_model, suffix, button)
end

local function get_enemy_state(player_id)
	return MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player_id] or nil
end

local function same_insane_int(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end

	return (tonumber(left.e_count) or 0) == (tonumber(right.e_count) or 0)
		and (tonumber(left.exponent) or 0) == (tonumber(right.exponent) or 0)
		and (tonumber(left.coefficient) or 0) == (tonumber(right.coefficient) or 0)
end

local function build_match_lobby_row_runtime_fields(player, lobby_context, is_self)
	local enemy_state = is_self and nil or get_enemy_state(player.id)
	local same_team = lobby_context.is_teams_mode and (player.team or 1) == (lobby_context.self_team_id or -1)
	local can_show_money_action = lobby_context.is_teams_mode
		and not is_self
		and same_team
		and BALATRO.is_run_stage()

	local location
	if is_self then
		location = MP.UI.localize_location((MP.GAME and MP.GAME.location) or "loc_selecting")
	elseif player.is_disconnected then
		location = player.location or MP.UI.localize_location("loc_disconnected")
	else
		location = (enemy_state and enemy_state.location) or player.location or MP.UI.localize_location("loc_selecting")
	end

	local lives
	local highest_score
	local score_display_int
	if is_self then
		lives = (MP.GAME and MP.GAME.lives) or 0
		highest_score = (MP.GAME and MP.GAME.highest_score) or 0
		local latest_score = parse_score_int(MP.GAME and MP.GAME.score_text)
		if same_insane_int(highest_score, latest_score) then
			score_display_int = MP.GAME and MP.GAME.score_display
		end
	else
		lives = (enemy_state and enemy_state.lives) or 0
		highest_score = (enemy_state and enemy_state.highest_score) or 0
		if same_insane_int(highest_score, enemy_state and enemy_state.synced_score) then
			score_display_int = enemy_state and enemy_state.score
		end
	end

	return {
		location = location,
		lives = lives,
		highest_score = highest_score,
		score_display_int = score_display_int,
		can_show_money_action = can_show_money_action,
		can_send_money = can_show_money_action,
		row_colour = lobby_context.is_teams_mode and (MP.TEAM_COLORS[player.team or 1] or G.C.WHITE)
			or darken(G.C.JOKER_GREY, 0.1),
	}
end

function MP.build_match_lobby_player_row_model(player, index, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local row_model = build_lobby_player_row_model(player, index, {
		lobby_context = lobby_context,
	})
	local runtime_fields = build_match_lobby_row_runtime_fields(player, lobby_context, row_model.is_self)
	row_model.is_host = not not lobby_context.is_host

	for key, value in pairs(runtime_fields) do
		row_model[key] = value
	end

	row_model.lives_lane_spec = {
		kind = "chip",
		text = tostring(row_model.lives) .. " " .. tostring(localize("k_lives") or "Lives"),
		colour = G.C.RED,
		minw = 1.95,
		scale = 0.45,
		slot_minw = 1.95,
	}
	row_model.kick_match_action = row_model.can_kick and create_kick_action(row_model, "_kick_match", "kick_player_match")
		or nil
	row_model.location_lane_spec = {
		kind = "text_lane",
		text = row_model.location,
		minw = 4.05,
		scale = 0.45,
		text_colour = G.C.UI.TEXT_LIGHT,
		slot_minw = 4.05,
	}
	local score_text = type(row_model.highest_score) == "table"
			and MP.INSANE_INT.to_string(row_model.highest_score)
			or tostring(row_model.highest_score)
	local score_display = row_model.score_display_int and score_shared.get_score_display
		and score_shared.get_score_display(score_text, row_model.score_display_int, { prefer_score_int = true })
		or nil
	row_model.score_lane_spec = {
		kind = "score_lane",
		text = score_text,
		score_display = score_display,
		minw = 2.45,
		scale = 0.45,
		text_colour = G.C.FILTER,
		slot_minw = 2.45,
	}
	row_model.money_action_spec = row_model.can_show_money_action and {
		kind = "action",
		disableable = true,
		id = row_model.id .. "_view_team_money_transfer",
		button = "view_team_money_transfer",
		label = "Send",
		disabled_text = "Send",
		colour = G.C.MONEY,
		text_colour = G.C.UI.TEXT_LIGHT,
		tooltip = { "Transfer money" },
		minw = 1.95,
		minh = 0.42,
		scale = 0.45,
		slot_minw = 1.95,
		slot_minh = 0.42,
		enabled_ref_table = { enabled = row_model.can_send_money },
		enabled_ref_value = "enabled",
	} or nil

	return row_model
end
