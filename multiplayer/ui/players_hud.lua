-- Consolidated Players HUD & Scoreboard Module
-- Replaces 8 fragmented files with a unified, high-performance module.

MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}
local shared = MP.UI.PLAYERS_HUD_SHARED
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local OPPONENTS = MP.OPPONENTS or {}

-- ============================================================================
-- SECTION 1: SCORE FORMATTING, SHADERS & EASING
-- (Consolidated from players_hud_shared_score_view.lua)
-- ============================================================================


local DEFAULT_SCORE_TEXT_MAXW = 2.28
local SCORE_TEXT_BOX_PADDING = 0.18
local PVP_SCORE_EASE_DELAY = 0.8
local RANK_POLYCHROME_SHADER_VERSION = "shared_polychrome_full_spectrum_2026_07_26"
local RANK_POLYCHROME_SPEED = 1.7
local RANK_POLYCHROME_TINT_ALPHA = 0.5
local RANK_POLYCHROME_WHITE_ALPHA = 0.36
local RANK_POLYCHROME_TINT_STRENGTH = 0.86
local RANK_POLYCHROME_FALLBACK_COLOUR = { 0.5, 0.85, 1, 1 }
local RANK_POLYCHROME_SHADER_CODE = [[
extern number mp_rank_time;
extern number mp_rank_strength;
extern vec4 mp_rank_screen_rect;

vec3 full_spectrum_colour(number phase) {
	return 0.5 + 0.5 * cos(6.28318 * (phase + vec3(0.0, 0.6666667, 0.3333333)));
}

vec3 polychrome_colour(vec2 uv, number time) {
	number phase = uv.x * 0.08 + uv.y * 0.04 - time * 0.055;
	return full_spectrum_colour(phase);
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
	vec4 tex = Texel(texture, texture_coords);
	vec2 rect_size = max(vec2(1.0), mp_rank_screen_rect.zw - mp_rank_screen_rect.xy);
	vec2 uv = clamp((screen_coords.xy - mp_rank_screen_rect.xy) / rect_size, 0.0, 1.0);
	vec3 tint = polychrome_colour(uv, mp_rank_time);
	vec3 rgb = mix(vec3(1.0), tint, mp_rank_strength);
	return vec4(rgb * colour.rgb, tex.a * colour.a);
}
]]

if shared.rank_polychrome_shader_version ~= RANK_POLYCHROME_SHADER_VERSION then
	shared.rank_polychrome_shader = nil
	shared.rank_polychrome_shader_unavailable = nil
	shared.rank_polychrome_shader_version = RANK_POLYCHROME_SHADER_VERSION
end

local function clean_score_text(score_text)
	local cleaned_score_text = tostring(score_text or "0"):gsub(",", "")
	return cleaned_score_text
end

