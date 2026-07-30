MP.UI.UTILS = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- Creates a text node
function MP.UI.UTILS.create_text_node(text, config)
	config = config or {}
	config.text = text
	return { n = G.UIT.T, config = config }
end

-- Creates a row container
function MP.UI.UTILS.create_row(config, nodes)
	config = config or {}
	return { n = G.UIT.R, config = config, nodes = nodes or {} }
end

local function create_column(config, nodes)
	config = config or {}
	return { n = G.UIT.C, config = config, nodes = nodes or {} }
end

function MP.UI.create_spacer(size, row)
	size = size or 0.2

	return row and {
		n = G.UIT.R,
		config = {
			align = "cm",
			minh = size,
		},
		nodes = {},
	} or {
		n = G.UIT.C,
		config = {
			align = "cm",
			minw = size,
		},
		nodes = {},
	}
end

function MP.UI.UTILS.resolve_enabled_flag(args)
	local enabled_table = args.enabled_ref_table or {}
	return enabled_table[args.enabled_ref_value]
end

-- Creates an object node
function MP.UI.UTILS.create_object_node(object, config)
	config = config or {}
	config.object = object
	return { n = G.UIT.O, config = config }
end

local TEAM_ROW_BLIND_ICON = {
	Small = { icon_kind = "small", blind_key = "bl_small", label_key = "k_mp_team_ready_row_Small", fallback = "Small Blind" },
	Big = { icon_kind = "big", blind_key = "bl_big", label_key = "k_mp_team_ready_row_Big", fallback = "Big Blind" },
	Boss = { icon_kind = "random", label_key = "k_mp_team_ready_row_Boss", fallback = "Boss Blind" },
}

local STATIC_BLIND_ICON = {
	small = { atlas = "blind_chips", pos = { x = 0, y = 0 } },
	big = { atlas = "blind_chips", pos = { x = 0, y = 1 } },
	random = { atlas = "blind_chips", pos = { x = 0, y = 30 } },
	pvp = { atlas = "mp_player_blind_col", pos = { x = 0, y = 22 } },
}

local function split_location(location_str)
	local location = tostring(location_str or "")
	local split_location, split_value = location:match("^([^-]+)%-(.*)$")
	if split_location then
		return split_location, split_value or ""
	end
	return location, ""
end

local function get_dictionary_value(key)
	return G
		and G.localization
		and G.localization.misc
		and G.localization.misc.dictionary
		and G.localization.misc.dictionary[key]
		or nil
end

local function get_localized_blind_name(blind_key, fallback)
	if not blind_key or blind_key == "" then
		return fallback
	end

	local loc_name = localize and localize({ type = "name_text", key = blind_key, set = "Blind" }) or "ERROR"
	if loc_name ~= "ERROR" then
		return loc_name
	end

	local blind_def = BALATRO.get_blind_def and BALATRO.get_blind_def(blind_key) or nil
	return (blind_def and blind_def.name) or fallback or blind_key
end

local function text_mentions_pvp(value)
	local text = tostring(value or ""):lower()
	return text ~= "" and text:find("pvp", 1, true) ~= nil
end

local function is_pvp_blind_identity(blind_value, options)
	local value = tostring(blind_value or ""):lower()
	if value == "bl_mp_nemesis" or value == "pvp" or value == "bl_pvp" or value == "pvp blind" then
		return true
	end

	local opts = options or {}
	if opts.location_type == "loc_ready" then
		return true
	end

	return opts.location_type == "loc_playing"
		and (text_mentions_pvp(opts.fallback_text) or text_mentions_pvp(opts.full_text))
end

local function get_team_row_label(row_key)
	local icon_spec = TEAM_ROW_BLIND_ICON[row_key]
	if not icon_spec then
		return tostring(row_key or "")
	end
	return get_dictionary_value(icon_spec.label_key) or icon_spec.fallback
end

local function get_icon_location_prefix(location_type, icon_spec)
	if location_type == "loc_ready" and icon_spec and icon_spec.icon_kind == "pvp" then
		local ready_text = get_dictionary_value(location_type)
		local prefix = ready_text and ready_text:gsub("%s*[Pp][Vv][Pp]%s*$", "") or nil
		if prefix and prefix ~= "" and prefix ~= ready_text then
			return prefix .. " "
		end
		return "Ready for "
	end
	if location_type == "loc_selecting" and icon_spec then
		local selecting_text = get_dictionary_value(location_type) or "Selecting"
		local prefix = selecting_text:gsub("%s*[Aa]%s+[Bb]lind%s*$", "")
		return prefix ~= "" and prefix or selecting_text
	end
	if location_type == "loc_ready_for_team_row" then
		return get_dictionary_value(location_type) or "Ready for "
	end
	if location_type == "loc_ready_to_skip_for_team_row" then
		return get_dictionary_value(location_type) or "ready to skip "
	end
	return get_dictionary_value(location_type) or location_type or "Unknown"
