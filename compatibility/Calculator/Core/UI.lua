-- Shared calculator HUD widgets.

MP = MP or {}
MP.CALCULATOR = MP.CALCULATOR or {}

local CORE = MP.CALCULATOR

local function update_dynatext_node(e, text, colour, should_pulse)
	local key = e.config.id:sub(-1)
	text = text ~= "" and tostring(text or " ") or " "
	if CORE.text.score[key] == text then return end

	CORE.text.score[key] = text
	e.config.object:update_text()
	if not G.TAROT_INTERRUPT_PULSE then
		G.FUNCS.text_super_juice(e, should_pulse and 5 or 0)
		e.config.object.colours = { colour or G.C.UI.TEXT_LIGHT }
	end
end

function G.FUNCS.mp_calculator_score_UI_set(e)
	if e.config.id ~= "mp_calculator_l" then
		update_dynatext_node(e, " ", G.C.UI.TEXT_LIGHT, false)
		return
	end

	local text, should_pulse, colour = CORE.current_display()
	update_dynatext_node(e, text, colour, should_pulse)
end

function G.FUNCS.mp_calculator_calculate_score_button()
	if type(CORE.request) == "function" then CORE.request() end
end

local function build_score_text_node(id, ref_value, text_scale)
	return {
		n = G.UIT.O,
		config = {
			id = id,
			func = "mp_calculator_score_UI_set",
			object = DynaText({
				string = { { ref_table = CORE.text.score, ref_value = ref_value } },
				colours = { G.C.UI.TEXT_LIGHT },
				shadow = true,
				float = true,
				scale = text_scale,
			}),
		},
	}
end

function CORE.get_score_node()
	return {
		n = G.UIT.C,
		config = { id = "mp_calculator_score", align = "cm" },
		nodes = {
			build_score_text_node("mp_calculator_l", "l", 0.5),
		},
	}
end

function CORE.get_calculate_score_button()
	return {
		n = G.UIT.C,
		config = {
			id = "mp_calculator_calculate_score_button",
			button = "mp_calculator_calculate_score_button",
			align = "cm",
			minh = 0.42,
			padding = 0.05,
			minw = 3,
			r = 0.02,
			colour = G.C.RED,
			hover = true,
			shadow = true,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = CORE.get_calculate_button_text(),
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
							scale = 0.36,
						},
					},
				},
			},
		},
	}
end

function CORE.get_hud_node()
	return {
		n = G.UIT.R,
		config = { id = "mp_calculator_wrap", align = "cm", padding = 0.0 },
		nodes = {
			{
				n = G.UIT.R,
				config = { id = "mp_calculator_score_wrap", align = "cm", padding = 0.1 },
				nodes = { CORE.get_score_node() },
			},
			{
				n = G.UIT.R,
				config = { id = "mp_calculator_button_wrap", align = "cm", padding = 0.1 },
				nodes = { CORE.get_calculate_score_button() },
			},
		},
	}
end
