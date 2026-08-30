MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

local function refresh_initial_tab_contents()
	local overlay = BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() or nil
	if not (overlay and overlay.get_UIE_by_ID) then
		return
	end

	local tab_contents = overlay:get_UIE_by_ID("tab_contents")
	local tab_group = overlay:get_UIE_by_ID("tab_shoulders") or overlay:get_UIE_by_ID("no_shoulders")
	local current_tab = tab_group
		and tab_group.config
		and tab_group.config.ref_table
		and tab_group.config.ref_table.current
		and tab_group.config.ref_table.current.v
		or nil
	if not (tab_contents and tab_contents.config and current_tab and current_tab.tab_definition_function) then
		return
	end

	if tab_contents.config.object and tab_contents.config.object.remove then
		tab_contents.config.object:remove()
	end
	tab_contents.config.object = UIBox({
		definition = current_tab.tab_definition_function(current_tab.tab_definition_function_args),
		config = {
			offset = { x = 0, y = 0 },
			parent = tab_contents,
			type = "cm",
		},
	})
	if tab_contents.UIBox and tab_contents.UIBox.recalculate then
		tab_contents.UIBox:recalculate()
	end
end

local function open_paused_overlay(definition, selected_input_id, options)
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = definition,
	})

	if options and options.refresh_initial_tab_contents then
		refresh_initial_tab_contents()
	end

	if selected_input_id then
		BALATRO.select_overlay_text_input_by_id(selected_input_id)
	end
end

local function clear_singleplayer_selection()
	if lobby_domain.clear_config_selection then
		lobby_domain.clear_config_selection()
	end
end

local function store_join_lobby_code(temp_code)
	if lobby_domain.set_setup_temp_code then
		lobby_domain.set_setup_temp_code(temp_code)
	end
end

local function normalize_join_lobby_code(code)
	return string.sub(string.upper(tostring(code or ""):gsub("[^%a]", "")), 1, 5)
end

local function request_lobby_browser_list(clear_lobbies)
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if lobby_domain.set_browser_pending then
		lobby_domain.set_browser_pending(true)
	end
	if clear_lobbies and lobby_domain.set_browser_lobbies then
		lobby_domain.set_browser_lobbies({})
	end
	if clear_lobbies and main_menu_play_ui.set_browse_lobbies_page then
		main_menu_play_ui.set_browse_lobbies_page(1)
	end

	if
		not (main_menu_play_ui.refresh_browse_lobbies_overlay and main_menu_play_ui.refresh_browse_lobbies_overlay())
		and main_menu_play_ui.open_browse_lobbies_overlay
	then
		main_menu_play_ui.open_browse_lobbies_overlay()
	end

	if MP.ACTIONS and MP.ACTIONS.request_lobby_list then
		MP.ACTIONS.request_lobby_list()
	elseif MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		if lobby_domain.set_browser_pending then
			lobby_domain.set_browser_pending(false)
		end
		MP.UI.UTILS.overlay_message("Lobby browsing is not available on this server.")
	end
end

local function get_config_request_id(e)
	local config = e and e.config or {}
	return config.request_id
		or (config.ref_table and config.ref_table.request_id)
		or nil
end

local function respond_lobby_join_request(e, accepted, blocked)
	local request_id = get_config_request_id(e)
	if not request_id then
		return
	end

	if MP.ACTIONS and MP.ACTIONS.respond_lobby_join_request then
		MP.ACTIONS.respond_lobby_join_request(request_id, accepted, blocked)
	end
	if lobby_domain.remove_join_request then
		lobby_domain.remove_join_request(request_id)
	end
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	local closed_notification = main_menu_play_ui.close_join_request_notification
		and main_menu_play_ui.close_join_request_notification(request_id)
	if BALATRO.exit_overlay_menu and not closed_notification and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_join_request then
		BALATRO.exit_overlay_menu()
	end
end

local function cancel_pending_lobby_join_request(request_id)
	local pending_request = lobby_domain.get_pending_join_request and lobby_domain.get_pending_join_request() or nil
	request_id = request_id or (pending_request and pending_request.requestId) or nil
	if not request_id then
		return
	end

	if MP.ACTIONS and MP.ACTIONS.cancel_lobby_join_request then
		MP.ACTIONS.cancel_lobby_join_request(request_id)
	end
	if lobby_domain.clear_pending_join_request then
		lobby_domain.clear_pending_join_request(request_id)
	end

	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		MP.UI.refresh_main_menu_multiplayer_buttons()
	end
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.refresh_browse_lobbies_overlay then
		main_menu_play_ui.refresh_browse_lobbies_overlay()
	end
end

