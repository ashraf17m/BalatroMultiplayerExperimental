local ROW_LAYOUT = MP.UI.ROW_LAYOUT
local ROW_VIEW_MODEL = MP.UI.PLAYER_ROW_VIEW_MODEL or {}

local MATCH_LOBBY_INFO_PLAYERS_BODY_ID = "mp_match_lobby_info_players_body"
local MATCH_LOBBY_INFO_TAB_CONTENTS_ID = "tab_contents"
local MATCH_LOBBY_INFO_PLAYERS_SINGLE_PAGE_SIZE = 16
local MATCH_LOBBY_INFO_PLAYERS_PAGED_PAGE_SIZE = 15
local MATCH_LOBBY_INFO_PLAYERS_PAGED_ROW_PADDING = 0.025
local MATCH_LOBBY_INFO_SCORE_LANE_WIDTH = 2.87

local function get_team_money_ui()
	return MP.UI and MP.UI.TEAM_MONEY or nil
end

local function get_match_lobby_info_runtime()
	return MP.UI and MP.UI.get_match_lobby_info_runtime and MP.UI.get_match_lobby_info_runtime() or nil
end

local function get_match_lobby_sorted_players(lobby_context)
	return MP.get_lobby_view_players and select(1, MP.get_lobby_view_players({
		lobby_context = lobby_context,
		match_only = true,
		sort_by_team = true,
	})) or {}
end

local function get_players_page_size(player_count)
	local count = tonumber(player_count) or 0
	if count > MATCH_LOBBY_INFO_PLAYERS_SINGLE_PAGE_SIZE then
		return MATCH_LOBBY_INFO_PLAYERS_PAGED_PAGE_SIZE
	end
	return MATCH_LOBBY_INFO_PLAYERS_SINGLE_PAGE_SIZE
end

local function get_players_page_count(player_count)
	local page_size = get_players_page_size(player_count)
	return math.max(1, math.ceil((tonumber(player_count) or 0) / page_size)), page_size
end

local function get_players_page()
	local runtime = get_match_lobby_info_runtime()
	return math.max(1, math.floor(tonumber(runtime and runtime.players_page) or 1))
end

local function set_players_page(page)
	local runtime = get_match_lobby_info_runtime()
	if runtime then
		runtime.players_page = math.max(1, math.floor(tonumber(page) or 1))
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

local function build_players_layout(lobby_context)
	local sorted_players = get_match_lobby_sorted_players(lobby_context)
	local player_count = #sorted_players
	local page_count, page_size = get_players_page_count(player_count)
	local page = clamp_players_page(page_count)
	local first_index = ((page - 1) * page_size) + 1
	local last_index = player_count > 0 and math.min(player_count, first_index + page_size - 1) or 0
	local row_count = last_index >= first_index and (last_index - first_index + 1) or 0

	return {
		sorted_players = sorted_players,
		player_count = player_count,
		page_count = page_count,
		page_size = page_size,
		page = page,
		first_index = first_index,
		last_index = last_index,
		row_count = row_count,
		compact_rows = page_count > 1,
	}
end

local function change_match_lobby_info_players_page(delta)
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local sorted_players = get_match_lobby_sorted_players(lobby_context)
	local page_count = get_players_page_count(#sorted_players)
	set_players_page(wrap_players_page(get_players_page() + delta, page_count))

	if MP.UI and MP.UI.request_match_lobby_info_refresh then
		return MP.UI.request_match_lobby_info_refresh()
	end
	return false
end

G.FUNCS.mp_match_lobby_info_players_prev_page = function()
	return change_match_lobby_info_players_page(-1)
end

G.FUNCS.mp_match_lobby_info_players_next_page = function()
	return change_match_lobby_info_players_page(1)
end

function MP.UI.reset_match_lobby_info_players_page()
	set_players_page(1)
end

G.FUNCS.kick_player_match = function(e)
	if e and e.config and e.config.id then
		local player_id = string.match(e.config.id, "(.+)_kick_match")
		if player_id then
			MP.UI.request_match_lobby_info_refresh()
			MP.ACTIONS.kick_player(player_id)
		end
	end
end

local function create_match_lobby_player_row(lobby_player, row_index, lobby_context, compact)
	local model = ROW_VIEW_MODEL.build_match_lobby_player_row_model(lobby_player, row_index, {
		lobby_context = lobby_context,
	})
	local row_nodes = {}

	if model.show_lives_lane then
		ROW_LAYOUT.append_node(row_nodes, ROW_LAYOUT.create_surface_lane_from_spec(model.lives_lane_spec))
		ROW_LAYOUT.append_node(row_nodes, { n = G.UIT.B, config = { w = 0.08, h = 0.01 } })
	end

	ROW_LAYOUT.append_node(row_nodes, ROW_LAYOUT.create_name_lane(model))

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_skip_chip(model.skip_chip_spec),
		1.75
	)

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_host_chip(model.is_owner),
		1.05
	)

	ROW_LAYOUT.append_row_slot(
		row_nodes,
		ROW_LAYOUT.create_action_button_from_spec(model.kick_match_action),
		0.65,
		0.42
	)

	if lobby_context.can_show_shared_money_actions then
		ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.money_action_spec, 1.95, 0.42)
	end

	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.location_lane_spec, 4.05)

	ROW_LAYOUT.append_surface_lane_slot(row_nodes, model.score_lane_spec, MATCH_LOBBY_INFO_SCORE_LANE_WIDTH)

	local row = ROW_LAYOUT.create_player_row_shell(model, row_nodes, {
		tooltip_player_id = lobby_player.id,
		force_focus = false,
	})
	if compact and row and row.config then
		row.config.padding = MATCH_LOBBY_INFO_PLAYERS_PAGED_ROW_PADDING
	end
	return row
