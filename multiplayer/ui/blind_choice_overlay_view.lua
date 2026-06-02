MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_OVERLAY = MP.UI.BLIND_CHOICE_OVERLAY or {}

local blind_choice_overlay = MP.UI.BLIND_CHOICE_OVERLAY
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_select_blind_button(type, run_info, blind_context, disabled)
	if not run_info then
		return {
			n = G.UIT.R,
			config = {
				id = "select_blind_button",
				align = "cm",
				ref_table = blind_context.blind_choice.config,
				colour = disabled and G.C.UI.BACKGROUND_INACTIVE or G.C.ORANGE,
				minh = 0.6,
				minw = 2.7,
				padding = 0.07,
				r = 0.1,
				shadow = true,
				hover = true,
				one_press = true,
				func = blind_context.use_mp_ready_flow and "pvp_ready_button" or nil,
				button = "select_blind",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						ref_table = BALATRO.get_round_reset_value and BALATRO.get_round_reset_value("loc_blind_states", {}) or {},
						ref_value = type,
						scale = 0.45,
						colour = disabled and G.C.UI.TEXT_INACTIVE or G.C.UI.TEXT_LIGHT,
						shadow = not disabled,
					},
				},
			},
		}
	end

	return {
		n = G.UIT.R,
		config = {
			id = "select_blind_button",
			align = "cm",
			ref_table = blind_context.blind_choice.config,
			colour = blind_context.run_info_colour,
			minh = 0.6,
			minw = 2.7,
			padding = 0.07,
			r = 0.1,
			emboss = 0.08,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize(blind_context.blind_state, "blind_states"),
					scale = 0.45,
					colour = G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

function blind_choice_overlay.create_box(type, run_info, blind_context)
	local disabled = false
	local preview = MP.UI.BLIND_CHOICE_PREVIEW
	local extras = preview and preview.get_blind_choice_extras and preview.get_blind_choice_extras(type, run_info) or nil

	return {
		n = G.UIT.R,
		config = {
			id = type,
			align = "tm",
			func = "blind_choice_handler",
			minh = not run_info and 10 or nil,
			ref_table = { deck = nil, run_info = run_info },
			r = 0.1,
			padding = 0.05,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5),
					r = 0.1,
					outline = 1,
					outline_colour = G.C.L_BLACK,
				},
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.2 },
						nodes = {
							create_select_blind_button(type, run_info, blind_context, disabled),
						},
					},
					preview and preview.create_name_node and preview.create_name_node(blind_context, disabled) or nil,
					preview and preview.create_details_node and preview.create_details_node(blind_context, disabled) or nil,
				},
			},
			{
				n = G.UIT.R,
				config = { id = "blind_extras", align = "cm" },
				nodes = {
					extras,
				},
			},
		},
	}
end
