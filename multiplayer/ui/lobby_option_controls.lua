MP.UI = MP.UI or {}
MP.UI.LOBBY_OPTION_CYCLE_SPECS = MP.UI.LOBBY_OPTION_CYCLE_SPECS or {}
MP.UI.LOBBY_OPTION_CYCLE_UI_STATES = MP.UI.LOBBY_OPTION_CYCLE_UI_STATES or {}

local view_model = MP.UI

local function create_option_page(nodes, minh, minw)
	return {
		n = G.UIT.ROOT,
		config = {
			emboss = 0.05,
			minh = minh or 4,
			r = 0.1,
			minw = minw or 10,
			align = "tm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = nodes or {},
	}
end

local function get_compact_option_page_minh(visible_count, minh, args)
	if not (args and args.compact_empty_space) then
		return minh
	end

	visible_count = visible_count or 0
	if visible_count <= 0 then
		return args.compact_empty_minh or 1
	end

	local base_minh = minh or 4
	local row_minh = args.compact_row_minh or 0.86
	local padding_minh = args.compact_padding_minh or 0.75
	local min_minh = args.compact_min_minh or 1.6
	local compact_minh = math.max(min_minh, padding_minh + row_minh * visible_count)

	return math.min(base_minh, compact_minh)
end

local function get_cycle_spec_id(spec)
	return spec.spec_id or spec.id or spec.option_key
end

local function get_cycle_option_values(spec)
	if view_model.get_lobby_option_spec_values then
		return view_model.get_lobby_option_spec_values(spec)
	end

	return spec.option_values or spec.options or {}
end

local function get_cycle_display_options(spec)
	if view_model.get_lobby_option_spec_display_options then
		return view_model.get_lobby_option_spec_display_options(spec)
	end

	return spec.display_options or spec.options or spec.option_values or {}
end

local function get_cycle_current_index(spec)
	local option_values = get_cycle_option_values(spec)
	local current_value = spec.current_value and spec.current_value(spec)
		or (spec.option_key and MP.LOBBY.config[spec.option_key] or nil)
	local current_index = view_model.get_lobby_option_value_index(option_values, current_value)

	return current_index or spec.default_index or spec.current_option or 1
end

local function create_cycle_pip_node(index, scale, selected)
	return {
		n = G.UIT.B,
		config = {
			w = 0.1 * scale,
			h = 0.1 * scale,
			r = 0.05,
			id = "pip_" .. index,
			colour = selected and G.C.WHITE or G.C.BLACK,
		},
	}
end

local function get_cycle_pips_parent(overlay, cycle_row)
	if not cycle_row then
		return nil
	end

	local first_pip = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID("pip_1", cycle_row) or nil
	return first_pip and first_pip.parent or nil
end

local function sync_cycle_pips(overlay, cycle_row, cycle_config)
	local pips_parent = get_cycle_pips_parent(overlay, cycle_row)
	local option_count = #(cycle_config.options or {})
	if not pips_parent then
		return option_count < 2
	end

	local scale = cycle_config.scale or 1
	local changed = false
	pips_parent.config.padding = (0.05 - (option_count > 15 and 0.03 or 0)) * scale

	if #pips_parent.children ~= option_count then
		for i = #pips_parent.children, 1, -1 do
			pips_parent.children[i]:remove()
			table.remove(pips_parent.children, i)
		end
		for i = 1, option_count do
			pips_parent.UIBox:set_parent_child(
				create_cycle_pip_node(i, scale, cycle_config.current_option == i),
				pips_parent
			)
		end
		changed = true
	end

	for i, pip in ipairs(pips_parent.children) do
		pip.config.id = "pip_" .. i
		pip.config.w = 0.1 * scale
		pip.config.h = 0.1 * scale
		pip.config.r = 0.05
		pip.config.colour = cycle_config.current_option == i and G.C.WHITE or G.C.BLACK
	end

	if changed and pips_parent.UIBox then
		pips_parent.UIBox:recalculate()
	end

	return true
end

view_model.sync_lobby_option_cycle_pips = sync_cycle_pips

function view_model.sync_bound_lobby_option_cycle(control_id)
	local overlay = G and G.OVERLAY_MENU or nil
	local cycle_config = view_model.LOBBY_OPTION_CYCLE_UI_STATES
		and view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id]
	local spec_id = cycle_config
		and cycle_config.opt_args
		and cycle_config.opt_args.spec_id
	local spec = spec_id and view_model.LOBBY_OPTION_CYCLE_SPECS[spec_id] or nil
	local cycle_row = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(control_id) or nil
	if not (cycle_config and spec and cycle_row) then
		return false
	end

	local display_options = get_cycle_display_options(spec)
	local option_values = get_cycle_option_values(spec)
	local current_index = get_cycle_current_index(spec)
	local current_display_value = display_options[current_index]

	cycle_config.options = display_options
	cycle_config.mp_option_values = option_values
	cycle_config.current_option = current_index
	if cycle_config.current_option_val ~= current_display_value then
		cycle_config.current_option_val = current_display_value
	end
	return sync_cycle_pips(overlay, cycle_row, cycle_config)
