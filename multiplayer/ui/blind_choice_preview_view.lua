MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_PREVIEW = MP.UI.BLIND_CHOICE_PREVIEW or {}

local blind_choice_preview = MP.UI.BLIND_CHOICE_PREVIEW
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_pvp_extra_text(localization_key, string_colour, text_colours, scale, bump)
	return DynaText({
		string = { { string = localize(localization_key), colour = string_colour } },
		colours = { text_colours },
		scale = scale,
		silent = true,
		pop_delay = 4.5,
		shadow = true,
		bump = bump,
		maxw = 3,
	})
end

local function create_centered_object_row(object)
	return { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = object } } } }
end

local function create_text_node(text, scale, colour, shadow)
	return {
		n = G.UIT.T,
		config = {
			text = text,
			scale = scale,
			colour = colour,
			shadow = shadow,
		},
	}
end

local function create_pvp_blind_extras()
	return {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.07, r = 0.1, colour = { 0, 0, 0, 0.12 }, minw = 2.9 },
				nodes = {
					create_centered_object_row(create_pvp_extra_text("k_bl_life", G.C.FILTER, G.C.BLACK, 0.55, true)),
					create_centered_object_row(create_pvp_extra_text("k_bl_or", G.C.WHITE, G.C.CHANCE, 0.35, nil)),
					create_centered_object_row(create_pvp_extra_text("k_bl_death", G.C.FILTER, G.C.BLACK, 0.55, true)),
				},
			},
		},
	}
end

function blind_choice_preview.get_blind_choice_extras(type, run_info)
	if
		(BALATRO.get_blind_choice and BALATRO.get_blind_choice(type) == "bl_mp_nemesis")
		or (BALATRO.get_pvp_blind_choice and BALATRO.get_pvp_blind_choice(type))
	then
		return create_pvp_blind_extras()
	end

	if type == "Small" or type == "Big" then
		return create_UIBox_blind_tag(type, run_info)
	end

	return nil
end

function blind_choice_preview.create_name_node(blind_context, disabled)
	return {
		n = G.UIT.R,
		config = { id = "blind_name", align = "cm", padding = 0.07 },
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					r = 0.1,
					outline = 1,
					outline_colour = blind_context.blind_col,
					colour = darken(blind_context.blind_col, 0.3),
					minw = 2.9,
					emboss = 0.1,
					padding = 0.07,
					line_emboss = 1,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = blind_context.loc_name,
								colours = { disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE },
								shadow = not disabled,
								float = not disabled,
								y_offset = -4,
								scale = 0.45,
								maxw = 2.8,
							}),
						},
					},
				},
			},
		},
	}
end

local function create_blind_description_text(text, disabled)
	return create_text_node(text or "-", 0.32, disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE, not disabled)
end

local function create_blind_description_row(text, disabled, blind_choice)
	local nodes = {}
	if blind_choice then
		nodes[#nodes + 1] = {
			n = G.UIT.T,
			config = {
				id = blind_choice.config.key,
				ref_table = { val = "" },
				ref_value = "val",
				scale = 0.32,
				colour = disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE,
				shadow = not disabled,
				func = "HUD_blind_debuff_prefix",
			},
		}
	end
	nodes[#nodes + 1] = create_blind_description_text(text, disabled)

	return {
		n = G.UIT.R,
		config = { align = "cm", maxw = 2.8 },
		nodes = nodes,
	}
end

local function create_text_rows(text_table, blind_choice, disabled)
	return {
		text_table and text_table[1] and create_blind_description_row(text_table[1], disabled, blind_choice) or nil,
		text_table[2] and create_blind_description_row(text_table[2], disabled) or nil,
		text_table[3] and create_blind_description_row(text_table[3], disabled) or nil,
	}
end

function blind_choice_preview.create_details_node(blind_context, disabled)
	local blind_choice = blind_context.blind_choice
	local text_table = blind_context.text_table

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			{
				n = G.UIT.R,
				config = { id = "blind_desc", align = "cm", padding = 0.05 },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm" },
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", minh = 1.5 },
								nodes = {
									{ n = G.UIT.O, config = { object = blind_choice.animation } },
								},
							},
							text_table and text_table[1] and {
								n = G.UIT.R,
								config = {
									align = "cm",
									minh = 0.7,
									padding = 0.05,
									minw = 2.9,
								},
								nodes = create_text_rows(text_table, blind_choice, disabled),
							} or nil,
						},
					},
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							r = 0.1,
							padding = 0.05,
							minw = 3.1,
							colour = G.C.BLACK,
							emboss = 0.05,
						},
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", maxw = 3 },
								nodes = {
									create_text_node(
										localize("ph_blind_score_at_least"),
										0.3,
										disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE,
										not disabled
									),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", minh = 0.6 },
								nodes = {
									{
										n = G.UIT.O,
										config = {
											w = 0.5,
											h = 0.5,
											colour = G.C.BLUE,
											object = blind_context.stake_sprite,
											hover = true,
											can_collide = false,
										},
									},
									{ n = G.UIT.B, config = { h = 0.1, w = 0.1 } },
									{
										n = G.UIT.T,
										config = {
											text = number_format(blind_context.blind_amt),
											scale = score_number_scale(0.9, blind_context.blind_amt),
											colour = disabled and G.C.UI.TEXT_INACTIVE or G.C.RED,
											shadow = not disabled,
										},
									},
								},
							},
							blind_context.reward and {
								n = G.UIT.R,
								config = { align = "cm" },
								nodes = {
									create_text_node(
										localize("ph_blind_reward"),
										0.35,
										disabled and G.C.UI.TEXT_INACTIVE or G.C.WHITE,
										not disabled
									),
									create_text_node(
										string.rep(localize("$"), blind_choice.config.dollars) .. "+",
										0.35,
										disabled and G.C.UI.TEXT_INACTIVE or G.C.MONEY,
										not disabled
									),
								},
							} or nil,
						},
					},
				},
			},
		},
	}
end
