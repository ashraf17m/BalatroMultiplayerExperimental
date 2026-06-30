local function should_show_custom_winners_controls()
	return not not (MP.UI.should_show_custom_winners_controls and MP.UI.should_show_custom_winners_controls())
end

local active_group_options_tab = "general"
local pending_party_mode_change = nil

local function is_head_to_head_lobby_type(lobby_type)
	return MP.LOBBY_TYPES and lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
end

local function is_duels_lobby_type(lobby_type)
	return MP.LOBBY_TYPES and lobby_type == MP.LOBBY_TYPES.DUELS
end

local function is_teams_lobby_type(lobby_type)
	local lobby_type_spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
	return not not (lobby_type_spec and lobby_type_spec.uses_teams)
end

local function is_scoring_locked_lobby_type(lobby_type)
	return is_head_to_head_lobby_type(lobby_type) or is_duels_lobby_type(lobby_type)
end

local function party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
	return is_scoring_locked_lobby_type(previous_lobby_type)
		or is_scoring_locked_lobby_type(lobby_type)
		or is_teams_lobby_type(previous_lobby_type) ~= is_teams_lobby_type(lobby_type)
end

function MP.UI.party_mode_change_requires_group_options_rebuild(previous_lobby_type, lobby_type)
	return party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
end

function MP.UI.mark_pending_party_mode_change(lobby_type)
	pending_party_mode_change = {
		from = MP.LOBBY and MP.LOBBY.lobby_type,
		to = lobby_type,
		rebuilt = false,
	}
end

function MP.UI.mark_pending_party_mode_change_rebuilt(lobby_type)
	if pending_party_mode_change and pending_party_mode_change.to == lobby_type then
		pending_party_mode_change.rebuilt = true
		return true
	end
	return false
end

function MP.UI.should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	local pending_change = pending_party_mode_change
	local is_pending_party_mode_change = pending_change and pending_change.to == lobby_type
	if is_pending_party_mode_change then
		pending_party_mode_change = nil
	end

	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options) then
		return true
	end

	if is_pending_party_mode_change then
		if pending_change.rebuilt then
			return false
		end
		if party_mode_change_requires_rebuild(pending_change.from or previous_lobby_type, lobby_type) then
			return true
		end
		if MP.UI.sync_party_options_cycles and MP.UI.sync_party_options_cycles("party_mode_cycle") then
			return false
		end
		return party_mode_change_requires_rebuild(previous_lobby_type, lobby_type)
	end

	return previous_lobby_type ~= lobby_type
end

function MP.UI.sync_party_options_cycles(skip_control_id)
	local overlay = G and G.OVERLAY_MENU or nil
	if not (overlay and overlay.is_mp_group_options) then
		return false
	end

	local synced = false
	for _, control_id in ipairs({
		"party_mode_cycle",
		"party_scoring_rule_cycle",
		"party_max_players_cycle",
		"party_custom_winners_cycle",
	}) do
		if control_id ~= skip_control_id and MP.UI.sync_bound_lobby_option_cycle then
			synced = MP.UI.sync_bound_lobby_option_cycle(control_id) or synced
		end
	end

	if MP.UI.update_custom_winners_percent_slider and MP.UI.get_custom_winner_count then
		synced = MP.UI.update_custom_winners_percent_slider(MP.UI.get_custom_winner_count()) or synced
	end

	return synced
end

local function create_group_advanced_tab()
	return MP.UI.create_lobby_option_specs_page(
		MP.UI.PARTY_OPTION_TAB_SPECS and MP.UI.PARTY_OPTION_TAB_SPECS.general,
		4,
		{ center_controls = true, compact_empty_space = true }
	)
end

local function create_team_options_tab()
	return MP.UI.create_lobby_option_specs_page(
		MP.UI.LOBBY_OPTION_TAB_SPECS.team_options,
		3,
		{ compact_empty_space = true }
	)
end

local function is_group_options_tab_available(tab_id, lobby_context)
	if tab_id == "shared_progress" then
		return lobby_context.can_show_shared_progress_options
	end

	return tab_id == "general"
end

local function create_group_options_tab_definition(tab_id, label, build)
	return {
		label = label,
		chosen = active_group_options_tab == tab_id,
		tab_definition_function = function()
			active_group_options_tab = tab_id
			return build()
		end,
	}
end

local function create_group_options_tab()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	if not is_group_options_tab_available(active_group_options_tab, lobby_context) then
		active_group_options_tab = "general"
	end

	local tabs = {
		create_group_options_tab_definition(
			"general",
			localize("k_lobby_general"),
			create_group_advanced_tab
		),
	}
	if lobby_context.can_show_shared_progress_options then
		tabs[#tabs + 1] = create_group_options_tab_definition(
			"shared_progress",
			localize("k_team_options"),
			create_team_options_tab
		)
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

local function open_group_options_overlay(silent)
	local config = silent and { offset = { x = 0, y = 0 } } or nil
	local previous_jiggle = silent and G and G.ROOM and G.ROOM.jiggle or nil

	G.FUNCS.overlay_menu({
		definition = create_group_options_tab(),
		config = config,
	})

	if previous_jiggle and G and G.ROOM then
		G.ROOM.jiggle = previous_jiggle
	end

	if G.OVERLAY_MENU then
		G.OVERLAY_MENU.is_mp_group_options = true
	end
end

function G.FUNCS.view_group_options(e)
	if MP.is_lobby_match_in_progress() then
		return
	end

	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	open_group_options_overlay(false)
end

function MP.UI.refresh_group_options_overlay()
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options and G.FUNCS and G.FUNCS.view_group_options) then
		return false
	end

	open_group_options_overlay(true)
	return true
end

local function has_option(options, key)
	return type(options) == "table" and options[key] ~= nil
end

local function custom_winners_controls_visible()
	return not not (G
		and G.OVERLAY_MENU
		and G.OVERLAY_MENU:get_UIE_by_ID("party_custom_winners_cycle") ~= nil)
end

local function is_lobby_type_lock_option_batch(options)
	return has_option(options, "pvp_score_rule")
		and has_option(options, "max_players")
		and has_option(options, "pvp_custom_winners")
end

function MP.UI.should_refresh_group_options_for_lobby_options(options)
	if not (G and G.OVERLAY_MENU and G.OVERLAY_MENU.is_mp_group_options) then
		return false
	end

	if not (MP.LOBBY and MP.LOBBY.is_host) then
		return true
	end

	if type(options) ~= "table" then
		return false
	end

	if pending_party_mode_change then
		if pending_party_mode_change.rebuilt then
			return false
		end
		if party_mode_change_requires_rebuild(pending_party_mode_change.from, pending_party_mode_change.to) then
			pending_party_mode_change.rebuilt = true
			return true
		end
		if MP.UI.sync_party_options_cycles then
			MP.UI.sync_party_options_cycles("party_mode_cycle")
		end
		return false
	end

	if is_lobby_type_lock_option_batch(options) then
		return false
	end

	if options.gamemode ~= nil then
		return true
	end

	if has_option(options, "pvp_score_rule") then
		return should_show_custom_winners_controls() ~= custom_winners_controls_visible()
	end

	if has_option(options, "max_players") then
		return false
	end

	if has_option(options, "pvp_custom_winners") then
		return false
	end

	return false
end