end

function view_model.create_group_mode_host_notice()
	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02 },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize("k_opts_only_host"),
					scale = 0.26,
					colour = G.C.UI.TEXT_INACTIVE,
					shadow = true,
				},
			},
		},
	}
end

function view_model.create_lobby_option_cycle(id, label_key, scale, options, current_option, callback, opt_args, ui_args)
	local Disableable_Option_Cycle = MP.UI.Disableable_Option_Cycle
	ui_args = ui_args or {}
	local cycle_args = {
		id = id,
		enabled_ref_table = MP.LOBBY,
		enabled_ref_value = "is_host",
		label = localize(label_key),
		scale = scale,
		options = options,
		current_option = current_option,
		opt_callback = callback,
		opt_args = opt_args,
		w = ui_args.w,
		colour = ui_args.colour,
		no_pips = ui_args.no_pips,
		cycle_shoulders = ui_args.cycle_shoulders,
	}
	local cycle = Disableable_Option_Cycle(cycle_args)
	if id then
		view_model.LOBBY_OPTION_CYCLE_UI_STATES[id] = cycle_args._mp_effective_cycle_args or cycle_args
	end
	return cycle
end

function view_model.create_lobby_option_toggle(id, label_key, ref_value, callback, label_text, ui_args)
	local Disableable_Toggle = MP.UI.Disableable_Toggle
	ui_args = ui_args or {}
	local toggle_state = {
		[ref_value] = MP.LOBBY.config[ref_value],
	}

	return {
		n = G.UIT.R,
		config = {
			padding = 0,
			align = "cr",
		},
		nodes = {
			Disableable_Toggle({
				id = id,
				enabled_ref_table = MP.LOBBY,
				enabled_ref_value = "is_host",
				label = label_text or localize(label_key),
				ref_table = toggle_state,
				ref_value = ref_value,
				w = ui_args.w,
				h = ui_args.h,
				scale = ui_args.scale,
				label_scale = ui_args.label_scale,
				active_colour = ui_args.active_colour,
				inactive_colour = ui_args.inactive_colour,
				callback = function()
					if callback then
						callback(toggle_state, ref_value)
					else
						view_model.send_lobby_option_update(ref_value, toggle_state[ref_value])
					end
				end,
			}),
		},
	}
end

function view_model.create_bound_lobby_option_cycle(spec)
	local spec_id = get_cycle_spec_id(spec)
	view_model.LOBBY_OPTION_CYCLE_SPECS[spec_id] = spec
	local control_id = spec.control_id or spec.id or (spec.option_key .. "_option")

	local cycle = view_model.create_lobby_option_cycle(
		control_id,
		spec.label_key,
		spec.scale or 0.85,
		get_cycle_display_options(spec),
		get_cycle_current_index(spec),
		"change_bound_lobby_option_cycle",
		{ spec_id = spec_id },
		spec.ui_args
	)
	if view_model.LOBBY_OPTION_CYCLE_UI_STATES and view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id] then
		view_model.LOBBY_OPTION_CYCLE_UI_STATES[control_id].mp_option_values = get_cycle_option_values(spec)
	end

	return cycle
end

function view_model.create_bound_lobby_option_toggle(spec)
	return view_model.create_lobby_option_toggle(
		spec.control_id or spec.id or (spec.option_key .. "_toggle"),
		spec.label_key,
		spec.option_key,
		spec.on_toggle
			and function(toggle_state, option_key)
				spec.on_toggle(toggle_state[option_key], toggle_state, spec)
			end
			or nil,
		spec.label_text,
		spec.ui_args
	)
end

function view_model.build_lobby_option_controls(specs)
	local nodes = {}

	for _, spec in ipairs(specs or {}) do
		if not spec.when or spec.when(spec) then
			local node = nil
			if spec.kind == "toggle" then
				node = view_model.create_bound_lobby_option_toggle(spec)
			elseif spec.kind == "cycle" then
				node = view_model.create_bound_lobby_option_cycle(spec)
			elseif spec.kind == "custom" and spec.build then
				node = spec.build(spec)
			end

			if node then
				nodes[#nodes + 1] = node
			end
		end
	end

	return nodes
end

local function create_centered_option_controls(nodes)
	return {
		{
			n = G.UIT.R,
			config = { padding = 0, align = "cm" },
			nodes = nodes or {},
		},
	}
end

function view_model.create_lobby_option_page(nodes, minh)
	return create_option_page(nodes or {}, minh or 4, 10)
end

function view_model.create_lobby_option_specs_page(specs, minh, args)
	args = args or {}
	local nodes = view_model.build_lobby_option_controls(specs)
	local visible_count = #nodes
	minh = get_compact_option_page_minh(visible_count, minh, args)
	if args.center_controls then
		nodes = create_centered_option_controls(nodes)
	end

	return view_model.create_lobby_option_page(nodes, minh)
end
