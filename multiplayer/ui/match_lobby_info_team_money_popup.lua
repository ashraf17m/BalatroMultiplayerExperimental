MP.UI = MP.UI or {}
local team_money_ui = MP.UI.TEAM_MONEY or {}
MP.UI.TEAM_MONEY = team_money_ui

local TEAM_MONEY_SLIDER_WIDTH = 3.1
local TEAM_MONEY_SLIDER_HEIGHT = 0.34
local TEAM_MONEY_CONFIRM_WIDTH = 1.2
local TEAM_MONEY_CONFIRM_HEIGHT = 0.42
local TEAM_MONEY_CONFIRM_TEXT_SCALE = 0.3
local TEAM_MONEY_POPUP_OFFSET_Y = -0.14

function team_money_ui.get_popup_box(player_id)
	local ui_state = team_money_ui.get_ui_state()
	local anchor = ui_state.popup_anchor
	local popup = anchor and anchor.children and anchor.children.mp_team_money_popup or nil

	if not popup then
		ui_state.popup_anchor = nil
		if player_id == nil or ui_state.active_player_id == player_id then
			return nil, nil
		end
		return nil, nil
	end

	if player_id ~= nil and ui_state.active_player_id ~= player_id then
		return nil, nil
	end

	return popup, anchor
end

function team_money_ui.is_popup_open(player_id)
	return team_money_ui.get_popup_box(player_id) ~= nil
end

function team_money_ui.close_popup(options)
	options = options or {}

	local ui_state = team_money_ui.get_ui_state()
	local active_player_id = ui_state.active_player_id
	local popup, anchor = team_money_ui.get_popup_box()

	if popup then
		popup:remove()
	end
	if anchor and anchor.children then
		anchor.children.mp_team_money_popup = nil
	end

	ui_state.popup_anchor = nil

	if options.reset_row and active_player_id then
		team_money_ui.reset_row(active_player_id)
	end
	if options.clear_active ~= false then
		ui_state.active_player_id = nil
	end

	return popup ~= nil
end

function team_money_ui.refresh_slider_widget(player_id)
	local popup = team_money_ui.get_popup_box(player_id)
	if not popup then
		return
	end

	local slider = popup:get_UIE_by_ID(team_money_ui.get_slider_id(player_id))
	if not slider or not slider.children or not slider.children[1] or not slider.children[1].children then
		return
	end

	local fill_bar = slider.children[1].children[1]
	if not fill_bar or not fill_bar.config then
		return
	end

	local slider_args = fill_bar.config.ref_table
	if not slider_args then
		return
	end

	local row_state = team_money_ui.refresh_row_state(player_id)
	slider_args.max = math.max(1, row_state.slider_max)
	slider_args.ref_table[slider_args.ref_value] = row_state.value
	slider_args.text = row_state.text

	local ratio = 0
	if slider_args.max > slider_args.min then
		ratio = (row_state.value - slider_args.min) / (slider_args.max - slider_args.min)
	end

	fill_bar.config.w = slider_args.w * ratio
	fill_bar.T.w = fill_bar.config.w
end

local function get_active_slider_context()
	local ui_state = team_money_ui.get_ui_state()
	local active_player_id = ui_state.active_player_id
	if not active_player_id then
		return nil
	end

	local popup = team_money_ui.get_popup_box(active_player_id)
	if not popup then
		return nil
	end

	local slider = popup:get_UIE_by_ID(team_money_ui.get_slider_id(active_player_id))
	local track = slider and slider.children and slider.children[1] or nil
	local fill_bar = track and track.children and track.children[1] or nil
	local slider_args = fill_bar and fill_bar.config and fill_bar.config.ref_table or nil

	if not slider or not track or not fill_bar or not slider_args then
		return nil
	end

	return {
		player_id = active_player_id,
		slider = slider,
		track = track,
		fill_bar = fill_bar,
		args = slider_args,
	}
end

function team_money_ui.nudge_active_slider(delta)
	local numeric_delta = tonumber(delta) or 0
	if numeric_delta == 0 then
		return false
	end

	local context = get_active_slider_context()
	if not context then
		return false
	end

	local row_state = team_money_ui.refresh_row_state(context.player_id)
	local slider_min = tonumber(context.args.min) or 0
	local selectable_max = row_state.slider_max
	if selectable_max <= slider_min then
		team_money_ui.refresh_slider_widget(context.player_id)
		return false
	end

	context.args.max = math.max(slider_min + 1, selectable_max)
	context.args.ref_table[context.args.ref_value] = row_state.value
	context.args.text = row_state.text

	G.FUNCS.slider_descreet(context.track, numeric_delta / (selectable_max - slider_min))
	if context.args.callback and G.FUNCS[context.args.callback] then
		G.FUNCS[context.args.callback](context.args)
	end

	return true
end

local function create_popup_definition(player_id)
	local row_state = team_money_ui.refresh_row_state(player_id)
	local slider = create_slider({
		w = TEAM_MONEY_SLIDER_WIDTH,
		h = TEAM_MONEY_SLIDER_HEIGHT,
		text_scale = 0.3,
		ref_table = row_state,
		ref_value = "value",
		min = 0,
		max = math.max(1, row_state.slider_max),
		decimal_places = 0,
		colour = G.C.MONEY,
		callback = "team_money_slider_change",
		player_id = player_id,
	})
	slider.config.id = team_money_ui.get_slider_id(player_id)

	local confirm_button = UIBox_button({
		id = team_money_ui.get_confirm_button_id(player_id),
		button = "send_team_money",
		label = { team_money_ui.get_send_money_label() },
		minw = TEAM_MONEY_CONFIRM_WIDTH,
		maxw = TEAM_MONEY_CONFIRM_WIDTH - 0.1,
		minh = TEAM_MONEY_CONFIRM_HEIGHT,
		scale = TEAM_MONEY_CONFIRM_TEXT_SCALE,
		colour = G.C.MONEY,
		text_colour = G.C.UI.TEXT_LIGHT,
		shadow = true,
		col = true,
		padding = 0.03,
		one_press = true,
		func = "team_money_confirm_button",
		ref_table = { player_id = player_id },
	})

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "cm",
					padding = 0.05,
					colour = G.C.BLACK,
					r = 0.12,
					emboss = 0.05,
				},
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.02 },
						nodes = {
							slider,
							{ n = G.UIT.B, config = { w = 0.06, h = 0.01 } },
							confirm_button,
						},
					},
				},
			},
		},
	}
end

function team_money_ui.open_popup(player_id, anchor_node)
	local target_player = MP.get_lobby_player_by_id and MP.get_lobby_player_by_id(player_id) or nil
	if not target_player or not anchor_node then
		return false
	end

	team_money_ui.close_popup({
		clear_active = false,
	})

	anchor_node.children = anchor_node.children or {}
	anchor_node.children.mp_team_money_popup = UIBox({
		definition = create_popup_definition(player_id),
		config = {
			align = "tm",
			offset = { x = 0, y = TEAM_MONEY_POPUP_OFFSET_Y },
			major = anchor_node,
			bond = "Weak",
			instance_type = "POPUP",
		},
	})

	local ui_state = team_money_ui.get_ui_state()
	ui_state.active_player_id = player_id
	ui_state.popup_anchor = anchor_node
	team_money_ui.refresh_slider_widget(player_id)
	return true
end
