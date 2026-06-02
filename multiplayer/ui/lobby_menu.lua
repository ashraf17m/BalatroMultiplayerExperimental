local function create_lobby_leave_button(text_scale)
	return UIBox_button({
		id = "lobby_menu_leave",
		button = "lobby_leave",
		colour = G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = { localize("b_leave") },
		scale = text_scale * 1.5,
		col = true,
	})
end

local function create_lobby_code_buttons(text_scale)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
		},
		nodes = {
			UIBox_button({
				button = "view_code",
				colour = G.C.PALE_GREEN,
				minw = 2.15,
				minh = 0.65,
				label = { localize("b_view_code") },
				scale = text_scale * 1.2,
			}),
			MP.UI.create_spacer(0.1, true),
			UIBox_button({
				button = "copy_to_clipboard",
				colour = G.C.PERISHABLE,
				minw = 2.15,
				minh = 0.65,
				label = { localize("b_copy_code") },
				scale = text_scale,
			}),
		},
	}
end

function G.UIDEF.create_UIBox_lobby_menu()
	local screen_state = MP.UI.LOBBY_VIEW_MODEL.build_lobby_menu_state()
	local text_scale = screen_state.text_scale
	local lobby_context = screen_state.lobby_context
	local back = screen_state.back
	local stake = screen_state.stake
	local lobby_type_options_button = screen_state.lobby_type_options_button
	local team_color = screen_state.team_color
	local team_name = screen_state.team_name

	local t = {
		n = G.UIT.ROOT,
		config = {
			align = "cm",
			colour = G.C.CLEAR,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "bm",
				},
				nodes = {
					MP.UI.lobby_status_display(),
					-- TEAM IDENTITY BADGE (Only in teams mode)
					(lobby_context.is_teams_mode and {
						n = G.UIT.R,
						config = { align = "cm", padding = 0.1, r = 0.1, colour = team_color, emboss = 0.05, shadow = true },
						nodes = {
							{ n = G.UIT.T, config = { text = "YOU ARE ON ", scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
							{ n = G.UIT.T, config = { text = team_name, scale = 0.45, colour = G.C.WHITE, shadow = true } },
						}
					}) or nil,
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							padding = 0.2,
							r = 0.1,
							emboss = 0.1,
							colour = G.C.L_BLACK,
							mid = true,
						},
						nodes = {
							MP.UI.create_lobby_main_button(text_scale),
							{
								n = G.UIT.C,
								config = {
									align = "cm",
								},
								nodes = {
									not lobby_context.config.forced_config and not lobby_context.match_in_progress and UIBox_button({
										button = "lobby_options",
										colour = G.C.ORANGE,
										minw = 3.15,
										minh = 1.35,
										label = {
											localize("b_lobby_options"),
										},
										scale = text_scale * 1.2,
										col = true,
									}) or nil,
									(not lobby_context.config.forced_config and not lobby_context.match_in_progress) and MP.UI.create_spacer() or nil,
									UIBox_button({
										button = "view_players_list",
										colour = G.C.BLUE,
										minw = 3.15,
										minh = 1.35,
										label = {
											localize("b_players"),
										},
										scale = text_scale * 1.2,
										col = true,
									}),
									MP.UI.create_spacer(),
									lobby_type_options_button,
									lobby_type_options_button and MP.UI.create_spacer() or nil,
									MP.UI.create_lobby_deck_button(text_scale, back, stake),
									MP.UI.create_spacer(),
									create_lobby_code_buttons(text_scale),
								},
							},
							create_lobby_leave_button(text_scale),
						},
					},
				},
			},
		},
	}
	return t
end

function G.UIDEF.create_UIBox_lobby_options()
	local screen_state = MP.UI.LOBBY_VIEW_MODEL.build_lobby_options_state()
	return create_UIBox_generic_options({
		contents = {
			{
				n = G.UIT.R,
				config = {
					id = "lobby_options_overlay",
					padding = 0,
					align = "cm",
				},
				nodes = {
					screen_state.show_host_notice and MP.UI.UTILS.create_row({ align = "cm", padding = 0.3 }, {
						MP.UI.UTILS.create_text_node(localize("k_opts_only_host"), {
							scale = 0.6,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}) or nil,
					create_tabs({
						snap_to_nav = true,
						colour = G.C.BOOSTER,
						tabs = screen_state.tab_definitions,
					}),
				},
			},
		},
	})
end
