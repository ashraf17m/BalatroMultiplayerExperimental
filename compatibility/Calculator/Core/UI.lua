-- Shared calculator HUD widgets.

MP = MP or {}
MP.CALCULATOR = MP.CALCULATOR or {}

local CORE = MP.CALCULATOR
local SCORE_TEXT_SCALE = 0.58
local SCORE_TEXT_MAX_WIDTH = 4.25
local SCORE_RANGE_VALUE_MAX_WIDTH = 1.85
local SCORE_RANGE_SEPARATOR_MAX_WIDTH = 0.35

local function is_blank_text(text)
	return tostring(text or ""):match("^%s*$") ~= nil
end

local function display_uses_range()
	if type(CORE.current_display_part) ~= "function" then return false end

	local middle = CORE.current_display_part("m")
	local right = CORE.current_display_part("r")
	return not is_blank_text(middle) or not is_blank_text(right)
end

local function get_score_part_maxw(key)
	if key == "m" then
		return SCORE_RANGE_SEPARATOR_MAX_WIDTH
	end
	if display_uses_range() then
		return SCORE_RANGE_VALUE_MAX_WIDTH
	end
	return key == "l" and SCORE_TEXT_MAX_WIDTH or 0.01
end

local function update_dynatext_width_limit(text_object, maxw)
	if not text_object then return end

	text_object.config.maxw = maxw
	text_object.scale = text_object.config.scale
	text_object:update_text()

	if maxw and text_object.config.W then
		text_object.scale = text_object.config.scale * math.min(1, maxw / text_object.config.W)
		text_object:update_text(true)
	end
end

local function update_dynatext_node(e, text, colour, should_pulse)
	local key = e.config.id:sub(-1)
	text = tostring(text or " ")
	colour = colour or G.C.UI.TEXT_LIGHT
	local maxw = get_score_part_maxw(key)

	local text_changed = CORE.text.score[key] ~= text
	local colour_changed = CORE.text.score_colours[key] ~= colour
	local maxw_changed = e.config.object and e.config.object.config and e.config.object.config.maxw ~= maxw
	if not text_changed and not colour_changed and not maxw_changed then return end

	CORE.text.score[key] = text
	CORE.text.score_colours[key] = colour
	if text_changed or maxw_changed then
		update_dynatext_width_limit(e.config.object, maxw)
	end

	if not G.TAROT_INTERRUPT_PULSE then
		G.FUNCS.text_super_juice(e, should_pulse and 5 or 0)
		e.config.object.colours = { colour }
	end
end

function G.FUNCS.mp_calculator_score_UI_set(e)
	local text, should_pulse, colour = CORE.current_display_part(e.config.id:sub(-1))
	update_dynatext_node(e, text, colour, should_pulse)
end

function G.FUNCS.mp_calculator_calculate_score_button()
	if type(CORE.request) == "function" then CORE.request() end
end

local function build_score_text_node(id, ref_value)
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
				scale = SCORE_TEXT_SCALE,
				maxw = get_score_part_maxw(id:sub(-1)),
			}),
		},
	}
end

function CORE.get_score_node()
	return {
		n = G.UIT.C,
		config = {
			id = "mp_calculator_score",
			align = "cm",
			minh = 0.5,
			minw = SCORE_TEXT_MAX_WIDTH,
			maxw = SCORE_TEXT_MAX_WIDTH,
		},
		nodes = {
			build_score_text_node("mp_calculator_l", "l"),
			build_score_text_node("mp_calculator_m", "m"),
			build_score_text_node("mp_calculator_r", "r"),
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
			maxw = 4.5,
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
							scale = 0.4,
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
				config = {
					id = "mp_calculator_score_wrap",
					align = "cm",
					padding = 0.1,
					minw = SCORE_TEXT_MAX_WIDTH,
					maxw = SCORE_TEXT_MAX_WIDTH,
				},
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
