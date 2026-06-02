MP.UI = MP.UI or {}
local team_money_ui = MP.UI.TEAM_MONEY or {}
MP.UI.TEAM_MONEY = team_money_ui
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function close_money_popup_and_reset()
	team_money_ui.close_popup({
		reset_row = true,
	})
end

local function close_active_money_popup()
	team_money_ui.close_popup({
		clear_active = true,
	})
end

local function get_team_money_event_player_id(e, action_suffix)
	if not e or not e.config or not e.config.id then
		return nil
	end

	return string.match(e.config.id, "(.+)_" .. action_suffix)
end

function team_money_ui.handle_money_update(money, delta, source_player_id)
	local ui_state = team_money_ui.get_ui_state()
	local delta_value = tonumber(delta) or 0
	local active_player_id = ui_state.active_player_id

	if ui_state.pending_target_id and delta_value < 0 and source_player_id == ui_state.pending_target_id then
		team_money_ui.clear_pending_target_row()
		close_active_money_popup()
		return true
	end

	if active_player_id and team_money_ui.is_popup_open(active_player_id) then
		team_money_ui.refresh_slider_widget(active_player_id)
		return true
	end

	return false
end

if not MP.TEAM_MONEY_TRANSFER_WHEEL_HOOK_LOADED then
	MP.TEAM_MONEY_TRANSFER_WHEEL_HOOK_LOADED = true

	BALATRO.register_wheelmoved_handler("mp_team_money_transfer", function(x, y)
		local wheel_delta = tonumber(y) or 0
		if wheel_delta == 0 then
			wheel_delta = tonumber(x) or 0
		end

		if wheel_delta ~= 0 and team_money_ui.nudge_active_slider(wheel_delta) then
			return true
		end
		return false
	end)
end

BALATRO.set_ui_function("view_team_money_transfer", function(e)
	local player_id = get_team_money_event_player_id(e, "view_team_money_transfer")
	if not player_id then
		return
	end

	local ui_state = team_money_ui.get_ui_state()
	local anchor_node = e.parent or e

	if ui_state.pending_target_id then
		return
	end

	if team_money_ui.is_popup_open(player_id) then
		local is_same_anchor = ui_state.popup_anchor and ui_state.popup_anchor == anchor_node
		close_money_popup_and_reset()
		if is_same_anchor then
			return
		end
	end

	team_money_ui.close_popup({
		reset_row = true,
		clear_active = false,
	})

	ui_state.active_player_id = player_id
	team_money_ui.reset_row(player_id)
	team_money_ui.open_popup(player_id, anchor_node)
end)

BALATRO.set_ui_function("team_money_slider_change", function(slider_config)
	if not slider_config or not slider_config.player_id then
		return
	end

	local row_state = team_money_ui.sync_row_state(
		slider_config.player_id,
		slider_config.ref_table and slider_config.ref_table[slider_config.ref_value]
	)

	slider_config.ref_table[slider_config.ref_value] = row_state.value
	slider_config.text = row_state.text

	team_money_ui.refresh_slider_widget(slider_config.player_id)
end)

BALATRO.set_ui_function("team_money_confirm_button", function(e)
	if not e or not e.config or not e.config.ref_table or not e.config.ref_table.player_id then
		return
	end

	local player_id = e.config.ref_table.player_id
	team_money_ui.refresh_row_state(player_id)
	local can_confirm = team_money_ui.can_confirm(player_id)

	e.config.button = can_confirm and "send_team_money" or nil
	e.config.colour = can_confirm and G.C.MONEY or G.C.UI.BACKGROUND_INACTIVE
	e.config.hover = can_confirm
	e.config.shadow = can_confirm
	e.config.one_press = true
	if can_confirm then
		e.disable_button = nil
	end

	local label = e.children and e.children[1]
	local text = label and label.children and label.children[1]
	if text and text.config then
		text.config.text = team_money_ui.get_send_money_label()
		text.config.colour = can_confirm and G.C.UI.TEXT_LIGHT or G.C.UI.TEXT_INACTIVE
		text.config.shadow = can_confirm
	end
end)

BALATRO.set_ui_function("send_team_money", function(e)
	local player_id = get_team_money_event_player_id(e, "send_team_money")
	if not player_id then
		return
	end

	local ui_state = team_money_ui.get_ui_state()
	local row_state = team_money_ui.refresh_row_state(player_id)
	if ui_state.pending_target_id or not team_money_ui.can_confirm(player_id) then
		return
	end

	local amount = row_state.value
	team_money_ui.set_pending(player_id, true)
	close_active_money_popup()

	local ok, err = pcall(function()
		return MP.ACTIONS.send_team_money(player_id, amount)
	end)
	if not ok or err ~= true then
		team_money_ui.set_pending(player_id, false)
		team_money_ui.reset_row(player_id)
		if not ok then
			sendWarnMessage("Failed to send team money: " .. tostring(err), "MULTIPLAYER")
		else
			sendWarnMessage("Failed to send team money transfer.", "MULTIPLAYER")
		end
	end
end)
