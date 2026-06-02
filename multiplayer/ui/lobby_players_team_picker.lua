MP.UI = MP.UI or {}
local lobby_players_ui = MP.UI.LOBBY_PLAYERS or {}
MP.UI.LOBBY_PLAYERS = lobby_players_ui
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local ROW_LAYOUT = MP.UI.ROW_LAYOUT
local ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL or {}
local TEAMS_DOMAIN = MP.DOMAIN and MP.DOMAIN.TEAMS or {}

function lobby_players_ui.create_team_picker_definition(player_id)
	local picker_model = ROW_VIEW_MODEL.build_lobby_team_picker_model and ROW_VIEW_MODEL.build_lobby_team_picker_model(player_id) or nil
	local picker_rows = ROW_LAYOUT.create_button_rows_from_specs((picker_model and picker_model.team_choice_rows) or {})

	return create_UIBox_generic_options({
		no_back = true,
		no_esc = true,
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = {
							align = "cm",
							padding = 0.12,
							colour = G.C.BLACK,
							r = 0.12,
							emboss = 0.05,
							minw = 8.0,
						},
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.02 },
								nodes = {
									lobby_players_ui.create_team_picker_player_row(player_id),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", padding = 0.06 },
								nodes = {
									{
										n = G.UIT.C,
										config = { align = "cm", padding = 0.02 },
										nodes = picker_rows,
									},
								},
							},
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.08 },
				nodes = {
					ROW_LAYOUT.create_button_from_spec((picker_model and picker_model.back_action) or {
						button = "cancel_player_team_picker",
						label = localize("b_back") or "Back",
						minw = 3.0,
						minh = 0.62,
						scale = 0.45,
						colour = G.C.ORANGE,
					}),
				},
			},
		},
	})
end

function lobby_players_ui.set_active_team_picker_player(player_id)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime and lobby_players_ui.get_overlay_runtime() or nil
	if not overlay_runtime then
		return
	end

	overlay_runtime.active_surface = "team_picker"
	overlay_runtime.active_team_picker_player_id = player_id
end

function lobby_players_ui.open_team_picker_overlay(player_id)
	if not player_id then
		return false
	end

	BALATRO.open_overlay_menu({
		definition = lobby_players_ui.create_team_picker_definition(player_id),
	})
	lobby_players_ui.set_active_team_picker_player(player_id)
	lobby_players_ui.mark_overlay("team_picker")
	return true
end

function lobby_players_ui.reopen_team_picker_overlay(player_id)
	if not player_id then
		return false
	end

	if BALATRO.get_overlay_menu() then
		BALATRO.exit_overlay_menu()
	end

	return lobby_players_ui.open_team_picker_overlay(player_id)
end

BALATRO.set_ui_function("view_player_team_picker", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id = string.match(e.config.id, "^team_picker_(.+)$")
		or string.match(e.config.id, "^(.+)_team_picker$")
	if not player_id or not (TEAMS_DOMAIN.can_edit_lobby_player_team and TEAMS_DOMAIN.can_edit_lobby_player_team(player_id)) then
		return
	end

	lobby_players_ui.open_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("choose_player_team", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id, team_id = string.match(e.config.id, "^team_choice_(.+)_(%d+)$")
	local applied_team_id = TEAMS_DOMAIN.apply_local_lobby_team_choice and TEAMS_DOMAIN.apply_local_lobby_team_choice(player_id, team_id) or nil
	if not player_id or not applied_team_id then
		return
	end

	if lobby_players_ui.suppress_next_team_picker_overlay_refresh then
		lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	end

	local self_player_id = BALATRO.get_player_id and BALATRO.get_player_id() or nil
	MP.ACTIONS.set_team(applied_team_id, player_id ~= self_player_id and player_id or nil)
	lobby_players_ui.reopen_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("toggle_player_team_lock", function(e)
	if not (e and e.config and e.config.id) then
		return
	end

	local player_id = string.match(e.config.id, "^team_lock_toggle_(.+)$")
	local next_locked = nil
	if TEAMS_DOMAIN.toggle_local_lobby_player_team_lock then
		next_locked = TEAMS_DOMAIN.toggle_local_lobby_player_team_lock(player_id)
	end
	if not player_id or next_locked == nil then
		return
	end

	if lobby_players_ui.suppress_next_team_picker_overlay_refresh then
		lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	end
	MP.ACTIONS.set_team_lock(player_id, next_locked)
	lobby_players_ui.reopen_team_picker_overlay(player_id)
end)

BALATRO.set_ui_function("cancel_player_team_picker", function()
	BALATRO.exit_overlay_menu()
	BALATRO.call_ui_function("view_players_list")
end)
