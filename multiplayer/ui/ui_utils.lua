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
	open_overlay_message_rows(build_overlay_message_rows(message), no_back)
end