local function is_finite_number(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function try_parse_score_int(score_text)
	local ok, score_int = pcall(MP.INSANE_INT.from_string, clean_score_text(score_text))
	if ok and score_int then
		return score_int
	end
	return nil
end

local function parse_score_int(score_text)
	return try_parse_score_int(score_text) or MP.INSANE_INT.empty()
end

local function format_score_int(score_int, fallback)
	local ok, formatted_score = pcall(MP.INSANE_INT.to_string, score_int)
	if ok and formatted_score ~= nil then
		return tostring(formatted_score)
	end
	return tostring(fallback or "0")
end

local function format_score_text(score_text, score_int, prefer_score_int)
	local parsed = score_int or parse_score_int(score_text)
	if parsed then
		return format_score_int(parsed, score_text)
	end

	local native_score = tonumber(clean_score_text(score_text))
	if is_finite_number(native_score) and number_format then
		local ok, formatted_score = pcall(number_format, native_score)
		if ok and formatted_score ~= nil then
			return tostring(formatted_score)
		end
	end
	return tostring(score_text or "0")
end

local function get_scale_number(num, scale, max)
	if not num or type(num) ~= "number" then return scale end
	max = max or 10000
	if math.abs(num) >= 100000000000 then
		return scale * 5 / 7
	elseif math.abs(num) >= max then
		local num_digits = math.floor(math.log(math.abs(num) * 10, 10) + 1e-6)
		local max_digits = math.floor(math.log(max * 10, 10) + 1e-6)
		if num_digits > max_digits then
			return scale * max_digits / num_digits
		end
	end
	return scale
end

local function score_digit_length(score_value)
	local text = ""
	if type(score_value) == "string" then
		text = clean_score_text(score_value):gsub("[^%d]", "")
	elseif type(score_value) == "number" and is_finite_number(score_value) then
		text = tostring(math.floor(math.abs(score_value)))
	elseif type(score_value) == "table" and MP.INSANE_INT then
		local ok, formatted = pcall(MP.INSANE_INT.to_string, score_value)
		if ok and formatted then
			text = tostring(formatted):gsub("[^%d]", "")
		end
	end
	return #text
end

local function score_scale(score_value, large_scale, small_scale, max_text_width)
	local preferred_scale = large_scale or 0.26
	local minimum_scale = small_scale or math.min(preferred_scale, 0.3)
	local digits = score_digit_length(score_value)
	if digits <= 5 then
		return preferred_scale
	elseif digits <= 8 then
		return math.max(minimum_scale, preferred_scale * 6 / 7)
	end
	return math.max(minimum_scale, preferred_scale * 5 / 7)
end


local function update_score_display_table(display, score_text, score_int, prefer_score_int)
	local score_display = display or {}
	local parsed_score = score_int or parse_score_int(score_text)
	score_display.text = format_score_text(score_text, parsed_score, prefer_score_int)
	score_display.raw_text = tostring(score_text or "0")
	score_display.score_int = parsed_score
	score_display.prefer_score_int = prefer_score_int
	return score_display
end

local function get_score_display(score_text, score_int, options)
	local parsed_score = score_int or parse_score_int(score_text)
	local prefer_score_int = options and options.prefer_score_int
	return update_score_display_table({}, score_text, parsed_score, prefer_score_int)
end

local function ease_standings_score_number(score_number, target_score, options)
	if not (MP.INSANE_INT and MP.INSANE_INT.ease_display_score) then
		return false
	end
	local delay = options and options.delay or shared.PVP_SCORE_EASE_DELAY or PVP_SCORE_EASE_DELAY
	return MP.INSANE_INT.ease_display_score(score_number, target_score, { delay = delay })
end

local function copy_insane_int(value)
	if MP.INSANE_INT and MP.INSANE_INT.copy then
		return MP.INSANE_INT.copy(value)
	end
	return value or MP.INSANE_INT.empty()
end

local function should_snap_score_display(display_score, target_score)
	if not display_score or not target_score then
		return true
	end
	if target_score.e_count == 0 and target_score.exponent == 0 and target_score.coefficient == 0 then
		return true
	end
	return MP.INSANE_INT.greater_than(display_score, target_score)
end

local function get_score_display_runtime_bucket(bucket)
	if not (MP.UI and MP.UI.get_player_list_runtime) then
		return nil
	end

	local player_list_runtime = MP.UI.get_player_list_runtime()
	player_list_runtime[bucket] = player_list_runtime[bucket] or {}
	return player_list_runtime[bucket]
end

local function get_eased_score_display(bucket, key, target_score, options)
	local display_score = target_score or MP.INSANE_INT.empty()
	local target_text = MP.INSANE_INT.to_string(display_score)
	local display_runtime = get_score_display_runtime_bucket(bucket)
	if not display_runtime then
		return get_score_display(target_text, display_score, { prefer_score_int = true })
	end

	local state_key = key or "default"
	local state = display_runtime[state_key]
	if not state then
		state = {
			score_int = copy_insane_int(display_score),
			target_text = target_text,
		}
		display_runtime[state_key] = state
	elseif state.target_text ~= target_text then
		state.target_text = target_text
		if should_snap_score_display(state.score_int, display_score) then
			state.score_int = copy_insane_int(display_score)
		elseif not ease_standings_score_number(state.score_int, display_score, options) then
			state.score_int = copy_insane_int(display_score)
		else
			if state.display then
				state.display._mp_juice_pending = true
			end
		end
	end

	state.display = state.display or {}
	return update_score_display_table(state.display, target_text, state.score_int, true)
end

local function get_self_live_score_display()
	if not (MP.SPECTATOR and MP.SPECTATOR.is_spectating) and G and G.GAME then
		local queue_chips = G.SCORE_DISPLAY_QUEUE and G.SCORE_DISPLAY_QUEUE[1]
		local chips = queue_chips or G.GAME.chips
		if chips ~= nil then
			local chips_text = (queue_chips and number_format and pcall(number_format, queue_chips) and number_format(queue_chips))
				or (G.GAME.chips_text and tostring(G.GAME.chips_text) ~= "" and tostring(G.GAME.chips_text))
				or (number_format and pcall(number_format, chips) and number_format(chips))
				or tostring(chips)
			return chips_text, chips
		end
	end
	return nil, nil
end


local function get_player_score_display(player_id, score_text, score_int, prefer_score_int, is_self)
	local display_runtime = get_score_display_runtime_bucket("player_standings_scores")
	local state_key = player_id or "default"
	local score_display
	if display_runtime then
		display_runtime[state_key] = display_runtime[state_key] or {}
		score_display = display_runtime[state_key]
	else
		score_display = {}
	end

	score_display.is_self = not not is_self
	local parsed_score = score_int or parse_score_int(score_text)
	local should_prefer = prefer_score_int ~= false and parsed_score ~= nil
	return update_score_display_table(score_display, score_text, parsed_score, should_prefer)
end

local function normalize_stat_text(value)
	local numeric_value = tonumber(value)
	if numeric_value ~= nil then
		return tostring(math.max(0, math.floor(numeric_value)))
	end
	return tostring(value or "0")
end

local function get_standings_stat_display(bucket, key, value)
	local display_runtime = get_score_display_runtime_bucket(bucket)
	if not display_runtime then
		return {
			text = normalize_stat_text(value),
		}
	end

	local state_key = key or "default"
	local state = display_runtime[state_key]
	if not state then
		state = {}
		display_runtime[state_key] = state
	end

	state.text = normalize_stat_text(value)
	return state
end

BALATRO.set_ui_function("mp_players_hud_score_text_update", function(e)
	local score_display = e and e.config and e.config.ref_table or nil
	if not score_display then
		return
	end

	local new_text
	local score_for_scale
	if score_display.is_self then
		local _, live_chips = get_self_live_score_display()
		if live_chips ~= nil then
			local live_int = try_parse_score_int(tostring(live_chips))
			new_text = format_score_text(tostring(live_chips), live_int, true)
			score_for_scale = live_int or tostring(live_chips)
		else
			new_text = format_score_text(score_display.raw_text, score_display.score_int, score_display.prefer_score_int ~= false)
			score_for_scale = score_display.score_int or score_display.raw_text
		end
	else
		new_text = format_score_text(score_display.raw_text, score_display.score_int, score_display.prefer_score_int ~= false)
		score_for_scale = score_display.score_int or score_display.raw_text
	end
	if score_display.text ~= new_text or (e.config.text and e.config.text ~= new_text) then
		score_display.text = new_text
		e.config.text = new_text
		local new_scale = score_scale(
			score_for_scale or new_text,
			score_display.large_scale or e.config.scale,
			score_display.small_scale,
			score_display.max_text_width
		)
		if math.abs((e.config.scale or new_scale) - new_scale) > 0.001 then
			e.config.scale = new_scale
		end
		if score_display._mp_juice_pending then
			score_display._mp_juice_pending = nil
			if e.juice_up then
				e:juice_up(0.2, 0.1)
			end
		end
	end
end)

BALATRO.set_ui_function("mp_players_hud_stat_text_update", function(e)
	local stat_display = e and e.config and e.config.ref_table or nil
	local ref_value = e and e.config and e.config.ref_value or nil
	if not (stat_display and ref_value) then
		return
	end

	e.config.text = normalize_stat_text(stat_display[ref_value])
end)

local function colour_with_alpha(colour, alpha)
	colour = colour or G.C.WHITE
	return {
		colour[1] or 1,
		colour[2] or 1,
		colour[3] or 1,
		alpha or colour[4] or 1,
	}
end

local function get_rank_polychrome_shader()
	if shared.rank_polychrome_shader_unavailable then
		return nil
	end
	if shared.rank_polychrome_shader then
		return shared.rank_polychrome_shader
	end
	if not (love and love.graphics and love.graphics.newShader) then
		shared.rank_polychrome_shader_unavailable = true
		return nil
	end

	local ok, shader = pcall(love.graphics.newShader, RANK_POLYCHROME_SHADER_CODE)
	if not ok or not shader then
		shared.rank_polychrome_shader_unavailable = true
		return nil
	end

	shared.rank_polychrome_shader = shader
	return shader
end

local function send_rank_shader_value(shader, name, value)
	if not (shader and shader.send) then
		return
	end
	pcall(function()
		shader:send(name, value)
	end)
end

local function get_dynatext_screen_rect(text_object, string_state)
	if not (love and love.graphics and love.graphics.transformPoint) then
		local width = love and love.graphics and love.graphics.getWidth and love.graphics.getWidth() or 1
		local height = love and love.graphics and love.graphics.getHeight and love.graphics.getHeight() or 1
		return 0, 0, width, height
	end

	local local_width = math.max(
		0.01,
		(text_object and text_object.config and text_object.config.W)
			or (string_state and string_state.W)
			or (text_object and text_object.T and text_object.T.w)
			or 0.01
	)
	local local_height = math.max(
		0.01,
		(text_object and text_object.config and text_object.config.H)
			or (string_state and string_state.H)
			or (text_object and text_object.T and text_object.T.h)
			or 0.01
	)
	local x1, y1 = love.graphics.transformPoint(0, 0)
	local x2, y2 = love.graphics.transformPoint(local_width, local_height)
	local left = math.min(x1, x2)
	local right = math.max(x1, x2)
	local top = math.min(y1, y2)
	local bottom = math.max(y1, y2)
	return left, top, math.max(left + 1, right), math.max(top + 1, bottom)
end

G.FUNCS.mp_players_hud_rank_label_colour = function(e)
	if not (e and e.config and e.config.ref_table) then
		return
	end

	local rank_data = e.config.ref_table
	if rank_data.rank == 1 then
		e.config.colour = G.C.WHITE
	else
		e.config.colour = rank_data.base_colour or e.config.colour
	end
end

local TEXT_OUTLINE_OFFSETS = {
	{ -1, 0 },
	{ 1, 0 },
	{ 0, -1 },
	{ 0, 1 },
	{ -1, -1 },
	{ 1, -1 },
	{ -1, 1 },
	{ 1, 1 },
}

local function draw_dynatext_layer(text_object, colour, offset_x, offset_y, options)
	if not (
		text_object
		and text_object.strings
		and text_object.focused_string
		and text_object.strings[text_object.focused_string]
		and love
		and love.graphics
	) then
		return
	end

	local opts = options or {}
	local string_state = text_object.strings[text_object.focused_string]
	local shadow_parrallax = text_object.shadow_parrallax or { x = 0, y = 0 }
	prep_draw(text_object, 1)
	love.graphics.translate(
		string_state.W_offset + text_object.text_offset.x * text_object.font.FONTSCALE / G.TILESIZE + (offset_x or 0),
		string_state.H_offset + text_object.text_offset.y * text_object.font.FONTSCALE / G.TILESIZE + (offset_y or 0)
	)
	if text_object.config.spacing then
		love.graphics.translate(text_object.config.spacing * text_object.font.FONTSCALE / G.TILESIZE, 0)
	end

	local shader_active = false
	if opts.shader and love.graphics.setShader then
		local left_x, top_y, right_x, bottom_y = get_dynatext_screen_rect(text_object, string_state)
		local shader_time = ((BALATRO.get_wall_time and BALATRO.get_wall_time()) or 0) * RANK_POLYCHROME_SPEED
			+ (opts.time_offset or 0)
		send_rank_shader_value(opts.shader, "mp_rank_time", shader_time)
		send_rank_shader_value(opts.shader, "mp_rank_strength", opts.strength or 1)
		send_rank_shader_value(opts.shader, "mp_rank_screen_rect", { left_x, top_y, right_x, bottom_y })
		love.graphics.setShader(opts.shader)
		shader_active = true
	end

	local shadow_norm_x = 0
	local shadow_norm_y = 0
	local shadow_dist = math.sqrt(shadow_parrallax.y * shadow_parrallax.y + shadow_parrallax.x * shadow_parrallax.x)
	if shadow_dist > 0 then
		shadow_norm_x = shadow_parrallax.x / shadow_dist * text_object.font.FONTSCALE / G.TILESIZE
		shadow_norm_y = shadow_parrallax.y / shadow_dist * text_object.font.FONTSCALE / G.TILESIZE
	end

	for letter_index, letter in ipairs(string_state.letters or {}) do
		local real_pop_in = text_object.config.min_cycle_time == 0 and 1 or (letter.pop_in or 1)
		local letter_colour = type(colour) == "function" and colour(letter, letter_index, string_state) or colour
		love.graphics.setColor(letter_colour)
		love.graphics.draw(
			letter.letter,
			0.5 * (letter.dims.x - letter.offset.x) * text_object.font.FONTSCALE / G.TILESIZE + shadow_norm_x,
			0.5 * (letter.dims.y - letter.offset.y) * text_object.font.FONTSCALE / G.TILESIZE + shadow_norm_y,
			letter.r or 0,
			real_pop_in * letter.scale * text_object.scale * text_object.font.FONTSCALE / G.TILESIZE,
			real_pop_in * letter.scale * text_object.scale * text_object.font.FONTSCALE / G.TILESIZE,
			0.5 * letter.dims.x / text_object.scale,
			0.5 * letter.dims.y / text_object.scale
		)
		love.graphics.translate(letter.dims.x * text_object.font.FONTSCALE / G.TILESIZE, 0)
	end
	if shader_active then
		love.graphics.setShader()
	end
	love.graphics.pop()
end

local function draw_dynatext_outline(text_object, colour, offset)
	for _, delta in ipairs(TEXT_OUTLINE_OFFSETS) do
		draw_dynatext_layer(text_object, colour, delta[1] * offset, delta[2] * offset)
	end
end

local function create_outlined_text_label(text, scale, colour, options)
	local opts = options or {}
	local text_colour = colour or G.C.WHITE
	local text_object = DynaText({
		string = { tostring(text or "") },
		colours = { text_colour },
		shadow = false,
		scale = scale,
		maxw = opts.maxw,
	})
	local outline_colour = opts.outline_colour or G.C.RED
	local outline_offset = opts.outline_offset or 0.028
	text_object.draw = function(self)
		if self.children and self.children.particle_effect then
			self.children.particle_effect:draw()
		end

		draw_dynatext_outline(self, outline_colour, outline_offset)
		draw_dynatext_layer(self, text_colour, 0, 0)

		add_to_drawhash(self)
		self:draw_boundingrect()
	end

	return {
		n = G.UIT.O,
		config = {
			object = text_object,
			can_collide = false,
		},
	}
end

local function create_polychrome_rank_label(rank, scale)
	local text_object = DynaText({
		string = { "#" .. tostring(rank or "-") },
		font = G.LANGUAGES and G.LANGUAGES["en-us"] and G.LANGUAGES["en-us"].font or nil,
		colours = { G.C.WHITE },
		shadow = false,
		scale = scale,
	})
	text_object.draw = function(self)
		if self.children and self.children.particle_effect then
			self.children.particle_effect:draw()
		end

		local polychrome_shader = get_rank_polychrome_shader()
		draw_dynatext_layer(self, G.C.WHITE, 0, 0)
		if polychrome_shader then
			draw_dynatext_layer(self, colour_with_alpha(G.C.WHITE, RANK_POLYCHROME_TINT_ALPHA), 0, 0, {
				shader = polychrome_shader,
				strength = RANK_POLYCHROME_TINT_STRENGTH,
			})
		else
			draw_dynatext_layer(self, colour_with_alpha(RANK_POLYCHROME_FALLBACK_COLOUR, RANK_POLYCHROME_TINT_ALPHA), 0, 0)
		end
		draw_dynatext_layer(self, colour_with_alpha(G.C.WHITE, RANK_POLYCHROME_WHITE_ALPHA), 0, 0)

		add_to_drawhash(self)
		self:draw_boundingrect()
	end

	return {
		n = G.UIT.O,
		config = {
			object = text_object,
			can_collide = false,
		},
	}
end

local function create_text_label(text, scale, colour, shadow, options)
	if options and options.outline_colour and DynaText then
		return create_outlined_text_label(text, scale, colour, options)
	end

	return {
		n = G.UIT.T,
		config = {
			text = text,
			scale = scale,
			colour = colour or G.C.WHITE,
			shadow = shadow ~= false,
			lang = options and options.lang or nil,
		},
	}
end

local function create_stat_text_label(stat_display, fallback_text, scale, colour, shadow)
	if not stat_display then
		return create_text_label(fallback_text, scale, colour, shadow, { lang = G.LANGUAGES and G.LANGUAGES["en-us"] or nil })
	end

	stat_display.text = stat_display.text or normalize_stat_text(fallback_text)
	return {
		n = G.UIT.T,
		config = {
			text = stat_display.text,
			ref_table = stat_display,
			ref_value = "text",
			lang = G.LANGUAGES and G.LANGUAGES["en-us"] or nil,
			func = "mp_players_hud_stat_text_update",
			scale = scale,
			colour = colour or G.C.WHITE,
			shadow = shadow ~= false,
		},
	}
end

local function create_score_text_label(score_display, fallback_text, scale, colour, shadow, max_text_width)
	if not score_display then
		return create_text_label(fallback_text, scale, colour, shadow, { lang = G.LANGUAGES and G.LANGUAGES["en-us"] or nil })
	end

	score_display.text = score_display.text or tostring(fallback_text or "0")
	score_display.large_scale = scale
	score_display.small_scale = score_display.small_scale or math.min(scale or 0.18, 0.34)
	score_display.max_text_width = max_text_width or score_display.max_text_width or DEFAULT_SCORE_TEXT_MAXW
	return {
		n = G.UIT.T,
		config = {
			text = score_display.text,
			ref_table = score_display,
			ref_value = "text",
			lang = G.LANGUAGES and G.LANGUAGES["en-us"] or nil,
			func = "mp_players_hud_score_text_update",
			scale = score_scale(score_display.text, scale or 0.18, score_display.small_scale, score_display.max_text_width),
			colour = colour or G.C.WHITE,
			shadow = shadow ~= false,
		},
	}
end

local function create_rank_label(rank, scale, colour)
	local rank_number = tonumber(rank)
	local base_colour = colour or G.C.WHITE
	if rank_number == 1 and DynaText then
		return create_polychrome_rank_label(rank, scale)
	end

	local rank_data = {
		rank = rank_number,
		base_colour = base_colour,
		phase_offset = (rank_number == 1) and 0 or nil,
	}

	return {
		n = G.UIT.T,
		config = {
			text = "#" .. tostring(rank or "-"),
			scale = scale,
			colour = rank_number == 1 and G.C.WHITE or base_colour,
			shadow = true,
			lang = G.LANGUAGES and G.LANGUAGES["en-us"] or nil,
			ref_table = rank_data,
			func = "mp_players_hud_rank_label_colour",
		},
	}
end

local function create_stake_score_box(score_text, minw, text_scale, text_colour, minh, stake_scale, score_display)
	local icon_scale = stake_scale or 0.36
	local icon_size = icon_scale > 0 and math.max(0.34, icon_scale * 0.96) or 0.34
	local stake = (G and G.GAME and G.GAME.stake or nil) or 1
	local stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite(stake, icon_scale) or nil
	local box_width = minw or 1.54
	local score_text_maxw = math.max(0.6, box_width - (stake_sprite and (icon_size + 0.05) or 0) - 0.04)
	local nodes = {}
	if stake_sprite then
		nodes[#nodes + 1] = { n = G.UIT.O, config = { object = stake_sprite, w = icon_size, h = icon_size, can_collide = false } }
		nodes[#nodes + 1] = { n = G.UIT.C, config = { minw = 0.05, no_fill = true }, nodes = {} }
	end
	nodes[#nodes + 1] =
		create_score_text_label(score_display, score_text or "0", text_scale or 0.18, text_colour or G.C.WHITE, nil, score_text_maxw)

	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0,
			minw = box_width,
			minh = minh or 0.3,
			no_fill = true,
		},
		nodes = nodes,
	}
end

shared.create_text_label = create_text_label
shared.create_stat_text_label = create_stat_text_label
shared.create_score_text_label = create_score_text_label
shared.create_rank_label = create_rank_label
shared.create_stake_score_box = create_stake_score_box
shared.clean_score_text = clean_score_text
shared.try_parse_score_int = try_parse_score_int
shared.parse_score_int = parse_score_int
shared.format_score_int = format_score_int
shared.update_score_display_table = update_score_display_table
shared.get_score_display = get_score_display
shared.get_player_score_display = get_player_score_display
shared.get_score_text_scale = score_scale
shared.PVP_SCORE_EASE_DELAY = PVP_SCORE_EASE_DELAY
shared.get_self_live_score_display = get_self_live_score_display
shared.ease_standings_score_number = ease_standings_score_number
shared.get_eased_score_display = get_eased_score_display
shared.get_standings_stat_display = get_standings_stat_display

-- ============================================================================
-- SECTION 2: SHARED TEAMMATES & BLIND STYLING
-- (Consolidated from players_hud_shared_teammate_view.lua)
-- ============================================================================



local function get_shared_team_lives(team_idx)
	local self_team = MP.get_self_team_id and MP.get_self_team_id() or nil
	if self_team ~= nil and team_idx == self_team then
		return (MP.GAME and (MP.GAME.team_lives or MP.GAME.lives)) or 0
	end

	if MP.LOBBY and MP.LOBBY.players and MP.GAME and MP.GAME.enemies then
		for _, lobby_player in ipairs(MP.LOBBY.players) do
			if (lobby_player.team or 1) == team_idx and lobby_player.id ~= ((G and G.MP_ID or nil)) then
				local enemy = MP.GAME.enemies[lobby_player.id]
				if enemy and enemy.team_lives ~= nil then
					return enemy.team_lives
				elseif enemy and enemy.lives ~= nil then
					return enemy.lives
				end
			end
		end
	end

	return 0
end

shared.get_shared_team_lives = get_shared_team_lives
shared.get_player_blind_main_colour = BALATRO.get_player_blind_main_colour
shared.create_blind_style_palette = BALATRO.create_blind_style_palette
shared.create_player_blind_icon_object = BALATRO.create_player_blind_icon_object

-- ============================================================================
-- SECTION 3: BLIND ROW LAYOUT & FLOATING ICONS
-- (Consolidated from players_hud_blind_row_layout.lua)
-- ============================================================================


local create_text_label = shared.create_text_label
local create_player_blind_icon_object = shared.create_player_blind_icon_object

local function create_floating_icon_anchor(player, size, offset, id)
	local icon_size = size or 0.56
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = math.max(0.46, icon_size * 0.9),
			minh = icon_size,
			padding = 0,
			offset = offset or { x = -0.1, y = -0.01 },
			no_fill = true,
		},
		nodes = {
			{
				n = G.UIT.O,
				config = {
					id = id,
					w = icon_size,
					h = icon_size,
					object = create_player_blind_icon_object(player, icon_size),
					focus_with_object = false,
				},
			},
		},
	}
