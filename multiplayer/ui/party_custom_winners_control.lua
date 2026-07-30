MP.UI = MP.UI or {}

local view_model = MP.UI

local function get_slider_percent_range()
	local min_percent = view_model.get_custom_winner_min_percent
			and view_model.get_custom_winner_min_percent()
		or 1
	local max_percent = view_model.get_custom_winner_percent_limit
			and view_model.get_custom_winner_percent_limit()
		or 100

	if max_percent <= min_percent then
		min_percent = math.max(1, max_percent - 1)
	end

	return min_percent, max_percent
end

local function get_slider_args(slider)
	local track = slider and slider.children and slider.children[1] or nil
	local fill_bar = track and track.children and track.children[1] or nil
	return fill_bar, fill_bar and fill_bar.config and fill_bar.config.ref_table or nil
end

local function set_initial_slider_text(slider, percent)
	local track = slider and slider.nodes and slider.nodes[1] or nil
	local fill_bar = track and track.nodes and track.nodes[1] or nil
	local slider_args = fill_bar and fill_bar.config and fill_bar.config.ref_table or nil
	if slider_args then
		slider_args.text = tostring(percent) .. "%"
	end
end

function view_model.update_custom_winners_percent_slider(winner_count)
	local overlay = G and G.OVERLAY_MENU or nil
	local slider = overlay and overlay.get_UIE_by_ID
		and overlay:get_UIE_by_ID("party_custom_winners_percent_slider")
		or nil
	local fill_bar, slider_args = get_slider_args(slider)
	if not (fill_bar and slider_args and slider_args.ref_table and slider_args.ref_value) then
		return false
	end

	slider_args.min, slider_args.max = get_slider_percent_range()

	local percent = view_model.get_custom_winner_slider_percent
			and view_model.get_custom_winner_slider_percent(winner_count)
		or view_model.get_custom_winner_percent(winner_count)
	percent = math.max(slider_args.min, math.min(slider_args.max, percent))
	slider_args.ref_table[slider_args.ref_value] = percent
	slider_args.text = tostring(percent) .. "%"

	local ratio = 1
	if slider_args.max > slider_args.min then
		ratio = (percent - slider_args.min) / (slider_args.max - slider_args.min)
	end

	fill_bar.config.w = slider_args.w * ratio
	if fill_bar.T then
		fill_bar.T.w = fill_bar.config.w
	end
	return true
end

function view_model.update_custom_winners_count_cycle(winner_count)
	local overlay = G and G.OVERLAY_MENU or nil
	local cycle_config = view_model.LOBBY_OPTION_CYCLE_UI_STATES
		and view_model.LOBBY_OPTION_CYCLE_UI_STATES.party_custom_winners_cycle
	if not (overlay and overlay.get_UIE_by_ID and cycle_config and cycle_config.options) then
		return false
	end

	if view_model.get_custom_winner_count_options then
		cycle_config.options = view_model.get_custom_winner_count_options()
		cycle_config.mp_option_values = cycle_config.options
	end

	local normalized_count = view_model.normalize_custom_winner_count(winner_count)
	local option_values = cycle_config.mp_option_values or cycle_config.options
	local next_index = view_model.get_lobby_option_value_index(option_values, normalized_count)
	if not next_index then
		return false
	end

	local cycle_row = overlay:get_UIE_by_ID("party_custom_winners_cycle")
	if not cycle_row then
		return false
	end

	cycle_config.current_option = next_index
	if cycle_config.current_option_val ~= cycle_config.options[next_index] then
		cycle_config.current_option_val = cycle_config.options[next_index]
	end

	if view_model.sync_lobby_option_cycle_pips then
		return view_model.sync_lobby_option_cycle_pips(overlay, cycle_row, cycle_config)
	end
	return true
end

function view_model.create_custom_winners_percent_slider(id)
	local min_percent, max_percent = get_slider_percent_range()
	local current_winner_count = view_model.get_custom_winner_count()
	local percent = view_model.get_custom_winner_slider_percent
			and view_model.get_custom_winner_slider_percent(current_winner_count)
		or view_model.get_custom_winner_percent(current_winner_count)
	percent = math.max(min_percent, math.min(max_percent, percent))
	local slider_state = {
		percent = percent,
	}
	local slider = create_slider({
		w = 4.165,
		h = 0.34,
		text_scale = 0.3,
		ref_table = slider_state,
		ref_value = "percent",
		min = min_percent,
		max = max_percent,
		decimal_places = 0,
		colour = G.C.RED,
		callback = "change_custom_winners_percent",
	})
	slider.config.id = id
	set_initial_slider_text(slider, percent)

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.03 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					{ n = G.UIT.B, config = { w = 0.8, h = 0.01 } },
					slider,
				},
			},
		},
	}
end
