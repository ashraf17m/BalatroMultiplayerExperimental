MP.UI = MP.UI or {}
MP.UI.LOBBY_OPTION_CYCLE_SPECS = MP.UI.LOBBY_OPTION_CYCLE_SPECS or {}

local view_model = MP.UI

local function copy_nodes(nodes)
	local copied_nodes = {}
	for _, node in ipairs(nodes or {}) do
		copied_nodes[#copied_nodes + 1] = node
	end

	return copied_nodes
end

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

local function get_cycle_spec_id(spec)
	return spec.spec_id or spec.id or spec.option_key
end

local function get_cycle_option_values(spec)
	return spec.option_values or spec.options or {}
end

local function get_cycle_display_options(spec)
	return spec.display_options or spec.options or spec.option_values or {}
end

local function get_cycle_current_index(spec)
	local option_values = get_cycle_option_values(spec)
	local current_value = spec.current_value and spec.current_value(spec)
		or (spec.option_key and MP.LOBBY.config[spec.option_key] or nil)
	local current_index = MP.UTILS.get_array_index_by_value(option_values, current_value)

	return current_index or spec.default_index or spec.current_option or 1
end

local function create_group_lobby_option_cycle(id, label_key, options, current_option, callback)
	return view_model.create_lobby_option_cycle(
		id,
		label_key,
		0.85,
		options,
		current_option,
		callback,
		nil,
		{
			w = 4.9,
			colour = G.C.ORANGE,
			no_pips = true,
			cycle_shoulders = true,
		}
	)
end

function view_model.create_group_scoring_cycle(id)
	return create_group_lobby_option_cycle(
		id,
		"b_beat_average_mode",
		view_model.get_group_scoring_options(),
		MP.LOBBY.config.ffa_scoring_beat_average and 2 or 1,
		"change_group_scoring_mode"
	)
end

function view_model.create_group_max_players_cycle(id, current_option)
	return create_group_lobby_option_cycle(
		id,
		"b_max_players",
		view_model.get_group_max_player_options(),
		current_option,
		"change_group_max_players"
	)
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

function view_model.create_group_mode_contents(args)
	return copy_nodes(args.nodes)
end

function view_model.create_group_mode_page(args)
	return create_option_page(
		view_model.create_group_mode_contents(args),
		args.minh or 4,
		args.minw or 10
	)
end

function view_model.create_lobby_option_cycle(id, label_key, scale, options, current_option, callback, opt_args, ui_args)
	local Disableable_Option_Cycle = MP.UI.Disableable_Option_Cycle
	ui_args = ui_args or {}
	return Disableable_Option_Cycle({
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
	})
end

function view_model.create_lobby_option_toggle(id, label_key, ref_value, callback)
	local Disableable_Toggle = MP.UI.Disableable_Toggle
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
				label = localize(label_key),
				ref_table = toggle_state,
				ref_value = ref_value,
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

	return view_model.create_lobby_option_cycle(
		spec.control_id or spec.id or (spec.option_key .. "_option"),
		spec.label_key,
		spec.scale or 0.85,
		get_cycle_display_options(spec),
		get_cycle_current_index(spec),
		"change_bound_lobby_option_cycle",
		{ spec_id = spec_id }
	)
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
			or nil
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

function view_model.create_lobby_option_page(nodes, minh)
	return create_option_page(nodes or {}, minh or 4, 10)
end