end

local function create_blind_style_body_slot(align, minw, minh, padding, colour, nodes, no_fill)
	return {
		n = G.UIT.C,
		config = {
			align = align,
			minw = minw,
			minh = minh,
			padding = padding,
			r = 0.1,
			colour = colour,
			no_fill = no_fill,
			shadow = false,
		},
		nodes = nodes or {},
	}
end

local function create_blind_style_row(config)
	local header_colour = config.header_colour or (G.C.MULTIPLAYER or G.C.DYN_UI.MAIN)
	local body_colour = config.body_colour or mix_colours(header_colour, G.C.BLACK, 0.52)
	local left_slot_colour = config.left_slot_colour or G.C.BLACK
	local center_slot_colour = config.center_slot_colour or G.C.BLACK
	local right_slot_colour = config.right_slot_colour or G.C.BLACK
	local far_right_slot_colour = config.far_right_slot_colour or G.C.BLACK
	local left_align = config.left_align or "cm"
	local left_padding = config.left_padding or 0.01
	local left_slot_no_fill = config.left_slot_no_fill or false
	local title_text = config.title or "PLAYER"
	local title_scale = config.title_scale or 0.34
	local row_width = config.minw or 5.8
	local row_height = config.minh or 1.22
	local row_padding = config.padding or 0.015
	local outer_inset = config.outer_inset or 0.06
	local inner_inset = config.inner_inset or 0.08
	local inner_width = row_width - outer_inset
	local lane_width = inner_width - inner_inset
	local header_height = config.header_minh or 0.34
	local body_height = config.body_minh or (row_height - (header_height + 0.16))
	local body_slot_height = math.max(0.25, body_height - 0.04)
	local left_width = config.left_w or 1.05
	local center_width = config.center_w or 0.94
	local far_right_width = (config.far_right_nodes and (config.far_right_w or 0.68)) or 0
	local right_width = config.right_w or (row_width - left_width - center_width - far_right_width - 0.32)
	local right_minw = config.right_minw or 1.2
	local right_padding = config.right_padding or 0.015
	local header_left_w = (config.header_left_nodes and (config.header_left_w or 0.6)) or 0
	local header_right_w = (config.header_right_nodes and (config.header_right_w or 0.6)) or 0
	local header_slot_gap = config.header_slot_gap or 0.025
	local header_left_no_fill = config.header_left_no_fill or false
	local header_center_nodes = config.header_center_nodes
		or {
			create_text_label(title_text, title_scale, G.C.UI.TEXT_LIGHT),
		}
	local header_nodes = config.header_nodes
	local header_row_colour = header_colour
	local header_row_emboss = 0.05
	local header_row_padding = 0.008
	if not header_nodes and (config.header_left_nodes or config.header_right_nodes) then
		header_row_colour = G.C.CLEAR
		header_row_emboss = 0
		header_row_padding = 0
		header_nodes = {}
		local header_center_w = math.max(0.8, lane_width - header_left_w - header_right_w - header_slot_gap)

		if config.header_left_nodes then
			header_nodes[#header_nodes + 1] = {
				n = G.UIT.C,
				config = {
					align = "cm",
					minw = header_left_w,
					minh = header_height,
					padding = 0.005,
					r = 0.1,
					colour = config.header_left_colour or (header_left_no_fill and G.C.CLEAR or G.C.BLACK),
					emboss = config.header_left_emboss == nil and (header_left_no_fill and 0 or 0.04) or config.header_left_emboss,
					shadow = false,
					no_fill = header_left_no_fill,
				},
				nodes = config.header_left_nodes,
			}
			header_nodes[#header_nodes + 1] = { n = G.UIT.C, config = { minw = header_slot_gap, no_fill = true }, nodes = {} }
		end

		header_nodes[#header_nodes + 1] = {
			n = G.UIT.C,
			config = {
				align = config.header_center_align or "cl",
				minw = header_center_w,
				minh = header_height,
				padding = 0.008,
				r = 0.1,
				colour = header_colour,
				emboss = 0.05,
				shadow = false,
			},
			nodes = header_center_nodes,
		}

		if config.header_right_nodes then
			header_nodes[#header_nodes + 1] = { n = G.UIT.C, config = { minw = header_slot_gap, no_fill = true }, nodes = {} }
			header_nodes[#header_nodes + 1] = {
				n = G.UIT.C,
				config = {
					align = "cr",
					minw = header_right_w,
					minh = header_height,
					padding = 0.005,
					r = 0.1,
					colour = config.header_right_colour or G.C.BLACK,
					emboss = 0.04,
					shadow = false,
				},
				nodes = config.header_right_nodes,
			}
		end
	elseif not header_nodes then
		header_nodes = header_center_nodes
	end

	return {
		n = G.UIT.R,
		config = {
			align = config.row_align or "cm",
			minw = row_width,
			minh = row_height,
			padding = row_padding,
			r = config.outer_r or 0.08,
			colour = config.outer_colour or G.C.BLACK,
			emboss = config.outer_emboss or 0.03,
			shadow = false,
			no_fill = false,
			outline = config.outer_outline,
			outline_colour = config.outer_outline_colour,
			on_demand_tooltip = config.on_demand_tooltip,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "tm",
					minw = inner_width,
					padding = 0.005,
					no_fill = true,
				},
				nodes = {
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							minw = lane_width,
							minh = header_height,
							padding = header_row_padding,
							r = 0.1,
							colour = header_row_colour,
							emboss = header_row_emboss,
							shadow = false,
						},
						nodes = header_nodes,
					},
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							minw = lane_width,
							minh = math.max(0.3, body_height),
							padding = 0.01,
							r = 0.1,
							colour = body_colour,
							shadow = false,
							emboss = 0.02,
						},
						nodes = {
							create_blind_style_body_slot(
								left_align,
								left_width,
								body_slot_height,
								left_padding,
								left_slot_colour,
								config.left_nodes or {},
								left_slot_no_fill
							),
							create_blind_style_body_slot(
								"cm",
								center_width,
								body_slot_height,
								0.01,
								center_slot_colour,
								config.center_nodes or {}
							),
							create_blind_style_body_slot(
								config.right_align or "cm",
								math.max(right_minw, right_width),
								body_slot_height,
								right_padding,
								right_slot_colour,
								config.right_nodes or {}
							),
							(config.far_right_nodes and create_blind_style_body_slot(
								"cm",
								far_right_width,
								body_slot_height,
								0.01,
								far_right_slot_colour,
								config.far_right_nodes
							)) or nil,
						},
					},
				},
			},
		},
	}
