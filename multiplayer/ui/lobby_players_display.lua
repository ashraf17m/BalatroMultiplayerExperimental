MP.UI = MP.UI or {}
local lobby_players_ui = MP.UI.LOBBY_PLAYERS or {}
MP.UI.LOBBY_PLAYERS = lobby_players_ui

function lobby_players_ui.get_overlay_runtime()
	return MP.UI and MP.UI.get_lobby_overlay_runtime and MP.UI.get_lobby_overlay_runtime() or nil
end

local function get_players_page_size()
	return lobby_players_ui.PLAYER_COLUMN_LIMIT * 2
end

local function get_players_page_count(player_count)
	local page_size = get_players_page_size()
	return math.max(1, math.ceil((tonumber(player_count) or 0) / page_size)), page_size
end

local function get_players_page()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	return math.max(1, math.floor(tonumber(overlay_runtime and overlay_runtime.players_page) or 1))
end

local function set_players_page(page)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.players_page = math.max(1, math.floor(tonumber(page) or 1))
	end
end

local function clamp_players_page(page_count)
	local page = math.min(get_players_page(), page_count)
	set_players_page(page)
	return page
end

local function wrap_players_page(page, page_count)
	if page_count <= 1 then
		return 1
	end
	return ((page - 1) % page_count) + 1
end

local function slice_players_page(players, page, page_size)
	local player_count = #players
	local first_index = ((page - 1) * page_size) + 1
	local last_index = player_count > 0 and math.min(player_count, first_index + page_size - 1) or 0
	local page_players = {}
	if last_index >= first_index then
		for idx = first_index, last_index do
			page_players[#page_players + 1] = players[idx]
		end
	end
	return page_players, first_index
end

local function get_lobby_overlay_list_width(lobby_context)
	local width = 8.8
	if lobby_context and lobby_context.uses_lobby_ready then
		width = width + 2.05
	end
	if lobby_context and lobby_context.is_teams_mode then
		width = width + 1.25
	end
	return width
end

local function get_lobby_overlay_table_width(players, lobby_context)
	local column_width = get_lobby_overlay_list_width(lobby_context)
	if lobby_players_ui.should_split_player_rows(players) then
		return column_width * 2 + (lobby_players_ui.PLAYER_COLUMN_GAP or 0)
	end
	return column_width
end

local function create_players_pager(page, page_count)
	if page_count <= 1 then
		return nil
	end

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = "<",
				button = "mp_lobby_players_prev_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.RED,
			}),
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 1.0, padding = 0.02, colour = G.C.CLEAR },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = tostring(page) .. "/" .. tostring(page_count),
							scale = 0.35,
							colour = G.C.UI.TEXT_LIGHT,
							shadow = true,
						},
					},
				},
			},
			{ n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
			MP.UI.ROW_LAYOUT.create_button_from_spec({
				label = ">",
				button = "mp_lobby_players_next_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.GREEN,
			}),
		},
	}
end

