local function update_custom_seed(value)
	MP.UI.send_lobby_option_update("custom_seed", value)
end

local function get_custom_seed_display()
	return MP.LOBBY.config.custom_seed == "random" and localize("k_random") or MP.LOBBY.config.custom_seed
end

local function create_custom_seed_button(id, button, colour, minw, label_key)
	return MP.UI.Disableable_Button({
		id = id,
		button = button,
		colour = colour,
		minw = minw,
		minh = 0.6,
		label = {
			localize(label_key),
		},
		disabled_text = {
			localize(label_key),
		},
		scale = 0.45,
		col = true,
		enabled_ref_table = MP.LOBBY,
		enabled_ref_value = "is_host",
	})
end

function G.FUNCS.custom_seed_overlay(e)
	G.FUNCS.overlay_menu({
		definition = G.UIDEF.create_UIBox_custom_seed_overlay(),
	})
end

function G.FUNCS.custom_seed_reset(e)
	update_custom_seed("random")
end

function G.FUNCS.display_custom_seed(e)
	local display = get_custom_seed_display()
	if display ~= e.children[2].config.text then
		e.children[2].config.text = display
		e.UIBox:recalculate(true)
	end
end

function G.UIDEF.create_UIBox_custom_seed_overlay()
	return create_UIBox_generic_options({
		back_func = "lobby_options",
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", colour = G.C.CLEAR },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", minw = 0.1 },
						nodes = {
							create_text_input({
								max_length = 8,
								all_caps = true,
								ref_table = MP.LOBBY.setup,
								ref_value = "temp_seed",
								prompt_text = localize("k_enter_seed"),
								keyboard_offset = 4,
								callback = function()
									update_custom_seed(MP.LOBBY.setup.temp_seed)
								end,
							}),
							{
								n = G.UIT.B,
								config = { w = 0.1, h = 0.1 },
							},
							{
								n = G.UIT.T,
								config = {
									scale = 0.3,
									text = localize("k_enter_to_save"),
									colour = G.C.UI.TEXT_LIGHT,
								},
							},
						},
					},
				},
			},
		},
	})
end

local function create_custom_seed_section()
	if not MP.LOBBY.config.different_seeds then return { n = G.UIT.B, config = { w = 0.1, h = 0.1 } } end

	return {
		n = G.UIT.R,
		config = { padding = 0, align = "cr" },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					padding = 0,
					align = "cm",
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							padding = 0.2,
							align = "cr",
							func = "display_custom_seed",
						},
						nodes = {
							{
								n = G.UIT.T,
								config = {
									scale = 0.45,
									text = localize("k_current_seed"),
									colour = G.C.UI.TEXT_LIGHT,
								},
							},
							{
								n = G.UIT.T,
								config = {
									scale = 0.45,
									text = get_custom_seed_display(),
									colour = G.C.UI.TEXT_LIGHT,
								},
							},
						},
					},
					{
						n = G.UIT.R,
						config = {
							padding = 0.2,
							align = "cr",
						},
						nodes = {
							create_custom_seed_button(
								"custom_seed_overlay",
								"custom_seed_overlay",
								G.C.BLUE,
								3.65,
								"b_set_custom_seed"
							),
							{
								n = G.UIT.B,
								config = {
									w = 0.1,
									h = 0.1,
								},
							},
							create_custom_seed_button(
								"custom_seed_reset",
								"custom_seed_reset",
								G.C.RED,
								1.65,
								"b_reset"
							),
						},
					},
				},
			},
		},
	}
end

function MP.UI.create_advanced_options_tab()
	local nodes = MP.UI.build_lobby_option_controls(MP.UI.LOBBY_OPTION_TAB_SPECS.advanced)
	nodes[#nodes + 1] = create_custom_seed_section()

	return MP.UI.create_lobby_option_page(nodes, 4)
end