end

shared.create_floating_icon_anchor = create_floating_icon_anchor
shared.create_blind_style_row = create_blind_style_row

-- ============================================================================
-- SECTION 4: SHARED COMPACT LAYOUTS & PAGINATION
-- (Consolidated from players_hud_shared_layout_view.lua)
-- ============================================================================


local create_text_label = shared.create_text_label
local create_stat_text_label = shared.create_stat_text_label or create_text_label
local create_rank_label = shared.create_rank_label
local create_player_blind_icon_object = shared.create_player_blind_icon_object
local create_stake_score_box = shared.create_stake_score_box
local create_blind_style_palette = shared.create_blind_style_palette
local get_eased_score_display = shared.get_eased_score_display
local get_player_score_display = shared.get_player_score_display
local get_standings_stat_display = shared.get_standings_stat_display
local create_blind_style_row = shared.create_blind_style_row

shared.PVP_HUD_LAYOUT_REVISION = "pvp_hud_2026_09_01_native_blind_hud"

local COMPACT_SCORE_ROW_DEFAULTS = {
	minw = 5.2,
	minh = 1.12,
	padding = 0.012,
	left_w = 0.68,
	center_w = 0.62,
	right_w = 0.62,
	right_minw = 0.62,
	far_right_w = 3.12,
	right_padding = 0.01,
	header_minh = 0.42,
	body_minh = 0.66,
	outer_inset = 0.0,
	inner_inset = 0.0,
	header_left_w = 0.62,
}

local COMPACT_STANDINGS_STYLE = {
	panel_minw = 5.2,
	visible_limit = 3,
	rank_text_scale = 0.36,
	title_text_scale = 0.38,
	stat_text_scale = 0.36,
	score_text_scale = 0.56,
	score_box_w = 3.06,
	full_list_column_size = 8,
	full_list_column_gap = 0.08,
	full_list_page_columns = 4,
}

local function create_compact_score_row(config)
	config = config or {}
	for key, value in pairs(COMPACT_SCORE_ROW_DEFAULTS) do
		if config[key] == nil then
			config[key] = value
		end
	end
	return create_blind_style_row(config)
end

local function get_entry_stat_display(entry, stat_key, value)
	if not get_standings_stat_display then
		return nil
	end

	local bucket = tostring(entry.stat_bucket or "standings") .. "_" .. tostring(stat_key)
	local key = entry.stat_key or entry.id or entry.title or entry.rank or "default"
	return get_standings_stat_display(bucket, key, value)
end

local function create_compact_average_score_row(config)
	config = config or {}
	local pvp_col = config.pvp_col or G.C.MULTIPLAYER or HEX("AC3232")
	local palette = create_blind_style_palette and create_blind_style_palette(darken(pvp_col, 0.16)) or {}
	local average_score_display = get_eased_score_display(
		"average_standings_scores",
		config.average_key,
		config.average_score,
		{ delay = shared.PVP_SCORE_EASE_DELAY }
	)

	return create_compact_score_row({
		header_colour = palette.header or darken(pvp_col, config.header_darken or 0.22),
		body_colour = palette.body or mix_colours(G.C.GREY, G.C.BLACK, 0.64),
		left_slot_colour = G.C.CLEAR,
		left_slot_no_fill = true,
		center_slot_colour = G.C.BLACK,
		right_slot_colour = G.C.BLACK,
		far_right_slot_colour = G.C.BLACK,
		header_left_nodes = {
			create_text_label(config.tag or "AVG", config.tag_scale or 0.3, G.C.UI.TEXT_LIGHT),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(config.title or "AVERAGE SCORE", config.title_scale or 0.36, G.C.UI.TEXT_LIGHT),
		},
		left_nodes = {
			create_text_label("-", config.placeholder_scale or 0.34, G.C.UI.TEXT_LIGHT),
		},
		center_nodes = {
			create_text_label("-", config.stat_scale or 0.36, G.C.RED, false),
		},
		right_nodes = {
			create_stat_text_label(
				get_standings_stat_display
						and get_standings_stat_display("average_standings_hands", config.average_key, config.total_hands)
					or nil,
				tostring(config.total_hands or 0),
				config.stat_scale or 0.36,
				G.C.BLUE,
				false
			),
		},
		far_right_nodes = {
			create_stake_score_box(
				average_score_display.text,
				config.score_box_w or COMPACT_STANDINGS_STYLE.score_box_w,
				config.score_scale or 0.56,
				G.C.WHITE,
				config.score_minh or 0.52,
				config.stake_scale or 0.44,
				average_score_display
			),
		},
	})
end

local function create_compact_blind_icon_nodes(player, icon_size)
	local size = icon_size or 0.6
	return {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.005 },
			nodes = {
				{
					n = G.UIT.O,
					config = {
						object = create_player_blind_icon_object(player, size),
						w = size,
						h = size,
						focus_with_object = false,
					},
				},
			},
		},
	}
end

local function append_spaced_stack_nodes(rows, entries, create_node)
	for index, entry in ipairs(entries) do
		rows[#rows + 1] = create_node(entry)
		if index < #entries then
			rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
		end
	end
end

local function create_full_list_columns(entries, create_entry, column_size, column_minw)
	local columns = {}
	local max_per_column = math.max(1, column_size or COMPACT_STANDINGS_STYLE.full_list_column_size)

	for start_index = 1, #entries, max_per_column do
		local column_rows = {}
		local end_index = math.min(#entries, start_index + max_per_column - 1)
		for entry_index = start_index, end_index do
			column_rows[#column_rows + 1] = create_entry(entries[entry_index])
			if entry_index < end_index then
				column_rows[#column_rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
			end
		end

		columns[#columns + 1] = {
			n = G.UIT.C,
			config = {
				align = "tm",
				minw = column_minw,
				padding = 0.0,
				colour = G.C.CLEAR,
			},
			nodes = column_rows,
		}

		if end_index < #entries then
			columns[#columns + 1] = {
				n = G.UIT.C,
				config = {
					minw = COMPACT_STANDINGS_STYLE.full_list_column_gap,
					colour = G.C.CLEAR,
				},
				nodes = {},
			}
		end
	end

	return {
		n = G.UIT.R,
		config = { align = "tm", padding = 0.0, colour = G.C.CLEAR },
		nodes = columns,
	}
end

local function create_full_standings_pager(page, page_count)
	if not (page_count and page_count > 1) then
		return nil
	end

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = "<",
				button = "mp_full_standings_prev_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.RED,
			}),
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 1.0, padding = 0.02, colour = G.C.CLEAR },
				nodes = {
					create_text_label(tostring(page) .. "/" .. tostring(page_count), 0.35, G.C.UI.TEXT_LIGHT),
				},
			},
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = ">",
				button = "mp_full_standings_next_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.GREEN,
			}),
		},
	}
end

local function create_compact_stack_panel(rows, minw, full_list)
	local panel_config = full_list
		and { align = "cm", padding = 0.02, minw = minw }
		or {
			align = "cm",
			padding = 0.0,
			minw = minw,
			r = 0.0,
			colour = G.C.CLEAR,
			shadow = false,
			emboss = 0,
			no_fill = true,
		}

	return {
		{
			n = G.UIT.C,
			config = panel_config,
			nodes = rows,
		},
	}
end

local function get_compact_standings_visible_limit(average_data, limit)
	local visible_limit = limit or COMPACT_STANDINGS_STYLE.visible_limit
	if average_data and average_data.show_average then
		visible_limit = visible_limit - 1
	end
	return math.max(0, visible_limit)
end

