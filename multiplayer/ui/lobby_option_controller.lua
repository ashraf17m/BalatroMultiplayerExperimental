MP.UI = MP.UI or {}

local view_model = MP.UI

local function should_block_group_option_change()
	return MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress()
end

local function get_cycle_next_value(spec, args)
	local option_values = spec.option_values or spec.options or {}
	local next_value = option_values[args.to_key]
	if next_value == nil then
		next_value = args.to_val
	end

	if spec.normalize then
		next_value = spec.normalize(next_value, args, spec)
	end

	return next_value
end

local function send_group_option_update(option_key, option_value)
	if should_block_group_option_change() then
		return false
	end

	view_model.send_lobby_option_update(option_key, option_value)
	return true
end

function view_model.send_lobby_options(options)
	MP.ACTIONS.lobby_options(options)
end

function view_model.send_lobby_option_update(option_key, option_value)
	local value = option_value
	if value == nil then
		value = MP.LOBBY.config[option_key]
	end

	view_model.send_lobby_options({
		[option_key] = value,
	})
end

function G.FUNCS.change_bound_lobby_option_cycle(args)
	local opt_args = args and args.cycle_config and args.cycle_config.opt_args or nil
	local spec = opt_args and view_model.LOBBY_OPTION_CYCLE_SPECS[opt_args.spec_id] or nil
	if not spec then
		return
	end

	local next_value = get_cycle_next_value(spec, args)

	if spec.on_change then
		spec.on_change(next_value, args, spec)
	else
		view_model.send_lobby_option_update(spec.option_key, next_value)
	end
end

function G.FUNCS.change_group_scoring_mode(args)
	return send_group_option_update(
		"ffa_scoring_beat_average",
		args.to_val == localize("k_beat_average")
	)
end

function G.FUNCS.change_group_max_players(args)
	return send_group_option_update("max_players", view_model.normalize_group_max_players(args.to_val))
end
