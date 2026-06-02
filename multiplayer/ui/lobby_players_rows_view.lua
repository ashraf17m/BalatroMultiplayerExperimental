MP.UI = MP.UI or {}
local lobby_players_ui = MP.UI.LOBBY_PLAYERS or {}
MP.UI.LOBBY_PLAYERS = lobby_players_ui
local ROW_LAYOUT = MP.UI.ROW_LAYOUT
local ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL or {}
lobby_players_ui.PLAYER_COLUMN_LIMIT = lobby_players_ui.PLAYER_COLUMN_LIMIT or 16
lobby_players_ui.PLAYER_COLUMN_GAP = lobby_players_ui.PLAYER_COLUMN_GAP or 0.24

local function create_default_row_nodes(model)
	return {
		ROW_LAYOUT.create_row_badge(model),
		{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
		ROW_LAYOUT.create_name_lane(model),
	}
end

function lobby_players_ui.create_team_picker_player_row(player_id)
	local picker_model = ROW_VIEW_MODEL.build_lobby_team_picker_model and ROW_VIEW_MODEL.build_lobby_team_picker_model(player_id) or nil
	local model = (picker_model and picker_model.row_model) or {
		id = player_id,
		username = "Guest",
		team = 1,
		row_colour = darken(G.C.JOKER_GREY, 0.1),
	}
	model.name_leading_space = false
	local row_nodes = create_default_row_nodes(model)
	local right_slot = nil
	local right_slot_minh = nil
	if model.is_owner then
		right_slot = ROW_LAYOUT.create_host_chip(true)
	elseif picker_model and picker_model.lock_action then
		right_slot = ROW_LAYOUT.create_button_from_spec(picker_model.lock_action)
		right_slot_minh = 0.42
	end
	ROW_LAYOUT.append_row_slot(row_nodes, right_slot, 1.05, right_slot_minh)

	return ROW_LAYOUT.create_player_row_shell(model, row_nodes)
end

function lobby_players_ui.create_lobby_player_row(player, surface, index, lobby_context)
	local model = ROW_VIEW_MODEL.build_lobby_player_surface_model(player, index, surface, {
		lobby_context = lobby_context,
	})
	local row_nodes = create_default_row_nodes(model)

	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.status_lane_spec)
	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.team_lane_spec)

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_host_chip(model.is_owner),
		1.05
	)

	if model.show_kick_slot then
		ROW_LAYOUT.append_row_slot(
			row_nodes,
			ROW_LAYOUT.create_action_button_from_spec(model.kick_action),
			0.65,
			0.42
		)
	end

	if model.show_make_host_slot then
		ROW_LAYOUT.append_row_slot(
			row_nodes,
			ROW_LAYOUT.create_action_button_from_spec(model.make_host_action),
			0.65,
			0.42
		)
	end

	if model.show_mod_lane then
		ROW_LAYOUT.append_row_slot(row_nodes, ROW_LAYOUT.create_mod_lane(model), 0.9)
	end

	return ROW_LAYOUT.create_player_row_shell(model, row_nodes, {
		tooltip_player_id = model.id,
	})
end

function lobby_players_ui.create_flat_player_rows(players, surface, lobby_context, start_index)
	local rows = {}
	local row_offset = (start_index or 1) - 1
	for index, player in ipairs(players) do
		ROW_LAYOUT.append_node(rows, lobby_players_ui.create_lobby_player_row(player, surface, row_offset + index, lobby_context))
	end
	return rows
end

function lobby_players_ui.should_split_player_rows(players)
	return #players > lobby_players_ui.PLAYER_COLUMN_LIMIT
end

function lobby_players_ui.create_player_row_columns(players, lobby_context, column_width)
	if not lobby_players_ui.should_split_player_rows(players) then
		return lobby_players_ui.create_flat_player_rows(players, "players", lobby_context)
	end

	local first_column_players = {}
	local second_column_players = {}
	for index, player in ipairs(players) do
		if index <= lobby_players_ui.PLAYER_COLUMN_LIMIT then
			first_column_players[#first_column_players + 1] = player
		else
			second_column_players[#second_column_players + 1] = player
		end
	end

	return {
		{
			n = G.UIT.R,
			config = { align = "tm", padding = 0 },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "tm", minw = column_width, padding = 0.02 },
					nodes = lobby_players_ui.create_flat_player_rows(first_column_players, "players", lobby_context, 1),
				},
				{ n = G.UIT.B, config = { w = lobby_players_ui.PLAYER_COLUMN_GAP, h = 0.01 } },
				{
					n = G.UIT.C,
					config = { align = "tm", minw = column_width, padding = 0.02 },
					nodes = lobby_players_ui.create_flat_player_rows(second_column_players, "players", lobby_context, lobby_players_ui.PLAYER_COLUMN_LIMIT + 1),
				},
			},
		},
	}
end