local function select_compact_standings_entries(entries, average_data, config)
	config = config or {}
	local visible_limit = get_compact_standings_visible_limit(average_data, config.visible_limit)
	local display_entries = {}
	local pinned_entry = nil

	for index, entry in ipairs(entries or {}) do
		if config.pin_entry and not pinned_entry and config.pin_entry(entry) then
			pinned_entry = entry
		end
		if index <= visible_limit then
			display_entries[#display_entries + 1] = entry
		end
	end

	if pinned_entry and visible_limit > 0 then
		local pinned_visible = false
		for _, entry in ipairs(display_entries) do
			if entry == pinned_entry then
				pinned_visible = true
				break
			end
		end
		if not pinned_visible and #display_entries > 0 then
			display_entries[#display_entries] = pinned_entry
		end
	end

	return display_entries
end

local function get_pvp_score_rule()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local score_rule = config.pvp_score_rule
	if score_rule == "average" or score_rule == "median" or score_rule == "geometric" or score_rule == "custom" then
		return score_rule
	end
	return "highest"
end

local function get_score_rule_target_label(score_rule, is_team)
	if score_rule == "average" then
		return "AVERAGE", "AVG"
	elseif score_rule == "median" then
		return "MEDIAN", "MED"
	elseif score_rule == "geometric" then
		return "GEOMETRIC", "GEO"
	elseif score_rule == "custom" then
		return "CUSTOM", "TOP"
	end
	return nil, nil
end

local function calculate_median_score(scores)
	table.sort(scores, function(a, b)
		return MP.INSANE_INT.greater_than(b, a)
	end)

	local count = #scores
	if count <= 0 then
		return MP.INSANE_INT.empty()
	end

	local upper_middle = math.floor(count / 2) + 1
	if count % 2 == 1 then
		return scores[upper_middle]
	end

	return MP.INSANE_INT.divide_floor(MP.INSANE_INT.add(scores[upper_middle - 1], scores[upper_middle]), 2)
end

local function calculate_custom_cutoff_score(scores)
	table.sort(scores, function(a, b)
		return MP.INSANE_INT.greater_than(a, b)
	end)

	local winner_count = MP.UI.get_custom_winner_count and MP.UI.get_custom_winner_count() or math.ceil(#scores / 2)
	local cutoff_index = math.max(1, math.min(#scores, winner_count))
	return scores[cutoff_index] or MP.INSANE_INT.empty()
end

local function calculate_standings_score_target(entries, config)
	local score_rule = get_pvp_score_rule()
	local show_target = score_rule ~= "highest"
	local target_score = MP.INSANE_INT.empty()
	local total_hands = 0
	local score_key = config and config.score_key or "score_int"
	local hands_key = config and config.hands_key or "hands"
	local scores = {}

	if show_target and #entries > 0 then
		local total_score = MP.INSANE_INT.empty()
		for _, entry in ipairs(entries) do
			local score = entry[score_key] or MP.INSANE_INT.empty()
			scores[#scores + 1] = score
			total_score = MP.INSANE_INT.add(total_score, score)
			total_hands = total_hands + (entry[hands_key] or 0)
		end

		if score_rule == "average" then
			target_score = MP.INSANE_INT.divide_floor(total_score, #entries)
		elseif score_rule == "median" then
			target_score = calculate_median_score(scores)
		elseif score_rule == "geometric" then
			target_score = MP.INSANE_INT.geometric_mean(scores)
		elseif score_rule == "custom" then
			target_score = calculate_custom_cutoff_score(scores)
		end
	end

	local title, tag = get_score_rule_target_label(score_rule, config and config.is_team)
	return {
		show_average = show_target and #entries > 0,
		average_score = target_score,
		total_hands = total_hands,
		title = title,
		tag = tag,
		score_rule = score_rule,
	}
end

local function create_compact_standings_entry(entry, pvp_col)
	local palette_source = entry.palette_colour or pvp_col
	local palette = create_blind_style_palette and create_blind_style_palette(palette_source) or {}
	local body_source = entry.body_colour or pvp_col
	local far_right_source = entry.far_right_colour or body_source

	return create_compact_score_row({
		header_colour = palette.header or mix_colours(pvp_col, G.C.DYN_UI.MAIN, 0.35),
		body_colour = palette.body or mix_colours(body_source, G.C.BLACK, 0.62),
		left_slot_colour = G.C.CLEAR,
		left_slot_no_fill = true,
		left_align = "tm",
		left_padding = 0.0,
		header_left_colour = G.C.CLEAR,
		header_left_emboss = 0,
		header_left_no_fill = true,
		center_slot_colour = G.C.BLACK,
		right_slot_colour = G.C.BLACK,
		far_right_slot_colour = G.C.BLACK,
		header_left_nodes = {
			create_rank_label(entry.rank, COMPACT_STANDINGS_STYLE.rank_text_scale, entry.rank_colour),
		},
		header_center_align = "cm",
		header_center_nodes = {
			create_text_label(entry.title or "Unknown", COMPACT_STANDINGS_STYLE.title_text_scale, entry.title_colour or G.C.UI.TEXT_LIGHT, nil, {
				outline_colour = entry.title_outline_colour,
				outline_offset = entry.title_outline_offset,
			}),
		},
		left_nodes = create_compact_blind_icon_nodes(entry.blind_player),
		center_nodes = {
			create_stat_text_label(
				get_entry_stat_display(entry, "lives", entry.lives),
				tostring(entry.lives or 0),
				COMPACT_STANDINGS_STYLE.stat_text_scale,
				G.C.RED,
				false
			),
		},
		right_nodes = {
			create_stat_text_label(
				get_entry_stat_display(entry, "hands", entry.hands),
				tostring(entry.hands or 0),
				COMPACT_STANDINGS_STYLE.stat_text_scale,
				G.C.BLUE,
				false
			),
		},
		far_right_nodes = {
			create_stake_score_box(
				entry.score_text or "0",
				COMPACT_STANDINGS_STYLE.score_box_w,
				COMPACT_STANDINGS_STYLE.score_text_scale,
				G.C.WHITE,
				0.52,
				0.44,
				entry.score_display
			),
		},
	})
end

local function create_compact_standings_nodes(config)
	local rows = {}
	local pvp_col = config.pvp_col or G.C.MULTIPLAYER or HEX("AC3232")
	local entries = config.entries or {}
	local average_data = config.average_data
	local panel_minw = config.panel_minw or COMPACT_STANDINGS_STYLE.panel_minw
	local display_entries = config.full_list and entries
		or config.display_entries
		or select_compact_standings_entries(entries, average_data, config)

	local page_entries = display_entries
	local page = 1
	local page_count = 1
	if config.full_list then
		local column_size = config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size
		local page_columns = config.full_list_page_columns or COMPACT_STANDINGS_STYLE.full_list_page_columns
		local page_size = math.max(1, page_columns * math.max(1, column_size))
		page_count = math.max(1, math.ceil(#display_entries / page_size))
		local runtime = MP.UI.get_player_list_runtime and MP.UI.get_player_list_runtime() or nil
		page = runtime and math.max(1, math.min(math.floor(tonumber(runtime.full_standings_page) or 1), page_count)) or 1
		if runtime then
			runtime.full_standings_page = page
			runtime.full_standings_page_count = page_count
		end
		local first_index = ((page - 1) * page_size) + 1
		local last_index = math.min(#display_entries, first_index + page_size - 1)
		page_entries = {}
		for idx = first_index, last_index do
			page_entries[#page_entries + 1] = display_entries[idx]
		end
	end

	local function mark_compact_standings_row(row)
		if not config.full_list and row and row.config then
			row.config.button = "mp_open_full_standings"
			row.config.hover = true
			row.config.shadow = false
			row.config.button_dist = 0
		end
		return row
	end

	if average_data and average_data.show_average then
		rows[#rows + 1] = mark_compact_standings_row(create_compact_average_score_row({
			pvp_col = pvp_col,
			title = average_data.title or config.average_title,
			tag = average_data.tag,
			average_key = config.average_key,
			total_hands = average_data.total_hands,
			average_score = average_data.average_score,
			header_darken = config.average_header_darken,
		}))
		rows[#rows + 1] = { n = G.UIT.R, config = { minh = 0.014 } }
	end

	if config.full_list then
		rows[#rows + 1] = create_full_list_columns(
			page_entries,
			config.create_entry,
			config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size,
			panel_minw
		)
		local pager = create_full_standings_pager(page, page_count)
		if pager then
			rows[#rows + 1] = pager
		end
	else
		append_spaced_stack_nodes(rows, display_entries, function(entry)
			return mark_compact_standings_row(config.create_entry(entry))
		end)
	end

	local column_count = config.full_list
		and math.max(1, math.ceil(#page_entries / (config.full_list_column_size or COMPACT_STANDINGS_STYLE.full_list_column_size)))
		or 1
	local full_list_minw = panel_minw * column_count
		+ (COMPACT_STANDINGS_STYLE.full_list_column_gap * math.max(0, column_count - 1))

	return create_compact_stack_panel(
		rows,
		config.full_list and full_list_minw or panel_minw,
		not not config.full_list
	)
end

shared.create_compact_score_row = create_compact_score_row
shared.create_compact_average_score_row = create_compact_average_score_row
shared.create_compact_standings_entry = create_compact_standings_entry
shared.create_compact_standings_nodes = create_compact_standings_nodes
shared.create_compact_blind_icon_nodes = create_compact_blind_icon_nodes
shared.append_spaced_stack_nodes = append_spaced_stack_nodes
shared.create_compact_stack_panel = create_compact_stack_panel
shared.calculate_standings_average = calculate_standings_score_target
shared.get_compact_standings_visible_limit = get_compact_standings_visible_limit
shared.select_compact_standings_entries = select_compact_standings_entries
shared.COMPACT_STANDINGS_STYLE = COMPACT_STANDINGS_STYLE

-- ============================================================================
-- SECTION 5: FFA STANDINGS VIEWS
-- (Consolidated from players_hud_ffa_view.lua)
-- ============================================================================

local get_player_blind_main_colour = shared.get_player_blind_main_colour
local calculate_standings_average = shared.calculate_standings_average
local create_compact_standings_entry = shared.create_compact_standings_entry
local create_compact_standings_nodes = shared.create_compact_standings_nodes
local get_eased_score_display = shared.get_eased_score_display
local get_player_score_display = shared.get_player_score_display
local get_standings_stat_display = shared.get_standings_stat_display

local function get_ffa_rank_colour(rank)
	if rank == 1 then
		return G.C.GOLD
	elseif rank == 2 then
		return G.C.BLUE
	elseif rank == 3 then
		return G.C.GREEN
	end
	return G.C.WHITE
end

function MP.UI.calculate_ffa_average(players)
	return calculate_standings_average(players, {
		score_key = "score_int",
		hands_key = "hands",
	})
end

function MP.UI.refresh_ffa_standings_score_targets(players)
	local standings_players = players or MP.UI.get_sorted_players()
	for _, player in ipairs(standings_players) do
		if player.id then
			local score_display = player.score_display
				or (get_player_score_display and get_player_score_display(player.id, player.score_text, player.score_int, true))
			if score_display and player.score_target_text then
				score_display.raw_text = player.score_target_text
			end
		end
	end

	local average_data = MP.UI.calculate_ffa_average(standings_players)
	if average_data.show_average and get_eased_score_display then
		get_eased_score_display("average_standings_scores", "ffa", average_data.average_score, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		})
	end
end

function MP.UI.refresh_ffa_standings_stat_targets(players)
	if not get_standings_stat_display then
		return
	end

	local standings_players = players or MP.UI.get_sorted_players()
	for _, player in ipairs(standings_players) do
		if player.id then
			get_standings_stat_display("player_standings_lives", player.id, player.lives)
			get_standings_stat_display("player_standings_hands", player.id, player.hands)
		end
	end

	local average_data = MP.UI.calculate_ffa_average(standings_players)
	if average_data.show_average then
		get_standings_stat_display("average_standings_hands", "ffa", average_data.total_hands)
	end
end

local function create_ffa_compact_entry(player, pvp_col)
	local accent = get_ffa_rank_colour(player.rank)
	local blind_main = get_player_blind_main_colour and get_player_blind_main_colour(player, pvp_col) or pvp_col
	local score_display = player.score_display
		or (get_player_score_display and get_player_score_display(player.id, player.score_text, player.score_int, true))
		or (get_eased_score_display and get_eased_score_display("player_standings_scores", player.id, player.score_int, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		}))
	return create_compact_standings_entry({
		rank = player.rank,
		rank_colour = accent,
		title = player.username or "Unknown",
		title_colour = player.is_self and G.C.EDITION or G.C.UI.TEXT_LIGHT,
		title_outline_colour = player.is_duels_nemesis and G.C.RED or nil,
		is_self = player.is_self,
		palette_colour = blind_main,
		body_colour = pvp_col,
		far_right_colour = pvp_col,
		stat_bucket = "player_standings",
		stat_key = player.id,
		blind_player = player,
		lives = player.lives,
		hands = player.hands,
		score_text = player.score_text,
		score_display = score_display,
	}, pvp_col)
end

function MP.UI.create_ffa_standings_nodes(full_list)
	local players = MP.UI.get_sorted_players()
	local average_data = MP.UI.calculate_ffa_average(players)
	local pvp_col = G.C.MULTIPLAYER or HEX("AC3232")

	return create_compact_standings_nodes({
		full_list = full_list,
		entries = players,
		average_data = average_data,
		average_title = "AVERAGE SCORE",
		average_key = "ffa",
		average_header_darken = 0.22,
		pvp_col = pvp_col,
		pin_entry = function(player)
			return player.is_self
		end,
		create_entry = function(player)
			return create_ffa_compact_entry(player, pvp_col)
		end,
	})
end

-- ============================================================================
-- SECTION 6: TEAMS STANDINGS VIEWS
-- (Consolidated from players_hud_teams_view.lua)
-- ============================================================================

local get_shared_team_lives = shared.get_shared_team_lives
local calculate_standings_average = shared.calculate_standings_average
local create_compact_standings_entry = shared.create_compact_standings_entry
local create_compact_standings_nodes = shared.create_compact_standings_nodes
local get_eased_score_display = shared.get_eased_score_display
local get_standings_stat_display = shared.get_standings_stat_display

local get_team_score_display

local function get_team_rank_colour(rank)
	if rank == 1 then
		return G.C.GOLD
	elseif rank == 2 then
		return HEX("D8DEE8")
	elseif rank == 3 then
		return HEX("D49A4A")
	end
	return G.C.WHITE
end

local function build_active_teams(players)
	local teams_data = {}
	for i = 1, MP.MAX_TEAMS do
		teams_data[i] = {
			id = i,
			total_score = MP.INSANE_INT.empty(),
			score_text = "0",
			total_hands = 0,
			players = {},
			color = MP.TEAM_COLORS[i] or G.C.WHITE,
			name = MP.TEAM_NAMES[i] or ("TEAM " .. tostring(i)),
			is_self_team = false,
			shared_lives = 0,
		}
	end

	for _, player in ipairs(players) do
		local team_idx = math.max(1, math.min(MP.MAX_TEAMS, tonumber(player.team) or 1))
		local team = teams_data[team_idx]
		team.total_score = MP.INSANE_INT.add(team.total_score, player.score_int)
		team.total_hands = team.total_hands + (player.hands or 0)
		team.is_self_team = team.is_self_team or player.is_self
		table.insert(team.players, player)
	end

	local active_teams = {}
	for _, team in ipairs(teams_data) do
		if #team.players > 0 then
			table.sort(team.players, function(a, b)
				return MP.INSANE_INT.greater_than(a.score_int, b.score_int)
			end)
			team.shared_lives = get_shared_team_lives(team.id)
			team.score_text = MP.INSANE_INT.to_string(team.total_score)
			team.score_display = get_team_score_display(team)
			table.insert(active_teams, team)
		end
	end

	table.sort(active_teams, function(a, b)
		return MP.INSANE_INT.greater_than(a.total_score, b.total_score)
	end)

	for rank, team in ipairs(active_teams) do
		team.rank = rank
	end

	return active_teams
end

local function get_team_representative_player(team)
	if not team or not team.players then
		return nil
	end

	for _, player in ipairs(team.players) do
		if player.is_self then return player end
	end

	return team.players[1]
end

get_team_score_display = function(team)
	return get_eased_score_display("team_standings_scores", team.id, team.total_score, {
		delay = shared.PVP_SCORE_EASE_DELAY,
	})
end

local function calculate_team_average(active_teams)
	return calculate_standings_average(active_teams, {
		score_key = "total_score",
		hands_key = "total_hands",
		is_team = true,
	})
end

function MP.UI.refresh_team_standings_score_targets(players)
	local active_teams = build_active_teams(players or MP.UI.get_sorted_players())
	local average_data = calculate_team_average(active_teams)
	if average_data.show_average then
		get_eased_score_display("average_standings_scores", "teams", average_data.average_score, {
			delay = shared.PVP_SCORE_EASE_DELAY,
		})
	end
	return active_teams
end

function MP.UI.refresh_team_standings_stat_targets(players)
	if not get_standings_stat_display then
		return
	end

	local active_teams = build_active_teams(players or MP.UI.get_sorted_players())
	for _, team in ipairs(active_teams) do
		get_standings_stat_display("team_standings_lives", team.id, team.shared_lives)
		get_standings_stat_display("team_standings_hands", team.id, team.total_hands)
	end

	local average_data = calculate_team_average(active_teams)
	if average_data.show_average then
		get_standings_stat_display("average_standings_hands", "teams", average_data.total_hands)
	end
end

local function create_team_compact_entry(team, pvp_col)
	local rank_colour = get_team_rank_colour(team.rank)
	local representative = get_team_representative_player(team)

	return create_compact_standings_entry({
		rank = team.rank,
		rank_colour = rank_colour,
		title = team.name,
		title_colour = team.is_self_team and G.C.EDITION or G.C.WHITE,
		is_self_team = team.is_self_team,
		palette_colour = team.color,
		body_colour = team.color,
		far_right_colour = team.color,
		stat_bucket = "team_standings",
		stat_key = team.id,
		blind_player = representative,
		lives = team.shared_lives,
		hands = team.total_hands,
		score_text = team.score_text,
		score_display = team.score_display,
	}, pvp_col)
end

function MP.UI.create_teams_standings_nodes(full_list)
	local players = MP.UI.get_sorted_players()
	local pvp_col = G.C.MULTIPLAYER or HEX("AC3232")
	local active_teams = build_active_teams(players)
	local average_data = calculate_team_average(active_teams)

	return create_compact_standings_nodes({
		full_list = full_list,
		entries = active_teams,
		average_data = average_data,
		average_title = "TEAM AVERAGE",
		average_key = "teams",
		average_header_darken = 0.24,
		pvp_col = pvp_col,
		pin_entry = function(team)
			return team.is_self_team
		end,
		create_entry = function(team)
			return create_team_compact_entry(team, pvp_col)
		end,
	})
end

-- ============================================================================
-- SECTION 7: STANDINGS VIEW MODEL & PLAYER DATA
-- (Consolidated from players_hud_view_model.lua)
-- ============================================================================

-- Shared player list state and reusable standings helpers.
-- FFA standings live in players_hud_ffa_view.lua.
-- Teams standings live in players_hud_teams_view.lua.


local function get_self_player_id()
	return (G and G.MP_ID or nil)
end

local function get_lobby_player(player_id)
	if player_id == nil then
		return nil
	end

	if MP.get_lobby_player_by_id then
		return MP.get_lobby_player_by_id(player_id)
	end

	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player.id == player_id then
			return player
		end
	end

	return nil
end

local function get_local_hands_left()
	return (G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or nil)
end

local function player_is_spectator(player)
	return not not (player and (player.is_spectator or player.role == "spectator"))
end

local function client_is_spectator()
	if MP.SPECTATOR and (MP.SPECTATOR.is_spectating or MP.SPECTATOR.is_spectator_role) then
		return true
	end
	local lobby_client = MP.LOBBY and MP.LOBBY.client
	if lobby_client and (lobby_client.is_spectator or lobby_client.role == "spectator") then
		return true
	end
	return player_is_spectator(MP.get_self_lobby_player and MP.get_self_lobby_player() or nil)
end

local function build_self_standings_player()
	if not MP.GAME then
		return nil
	end

	local spec = MP.SPECTATOR
	if spec and spec.is_spectating and spec.target_player_id then
		local target_id = spec.target_player_id
		local lobby_player = get_lobby_player(target_id)
		return {
			id = target_id,
			username = (lobby_player and lobby_player.username) or spec.target_username or "Player",
			score_text = tostring(MP.GAME.score_text or "0"),
			score_display_int = MP.GAME.score_display,
			hands = get_local_hands_left(),
			lives = MP.GAME.lives or (lobby_player and lobby_player.lives) or 0,
			is_self = true,
			team = (lobby_player and lobby_player.team) or 1,
			blind_col = (MP.UTILS and MP.UTILS.get_blind_col and MP.UTILS.get_blind_col())
				or (lobby_player and lobby_player.blind_col)
				or 1,
			config = lobby_player and lobby_player.config or nil,
		}
	end

	if client_is_spectator() then
		return nil
	end

	local player_id = get_self_player_id()
	if player_id == nil then
		return nil
	end

	local lobby_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or get_lobby_player(player_id)
	local lobby_client = MP.LOBBY and MP.LOBBY.client or {}
	local target_score_text = tostring(MP.GAME.score_text or "0")
	local live_chips_text, live_chips = get_self_live_score_display()
	local self_score_text = (live_chips_text and live_chips ~= nil) and live_chips_text or target_score_text
	local target_score_int = (MP.GAME.synced_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(MP.GAME.synced_score)) and MP.GAME.synced_score)
		or parse_score_int(target_score_text)
	local self_score_int = (live_chips ~= nil and try_parse_score_int(self_score_text))
		or (MP.GAME.score_display and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(MP.GAME.score_display)) and MP.GAME.score_display)
		or target_score_int
	return {
		id = player_id,
		username = (lobby_player and lobby_player.username) or lobby_client.username or "You",
		score_text = self_score_text,
		score_target_int = target_score_int,
		score_display_int = self_score_int,
		hands = get_local_hands_left(),
		lives = MP.GAME.lives or 0,
		is_self = true,
		team = (lobby_player and lobby_player.team) or 1,
		blind_col = (MP.UTILS and MP.UTILS.get_blind_col and MP.UTILS.get_blind_col())
			or (lobby_player and lobby_player.blind_col)
			or lobby_client.blind_col
			or 1,
		config = lobby_player and lobby_player.config or nil,
	}
end

local function build_enemy_standings_player(player_id, enemy, opts)
	if not enemy or enemy.in_match == false then
		return nil
	end

	local options = opts or {}
	local lobby_player = get_lobby_player(player_id)
	local target_score = (enemy.synced_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(enemy.synced_score)) and enemy.synced_score)
		or (enemy.score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(enemy.score)) and enemy.score)
		or nil
	local target_score_text = (enemy.score_text and enemy.score_text ~= "" and enemy.score_text ~= "0" and enemy.score_text)
		or (target_score and MP.INSANE_INT and MP.INSANE_INT.to_string(target_score))
		or tostring(enemy.score_text or "0")
	local live_easing_score = enemy.score or target_score

	return {
		id = player_id,
		username = enemy.username or (lobby_player and lobby_player.username) or "Unknown",
		score_text = target_score_text,
		score_target_int = target_score,
		score_display_int = live_easing_score,
		hands = enemy.hands or 0,
		lives = enemy.lives or 0,
		is_self = false,
		team = enemy.team or (lobby_player and lobby_player.team),
		blind_col = (lobby_player and lobby_player.blind_col) or 1,
		config = lobby_player and lobby_player.config or nil,
		is_duels_nemesis = not not options.is_duels_nemesis,
	}
end

local function add_enemy_standings_player(players, included_ids, player_id, enemy, opts)
	if player_id == nil or included_ids[player_id] then
		return
	end
	if player_is_spectator(get_lobby_player(player_id)) then
		return
	end

	local row = build_enemy_standings_player(player_id, enemy, opts)
	if not row then
		return
	end

	players[#players + 1] = row
	included_ids[player_id] = true
end

local function add_dummy_standings_players(players, included_ids)
	local testing = MP.TESTING or {}
	if not testing.get_dummy_players then
		return
	end

	for _, dummy in ipairs(testing.get_dummy_players()) do
		if dummy.id and not included_ids[dummy.id] then
			local dummy_target_score = dummy.score_target_int or dummy.score_int or parse_score_int(dummy.score_text)
			players[#players + 1] = {
				id = dummy.id,
				username = dummy.username or "Dummy",
				score_text = tostring(dummy.score_text or "0"),
				score_target_int = dummy_target_score,
				score_display_int = dummy.score or dummy.score_display_int or dummy_target_score,
				hands = dummy.hands or 0,
				lives = dummy.lives or 0,
				is_self = false,
				team = dummy.team,
				blind_col = dummy.blind_col or 1,
				config = dummy.config,
			}
			included_ids[dummy.id] = true
		end
	end
end

local function add_duels_opponent_standings_player(players, included_ids, enemies)
	local opponents = MP.OPPONENTS or {}
	local nemesis = opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player() or nil
	local nemesis_id = nemesis and nemesis.id
	if not nemesis_id then
		local ref_id = (MP.SPECTATOR and MP.SPECTATOR.is_spectating and MP.SPECTATOR.target_player_id) or get_self_player_id()
		local p = get_lobby_player(ref_id)
		nemesis_id = p and p.nemesis_player_id
	end
	if not nemesis_id then
		return
	end

	add_enemy_standings_player(players, included_ids, nemesis_id, enemies[nemesis_id], {
		is_duels_nemesis = true,
	})
end

function MP.UI.get_live_match_standings_players()
	local players = {}
	local included_ids = {}
	local enemies = MP.GAME and MP.GAME.enemies or {}
	local self_player = build_self_standings_player()

	if self_player then
		players[#players + 1] = self_player
		included_ids[self_player.id] = true
	end

	if MP.is_duels_mode and MP.is_duels_mode() then
		add_duels_opponent_standings_player(players, included_ids, enemies)
		return players
	end

	for _, lobby_player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if not player_is_spectator(lobby_player) then
			local enemy = enemies[lobby_player.id]
			if not enemy and MP.DOMAIN and MP.DOMAIN.MATCH and MP.DOMAIN.MATCH.get_or_create_enemy_state then
				enemy = MP.DOMAIN.MATCH.get_or_create_enemy_state(lobby_player.id, lobby_player.username)
			end
			add_enemy_standings_player(players, included_ids, lobby_player.id, enemy)
		end
	end

	for player_id, enemy in pairs(enemies) do
		add_enemy_standings_player(players, included_ids, player_id, enemy)
	end

	add_dummy_standings_players(players, included_ids)

	return players
end

local function get_terminal_standings_players()
	if not (((G and (G.STATE == G.STATES.GAME_OVER or G.STATE == G.STATES.GAME_WIN) or false)) or (MP.GAME and MP.GAME.won)) then
		return nil, false
	end

	if MP.UI and MP.UI.get_end_game_standings_participants then
		return MP.UI.get_end_game_standings_participants() or {}, true
	end

	return {}, true
end

local function get_standings_source_players()
	local terminal_players, using_terminal_standings = get_terminal_standings_players()
	if using_terminal_standings then
		return terminal_players
	end

	return MP.UI.get_live_match_standings_players()
end

function MP.UI.get_sorted_players()
	local players = {}
	local source_players = get_standings_source_players()

	if source_players then
		for _, standings_player in ipairs(source_players) do
			local raw_score_text = tostring(standings_player.score_text or "0")
			local live_score_int = standings_player.score_display_int
			local target_score_int = standings_player.score_target_int
				or standings_player.score_int
				or parse_score_int(raw_score_text)
			local score_display = (get_player_score_display and get_player_score_display(
				standings_player.id,
				raw_score_text,
				live_score_int or target_score_int,
				true,
				standings_player.is_self
			)) or shared.get_score_display(
				raw_score_text,
				live_score_int or target_score_int,
				{ prefer_score_int = true }
			)
			score_display.is_self = not not standings_player.is_self
			local target_score_text = (target_score_int and MP.INSANE_INT and MP.INSANE_INT.to_string and MP.INSANE_INT.to_string(target_score_int)) or raw_score_text

			table.insert(players, {
				id = standings_player.id,
				username = standings_player.username or "Unknown",
				score_text = score_display.text,
				score_target_text = target_score_text,
				score_int = target_score_int,
				score_display = score_display,
				hands = standings_player.hands or 0,
				lives = standings_player.lives or 0,
				is_self = not not standings_player.is_self,
				is_duels_nemesis = not not standings_player.is_duels_nemesis,
				team = standings_player.team,
				blind_col = standings_player.blind_col or 1,
				config = standings_player.config,
			})
		end
	end

	table.sort(players, function(a, b)
		if not a.score_int or not b.score_int then return false end
		return MP.INSANE_INT.greater_than(a.score_int, b.score_int)
	end)

	for i, player in ipairs(players) do
		player.rank = i
	end

	return players
end

function MP.UI.get_pvp_score_to_beat()
	local ref_player_id = nil
	if MP.SPECTATOR and MP.SPECTATOR.is_spectating and MP.SPECTATOR.target_player_id then
		ref_player_id = MP.SPECTATOR.target_player_id
	else
		ref_player_id = get_self_player_id()
	end

	-- 1. Duel Bye: Solo player facing the Boss Blind target
	if MP.is_duel_bye_blind and MP.is_duel_bye_blind() then
		local ante = (G.GAME and G.GAME.round_resets and (G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante)) or 1
		local mult = 2
		local scaling = (G.GAME and G.GAME.starting_params and G.GAME.starting_params.ante_scaling) or 1
		local get_amt = BALATRO.get_blind_amount or (type(get_blind_amount) == "function" and get_blind_amount)
		local boss_chips = (get_amt and get_amt(ante) or 300) * mult * scaling
		local boss_int = MP.INSANE_INT and MP.INSANE_INT.from_number and MP.INSANE_INT.from_number(boss_chips)
		local num_fmt = number_format or (type(number_format) == "function" and number_format)
		return boss_int, num_fmt and num_fmt(boss_chips) or tostring(boss_chips)
	end

	-- 2. Duels: Direct 1v1 opponent score
	if MP.is_duels_mode and MP.is_duels_mode() then
		local players = MP.UI.get_sorted_players()
		for _, player in ipairs(players) do
			if player.is_duels_nemesis then
				local score_val = player.score_int
				local s_text = (player.score_target_text and player.score_target_text ~= "" and player.score_target_text ~= "0" and player.score_target_text)
					or (player.score_text and player.score_text ~= "" and player.score_text ~= "0" and player.score_text)
					or (score_val and MP.INSANE_INT and MP.INSANE_INT.to_string(score_val))
					or "0"
				return score_val, s_text
			end
		end
		local opponents = MP.OPPONENTS or {}
		local nemesis_state = opponents.get_nemesis_enemy_state and opponents.get_nemesis_enemy_state()
		local nem_score = nemesis_state and (nemesis_state.synced_score or nemesis_state.score)
		if nem_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(nem_score)) then
			return nem_score, nemesis_state.score_text or (MP.INSANE_INT and MP.INSANE_INT.to_string(nem_score)) or "0"
		end
		local p = get_lobby_player(ref_player_id)
		local nem_id = p and p.nemesis_player_id
		if nem_id and MP.GAME and MP.GAME.enemies and MP.GAME.enemies[nem_id] then
			local enemy = MP.GAME.enemies[nem_id]
			local e_score = enemy.synced_score or enemy.score
			if e_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(e_score)) then
				return e_score, enemy.score_text or (MP.INSANE_INT and MP.INSANE_INT.to_string(e_score)) or "0"
			end
		end
		local enemy = opponents.get_primary_enemy_state and opponents.get_primary_enemy_state()
		local pri_score = enemy and (enemy.synced_score or enemy.score)
		if pri_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(pri_score)) then
			return pri_score, enemy.score_text or (MP.INSANE_INT and MP.INSANE_INT.to_string(pri_score)) or "0"
		end
		return MP.INSANE_INT and MP.INSANE_INT.empty() or nil, "0"
	end

	-- 3. Teams: Highest opposing team aggregate score
	if MP.is_teams_mode and MP.is_teams_mode() then
		local players = MP.UI.get_sorted_players()
		local ref_team_id = nil
		for _, p in ipairs(players) do
			if (ref_player_id and p.id == ref_player_id) or p.is_self then
				ref_team_id = tonumber(p.team) or 1
				break
			end
		end
		if not ref_team_id and ref_player_id then
			local lobby_player = get_lobby_player(ref_player_id)
			if lobby_player and lobby_player.team then
				ref_team_id = tonumber(lobby_player.team) or 1
			end
		end
		ref_team_id = ref_team_id or 1
		local team_scores = {}
		for _, p in ipairs(players) do
			local tid = tonumber(p.team) or 1
			local p_score = p.score_int
			if (not p_score or (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(p_score))) and p.score_target_text and p.score_target_text ~= "0" then
				p_score = MP.INSANE_INT.from_string(p.score_target_text)
			end
			team_scores[tid] = MP.INSANE_INT and MP.INSANE_INT.add(team_scores[tid] or MP.INSANE_INT.empty(), p_score or MP.INSANE_INT.empty())
		end
		local highest_enemy_team_score = MP.INSANE_INT and MP.INSANE_INT.empty() or nil
		for tid, tscore in pairs(team_scores) do
			if tid ~= ref_team_id then
				if not highest_enemy_team_score or (MP.INSANE_INT and MP.INSANE_INT.greater_than(tscore, highest_enemy_team_score)) then
					highest_enemy_team_score = tscore
				end
			end
		end
		if highest_enemy_team_score then
			return highest_enemy_team_score, MP.INSANE_INT and MP.INSANE_INT.to_string(highest_enemy_team_score) or "0"
		end
		return MP.INSANE_INT and MP.INSANE_INT.empty() or nil, "0"
	end

	-- 4. FFA: Dependent on pvp_score_rule
	local players = MP.UI.get_sorted_players()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local score_rule = config.pvp_score_rule or "highest"

	if score_rule == "highest" then
		for _, player in ipairs(players) do
			local is_ref = (ref_player_id and player.id == ref_player_id) or player.is_self
			if not is_ref then
				local score_val = player.score_int
				local s_text = (player.score_target_text and player.score_target_text ~= "" and player.score_target_text ~= "0" and player.score_target_text)
					or (player.score_text and player.score_text ~= "" and player.score_text ~= "0" and player.score_text)
					or (score_val and MP.INSANE_INT and MP.INSANE_INT.to_string(score_val))
					or "0"
				if s_text ~= "0" then
					return score_val, s_text
				end
			end
		end

		-- Direct fallback from MP.GAME.enemies if players didn't yield a non-zero opponent score
		local best_enemy_int = nil
		local best_enemy_text = nil
		for eid, enemy in pairs(MP.GAME and MP.GAME.enemies or {}) do
			if eid ~= ref_player_id then
				local escore = (enemy.synced_score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(enemy.synced_score)) and enemy.synced_score)
					or (enemy.score and not (MP.INSANE_INT and MP.INSANE_INT.is_empty and MP.INSANE_INT.is_empty(enemy.score)) and enemy.score)
					or (enemy.score_text and enemy.score_text ~= "" and enemy.score_text ~= "0" and MP.INSANE_INT and MP.INSANE_INT.from_string(enemy.score_text))
				if escore then
					if not best_enemy_int or (MP.INSANE_INT and MP.INSANE_INT.greater_than(escore, best_enemy_int)) then
						best_enemy_int = escore
						best_enemy_text = enemy.score_text or (MP.INSANE_INT and MP.INSANE_INT.to_string(escore))
					end
				end
			end
		end
		if best_enemy_text and best_enemy_text ~= "" and best_enemy_text ~= "0" then
			return best_enemy_int, best_enemy_text
		end

		-- Check if any opponent in players had 0
		for _, player in ipairs(players) do
			local is_ref = (ref_player_id and player.id == ref_player_id) or player.is_self
			if not is_ref then
				return player.score_int, player.score_text or "0"
			end
		end

		return MP.INSANE_INT and MP.INSANE_INT.empty() or nil, "0"
	else
		local average_data = MP.UI.calculate_ffa_average and MP.UI.calculate_ffa_average(players)
		if average_data and average_data.average_score then
			return average_data.average_score, MP.INSANE_INT and MP.INSANE_INT.to_string(average_data.average_score) or "0"
		end
	end

	return MP.INSANE_INT and MP.INSANE_INT.empty() or nil, "0"
end

-- ============================================================================
-- SECTION 8: OVERLAY CONTROLLER & LIFECYCLE HOOKS
-- (Consolidated from players_hud_overlay_controller.lua)
-- ============================================================================

-- PvP standings sit on the vanilla blind HUD. Blind.lua and Steamodded
-- still own HUD_blind_name / dollars_to_be_earned / HUD_blind_debuff;
-- we hide those rows and overlay the table. Live score/hands/lives update
-- through DynaText. The UIBox is rebuilt only when the roster changes.


local function get_player_list_mode()
	if MP.is_teams_mode and MP.is_teams_mode() then
		return "teams"
	end
	if (MP.is_ffa_mode and MP.is_ffa_mode()) or (MP.is_duels_mode and MP.is_duels_mode()) then
		return "ffa"
	end
	return nil
end

function MP.UI.using_standings_blind_hud()
	return not not (
		MP.LOBBY
		and MP.LOBBY.code
		and MP.is_pvp_boss
		and MP.is_pvp_boss()
		and get_player_list_mode()
	)
end

local function stringify_signature_value(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function build_player_list_signature(mode)
	if not mode then
		return "none"
	end

	local players = MP.UI.get_sorted_players and MP.UI.get_sorted_players() or {}
	local parts = {
		mode,
		"layout=" .. stringify_signature_value(shared.PVP_HUD_LAYOUT_REVISION),
		stringify_signature_value(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.pvp_score_rule),
		stringify_signature_value(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.pvp_custom_winners),
	}

	for _, player in ipairs(players) do
		parts[#parts + 1] = table.concat({
			stringify_signature_value(player.id),
			stringify_signature_value(player.username),
			stringify_signature_value(player.team),
			stringify_signature_value(player.blind_col),
			stringify_signature_value(player.is_self),
			stringify_signature_value(player.is_spectator),
			stringify_signature_value(player.role),
		}, "|")
	end

	return table.concat(parts, ";")
end

local function refresh_score_targets(mode)
	local players = MP.UI.get_sorted_players and MP.UI.get_sorted_players() or nil
	if mode == "teams" and MP.UI.refresh_team_standings_score_targets then
		MP.UI.refresh_team_standings_score_targets(players)
		if MP.UI.refresh_team_standings_stat_targets then
			MP.UI.refresh_team_standings_stat_targets(players)
		end
	elseif mode == "ffa" and MP.UI.refresh_ffa_standings_score_targets then
		MP.UI.refresh_ffa_standings_score_targets(players)
		if MP.UI.refresh_ffa_standings_stat_targets then
			MP.UI.refresh_ffa_standings_stat_targets(players)
		end
	end

	if MP.is_pvp_boss and MP.is_pvp_boss() and not (MP.is_duel_bye_blind and MP.is_duel_bye_blind()) then
		if G.GAME and G.GAME.blind and MP.UI and MP.UI.get_pvp_score_to_beat then
			local score_int, score_text = MP.UI.get_pvp_score_to_beat()
			if score_int then
				G.GAME.blind.chips = (MP.INSANE_INT and MP.INSANE_INT.to_safe_number(score_int)) or 0
				G.GAME.blind.chip_text = score_text or tostring(G.GAME.blind.chips)
			end
		end
	end
end

-- Keep name/score on the normal HUD text path so button hover does not
-- redraw them as lifted glyphs.
local function seat_standings_labels(node)
	if not node then
		return
	end
	if node.UIT == G.UIT.T or node.UIT == G.UIT.O then
		if node.config then
			node.config.button_UIE = nil
		end
	end
	if node.children then
		for _, child in pairs(node.children) do
			seat_standings_labels(child)
		end
	end
end

local function set_vanilla_blind_rows_visible(visible)
	local hud = BALATRO.get_hud_blind and BALATRO.get_hud_blind()
	local root = hud and hud.get_UIE_by_ID and hud:get_UIE_by_ID("HUD_blind")
	if not root then
		return
	end
	if root.config then
		root.config.colour = visible and G.C.BLACK or G.C.CLEAR
		root.config.emboss = visible and 0.05 or 0
	end
	if not root.children then
		return
	end
	for _, child in ipairs(root.children) do
		if child.states then
			child.states.visible = not not visible
		end
	end
end

local function clear_standings_overlay(player_list_runtime)
	if player_list_runtime.ui then
		pcall(function()
			player_list_runtime.ui:remove()
		end)
		player_list_runtime.ui = nil
	end
	if player_list_runtime.ui_boxes then
		for _, box in ipairs(player_list_runtime.ui_boxes) do
			if box and box.remove then
				pcall(function()
					box:remove()
				end)
			end
		end
		player_list_runtime.ui_boxes = nil
	end
	player_list_runtime.ui_major = nil
end

local hud_blind_badge_ref = G.FUNCS and G.FUNCS.HUD_blind_badge
G.FUNCS = G.FUNCS or {}
G.FUNCS.HUD_blind_badge = function(e)
	if MP.UI.using_standings_blind_hud and MP.UI.using_standings_blind_hud() then
		return
	end
	if hud_blind_badge_ref then
		return hud_blind_badge_ref(e)
	end
end

local function open_standings_overlay(contents, reset_existing)
	if reset_existing and (G and G.OVERLAY_MENU or nil) then
		BALATRO.exit_overlay_menu()
	end
	if reset_existing then
		BALATRO.set_paused(true)
	end

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			contents = contents,
		}),
		config = reset_existing and { offset = { x = 0, y = 0 } } or nil,
	})
end

function MP.UI.create_unified_player_list()
	local mode = get_player_list_mode()
	local hud = BALATRO.get_hud_blind and BALATRO.get_hud_blind()
	if not hud or not mode or not (MP.is_pvp_boss and MP.is_pvp_boss()) then
		return
	end

	refresh_score_targets(mode)
	set_vanilla_blind_rows_visible(false)

	local player_list_runtime = MP.UI.get_player_list_runtime()
	local signature = build_player_list_signature(mode)
	if player_list_runtime.ui
		and player_list_runtime.ui_mode == mode
		and player_list_runtime.ui_signature == signature
	then
		return
	end

	clear_standings_overlay(player_list_runtime)
	local standings_nodes = mode == "teams" and MP.UI.create_teams_standings_nodes(false)
		or MP.UI.create_ffa_standings_nodes(false)
	if not (standings_nodes and #standings_nodes > 0) then
		set_vanilla_blind_rows_visible(true)
		return
	end

	player_list_runtime.ui = UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { id = "MP_PLAYER_LIST_CONTAINER", align = "cm", colour = G.C.CLEAR },
			nodes = standings_nodes,
		},
		config = {
			align = "cm",
			bond = "Weak",
			offset = { x = 0, y = 0 },
			major = hud,
			colour = G.C.CLEAR,
		},
	})
	if player_list_runtime.ui and player_list_runtime.ui.UIRoot then
		seat_standings_labels(player_list_runtime.ui.UIRoot)
	end
	player_list_runtime.ui_signature = signature
	player_list_runtime.ui_mode = mode