local function create_lobby_overlay_contents()
	local players, lobby_context = MP.get_lobby_view_players({
		lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or nil,
		sort_by_team = true,
	})
	local player_count = #players
	local page_count, page_size = get_players_page_count(player_count)
	local page = clamp_players_page(page_count)
	local page_players, page_first_index = slice_players_page(players, page, page_size)
	local column_width = get_lobby_overlay_list_width(lobby_context)
	local rows = lobby_players_ui.create_player_row_columns(page_players, lobby_context, column_width, page_first_index)
	local list_width = get_lobby_overlay_table_width(page_players, lobby_context)
	local pager = create_players_pager(page, page_count)

	local contents = {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.12 },
			nodes = {
				{ n = G.UIT.T, config = { text = localize("b_players"), scale = 0.62, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
			},
		},
		{
			n = G.UIT.R,
			config = { align = "tm", padding = 0.08 },
			nodes = {
				{
					n = G.UIT.C,
					config = { align = "tm", minw = list_width, padding = 0.02 },
					nodes = rows,
				},
			},
		},
	}

	if pager then
		contents[#contents + 1] = pager
	end

	return contents
end

function lobby_players_ui.mark_overlay(surface)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.active_surface = surface
		overlay_runtime.active_team_picker_player_id = surface == "team_picker" and overlay_runtime.active_team_picker_player_id or nil
		if surface ~= "team_picker" then
			overlay_runtime.suppress_next_team_picker_refresh = nil
		end
	end

	if not (G and G.OVERLAY_MENU) then
		return
	end

	G.OVERLAY_MENU.is_mp_players_list = surface == "players"
	G.OVERLAY_MENU.is_mp_team_picker = surface == "team_picker"
end

function lobby_players_ui.clear_pending_overlay_refresh()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.pending_surface = nil
	end
end

function lobby_players_ui.suppress_next_team_picker_overlay_refresh(player_id)
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime then
		overlay_runtime.suppress_next_team_picker_refresh = player_id or true
	end
end

function lobby_players_ui.open_overlay(surface)
	if surface == "team_picker" then
		local overlay_runtime = lobby_players_ui.get_overlay_runtime()
		local player_id = overlay_runtime and overlay_runtime.active_team_picker_player_id or nil
		if lobby_players_ui.open_team_picker_overlay then
			return lobby_players_ui.open_team_picker_overlay(player_id)
		end
		return false
	end

	G.FUNCS.overlay_menu({
		definition = G.UIDEF.create_UIBox_players_list(),
	})
	lobby_players_ui.mark_overlay("players")
end

function lobby_players_ui.get_active_surface()
	if not (G and G.OVERLAY_MENU) then
		return nil
	end

	if G.OVERLAY_MENU.is_mp_players_list then
		return "players"
	end
	if G.OVERLAY_MENU.is_mp_team_picker then
		return "team_picker"
	end

	return nil
end

function lobby_players_ui.request_lobby_overlay_refresh(surface)
	local target_surface = surface or lobby_players_ui.get_active_surface()
	if not target_surface then
		return false
	end

	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	if overlay_runtime and target_surface == "team_picker" then
		local suppressed_player_id = overlay_runtime.suppress_next_team_picker_refresh
		if suppressed_player_id == true or suppressed_player_id == overlay_runtime.active_team_picker_player_id then
			overlay_runtime.suppress_next_team_picker_refresh = nil
			return false
		end
	end

	if overlay_runtime then
		overlay_runtime.pending_surface = target_surface
	end
	if MP.UI and MP.UI.request_pending_lobby_overlay_refresh then
		MP.UI.request_pending_lobby_overlay_refresh()
	end
	return true
end

MP.UI.request_lobby_overlay_refresh = lobby_players_ui.request_lobby_overlay_refresh

function lobby_players_ui.refresh_pending_lobby_overlay()
	local overlay_runtime = lobby_players_ui.get_overlay_runtime()
	local target_surface = overlay_runtime and overlay_runtime.pending_surface or nil
	if not target_surface then
		return false
	end

	overlay_runtime.pending_surface = nil
	if G and G.OVERLAY_MENU then
		G.FUNCS.exit_overlay_menu()
	end
	lobby_players_ui.open_overlay(target_surface)
	return true
end

MP.UI.refresh_pending_lobby_overlay = lobby_players_ui.refresh_pending_lobby_overlay

function G.UIDEF.create_UIBox_players_list()
	return create_UIBox_generic_options({
		contents = create_lobby_overlay_contents(),
	})
end

local function change_players_page(delta)
	local players = MP.get_lobby_view_players and select(1, MP.get_lobby_view_players({
		lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or nil,
		sort_by_team = true,
	})) or {}
	local page_count = get_players_page_count(#players)
	set_players_page(wrap_players_page(get_players_page() + delta, page_count))
	return lobby_players_ui.request_lobby_overlay_refresh("players")
end

G.FUNCS.mp_lobby_players_prev_page = function()
	return change_players_page(-1)
end

G.FUNCS.mp_lobby_players_next_page = function()
	return change_players_page(1)
end

function G.FUNCS.view_players_list(e)
	lobby_players_ui.clear_pending_overlay_refresh()
	set_players_page(1)
	lobby_players_ui.open_overlay("players")
end