end

local function create_match_lobby_player_rows(lobby_context)
	local rows = {}
	local layout = build_players_layout(lobby_context)

	for idx = layout.first_index, layout.last_index do
		rows[#rows + 1] = create_match_lobby_player_row(layout.sorted_players[idx], idx, lobby_context, layout.compact_rows)
	end

	return rows, layout.page, layout.page_count
end

local function create_match_lobby_players_pager(page, page_count)
	if page_count <= 1 then
		return nil
	end

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			ROW_LAYOUT.create_button_from_spec({
				label = "<",
				button = "mp_match_lobby_info_players_prev_page",
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
			ROW_LAYOUT.create_button_from_spec({
				label = ">",
				button = "mp_match_lobby_info_players_next_page",
				minw = 0.52,
				minh = 0.34,
				scale = 0.38,
				colour = G.C.GREEN,
			}),
		},
	}
end

local function create_match_lobby_players_body_definition()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local player_rows, page, page_count = create_match_lobby_player_rows(lobby_context)
	local pager = create_match_lobby_players_pager(page, page_count)
	local body_minw = lobby_context.can_show_shared_money_actions and 18.95 or 16.95
	if pager then
		player_rows[#player_rows + 1] = pager
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = page_count > 1 and 0.04 or 0.1, r = 0.1, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "tm", minw = body_minw, padding = 0.02 },
				nodes = player_rows,
			},
		},
	}
end

local function create_match_lobby_players_body_object(parent)
	return UIBox({
		definition = create_match_lobby_players_body_definition(),
		config = parent and { align = "cm", parent = parent } or { align = "cm" },
	})
end

local function restore_active_money_popup(active_player_id)
	local team_money_ui = get_team_money_ui()
	if not (active_player_id and team_money_ui and team_money_ui.open_popup) then
		return false
	end

	local overlay = G and G.OVERLAY_MENU
	local anchor_id = tostring(active_player_id) .. "_view_team_money_transfer"
	local anchor = overlay and overlay.get_UIE_by_ID and overlay:get_UIE_by_ID(anchor_id) or nil
	if not anchor then
		if team_money_ui.close_popup then
			team_money_ui.close_popup()
		end
		return false
	end

	return team_money_ui.open_popup(active_player_id, anchor)
end

local function create_match_lobby_players_tab_definition(options)
	local opts = options or {}
	if opts.reset_page ~= false then
		MP.UI.reset_match_lobby_info_players_page()
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.1, r = 0.1, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.O,
				config = {
					id = MATCH_LOBBY_INFO_PLAYERS_BODY_ID,
					object = create_match_lobby_players_body_object(),
				},
			},
		},
	}
end

function MP.UI.refresh_match_lobby_info_players()
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.get_UIE_by_ID) then
		return false
	end

	local tab_contents = G.OVERLAY_MENU:get_UIE_by_ID(MATCH_LOBBY_INFO_TAB_CONTENTS_ID)
	if not (tab_contents and tab_contents.config) then
		return false
	end

	local team_money_ui = get_team_money_ui()
	local money_state = team_money_ui and team_money_ui.get_ui_state and team_money_ui.get_ui_state() or nil
	local active_money_player_id = money_state and money_state.active_player_id or nil
	local should_restore_money_popup = active_money_player_id
		and team_money_ui
		and team_money_ui.is_popup_open
		and team_money_ui.is_popup_open(active_money_player_id)
	if should_restore_money_popup and team_money_ui.close_popup then
		team_money_ui.close_popup({ clear_active = false })
	end

	local refreshed = MP.UI.UTILS.replace_config_object(tab_contents, UIBox({
		definition = create_match_lobby_players_tab_definition({ reset_page = false }),
		config = { offset = { x = 0, y = 0 }, parent = tab_contents, type = "cm" },
	}), {
		recalculate_uie = true,
		recalculate_target = tab_contents.UIBox or G.OVERLAY_MENU,
	})
	if refreshed and should_restore_money_popup then
		restore_active_money_popup(active_money_player_id)
	end
	return refreshed
end

function MP.UI.create_UIBox_players()
	if MP.UI and MP.UI.set_match_lobby_info_active_tab then
		MP.UI.set_match_lobby_info_active_tab("players")
	end
	return create_match_lobby_players_tab_definition({ reset_page = true })
end