end

function MP.UI.refresh_player_list()
	if ((G and (G.STATE == G.STATES.GAME_OVER or G.STATE == G.STATES.GAME_WIN) or false)) or (MP.GAME and MP.GAME.won) then
		return
	end

	if MP.is_pvp_boss and MP.is_pvp_boss() then
		MP.UI.create_unified_player_list()
	else
		MP.UI.remove_player_list(true)
	end
end

function MP.UI.remove_player_list(force)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	clear_standings_overlay(player_list_runtime)
	player_list_runtime.ui_signature = nil
	player_list_runtime.ui_mode = nil
	player_list_runtime.hud_is_standings = nil
	if BALATRO.get_hud_blind and BALATRO.get_hud_blind() then
		set_vanilla_blind_rows_visible(true)
	end
end

local function change_full_standings_page(delta)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	local page = math.max(1, math.floor(tonumber(player_list_runtime and player_list_runtime.full_standings_page) or 1))
	local page_count = math.max(1, math.floor(tonumber(player_list_runtime and player_list_runtime.full_standings_page_count) or 1))
	if page_count > 1 then
		page = ((page - 1 + delta) % page_count) + 1
	end
	if player_list_runtime then
		player_list_runtime.full_standings_page = page
	end

	if MP.is_teams_mode() then
		open_standings_overlay(MP.UI.create_teams_standings_nodes(true), true)
		return
	end

	open_standings_overlay(MP.UI.create_ffa_standings_nodes(true), true)
end

G.FUNCS.mp_full_standings_prev_page = function()
	return change_full_standings_page(-1)
end

G.FUNCS.mp_full_standings_next_page = function()
	return change_full_standings_page(1)
end

BALATRO.set_ui_function("mp_open_full_standings", function()
	local player_list_runtime = MP.UI.get_player_list_runtime()
	if player_list_runtime then
		player_list_runtime.full_standings_page = 1
	end
	if MP.is_teams_mode() then
		open_standings_overlay(MP.UI.create_teams_standings_nodes(true), false)
		return
	end

	open_standings_overlay(MP.UI.create_ffa_standings_nodes(true), false)
end)