end

local function get_pvp_display_blind_key(options)
	local opts = options or {}
	if opts.pvp_blind_key then
		return opts.pvp_blind_key
	end
	if opts.player and opts.player.blind_col and MP.UTILS and MP.UTILS.blind_col_numtokey then
		return MP.UTILS.blind_col_numtokey(opts.player.blind_col)
	end
	if MP.GAME and MP.UTILS and MP.UTILS.get_pvp_blind_key then
		return MP.UTILS.get_pvp_blind_key()
	end
	return nil
end

local function get_boss_display_blind_key()
	local boss_key = BALATRO.get_blind_choice and BALATRO.get_blind_choice("Boss") or nil
	if boss_key and boss_key ~= "bl_mp_nemesis" and BALATRO.get_blind_def and BALATRO.get_blind_def(boss_key) then
		return boss_key
	end
	return nil
end

local function resolve_blind_icon_spec(blind_value, options)
	if is_pvp_blind_identity(blind_value, options) then
		return {
			icon_kind = "pvp",
			pvp_blind_key = get_pvp_display_blind_key(options),
			icon_label = "PvP",
		}
	end

	if not blind_value or blind_value == "" then
		return nil
	end

	local team_icon = TEAM_ROW_BLIND_ICON[blind_value]
	if team_icon then
		local boss_blind_key = blind_value == "Boss" and get_boss_display_blind_key() or nil
		return {
			icon_kind = boss_blind_key and nil or team_icon.icon_kind,
			blind_key = boss_blind_key or team_icon.blind_key,
			icon_label = get_team_row_label(blind_value),
		}
	end

	if blind_value:match("^bl_") then
		local blind_def = BALATRO.get_blind_def and BALATRO.get_blind_def(blind_value) or nil
		if blind_def then
			return {
				blind_key = blind_value,
				icon_label = get_localized_blind_name(blind_value, blind_def.name),
			}
		end
	end

	return nil
end

function MP.UI.UTILS.resolve_location_display(location_str, fallback_text, options)
	local full_text = fallback_text
	if MP.UTILS and MP.UTILS.resolve_location_text then
		local _, resolved_text = MP.UTILS.resolve_location_text(location_str)
		full_text = resolved_text
	end
	full_text = full_text or "Unknown"

	local location_type, blind_value = split_location(location_str)
	local icon_options = {}
	for key, value in pairs(options or {}) do
		icon_options[key] = value
	end
	icon_options.location_type = location_type
	icon_options.fallback_text = fallback_text
	icon_options.full_text = full_text
	local icon_spec = resolve_blind_icon_spec(blind_value, icon_options)
	if not icon_spec then
		return {
			raw_location = location_str,
			location_type = location_type,
			blind_value = blind_value,
			text = full_text,
			full_text = full_text,
		}
	end

	local prefix_text = get_icon_location_prefix(location_type, icon_spec)
	return {
		raw_location = location_str,
		location_type = location_type,
		blind_value = blind_value,
		text = prefix_text,
		full_text = full_text,
		icon_kind = icon_spec.icon_kind,
		blind_key = icon_spec.blind_key,
		pvp_blind_key = icon_spec.pvp_blind_key,
		icon_label = icon_spec.icon_label,
	}
end

