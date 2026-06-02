MP.UI = MP.UI or {}
MP.UI.PLAYERS_HUD_SHARED = MP.UI.PLAYERS_HUD_SHARED or {}

local shared = MP.UI.PLAYERS_HUD_SHARED
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local DEFAULT_SCORE_TEXT_MAXW = 2.28
local SCORE_TEXT_BOX_PADDING = 0.18
local PVP_SCORE_EASE_DELAY = 1
local RANK_RAINBOW_SPEED = 1.65

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
	if prefer_score_int and score_int then
		return format_score_int(score_int, score_text)
	end

	local native_score = tonumber(clean_score_text(score_text))
	if is_finite_number(native_score) and number_format then
		local ok, formatted_score = pcall(number_format, native_score)
		if ok and formatted_score ~= nil then
			return tostring(formatted_score)
		end
	end

	local ok, formatted_score = pcall(MP.INSANE_INT.to_string, score_int or parse_score_int(score_text))
	if ok and formatted_score ~= nil then
		return tostring(formatted_score)
	end
	return tostring(score_text or "0")
end

local function each_text_char(text, callback)
	if utf8 and utf8.chars then
		for _, char in utf8.chars(text) do
			callback(char)
		end
		return
	end

	for index = 1, #text do
		callback(text:sub(index, index))
	end
end

local function estimate_score_text_width(score_text, scale)
	local text = tostring(score_text or "")
	local font = G and G.LANG and G.LANG.font or nil
	if font and font.FONT and G and G.TILESIZE and G.TILESCALE and font.FONTSCALE then
		local width = 0
		each_text_char(text, function(char)
			local char_width = font.FONT:getWidth(char) * (0.33 * scale) * G.TILESCALE * font.FONTSCALE
				+ 2.7 * G.TILESCALE * font.FONTSCALE
			width = width + char_width / (G.TILESIZE * G.TILESCALE)
		end)
		return width
	end

	return #text * scale * 0.58
end

local function score_scale(score_text, large_scale, small_scale, max_text_width)
	local preferred_scale = large_scale or 0.26
	local minimum_scale = small_scale or math.min(preferred_scale, 0.3)
	local available_width = max_text_width or DEFAULT_SCORE_TEXT_MAXW
	local preferred_width = estimate_score_text_width(score_text, preferred_scale)

	if preferred_width <= available_width then
		return preferred_scale
	end

	return math.max(minimum_scale, preferred_scale * available_width / preferred_width)
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
	if not (score_number and target_score and BALATRO.queue_event) then
		return false
	end
	local delay = options and options.delay or shared.PVP_SCORE_EASE_DELAY or PVP_SCORE_EASE_DELAY

	local function queue_score_field(ref_value, ease_to)
		BALATRO.queue_event({
			blockable = false,
			blocking = false,
			trigger = "ease",
			delay = delay,
			ref_table = score_number,
			ref_value = ref_value,
			ease_to = tonumber(ease_to) or 0,
			func = function(t)
				return math.floor(t)
			end,
		})
	end

	queue_score_field("e_count", target_score.e_count)
	queue_score_field("coefficient", target_score.coefficient)
	queue_score_field("exponent", target_score.exponent)
	return true
end

local function copy_insane_int(value)
	if not value then
		return MP.INSANE_INT.empty()
	end
	return MP.INSANE_INT.create(value.coefficient, value.exponent, value.e_count)
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
		end
	end

	state.display = state.display or {}
	return update_score_display_table(state.display, target_text, state.score_int, true)
end

BALATRO.set_ui_function("mp_players_hud_score_text_update", function(e)
	local score_display = e and e.config and e.config.ref_table or nil
	if not score_display then
		return
	end

	score_display.text = format_score_text(score_display.raw_text, score_display.score_int, score_display.prefer_score_int)
	e.config.scale = score_scale(
		score_display.text,
		score_display.large_scale or e.config.scale,
		score_display.small_scale,
		score_display.max_text_width
	)
end)

local function get_rank_rainbow_colour(phase_offset)
	local phase = ((BALATRO.get_wall_time and BALATRO.get_wall_time()) or 0) * RANK_RAINBOW_SPEED + (phase_offset or 0)
	local red = 0.58 + 0.42 * math.sin(phase)
	local green = 0.58 + 0.42 * math.sin(phase + 2.09439510239)
	local blue = 0.58 + 0.42 * math.sin(phase + 4.18879020479)
	return {
		math.min(1, math.max(0, red)),
		math.min(1, math.max(0, green)),
		math.min(1, math.max(0, blue)),
		1,
	}
end

G.FUNCS.mp_players_hud_rank_label_colour = function(e)
	if not (e and e.config and e.config.ref_table) then
		return
	end

	local rank_data = e.config.ref_table
	if rank_data.rank == 1 then
		e.config.colour = get_rank_rainbow_colour(rank_data.phase_offset)
	else
		e.config.colour = rank_data.base_colour or e.config.colour
	end
end

local function create_text_label(text, scale, colour, shadow)
	return {
		n = G.UIT.T,
		config = {
			text = text,
			scale = scale,
			colour = colour or G.C.WHITE,
			shadow = shadow ~= false,
		},
	}
end

local function create_score_text_label(score_display, fallback_text, scale, colour, shadow, max_text_width)
	if not score_display then
		return create_text_label(fallback_text, scale, colour, shadow)
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
			colour = rank_number == 1 and get_rank_rainbow_colour(rank_data.phase_offset) or base_colour,
			shadow = true,
			ref_table = rank_data,
			func = "mp_players_hud_rank_label_colour",
		},
	}
end

local function create_stake_score_box(score_text, minw, text_scale, text_colour, minh, stake_scale, score_display)
	local icon_scale = stake_scale or 0.36
	local icon_size = icon_scale > 0 and math.max(0.34, icon_scale * 0.96) or 0.34
	local stake = BALATRO.get_stake and BALATRO.get_stake() or 1
	local stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite(stake, icon_scale) or nil
	local box_width = minw or 1.54
	local score_text_maxw = math.max(0.6, box_width - SCORE_TEXT_BOX_PADDING)
	local nodes = {}
	if stake_sprite then
		nodes[#nodes + 1] = { n = G.UIT.O, config = { object = stake_sprite, w = icon_size, h = icon_size, can_collide = false } }
		nodes[#nodes + 1] = { n = G.UIT.C, config = { minw = 0.05 }, nodes = {} }
		score_text_maxw = math.max(0.6, score_text_maxw - icon_size - 0.05)
	end
	nodes[#nodes + 1] =
		create_score_text_label(score_display, score_text or "0", text_scale or 0.18, text_colour or G.C.WHITE, nil, score_text_maxw)

	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.01,
			minw = box_width,
			minh = minh or 0.3,
			r = 0.08,
			colour = G.C.BLACK,
			shadow = false,
			emboss = 0.03,
		},
		nodes = nodes,
	}
end

shared.create_text_label = create_text_label
shared.create_score_text_label = create_score_text_label
shared.create_rank_label = create_rank_label
shared.create_stake_score_box = create_stake_score_box
shared.clean_score_text = clean_score_text
shared.try_parse_score_int = try_parse_score_int
shared.parse_score_int = parse_score_int
shared.format_score_int = format_score_int
shared.update_score_display_table = update_score_display_table
shared.get_score_display = get_score_display
shared.get_score_text_scale = score_scale
shared.PVP_SCORE_EASE_DELAY = PVP_SCORE_EASE_DELAY
shared.ease_standings_score_number = ease_standings_score_number
shared.get_eased_score_display = get_eased_score_display
