local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_calculator_label_row(padding, scale, text_key)
	return {
		n = G.UIT.R,
		config = {
			padding = padding,
			align = "cm",
			id = "calculator_text_input",
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					scale = scale,
					text = localize(text_key),
					colour = G.C.UI.TEXT_LIGHT,
				},
			},
		},
	}
end

local function save_calculator_label_settings()
	MP.UTILS.save_calculator_labels(MP.CALCULATOR_LABELS)
end

local function create_calculator_text_input(input_spec)
	return create_text_input({
		id = input_spec.id,
		w = 4,
		max_length = 25,
		prompt_text = input_spec.prompt_text,
		colour = copy_table(input_spec.colour),
		hooked_colour = darken(copy_table(input_spec.colour), 0.3),
		ref_table = MP.CALCULATOR_LABELS,
		ref_value = input_spec.ref_value,
		extended_corpus = true,
		keyboard_offset = -3,
		callback = save_calculator_label_settings,
	})
end

local function create_calculator_inputs_row(calculator_input_specs)
	local calculator_nodes = {}

	for _, input_spec in ipairs(calculator_input_specs) do
		calculator_nodes[#calculator_nodes + 1] = create_calculator_text_input(input_spec)
	end

	return {
		n = G.UIT.R,
		config = {
			padding = 0.15,
			align = "cm",
			id = "calculator_text_input",
		},
		nodes = calculator_nodes,
	}
end

local function create_blind_colour_options(limit)
	local blind_colour_options = {}

	for blind_col = 1, limit do
		blind_colour_options[#blind_colour_options + 1] = blind_col
	end

	return blind_colour_options
end

local function create_customization_tab()
	local preview_customization_available = (MP.INTEGRATIONS and MP.INTEGRATIONS.Preview)
		or tonumber(MP.PLATFORM.SMODS.get_config_value("calculator.backend", 1, MP)) == 2
	local blind_colour_count = MP.UTILS.get_blind_col_count()
	local blind_def = BALATRO.get_blind_def(MP.UTILS.blind_col_numtokey(MP.LOBBY.client.blind_col))
	local blind_anim = BALATRO.create_animated_sprite(
		0,
		0,
		1.4,
		1.4,
		BALATRO.get_animation_atlas("mp_player_blind_col"),
		blind_def and blind_def.pos or { x = 0, y = 0 }
	)
	blind_anim:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	MP.CALCULATOR_LABELS.text = MP.UTILS.get_calculator_label("text")
	MP.CALCULATOR_LABELS.button = MP.UTILS.get_calculator_label("button")
	local calculator_input_specs = {
		{
			id = "calculator_text",
			prompt_text = "CALCULATING", -- raw string but this doesn't need localization
			colour = G.C.BLACK,
			ref_value = "text",
		},
		{
			id = "calculator_button",
			prompt_text = "Calculate Score",
			colour = G.C.RED,
			ref_value = "button",
		},
	}
	local ret = {
		n = G.UIT.ROOT,
		config = {
			r = 0.1,
			minw = 5,
			align = "cm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = {
			preview_customization_available and create_calculator_label_row(0.10, 0.5, "k_customize_preview") or nil,
			preview_customization_available and create_calculator_label_row(0, 0.3, "k_enter_to_save") or nil,
			preview_customization_available and create_calculator_inputs_row(calculator_input_specs) or nil,
			{
				n = G.UIT.R,
				config = {
					padding = 0.5,
					align = "cm",
					id = "username_input_box",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							scale = 0.6,
							text = localize("k_username"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
					create_text_input({
						id = "enter_username",
						w = 4,
						max_length = 25,
						prompt_text = localize("k_enter_username"),
						ref_table = MP.LOBBY.client,
						ref_value = "username",
						extended_corpus = true,
						keyboard_offset = -3,
						callback = function(val)
							MP.UTILS.save_username(MP.LOBBY.client.username)
						end,
					}),
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
			{
				n = G.UIT.R,
				config = {
					padding = 0.1,
					align = "cm",
					id = "blind_col_changer",
				},
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							{ n = G.UIT.O, config = { id = "blind_col_changer_sprite", object = blind_anim } },
						},
					},
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							create_option_cycle({
								id = "blind_col_changer_option",
								label = localize({
									type = "name_text",
									key = MP.UTILS.blind_col_numtokey(MP.LOBBY.client.blind_col),
									set = "Blind",
								}),
								scale = 0.8,
								options = create_blind_colour_options(blind_colour_count),
								opt_callback = "change_blind_col",
								current_option = MP.LOBBY.client.blind_col,
							}),
						},
					},
				},
			},
		},
	}
	return ret
end

function MP.UI.create_extra_tabs()
	return {
		{
			label = localize("k_customization"),
			tab_definition_function = create_customization_tab,
		},
	}
end
