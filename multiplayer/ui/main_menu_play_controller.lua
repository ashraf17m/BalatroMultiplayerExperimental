MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}
MP.SP = MP.SP or { ruleset = nil }
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function open_paused_overlay(definition, selected_input_id)
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = definition,
	})

	if selected_input_id then
		BALATRO.select_overlay_text_input_by_id(selected_input_id)
	end
end

local function clear_singleplayer_selection()
	if MP.clear_lobby_config_selection then
		MP.clear_lobby_config_selection()
	end
	MP.SP.ruleset = nil
end

local function set_lobby_setup_temp_code(temp_code)
	if MP.set_lobby_setup_temp_code then
		MP.set_lobby_setup_temp_code(temp_code)
	end
end

local function open_multiplayer_lobby_creation(lobby_type)
	if lobby_type and MP.set_lobby_type then
		MP.set_lobby_type(lobby_type)
	end

	open_paused_overlay(G.UIDEF.ruleset_selection_options("mp"))
end

BALATRO.set_ui_function("setup_run_singleplayer", function(e)
	clear_singleplayer_selection()
	open_paused_overlay(G.UIDEF.ruleset_selection_options("sp"))
end)

BALATRO.set_ui_function("start_sp_run", function(e)
	BALATRO.exit_overlay_menu()
	BALATRO.call_ui_function("setup_run", e)
end)

BALATRO.set_ui_function("start_vanilla_sp", function(e)
	clear_singleplayer_selection()
	BALATRO.call_ui_function("setup_run", e)
end)

BALATRO.set_ui_function("play_options", function()
	open_paused_overlay(G.UIDEF.override_main_menu_play_button())
end)

BALATRO.set_ui_function("resume_match", function()
	local pending_resume, error_message
	if MP.RESUME and MP.RESUME.begin_manual_resume then
		pending_resume, error_message = MP.RESUME.begin_manual_resume()
	end
	if not pending_resume then
		MP.UI.UTILS.overlay_message(error_message or "No saved match was found.")
		return
	end
	if MP.RESUME and MP.RESUME.repair_saved_run_snapshot then
		MP.RESUME.repair_saved_run_snapshot(pending_resume.run_snapshot)
	end

	BALATRO.exit_overlay_menu()

	if MP.LOBBY.client and MP.LOBBY.client.connected then
		MP.ACTIONS.rejoin_lobby(pending_resume.meta.lobby_code, pending_resume.meta.reconnect_token)
	else
		MP.ACTIONS.connect()
	end
end)

for _, lobby_type_spec in ipairs(MP.get_lobby_type_specs and MP.get_lobby_type_specs() or {}) do
	BALATRO.set_ui_function(lobby_type_spec.create_button_id, function()
		open_multiplayer_lobby_creation(lobby_type_spec.id)
	end)
end

BALATRO.set_ui_function("create_group_lobby", function()
	open_multiplayer_lobby_creation(MP.LOBBY_TYPES.FFA)
end)

BALATRO.set_ui_function("create_lobby", function()
	open_multiplayer_lobby_creation(MP.LOBBY_TYPES.FFA)
end)

BALATRO.set_ui_function("select_gamemode", function()
	open_paused_overlay(G.UIDEF.gamemode_selection_options())
end)

BALATRO.set_ui_function("join_lobby", function()
	open_paused_overlay(G.UIDEF.create_UIBox_join_lobby_button(), "text_input")
end)

BALATRO.set_ui_function("weekly_interrupt", function()
	if (not MP.LOBBY.config.weekly) or (MP.LOBBY.config.weekly ~= MP.LOBBY.setup.fetched_weekly) then
		BALATRO.set_paused(true)

		BALATRO.open_overlay_menu({
			definition = G.UIDEF.weekly_interrupt(not not MP.LOBBY.config.weekly),
		})
		return true
	end
	return false
end)

BALATRO.set_ui_function("set_weekly", function()
	MP.PLATFORM.SMODS.set_config_value("weekly", MP.LOBBY.setup.fetched_weekly, MP)
	MP.save_current_config()
	MP.PLATFORM.SMODS.restart_game()
end)

BALATRO.set_ui_function("skip_tutorial", function(e)
	G.SETTINGS.tutorial_complete = true
	G.SETTINGS.tutorial_progress = nil
	BALATRO.call_ui_function("play_options", e)
end)

BALATRO.set_ui_function("join_from_clipboard", function()
	local paste = MP.UTILS.get_from_clipboard()
	if not paste then
		return
	end

	local temp_code = string.sub(string.upper(paste:gsub("[^%a]", "")), 1, 5)
	set_lobby_setup_temp_code(temp_code)
	MP.ACTIONS.join_lobby(temp_code)
end)

BALATRO.set_ui_function("start_lobby", function()
	BALATRO.set_paused(false)

	local prepared, error_key = MP.prepare_lobby_config_for_creation()
	if not prepared then
		MP.UI.UTILS.overlay_message(localize(error_key == "ruleset_not_found" and "k_ruleset_not_found" or error_key))
		return
	end

	MP.ACTIONS.create_lobby(string.sub(MP.LOBBY.config.gamemode, 13))
	BALATRO.exit_overlay_menu()
end)

BALATRO.set_ui_function("join_game_submit", function()
	BALATRO.exit_overlay_menu()
	MP.ACTIONS.join_lobby(MP.LOBBY.setup.temp_code)
end)

BALATRO.set_ui_function("join_game_paste", function()
	local temp_code = MP.UTILS.get_from_clipboard()
	set_lobby_setup_temp_code(temp_code)
	MP.ACTIONS.join_lobby(temp_code)
	BALATRO.exit_overlay_menu()
end)

for gamemode, _ in pairs(MP.Gamemodes) do
	BALATRO.set_ui_function("force_" .. gamemode, function(e)
		MP.set_lobby_creation_gamemode(gamemode)
		BALATRO.call_ui_function("start_lobby", e)
	end)
end
