MP.UI = MP.UI or {}

local view_model = MP.UI
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local pending_custom_winners_slider_count = nil
local pending_custom_winners_slider_percent = nil

local function get_cycle_next_value(spec, args)
	local option_values = view_model.get_lobby_option_spec_values and view_model.get_lobby_option_spec_values(spec)
		or spec.option_values
		or spec.options
		or {}
	local option_index = tonumber(args and args.to_key)
	local next_value = option_index and option_values[option_index] or option_values[args and args.to_key]
	if next_value == nil then
		next_value = args and args.to_val
	end

	if spec.normalize then
		next_value = spec.normalize(next_value, args, spec)
	end

	return next_value
end

local function send_group_options_update(options)
	if MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress() then
		return false
	end

	view_model.send_lobby_options(options)
	return true
end

function view_model.send_lobby_options(options)
	MP.ACTIONS.lobby_options(options)
end

function view_model.send_party_options_update(options)
	return send_group_options_update(options)
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

function view_model.reset_custom_winners_input_state()
	view_model.CUSTOM_WINNERS_SLIDER_LAST_SENT = nil
	view_model.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = nil
	pending_custom_winners_slider_count = nil
	pending_custom_winners_slider_percent = nil
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

local function flush_custom_winners_slider_change()
	if not pending_custom_winners_slider_count then
		return false
	end

	if BALATRO.is_controller_mouse_dragging and BALATRO.is_controller_mouse_dragging() then
		return false
	end

	local winner_count = pending_custom_winners_slider_count
	local winner_percent = pending_custom_winners_slider_percent
	pending_custom_winners_slider_count = nil
	pending_custom_winners_slider_percent = nil

	if
		MP.UI.CUSTOM_WINNERS_SLIDER_LAST_SENT == winner_count
		and MP.UI.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT == winner_percent
	then
		return false
	end
	MP.UI.CUSTOM_WINNERS_SLIDER_LAST_SENT = winner_count
	MP.UI.CUSTOM_WINNERS_SLIDER_PERCENT_LAST_SENT = winner_percent

	return send_group_options_update({
		pvp_custom_winners = winner_count,
		pvp_custom_winners_percent = winner_percent,
	})
end

function G.FUNCS.change_custom_winners_percent(slider_config)
	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return
	end

	local slider_state = slider_config and slider_config.ref_table or nil
	local percent_key = slider_config and slider_config.ref_value or nil
	local raw_percent = slider_state and percent_key and slider_state[percent_key] or nil
	local winner_count = view_model.get_custom_winner_count_from_percent(raw_percent)
	local normalized_percent = view_model.normalize_custom_winner_percent
			and view_model.normalize_custom_winner_percent(raw_percent)
		or view_model.get_custom_winner_percent(winner_count)

	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.pvp_custom_winners = winner_count
		MP.LOBBY.config.pvp_custom_winners_percent = normalized_percent
	end
	if slider_state and percent_key then
		slider_state[percent_key] = normalized_percent
	end
	if slider_config then
		slider_config.text = tostring(normalized_percent) .. "%"
	end
	if view_model.update_custom_winners_percent_slider then
		view_model.update_custom_winners_percent_slider(winner_count)
	end
	if view_model.update_custom_winners_count_cycle then
		view_model.update_custom_winners_count_cycle(winner_count)
	end

	pending_custom_winners_slider_count = winner_count
	pending_custom_winners_slider_percent = normalized_percent
	return flush_custom_winners_slider_change()
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after(
		"mp.ui.custom_winners_slider_flush",
		flush_custom_winners_slider_change,
		110
	)
end
