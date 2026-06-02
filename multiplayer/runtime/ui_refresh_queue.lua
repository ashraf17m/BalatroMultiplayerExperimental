local ui_refresh = {}

function ui_refresh.get_refresh_runtime()
	ui_refresh.RUNTIME = ui_refresh.RUNTIME or {}
	return ui_refresh.RUNTIME
end

function ui_refresh.request_refresh(key)
	if type(key) ~= "string" or key == "" then
		return false
	end

	local refresh_runtime = ui_refresh.get_refresh_runtime()
	refresh_runtime[key] = true
	return true
end

local REQUEST_REFRESH_KEYS = {
	request_connection_status_refresh = "connection_status",
	request_overlay_menu_close = "overlay_menu_close",
	request_lobby_main_menu_refresh = "lobby_main_menu",
	request_pending_lobby_overlay_refresh = "pending_lobby_overlay",
	request_group_options_overlay_refresh = "group_options_overlay",
	request_lobby_option_failure = "lobby_option_failure",
	request_pending_match_lobby_info_refresh = "pending_match_lobby_info",
	request_shared_score_refresh = "shared_score",
	request_player_list_refresh = "player_list",
}

for function_name, key in pairs(REQUEST_REFRESH_KEYS) do
	ui_refresh[function_name] = function()
		return ui_refresh.request_refresh(key)
	end
end

local FLUSH_REFRESH_CALLBACKS = {
	connection_status = function()
		return MP.UI and MP.UI.update_connection_status
	end,
	overlay_menu_close = function()
		return MP.UI and MP.UI.close_active_overlay_menu
	end,
	lobby_main_menu = function()
		return MP.UI and MP.UI.refresh_lobby_main_menu
	end,
	pending_lobby_overlay = function()
		return MP.UI and MP.UI.refresh_pending_lobby_overlay
	end,
	group_options_overlay = function()
		return MP.UI and MP.UI.refresh_group_options_overlay
	end,
	lobby_option_failure = function()
		return MP.UI and MP.UI.process_pending_lobby_option_failure
	end,
	pending_match_lobby_info = function()
		return MP.UI and MP.UI.refresh_pending_match_lobby_info
	end,
	shared_score = function()
		return MP.UI and MP.UI.refresh_shared_score_ui
	end,
	player_list = function()
		return MP.UI and MP.UI.refresh_player_list
	end,
}

function ui_refresh.flush_requested_refreshes()
	local refresh_runtime = ui_refresh.get_refresh_runtime()
	if not next(refresh_runtime) then
		return false
	end

	local requested = {}
	for key, value in pairs(refresh_runtime) do
		requested[key] = value
		refresh_runtime[key] = nil
	end

	local function requeue_if_missing(key, callback)
		if type(callback) == "function" then
			callback()
			return true
		end

		refresh_runtime[key] = true
		return false
	end

	local flushed_any = false

	for key in pairs(requested) do
		local callback_resolver = FLUSH_REFRESH_CALLBACKS[key]
		if callback_resolver then
			flushed_any = requeue_if_missing(key, callback_resolver()) or flushed_any
		end
	end

	return flushed_any
end

return ui_refresh
