local GROUP_LOBBY_TYPE_VALUES = {
	MP.LOBBY_TYPES.FFA,
	MP.LOBBY_TYPES.TEAMS,
}

local function get_group_lobby_type_options()
	return {
		"FFA",
		localize("k_team"),
	}
end

local function get_current_group_lobby_type_index()
	if MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.TEAMS then
		return 2
	end

	return 1
end

function G.FUNCS.change_group_lobby_type(args)
	if MP.is_lobby_match_in_progress() then
		return
	end

	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return
	end

	local next_lobby_type = GROUP_LOBBY_TYPE_VALUES[tonumber(args and args.to_key) or 0]
	if not next_lobby_type or next_lobby_type == MP.LOBBY.lobby_type then
		return
	end

	MP.ACTIONS.set_lobby_type(next_lobby_type)
end

local function create_group_advanced_tab()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local current_max_players = tonumber(MP.LOBBY.config.max_players) or MP.DEFAULT_GROUP_LOBBY_PLAYERS
	local current_max_players_index = MP.UI.get_group_max_players_index(current_max_players)

	local nodes = {}
	if not lobby_context.is_coop_gamemode then
		nodes[#nodes + 1] = MP.UI.create_lobby_option_cycle(
			"group_lobby_type_cycle",
			"k_lobby_type",
			0.85,
			get_group_lobby_type_options(),
			get_current_group_lobby_type_index(),
			"change_group_lobby_type",
			nil,
			{
				w = 4.9,
				no_pips = true,
				cycle_shoulders = true,
			}
		)
		nodes[#nodes + 1] = MP.UI.create_group_scoring_cycle("team_scoring_system_cycle")
	end
	nodes[#nodes + 1] = MP.UI.create_group_max_players_cycle("team_max_players_cycle", current_max_players_index)

	return MP.UI.create_group_mode_page({
		nodes = nodes,
	})
end

local function create_team_options_tab()
	return MP.UI.create_lobby_option_page(
		MP.UI.build_lobby_option_controls(MP.UI.LOBBY_OPTION_TAB_SPECS.team_options),
		3
	)
end

local function create_group_options_tab()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local tabs = {
		{
			label = localize("k_lobby_general"),
			chosen = true,
			tab_definition_function = create_group_advanced_tab,
		},
	}
	if lobby_context.can_show_team_options then
		tabs[#tabs + 1] = {
			label = localize("k_team_options"),
			chosen = false,
			tab_definition_function = create_team_options_tab,
		}
	end

	local contents = {}
	if not (MP.LOBBY and MP.LOBBY.is_host) then
		contents[#contents + 1] = MP.UI.create_group_mode_host_notice()
		contents[#contents + 1] = MP.UI.create_spacer(0.08, true)
	end

	contents[#contents + 1] = {
		n = G.UIT.R,
		config = {
			padding = 0,
			align = "cm",
		},
		nodes = {
			create_tabs({
				snap_to_nav = true,
				colour = G.C.BOOSTER,
				tabs = tabs,
			}),
		},
	}

	return create_UIBox_generic_options({
		contents = contents,
	})
end

function G.FUNCS.view_group_options(e)
	if MP.is_lobby_match_in_progress() then
		return
	end

	G.FUNCS.overlay_menu({
		definition = create_group_options_tab(),
	})
	if G.OVERLAY_MENU then
		G.OVERLAY_MENU.is_mp_group_options = true
	end
end

function MP.UI.refresh_group_options_overlay()
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options and G.FUNCS and G.FUNCS.view_group_options) then
		return false
	end

	G.FUNCS.view_group_options(nil)
	return true
end
