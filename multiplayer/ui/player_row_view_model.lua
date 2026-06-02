local BALATRO = MP.PLATFORM.BALATRO
MP.UI.PLAYER_ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL or {}
local ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL
local TEAMS_DOMAIN = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

local function build_lobby_team_picker_choice_rows(player_id, current_team)
	local rows = {}
	local current_row = nil

	for team_idx = 1, MP.MAX_TEAMS do
		if not current_row or #current_row.buttons >= 4 then
			current_row = {
				padding = 0.05,
				gap = 0.08,
				buttons = {},
			}
			rows[#rows + 1] = current_row
		end

		current_row.buttons[#current_row.buttons + 1] = {
			id = "team_choice_" .. tostring(player_id) .. "_" .. tostring(team_idx),
			button = "choose_player_team",
			label = TEAMS_DOMAIN.get_short_display_name(team_idx),
			minw = 1.75,
			minh = 0.62,
			scale = 0.45,
			colour = MP.TEAM_COLORS[team_idx] or G.C.WHITE,
			text_colour = G.C.WHITE,
			chosen = team_idx == current_team,
		}
	end

	return rows
end

local function count_player_mods(player)
	local mods = player and player.config and player.config.Mods or nil
	if not mods then
		return 0
	end

	local count = 0
	for _ in pairs(mods) do
		count = count + 1
	end
	return count
end

local function create_kick_action(row_model, suffix, button)
	return {
		id = row_model.id .. suffix,
		button = button,
		label = "K",
		colour = G.C.RED,
		tooltip = { localize("b_kick") },
		minw = 0.65,
	}
end
ROW_VIEW_MODEL.create_kick_action = create_kick_action

local build_lobby_player_row_model

local function get_lobby_player_display_index(player_id, opts)
	local options = opts or {}
	local players = MP.get_lobby_view_players and MP.get_lobby_view_players({
		lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or nil,
		sort_by_team = options.sort_by_team ~= false,
		match_only = options.match_only,
	}) or nil

	for index, player in ipairs(players or {}) do
		if player.id == player_id then
			return index
		end
	end

	return 1
end

local function build_lobby_team_picker_model(player_id, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local player = (MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id)) or {
		id = player_id,
		username = "Guest",
		team = 1,
	}
	local row_model = build_lobby_player_row_model(player, get_lobby_player_display_index(player_id, {
		lobby_context = lobby_context,
		sort_by_team = true,
	}), {
		lobby_context = lobby_context,
	})
	local current_team = (player and player.team) or 1
	return {
		player_id = player_id,
		player = player,
		current_team = current_team,
		lobby_context = lobby_context,
		row_model = row_model,
		lock_action = (lobby_context.is_host and not row_model.is_self) and {
			id = "team_lock_toggle_" .. tostring(player_id),
			button = "toggle_player_team_lock",
			label = row_model.is_team_locked and "LOCK" or "FREE",
			minw = 1.05,
			minh = 0.42,
			scale = 0.45,
			colour = row_model.is_team_locked and G.C.RED or G.C.GREEN,
			text_colour = G.C.WHITE,
		} or nil,
		team_choice_rows = build_lobby_team_picker_choice_rows(player_id, current_team),
		back_action = {
			button = "cancel_player_team_picker",
			label = localize("b_back") or "Back",
			minw = 3.0,
			minh = 0.62,
			scale = 0.45,
			colour = G.C.ORANGE,
		},
	}
end
ROW_VIEW_MODEL.build_lobby_team_picker_model = build_lobby_team_picker_model

build_lobby_player_row_model = function(player, index, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local is_dummy = not not player.is_dummy
	local is_self = player.is_self
	if is_self == nil then
		is_self = (player.id == BALATRO.get_player_id())
	end

	local can_manage = player.can_kick
	if can_manage == nil then
		can_manage = lobby_context.is_host and not is_self and not player.is_owner
	end
	if is_dummy then
		can_manage = false
	end

	local uses_lobby_ready = lobby_context.uses_lobby_ready
	local status_kind = nil
	local status_text = nil
	if uses_lobby_ready then
		status_kind = player.status_kind or (player.is_ready and "ready" or "waiting")
		status_text = player.status_text
		if not status_text or status_text == "" then
			status_text = player.is_ready and localize("b_ready") or localize("b_unready")
		end
	end

	local badge_colour = MP.TEAM_COLORS[player.team or 1] or G.C.WHITE
	if is_self then
		badge_colour = G.C.GOLD
	elseif player.is_owner then
		badge_colour = G.C.ORANGE
	elseif uses_lobby_ready and player.is_ready then
		badge_colour = G.C.GREEN
	end

	local can_change_team = lobby_context.is_teams_mode
		and not lobby_context.match_in_progress
		and not is_dummy
		and (lobby_context.is_host or (is_self and not player.is_team_locked))
	local row_colour = lobby_context.is_teams_mode and (MP.TEAM_COLORS[player.team or 1] or G.C.WHITE)
		or darken(G.C.JOKER_GREY, 0.1)

	return {
		id = player.id,
		index = index or 1,
		username = player.username or "Guest",
		is_dummy = is_dummy,
		is_self = is_self,
		is_owner = not not player.is_owner,
		is_ready = not not player.is_ready,
		team = player.team or 1,
		team_name = player.team_name or (MP.TEAM_NAMES[player.team or 1] or "TEAM"),
		team_colour = MP.TEAM_COLORS[player.team or 1] or G.C.WHITE,
		blind_col = player.blind_col or 1,
		status_text = status_text,
		status_kind = status_kind,
		uses_lobby_ready = uses_lobby_ready,
		can_kick = not not can_manage,
		can_make_host = not not (player.can_make_host == nil and can_manage or player.can_make_host),
		mod_count = player.mod_count or count_player_mods(player),
		cached = not not player.cached,
		badge_colour = badge_colour,
		row_colour = row_colour,
		is_team_locked = not not player.is_team_locked,
		can_change_team = not not can_change_team,
	}
end
ROW_VIEW_MODEL.build_lobby_player_row_model = build_lobby_player_row_model

local function build_lobby_player_surface_model(player, index, surface, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local row_model = build_lobby_player_row_model(player, index, {
		lobby_context = lobby_context,
	})
	local is_players_surface = surface == "players"
	local show_status_lane = not not (row_model.uses_lobby_ready and row_model.status_text and row_model.status_text ~= "")
	local show_team_lane = not not (lobby_context.is_teams_mode and is_players_surface)
	local team_lane_interactive = not not (is_players_surface and row_model.can_change_team)

	row_model.surface = surface
	row_model.show_status_lane = show_status_lane
	row_model.show_team_lane = show_team_lane
	row_model.team_lane_interactive = team_lane_interactive
	row_model.show_kick_slot = is_players_surface
	row_model.show_kick_button = not not (is_players_surface and row_model.can_kick)
	row_model.show_make_host_slot = is_players_surface
	row_model.show_make_host_button = not not (is_players_surface and row_model.can_make_host)
	row_model.show_mod_lane = true
	row_model.status_lane_spec = show_status_lane and {
		kind = "chip",
		text = row_model.status_text,
		colour = row_model.is_ready and G.C.GREEN or G.C.RED,
		minw = 1.95,
		scale = 0.45,
		slot_minw = 1.95,
		slot_minh = 0.42,
	} or nil
	row_model.team_lane_spec = show_team_lane and (
		team_lane_interactive and {
			kind = "action",
			id = row_model.id .. "_team_picker",
			button = "view_player_team_picker",
			label = TEAMS_DOMAIN.get_short_display_name(row_model.team),
			colour = row_model.team_colour,
			text_colour = G.C.WHITE,
			minw = 1.15,
			slot_minw = 1.15,
			slot_minh = 0.42,
		} or {
			kind = "chip",
			text = TEAMS_DOMAIN.get_short_display_name(row_model.team),
			colour = row_model.team_colour,
			text_colour = G.C.WHITE,
			minw = 1.15,
			scale = 0.45,
			slot_minw = 1.15,
		}
	) or nil
	row_model.kick_action = row_model.show_kick_button and create_kick_action(row_model, "_kick", "kick_player") or nil
	row_model.make_host_action = row_model.show_make_host_button and {
		id = row_model.id .. "_make_host",
		button = "make_player_host",
		label = "H",
		colour = G.C.BLUE,
		tooltip = { localize("b_make_host") },
		minw = 0.65,
	} or nil

	return row_model
end
ROW_VIEW_MODEL.build_lobby_player_surface_model = build_lobby_player_surface_model
