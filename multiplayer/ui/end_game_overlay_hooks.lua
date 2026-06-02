local create_UIBox_game_over_ref = create_UIBox_game_over
function create_UIBox_game_over()
	if not MP.LOBBY.code then return create_UIBox_game_over_ref() end
	return MP.UI.create_UIBox_mp_game_end(false)
end

local create_UIBox_win_ref = create_UIBox_win
function create_UIBox_win()
	if not MP.LOBBY.code then return create_UIBox_win_ref() end
	return MP.UI.create_UIBox_mp_game_end(true)
end

local exit_overlay_menu_ref = G.FUNCS.exit_overlay_menu
---@diagnostic disable-next-line: duplicate-set-field
function G.FUNCS:exit_overlay_menu()
	if G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_end_game_deck_view then
		exit_overlay_menu_ref(self)
		G.FUNCS.overlay_endgame_menu()
		return
	end

	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		MP.UTILS.save_username(MP.LOBBY.client.username)
	end

	exit_overlay_menu_ref(self)
end

local mods_button_ref = G.FUNCS.mods_button
function G.FUNCS.mods_button(arg_736_0)
	if G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID("username_input_box") ~= nil then
		MP.UTILS.save_username(MP.LOBBY.client.username)
	end

	mods_button_ref(arg_736_0)
end
