local BALATRO = MP.PLATFORM.BALATRO
local ROW_VIEW_MODEL = MP.UI and MP.UI.PLAYER_ROW_VIEW_MODEL or {}
local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
local parse_score_int = score_shared.try_parse_score_int
local SCORE_LANE_WIDTH = 2.87

local function same_insane_int(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end

	return (tonumber(left.e_count) or 0) == (tonumber(right.e_count) or 0)
		and (tonumber(left.exponent) or 0) == (tonumber(right.exponent) or 0)
		and (tonumber(left.coefficient) or 0) == (tonumber(right.coefficient) or 0)
end

local function get_localized_text(key, fallback)
	local value = localize(key)
	if type(value) == "string" and value ~= "" and value ~= "ERROR" and value ~= key then
		return value
	end
	return fallback
end

local function get_player_skips(enemy_state, is_self)
	if is_self then
		local local_skips = BALATRO.get_skips and BALATRO.get_skips() or (G and G.GAME and G.GAME.skips)
		return tonumber(local_skips) or 0
	end
	return tonumber(enemy_state and enemy_state.skips) or 0
end

local function build_match_lobby_row_runtime_fields(player, lobby_context, is_self)
	local enemy_state = is_self and nil or (MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player.id] or nil)
	local capabilities = lobby_context.capabilities or {}
	local same_sync_group = MP.lobby_players_share_sync_group
		and MP.lobby_players_share_sync_group(lobby_context.self_player, player, capabilities)
	local can_show_money_action = lobby_context.can_show_shared_money_actions
		and not is_self
		and same_sync_group
		and BALATRO.is_run_stage()

	local raw_location
	local location
	if is_self then
		raw_location = (MP.GAME and MP.GAME.location) or "loc_selecting"
		location = MP.UI.localize_location(raw_location)
	elseif player.is_disconnected then
		raw_location = "loc_disconnected"
		location = player.location or MP.UI.localize_location("loc_disconnected")
	else
		raw_location = (enemy_state and enemy_state.raw_location) or player.raw_location or "loc_selecting"
		location = (enemy_state and enemy_state.location) or player.location or MP.UI.localize_location(raw_location)
	end

	local lives
	local highest_score
	local score_display_int
	local skips = get_player_skips(enemy_state, is_self)
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
		raw_location = raw_location,
		location = location,
		lives = lives,
		skips = skips,
		highest_score = highest_score,
		score_display_int = score_display_int,
		can_show_money_action = can_show_money_action,
		can_send_money = can_show_money_action,
		row_colour = lobby_context.uses_team_colours and (MP.TEAM_COLORS[player.team or 1] or G.C.WHITE)
			or darken(G.C.JOKER_GREY, 0.1),
	}
end

local function build_match_lobby_player_row_model(player, index, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local row_model = ROW_VIEW_MODEL.build_lobby_player_row_model(player, index, {
		lobby_context = lobby_context,
	})
	local runtime_fields = build_match_lobby_row_runtime_fields(player, lobby_context, row_model.is_self)
	row_model.is_host = not not lobby_context.is_host

	for key, value in pairs(runtime_fields) do
		row_model[key] = value
	end

	-- Spectator means spectator; eliminated players are conveyed by lives = 0
	-- in the lives lane, not by a spectator chip.
	row_model.is_spectator = not not (
		row_model.is_spectator
		or player.is_spectator
		or player.role == "spectator"
	)

	row_model.show_lives_lane = not lobby_context.is_coop_gamemode
	if row_model.show_lives_lane then
		row_model.lives_lane_spec = {
			kind = "chip",
			text = tostring(row_model.lives) .. " " .. tostring(localize("k_lives") or "Lives"),
			colour = G.C.RED,
			minw = 1.95,
			scale = 0.45,
			slot_minw = 1.95,
		}
	end
	row_model.skip_chip_spec = {
		text = tostring(row_model.skips or 0) .. " " .. get_localized_text("k_skips", "Skips"),
		colour = G.C.PURPLE,
		minw = 1.75,
		scale = 0.45,
		slot_minw = 1.75,
	}
	row_model.kick_match_action = row_model.can_kick
			and ROW_VIEW_MODEL.create_kick_action(row_model, "_kick_match", "kick_player_match")
		or nil
	row_model.location_lane_spec = {
		kind = "location_lane",
		raw_location = row_model.raw_location,
		display = MP.UI.UTILS.resolve_location_display(row_model.raw_location, row_model.location, {
			player = player,
			is_self = row_model.is_self,
		}),
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
		minw = SCORE_LANE_WIDTH,
		scale = 0.45,
		text_colour = G.C.WHITE,
		slot_minw = SCORE_LANE_WIDTH,
		minh = 0.46,
		stake_scale = 0.38,
		show_stake_icon = true,
	}
	row_model.money_action_spec = row_model.can_show_money_action and {
		kind = "action",
		disableable = true,
		id = row_model.id .. "_view_team_money_transfer",
		button = "view_team_money_transfer",
		label = localize("b_send_money"),
		disabled_text = localize("b_send_money"),
		colour = G.C.MONEY,
		text_colour = G.C.UI.TEXT_LIGHT,
		tooltip = { localize("k_transfer_money") },
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
ROW_VIEW_MODEL.build_match_lobby_player_row_model = build_match_lobby_player_row_model
