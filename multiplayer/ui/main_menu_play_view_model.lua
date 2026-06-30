MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_PLAY = MP.UI.MAIN_MENU_PLAY or {}

local view_model = MP.UI.MAIN_MENU_PLAY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function append_node(contents, node)
	if node then
		contents[#contents + 1] = node
	end
end

local function create_play_button(label_key, colour, button, minh)
	return UIBox_button({
		label = { localize(label_key) },
		colour = colour,
		button = button,
		minw = 5,
		minh = minh,
	})
end

local function append_play_button_if(contents, condition, label_key, colour, button, minh)
	if condition then
		append_node(contents, create_play_button(label_key, colour, button, minh))
	end
end

local function append_multiplayer_lobby_create_buttons(contents)
	if not (MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.connected) then
		return
	end

	append_node(contents, create_play_button("b_create_party", G.C.GREEN, "create_group_lobby"))
end

local function append_resume_match_button(contents)
	if not (MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume()) then
		return
	end

	append_node(contents, create_play_button("b_resume_match", G.C.GREEN, "resume_match"))
end

function view_model.build_play_options_contents()
	if
		not (BALATRO.get_setting_value and BALATRO.get_setting_value("tutorial_complete", false))
		or (BALATRO.get_setting_value and BALATRO.get_setting_value("tutorial_progress", nil) ~= nil)
	then
		return {
			create_play_button("b_singleplayer", G.C.BLUE, "start_vanilla_sp"),
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.5,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_tutorial_not_complete"),
							colour = G.C.UI.TEXT_LIGHT,
							scale = 0.45,
						},
					},
				},
			},
			create_play_button("b_skip_tutorial", G.C.RED, "skip_tutorial"),
		}
	end

	local contents = {
		create_play_button("b_singleplayer", G.C.BLUE, "start_vanilla_sp"),
		create_play_button("b_practice", G.C.ORANGE, "setup_practice_mode"),
	}

	append_resume_match_button(contents)
	append_multiplayer_lobby_create_buttons(contents)

	local is_connected = MP.LOBBY.client.connected
	append_play_button_if(contents, is_connected, "b_join_lobby", G.C.RED, "join_lobby", 0.7)
	append_play_button_if(contents, is_connected, "b_join_lobby_clipboard", G.C.PURPLE, "join_from_clipboard", 0.7)
	append_play_button_if(contents, not is_connected, "b_reconnect", G.C.RED, "reconnect")

	return contents
end

function view_model.create_play_options_overlay()
	return create_UIBox_generic_options({
		contents = view_model.build_play_options_contents(),
	})
end

function view_model.create_join_lobby_overlay()
	return create_UIBox_generic_options({
		back_func = "play_options",
		contents = {
			{
				n = G.UIT.R,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							padding = 0.5,
							align = "cm",
						},
						nodes = {
							create_text_input({
								w = 4,
								h = 1,
								max_length = 5,
								all_caps = true,
								prompt_text = localize("k_enter_lobby_code"),
								ref_table = MP.LOBBY.setup,
								ref_value = "temp_code",
								extended_corpus = false,
								keyboard_offset = 4,
								minw = 5,
								callback = function()
									MP.ACTIONS.join_lobby(MP.LOBBY.setup.temp_code)
								end,
							}),
						},
					},
				},
			},
		},
	})
end

function view_model.create_weekly_interrupt_overlay()
	return create_UIBox_generic_options({
		back_func = "create_group_lobby",
		contents = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.1,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = "A new weekly ruleset is available!",
							colour = G.C.UI.TEXT_LIGHT,
							scale = 0.45,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					padding = 0.2,
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = localize("k_currently_colon") .. localize("k_weekly_" .. MP.LOBBY.setup.fetched_weekly),
							colour = darken(G.C.UI.TEXT_LIGHT, 0.2),
							scale = 0.35,
						},
					},
				},
			},
			create_play_button("k_sync_locally", G.C.DARK_EDITION, "set_weekly"),
		},
	})
end

G.UIDEF.override_main_menu_play_button = view_model.create_play_options_overlay
G.UIDEF.create_UIBox_join_lobby_button = view_model.create_join_lobby_overlay
G.UIDEF.weekly_interrupt = view_model.create_weekly_interrupt_overlay
