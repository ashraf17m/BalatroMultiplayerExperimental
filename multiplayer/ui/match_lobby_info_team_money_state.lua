MP.UI = MP.UI or {}
local team_money_ui = MP.UI.TEAM_MONEY or {}
MP.UI.TEAM_MONEY = team_money_ui

local TEAM_MONEY_DEFAULT_AMOUNT = 0
local TEAM_MONEY_MIN_SLIDER_MAX = TEAM_MONEY_DEFAULT_AMOUNT

local function get_transfer_slider_max()
	local local_money = MP.get_local_money and MP.get_local_money() or 0
	return math.max(TEAM_MONEY_MIN_SLIDER_MAX, math.floor(tonumber(local_money) or 0))
end

function team_money_ui.get_ui_state()
	MP.TEAM_MONEY_TRANSFER_UI = MP.TEAM_MONEY_TRANSFER_UI or {
		active_player_id = nil,
		pending_target_id = nil,
		popup_anchor = nil,
		players = {},
	}

	return MP.TEAM_MONEY_TRANSFER_UI
end

function team_money_ui.get_row_state(player_id)
	local ui_state = team_money_ui.get_ui_state()
	local row_state = ui_state.players[player_id]
	if row_state then
		return row_state
	end

	row_state = {
		value = TEAM_MONEY_DEFAULT_AMOUNT,
		text = tostring(TEAM_MONEY_DEFAULT_AMOUNT),
		slider_max = 0,
		pending = false,
	}
	ui_state.players[player_id] = row_state
	return row_state
end

function team_money_ui.get_slider_id(player_id)
	return "team_money_slider_" .. tostring(player_id)
end

function team_money_ui.get_confirm_button_id(player_id)
	return tostring(player_id) .. "_send_team_money"
end

function team_money_ui.get_send_money_label()
	return type(localize) == "function" and localize("b_send_money") or "Send"
end

function team_money_ui.set_pending(player_id, pending)
	local ui_state = team_money_ui.get_ui_state()
	local row_state = team_money_ui.get_row_state(player_id)
	row_state.pending = pending == true

	if row_state.pending then
		ui_state.pending_target_id = player_id
	elseif ui_state.pending_target_id == player_id then
		ui_state.pending_target_id = nil
	end

	return row_state
end

function team_money_ui.normalize_amount(amount, max_amount)
	local normalized_max = math.max(0, math.floor(tonumber(max_amount) or 0))
	local normalized_amount = math.floor(tonumber(amount) or 0)

	if normalized_amount < 0 then
		normalized_amount = 0
	end
	if normalized_amount > normalized_max then
		normalized_amount = normalized_max
	end

	return normalized_amount, normalized_max
end

function team_money_ui.sync_row_state(player_id, amount)
	local row_state = team_money_ui.get_row_state(player_id)
	local normalized_amount, normalized_max = team_money_ui.normalize_amount(amount, get_transfer_slider_max())

	row_state.value = normalized_amount
	row_state.slider_max = normalized_max
	row_state.text = tostring(normalized_amount)

	return row_state
end

function team_money_ui.refresh_row_state(player_id)
	return team_money_ui.sync_row_state(player_id, team_money_ui.get_row_state(player_id).value)
end

function team_money_ui.can_send_amount(amount, max_amount)
	local numeric_amount = tonumber(amount)
	local normalized_max = math.max(0, math.floor(tonumber(max_amount) or 0))
	return numeric_amount ~= nil
		and numeric_amount >= 1
		and numeric_amount <= normalized_max
		and math.floor(numeric_amount) == numeric_amount
end

function team_money_ui.can_confirm(player_id)
	local ui_state = team_money_ui.get_ui_state()
	local row_state = team_money_ui.get_row_state(player_id)

	return (ui_state.pending_target_id == nil or ui_state.pending_target_id == player_id)
		and (not row_state.pending)
		and team_money_ui.can_send_amount(row_state.value, row_state.slider_max)
end

function team_money_ui.reset_row(player_id)
	local row_state = team_money_ui.get_row_state(player_id)
	row_state.pending = false
	return team_money_ui.sync_row_state(player_id, TEAM_MONEY_DEFAULT_AMOUNT)
end

function team_money_ui.clear_pending_target_row()
	local ui_state = team_money_ui.get_ui_state()
	local pending_target_id = ui_state.pending_target_id
	if not pending_target_id then
		return nil
	end

	team_money_ui.set_pending(pending_target_id, false)
	team_money_ui.reset_row(pending_target_id)
	return pending_target_id
end
