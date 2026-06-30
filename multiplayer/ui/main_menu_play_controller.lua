MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

local function settle_selection_info_area()
	local overlay = BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() or nil
	local replace_object = MP.UI and MP.UI.UTILS and MP.UI.UTILS.replace_config_object or nil
	if not (overlay and replace_object) then
		return
	end

	for _, area_id in ipairs({ "ruleset_area", "gamemode_area" }) do
		local info_area = overlay:get_UIE_by_ID(area_id)
		local object = info_area and info_area.config and info_area.config.object or nil
		if object then
			replace_object(info_area, object, {
				recalculate_target = overlay,
			})
			break
		end
	end
end

local function open_paused_overlay(definition, selected_input_id)
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = definition,
	})
	settle_selection_info_area()

	if selected_input_id then
		BALATRO.select_overlay_text_input_by_id(selected_input_id)
	end
end

local function clear_singleplayer_selection()
	if lobby_domain.clear_config_selection then
		lobby_domain.clear_config_selection()
	end
	if MP.clear_practice_mode then
		MP.clear_practice_mode()
	end
end

local function store_join_lobby_code(temp_code)
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(temp_code)
	end
end

local function create_ruleset_selection_overlay(initial_ruleset_key, options)
	if G.UIDEF.ruleset_selection_tabs then
		return G.UIDEF.ruleset_selection_tabs(initial_ruleset_key, options)
	end
	return G.UIDEF.ruleset_selection_options(initial_ruleset_key, options)
end

local function create_gamemode_selection_overlay(initial_gamemode_key, options)
	if G.UIDEF.gamemode_selection_tabs then
		return G.UIDEF.gamemode_selection_tabs(initial_gamemode_key, options)
	end
	return G.UIDEF.gamemode_selection_options(initial_gamemode_key, options)
end

local function open_multiplayer_lobby_creation(lobby_type)
	if MP.clear_practice_mode then
		MP.clear_practice_mode()
	end
	if lobby_type and lobby_domain.set_lobby_type then
		lobby_domain.set_lobby_type(lobby_type)
	end

	open_paused_overlay(create_ruleset_selection_overlay())
end

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

BALATRO.set_ui_function("create_group_lobby", function()
	open_multiplayer_lobby_creation(MP.LOBBY_TYPES.FFA)
end)

BALATRO.set_ui_function("return_to_ruleset_selection", function()
	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	open_paused_overlay(create_ruleset_selection_overlay(ruleset_key, {
		preserve_modifiers = true,
	}))
end)

BALATRO.set_ui_function("select_gamemode", function()
	if MP.ACTIONS and MP.ACTIONS.request_coop_saves then
		MP.ACTIONS.request_coop_saves()
	end
	local gamemode_key = lobby_domain.get_creation_gamemode and lobby_domain.get_creation_gamemode()
		or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	open_paused_overlay(create_gamemode_selection_overlay(gamemode_key))
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
	BALATRO.set_setting_value("tutorial_complete", true)
	BALATRO.set_setting_value("tutorial_progress", nil)
	BALATRO.call_ui_function("play_options", e)
end)

BALATRO.set_ui_function("join_from_clipboard", function()
	local paste = MP.UTILS.get_from_clipboard()
	if not paste then
		return
	end

	local temp_code = string.sub(string.upper(paste:gsub("[^%a]", "")), 1, 5)
	store_join_lobby_code(temp_code)
	MP.ACTIONS.join_lobby(temp_code)
end)

BALATRO.set_ui_function("start_lobby", function()
	BALATRO.set_paused(false)

	local prepared, error_key = lobby_domain.prepare_config_for_creation()
	if not prepared then
		MP.UI.UTILS.overlay_message(localize(error_key == "ruleset_not_found" and "k_ruleset_not_found" or error_key))
		return
	end

	MP.ACTIONS.create_lobby(string.sub(MP.LOBBY.config.gamemode, 13))
	BALATRO.exit_overlay_menu()
end)

for gamemode, _ in pairs(MP.Gamemodes) do
	BALATRO.set_ui_function("force_" .. gamemode, function(e)
		lobby_domain.set_creation_gamemode(gamemode)
		BALATRO.call_ui_function("start_lobby", e)
	end)
end