function MP.UI.UTILS.create_location_blind_icon_object(location_display, size)
	local display = location_display or {}
	local icon_size = size or 0.45
	local atlas_key
	local pos

	if display.icon_kind == "pvp" then
		local pvp_blind = display.pvp_blind_key and BALATRO.get_blind_def and BALATRO.get_blind_def(display.pvp_blind_key) or nil
		atlas_key = "player_blind_col"
		pos = pvp_blind and pvp_blind.pos or nil
	end

	if display.blind_key and display.blind_key ~= "bl_mp_nemesis" then
		local blind_def = BALATRO.get_blind_def and BALATRO.get_blind_def(display.blind_key) or nil
		if blind_def then
			atlas_key = blind_def.atlas or "blind_chips"
			pos = blind_def.pos
		end
	end

	if not (atlas_key and pos) then
		local static_icon = STATIC_BLIND_ICON[display.icon_kind or ""]
		if static_icon then
			atlas_key = static_icon.atlas
			pos = static_icon.pos
		end
	end

	local atlas = atlas_key and BALATRO.get_animation_atlas and BALATRO.get_animation_atlas(atlas_key) or nil
	if not atlas and atlas_key == "player_blind_col" and BALATRO.get_animation_atlas then
		atlas = BALATRO.get_animation_atlas("mp_player_blind_col")
	end
	if not atlas and atlas_key == "mp_player_blind_col" and BALATRO.get_animation_atlas then
		atlas = BALATRO.get_animation_atlas("player_blind_col")
	end
	if not (atlas and pos and BALATRO.create_animated_sprite) then
		return nil
	end

	local blind_sprite = BALATRO.create_animated_sprite(0, 0, icon_size, icon_size, atlas, pos)
	if blind_sprite and blind_sprite.define_draw_steps then
		blind_sprite:define_draw_steps({
			{ shader = "dissolve", shadow_height = 0.05 * icon_size },
			{ shader = "dissolve" },
		})
	end
	return blind_sprite
end

function MP.UI.UTILS.replace_config_object(uie, next_object, options)
	options = options or {}
	if not (uie and uie.config and next_object) then
		return false
	end

	local previous_object = uie.config.object
	uie.config.object = next_object
	next_object.parent = uie

	if previous_object and previous_object ~= next_object and previous_object.remove then
		previous_object:remove()
	end

	if options.recalculate_object ~= false and next_object.recalculate then
		next_object:recalculate()
	end
	if options.recalculate_uie and uie.recalculate then
		uie:recalculate()
	end

	local recalculate_target = options.recalculate_target
	if recalculate_target and recalculate_target.recalculate then
		recalculate_target:recalculate()
	elseif options.recalculate_ui_box ~= false and uie.UIBox and uie.UIBox.recalculate then
		uie.UIBox:recalculate()
	end

	return true
end

local function build_overlay_message_rows(message)
	local message_table = MP.UTILS.string_split(message, "\n")
	local message_rows = {
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.2 }, {
			MP.UI.UTILS.create_text_node("MULTIPLAYER", {
				scale = 0.8,
				colour = G.C.UI.TEXT_LIGHT,
			}),
		}),
	}

	for _, v in ipairs(message_table) do
		table.insert(
			message_rows,
			MP.UI.UTILS.create_row({ align = "cm", padding = 0.1 }, {
				MP.UI.UTILS.create_text_node(v, {
					scale = 0.6,
					colour = G.C.UI.TEXT_LIGHT,
				}),
			})
		)
	end

	return message_rows
end

local function open_overlay_message_rows(message_rows, no_back)
	BALATRO.set_paused(true)

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			no_back = no_back,
			no_esc = no_back,
			contents = {
				create_column({ align = "cm", padding = 0.2 }, message_rows),
			},
		}),
	})
end

--- Overlay with a DynaText countdown timer
--- @param message string Static message lines (newline-separated)
--- @param countdown_table table Table with a "display" key that gets updated externally
--- @param no_back boolean If true, disables back/esc buttons
function MP.UI.UTILS.overlay_message_countdown(message, countdown_table, no_back)
	local message_rows = build_overlay_message_rows(message)

	-- Countdown row using DynaText with ref_table for live updates
	table.insert(
		message_rows,
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.2 }, {
			MP.UI.UTILS.create_object_node(
				DynaText({
					string = {{ ref_table = countdown_table, ref_value = "display" }},
					colours = { G.C.UI.TEXT_LIGHT },
					shadow = true,
					silent = true,
					scale = 0.7,
					pop_in = 0,
				})
			),
		})
	)

	open_overlay_message_rows(message_rows, no_back)
end

-- Localizes a game location string (e.g. "loc_playing-bl_small" -> "Playing Small Blind")
function MP.UI.localize_location(location_str)
	local _, location_text = MP.UTILS.resolve_location_text(location_str)
	return location_text
end

-- Overlay message helper
function MP.UI.UTILS.overlay_message(message, no_back)
	local main_menu_play_ui = MP.UI and MP.UI.MAIN_MENU_PLAY or nil
	if
		main_menu_play_ui
		and main_menu_play_ui.is_browse_lobbies_overlay_open
		and main_menu_play_ui.is_browse_lobbies_overlay_open()
		and main_menu_play_ui.show_browse_lobbies_notice
		and main_menu_play_ui.show_browse_lobbies_notice(message)
	then
		return
	end

	open_overlay_message_rows(build_overlay_message_rows(message), no_back)
end
