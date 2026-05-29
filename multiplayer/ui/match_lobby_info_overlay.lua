local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_match_lobby_info_runtime()
	return MP.UI and MP.UI.get_match_lobby_info_runtime and MP.UI.get_match_lobby_info_runtime() or nil
end

local function mark_match_lobby_info_active(active)
	local runtime = get_match_lobby_info_runtime()
	if runtime then
		runtime.active = not not active
	end
end

local create_lobby_info_ui

function MP.request_match_lobby_info_refresh()
	local runtime = get_match_lobby_info_runtime()
	if runtime then
		runtime.pending_refresh = true
	end
	if MP.UI and MP.UI.request_pending_match_lobby_info_refresh then
		return MP.UI.request_pending_match_lobby_info_refresh()
	end
	if MP.refresh_pending_match_lobby_info then
		return MP.refresh_pending_match_lobby_info()
	end
	return true
end

function MP.refresh_pending_match_lobby_info()
	local runtime = get_match_lobby_info_runtime()
	local pending_refresh = runtime and runtime.pending_refresh or false
	if not pending_refresh then
		return false
	end
	if not BALATRO.get_overlay_property("is_mp_match_lobby_info") then
		return false
	end

	runtime.pending_refresh = false
	if MP.UI and MP.UI.refresh_match_lobby_info_players then
		return MP.UI.refresh_match_lobby_info_players()
	end
	return false
end

BALATRO.set_ui_function("lobby_info", function()
	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = create_lobby_info_ui(),
	})
	mark_match_lobby_info_active(true)
	BALATRO.set_overlay_property("is_mp_match_lobby_info", true)
end)

create_lobby_info_ui = function()
	return create_UIBox_generic_options({
		contents = {
			create_tabs({
				tabs = {
					{
						label = localize("b_players"),
						chosen = true,
						tab_definition_function = MP.UI.create_UIBox_players,
					},
					{
						label = localize("b_lobby_info"),
						chosen = false,
						tab_definition_function = MP.UI.create_UIBox_settings,
					},
				},
				tab_h = 8,
				snap_to_nav = true,
			}),
		},
	})
end