local function refresh_main_menu_ui()
	if G.MAIN_MENU_UI then
		G.MAIN_MENU_UI:remove()
	end
	if G.PROFILE_BUTTON then
		G.PROFILE_BUTTON:remove()
	end
	if set_main_menu_UI then
		set_main_menu_UI()
	end
end

local function refresh_main_menu_multiplayer_buttons(select_input_id)
	if MP.UI and MP.UI.refresh_main_menu_multiplayer_buttons then
		return MP.UI.refresh_main_menu_multiplayer_buttons({
			select_text_input_id = select_input_id,
		})
	end

	return refresh_main_menu_ui()
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
	if lobby_type and lobby_domain.set_lobby_type then
		lobby_domain.set_lobby_type(lobby_type)
	end

	local ruleset_key = lobby_domain.get_creation_ruleset and lobby_domain.get_creation_ruleset()
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	open_paused_overlay(create_ruleset_selection_overlay(ruleset_key), nil, {
		refresh_initial_tab_contents = true,
	})
end

BALATRO.set_ui_function("start_vanilla_sp", function(e)
	clear_singleplayer_selection()
	BALATRO.call_ui_function("setup_run", e)
end)

BALATRO.set_ui_function("play_options", function()
	if BALATRO.get_overlay_menu and BALATRO.get_overlay_menu() then
		BALATRO.exit_overlay_menu()
	else
		refresh_main_menu_ui()
	end
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
	}), nil, {
		refresh_initial_tab_contents = true,
	})
end)

BALATRO.set_ui_function("select_gamemode", function()
	if MP.ACTIONS and MP.ACTIONS.request_coop_saves then
		MP.ACTIONS.request_coop_saves()
	end
	local gamemode_key = lobby_domain.get_creation_gamemode and lobby_domain.get_creation_gamemode()
		or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	open_paused_overlay(create_gamemode_selection_overlay(gamemode_key), nil, {
		refresh_initial_tab_contents = true,
	})
end)

BALATRO.set_ui_function("join_lobby", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.set_inline_join_lobby_input_active then
		main_menu_play_ui.set_inline_join_lobby_input_active(true)
	end
	store_join_lobby_code("")
	refresh_main_menu_multiplayer_buttons(
		main_menu_play_ui.get_inline_join_lobby_input_id and main_menu_play_ui.get_inline_join_lobby_input_id()
	)
end)

BALATRO.set_ui_function("submit_inline_join_lobby", function()
	local lobby_code = normalize_join_lobby_code(MP.LOBBY and MP.LOBBY.setup and MP.LOBBY.setup.temp_code or "")
	if lobby_code == "" then
		return
	end

	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.set_inline_join_lobby_input_active then
		main_menu_play_ui.set_inline_join_lobby_input_active(false)
	end
	store_join_lobby_code(lobby_code)
	refresh_main_menu_multiplayer_buttons()
	MP.ACTIONS.join_lobby(lobby_code)
end)

BALATRO.set_ui_function("browse_lobbies", function()
	request_lobby_browser_list(true)
end)

BALATRO.set_ui_function("refresh_lobbies", function()
	request_lobby_browser_list(false)
end)

BALATRO.set_ui_function("browse_lobbies_prev_page", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.step_browse_lobbies_page then
		main_menu_play_ui.step_browse_lobbies_page(-1)
	end
end)

BALATRO.set_ui_function("browse_lobbies_next_page", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.step_browse_lobbies_page then
		main_menu_play_ui.step_browse_lobbies_page(1)
	end
end)

BALATRO.set_ui_function("toggle_browse_lobby_names", function()
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or {}
	if main_menu_play_ui.toggle_browse_lobby_names then
		main_menu_play_ui.toggle_browse_lobby_names()
	end
end)

BALATRO.set_ui_function("join_browsed_lobby", function(e)
	local lobby_code = e and e.config and e.config.lobby_code or nil
	if not lobby_code or lobby_code == "" then
		return
	end

	store_join_lobby_code(lobby_code)
	MP.ACTIONS.join_lobby(lobby_code)
end)

BALATRO.set_ui_function("approve_lobby_join_request", function(e)
	respond_lobby_join_request(e, true)
end)

BALATRO.set_ui_function("deny_lobby_join_request", function(e)
	respond_lobby_join_request(e, false)
end)

BALATRO.set_ui_function("block_lobby_join_request", function(e)
	respond_lobby_join_request(e, false, true)
end)

BALATRO.set_ui_function("cancel_lobby_join_request", function(e)
	cancel_pending_lobby_join_request(get_config_request_id(e))
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

BALATRO.set_ui_function("join_from_clipboard", function()
	local paste = MP.UTILS.get_from_clipboard()
	if not paste then
		return
	end

	local temp_code = normalize_join_lobby_code(paste)
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
