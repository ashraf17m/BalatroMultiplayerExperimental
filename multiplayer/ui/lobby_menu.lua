-- Consolidated Lobby Menu Module
-- Replaces 10 fragmented files with a unified, cohesive vertical module.

G = G or {}
G.UIDEF = G.UIDEF or {}
G.FUNCS = G.FUNCS or {}
MP = MP or {}
MP.UTILS = MP.UTILS or {}
MP.HOOKS = MP.HOOKS or {}
MP.GAME_UPDATE_CYCLE = MP.GAME_UPDATE_CYCLE or {}
MP.UI = MP.UI or {}
MP.UI.LOBBY_MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE or {}
MP.UI.LOBBY_VIEW_MODEL = MP.UI.LOBBY_VIEW_MODEL or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

-- ============================================================================
-- SECTION 1: LOBBY MAIN BUTTON STATE
-- (Consolidated from lobby_main_button_state.lua)
-- ============================================================================

local MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE

local WAITING_FOR_MATCH_FINISH_TEXT = { "WAITING FOR", "MATCH TO FINISH" }

local function get_active_players()
	local active = {}
	for _, player in ipairs(MP.LOBBY and MP.LOBBY.players or {}) do
		if not (player.is_spectator or player.role == "spectator") then
			table.insert(active, player)
		end
	end
	return active
end

local function get_lobby_team_count()
	local teams = {}

	for _, player in ipairs(get_active_players()) do
		teams[player.team or 1] = true
	end

	local count = 0
	for _, _ in pairs(teams) do
		count = count + 1
	end

	return count
end

local function get_lobby_start_block_reason(lobby_context)
	if MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress() then
		return "match_in_progress"
	end

	local active_players = get_active_players()
	local player_count = #active_players

	if lobby_context and lobby_context.is_saved_coop_restore then
		local required_players = tonumber(lobby_context.config and lobby_context.config.max_players) or 1
		if player_count < required_players then
			return "waiting_for_players"
		end
		return nil
	end

	if MP.lobby_uses_ready and MP.lobby_uses_ready() then
		if player_count ~= 2 then
			return "waiting_for_players"
		end

		for _, player in ipairs(active_players) do
			if not player.is_owner then
				if player.is_ready == true then
					return nil
				end

				return "waiting_for_guest_ready"
			end
		end

		return "waiting_for_players"
	end

	if player_count < 2 then
		return "waiting_for_players"
	end

	if MP.is_teams_mode() and get_lobby_team_count() < 2 then
		return "waiting_for_teams"
	end

	return nil
end

function MAIN_BUTTON_STATE.get_state()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local is_self_spectator = not not (
		(lobby_context.self_player and (lobby_context.self_player.is_spectator or lobby_context.self_player.role == "spectator"))
		or (MP.SPECTATOR and MP.SPECTATOR.is_spectator_role)
	)

	if lobby_context.is_host then
		local start_block_reason = get_lobby_start_block_reason(lobby_context)
		local disabled_text = start_block_reason == "match_in_progress" and WAITING_FOR_MATCH_FINISH_TEXT
			or start_block_reason == "waiting_for_guest_ready" and localize("b_wait_for_guest_ready")
			or start_block_reason == "waiting_for_teams" and localize("b_wait_for_teams")
			or localize("b_wait_for_players")

		return {
			mode = "host_start",
			enabled = start_block_reason == nil,
			disabled_text = disabled_text,
		}
	end

	if not (MP.lobby_uses_ready and MP.lobby_uses_ready()) or is_self_spectator then
		return {
			mode = "guest_wait",
			enabled = false,
			disabled_text = (MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress()) and WAITING_FOR_MATCH_FINISH_TEXT
				or localize("b_wait_for_host_start"),
		}
	end

	local pending_ready = lobby_context.client and lobby_context.client.pending_lobby_ready
	local self_ready = not not (lobby_context.self_player and lobby_context.self_player.is_ready)

	return {
		mode = "guest_ready",
		enabled = true,
		is_ready = pending_ready ~= nil and pending_ready or self_ready,
	}
end

-- ============================================================================
-- SECTION 2: LOBBY WARNING STATE & NOTIFICATIONS
-- (Consolidated from lobby_warning_state.lua)
-- ============================================================================


local function add_warning(warnings, text, colour, scale)
	warnings[#warnings + 1] = { text, colour, scale }
end

local function get_lobby_owner()
	for _, player in ipairs(MP.LOBBY.players or {}) do
		if player.is_owner then
			return player
		end
	end
	return nil
end

local function get_extra_credit_warning_text(key)
	return string.format(localize(key), localize("mp_sticker_extra_credit"))
end

local function stringify(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function get_warning_text_colour()
	local smods = MP.PLATFORM and MP.PLATFORM.SMODS
	if smods and smods.get_gradient then
		return smods.get_gradient("warning_text", G.C.UI.TEXT_LIGHT)
	end
	return G.C.UI.TEXT_LIGHT
end

local function build_player_warning_key(player)
	local config = player and player.config or {}

	return table.concat({
		stringify(player and player.id),
		stringify(player and player.is_owner),
		stringify(player and player.cached),
		stringify(config.hash_str),
	}, "|")
end

local function build_lobby_warning_cache_key()
	local players = {}
	for _, player in ipairs(MP.LOBBY.players or {}) do
		players[#players + 1] = build_player_warning_key(player)
	end

	return table.concat({
		stringify(MP.LOBBY and MP.LOBBY.lobby_type),
		stringify(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset),
		stringify(MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.username),
		stringify(MP.UTILS.unlock_check and MP.UTILS.unlock_check()),
		stringify(SMODS and SMODS.version),
		table.concat(players, ";"),
	}, "||")
end

local function compute_lobby_warnings()
	local warnings = {}
	local cheating_warning_added = false
	local banned_mods_warning_added = false
	local warning_text_colour = get_warning_text_colour()

	local self_player_id = (G and G.MP_ID or nil)
	for _, p in ipairs(MP.LOBBY.players or {}) do
		if p.id ~= self_player_id then
			if p.cached == false and not cheating_warning_added then
				local cheating_msg = string.format(localize("k_warning_cheating2"), MP.UTILS.random_message())
				add_warning(warnings, localize("k_warning_cheating1"), warning_text_colour, 0.4)
				add_warning(warnings, cheating_msg, warning_text_colour)
				cheating_warning_added = true
			end

			if p.config and p.config.unlocked == false then
				add_warning(warnings, localize("k_warning_nemesis_unlock"), warning_text_colour, 0.25)
			end
		end

		if not banned_mods_warning_added and p.config and MP.UTILS.get_banned_mods then
			local banned_mods = MP.UTILS.get_banned_mods(p.config.Mods)
			if #banned_mods > 0 then
				add_warning(warnings, localize("k_warning_banned_mods"), G.C.RED or warning_text_colour, 0.4)
				banned_mods_warning_added = true
			end
		end
	end

	local host = get_lobby_owner()

	if host and host.config and MP.LOBBY and MP.LOBBY.lobby_type == MP.LOBBY_TYPES.ONE_V_ONE then
		local guest = nil
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if p.id ~= host.id then
				guest = p
				break
			end
		end

		if guest and guest.config then
			local host_extra_credit_version = host.config.Mods["extracredit"]
			local guest_extra_credit_version = guest.config.Mods["extracredit"]

			if host_extra_credit_version ~= guest_extra_credit_version then
				add_warning(
					warnings,
					get_extra_credit_warning_text("k_warning_extra_credit_mismatch"),
					warning_text_colour
				)
			elseif host_extra_credit_version ~= nil then
				add_warning(
					warnings,
					get_extra_credit_warning_text("k_warning_extra_credit_active"),
					G.C.GREEN,
					0.25
				)
			end
		end
	elseif host and host.config then
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if not p.is_owner and p.config then
				local host_extra_credit = host.config.Mods["extracredit"]
				local guest_extra_credit = p.config.Mods["extracredit"]
				if host_extra_credit ~= guest_extra_credit then
					add_warning(
						warnings,
						get_extra_credit_warning_text("k_warning_extra_credit_mismatch_short"),
						warning_text_colour
					)
					break
				end
			end
		end
	end

	if host and host.config then
		if MP.UTILS.mp_version_mismatch and MP.UTILS.mp_version_mismatch(MP.LOBBY.players) then
			add_warning(warnings, localize("k_mp_version_warning"), warning_text_colour)
		end

		local host_steamodded_version = host.config.Mods["Steamodded"]
		for _, p in ipairs(MP.LOBBY.players or {}) do
			if not p.is_owner and p.config then
				local guest_steamodded_version = p.config.Mods["Steamodded"]
				if host_steamodded_version ~= guest_steamodded_version then
					add_warning(warnings, localize("k_steamodded_warning"), warning_text_colour)
					break
				end
			end
		end
	end

	if MP.UTILS and MP.UTILS.is_ranked_ruleset_key and MP.UTILS.is_ranked_ruleset_key(MP.LOBBY.config and MP.LOBBY.config.ruleset) then
		local smods_warning = MP.UTILS.check_smods_recommended_version and MP.UTILS.check_smods_recommended_version() or false
		if smods_warning then
			add_warning(warnings, smods_warning, warning_text_colour, 0.25)
		end
	end

	local is_unlocked = MP.UTILS.unlock_check and MP.UTILS.unlock_check()
	if is_unlocked == false then
		add_warning(warnings, localize("k_warning_unlock_profile"), warning_text_colour, 0.25)
	end

	if MP.LOBBY and MP.LOBBY.client and MP.LOBBY.client.username == "Guest" then
		add_warning(warnings, localize("k_set_name"), G.C.UI.TEXT_LIGHT)
	end

	if #warnings == 0 then
		add_warning(warnings, " ", G.C.UI.TEXT_LIGHT)
	end

	return warnings
end

function MP.UI.get_lobby_warnings()
	local cache_key = build_lobby_warning_cache_key()
	local cache = MP.UI.lobby_warning_cache
	if cache and cache.key == cache_key and cache.warnings then
		return cache.warnings
	end

	local warnings = compute_lobby_warnings()
	MP.UI.lobby_warning_cache = {
		key = cache_key,
		warnings = warnings,
	}
	return warnings
end

-- ============================================================================
-- SECTION 3: LOBBY STATUS OVERLAY
-- (Consolidated from lobby_overlays.lua)
-- ============================================================================

G.HUD_connection_status = nil

function G.UIDEF.get_connection_status_ui()
	return UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = {
				align = "cm",
				colour = G.C.UI.TRANSPARENT_DARK,
			},
			nodes = {
				MP.UI.UTILS.create_text_node(
					(MP.LOBBY.code and localize("k_in_lobby"))
						or (MP.LOBBY.client and MP.LOBBY.client.connected and localize("k_connected"))
						or localize("k_warn_service"),
					{
						scale = 0.3,
						colour = G.C.UI.TEXT_LIGHT,
					}
				),
			},
		},
		config = {
			align = "tri",
			bond = "Weak",
			offset = {
				x = 0,
				y = 0.9,
			},
			major = G.ROOM_ATTACH,
		},
	})
end

function G.UIDEF.create_UIBox_unstuck()
	return (
		create_UIBox_generic_options({
			back_func = "options",
			contents = {
				{
					n = G.UIT.C,
					config = {
						padding = 0.2,
						align = "cm",
					},
					nodes = {
						UIBox_button({ label = { localize("b_unstuck_blind") }, button = "mp_unstuck_blind", minw = 5 }),
					},
				},
			},
		})
	)
end

-- ============================================================================
-- SECTION 4: LOBBY DECK & STAKE BUTTON
-- (Consolidated from lobby_deck_stake_button.lua)
-- ============================================================================

local Disableable_Button = MP.UI.Disableable_Button

-- Component for deck selection button in lobby
function MP.UI.create_lobby_deck_button(text_scale, back, stake)
	local random_loadout = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.random_loadout
	local deck_labels = {
		random_loadout and "???" or localize({
			type = "name_text",
			key = (MP.UTILS and MP.UTILS.get_deck_key_from_name and MP.UTILS.get_deck_key_from_name(back)) or "b_red",
			set = "Back",
		}),
		random_loadout and "???" or localize({
			type = "name_text",
			key = (MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_stake_key and MP.PLATFORM.SMODS.get_stake_key(type(stake) == "string" and tonumber(stake) or stake)) or "stake_white",
			set = "Stake",
		}),
	}
	local enabled_ref_table = MP.LOBBY
	local enabled_ref_value = "is_host"

	if MP.LOBBY.is_saved_coop_restore then
		enabled_ref_table = { value = false }
		enabled_ref_value = "value"
	elseif not MP.LOBBY.is_host then
		enabled_ref_table = MP.LOBBY.config
		enabled_ref_value = "different_decks"
	end

	return Disableable_Button({
		id = "lobby_choose_deck",
		button = "lobby_choose_deck",
		colour = G.C.PURPLE,
		minw = 2.15,
		minh = 1.35,
		label = deck_labels,
		scale = text_scale * 1.2,
		col = true,
		enabled_ref_table = enabled_ref_table,
		enabled_ref_value = enabled_ref_value,
	})
end

-- ============================================================================
-- SECTION 5: LOBBY START / READY BUTTON
-- (Consolidated from lobby_start_ready_button.lua)
-- ============================================================================

local Disableable_Button = MP.UI.Disableable_Button
local MAIN_BUTTON_STATE = MP.UI.LOBBY_MAIN_BUTTON_STATE

local function create_lobby_main_disableable_button(text_scale, button_spec)
	return Disableable_Button({
		id = "lobby_menu_start",
		button = button_spec.button,
		colour = button_spec.colour,
		minw = 3.65,
		minh = 1.55,
		label = button_spec.label,
		disabled_text = button_spec.disabled_text,
		scale = text_scale * 2,
		col = true,
		enabled_ref_table = { enabled = button_spec.enabled },
		enabled_ref_value = "enabled",
	})
end

function MP.UI.lobby_status_display()
	local warnings = MP.UI.get_lobby_warnings and MP.UI.get_lobby_warnings() or { { " ", G.C.UI.TEXT_LIGHT } }

	local warning_texts = {}
	for k, v in pairs(warnings) do
		table.insert(
			warning_texts,
			MP.UI.UTILS.create_row({ align = "cm", padding = -0.25 }, {
				MP.UI.UTILS.create_text_node(v[1], {
					colour = v[2],
					scale = v[3] or 0.25,
				}),
			})
		)
	end

	return MP.UI.UTILS.create_row({ padding = 0.35, align = "cm" }, warning_texts)
end

-- Component for main start/ready button in lobby
function MP.UI.create_lobby_main_button(text_scale)
	local button_state = MAIN_BUTTON_STATE.get_state()

	if button_state.mode == "host_start" then
		return create_lobby_main_disableable_button(text_scale, {
			button = "lobby_start_game",
			colour = G.C.BLUE,
			label = { localize("b_start") },
			disabled_text = button_state.disabled_text,
			enabled = button_state.enabled,
		})
	end

	if button_state.mode == "guest_wait" then
		return create_lobby_main_disableable_button(text_scale, {
			button = "lobby_ready_up",
			colour = G.C.BLUE,
			label = button_state.disabled_text or { localize("b_wait_for_host_start") },
			disabled_text = button_state.disabled_text or localize("b_wait_for_host_start"),
			enabled = button_state.enabled,
		})
	end

	return UIBox_button({
		id = "lobby_menu_start",
		button = "lobby_ready_up",
		colour = button_state.is_ready and G.C.GREEN or G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = { button_state.is_ready and localize("b_unready") or localize("b_ready") },
		scale = text_scale * 2,
		col = true,
	})
end

-- ============================================================================
-- SECTION 6: LOBBY VIEW MODEL & ACTIONS
-- (Consolidated from lobby_view_model.lua)
-- ============================================================================


local view_model = MP.UI.LOBBY_VIEW_MODEL

local function get_lobby_context()
	local ctx = MP.get_lobby_state_context and MP.get_lobby_state_context() or (MP.LOBBY or {})
	ctx.config = ctx.config or (MP.LOBBY and MP.LOBBY.config) or {}
	return ctx
end

local LOBBY_OPTIONS_TAB_SPECS = {
	{
		id = "general",
		label_key = "k_lobby_general",
		build = function()
			return MP.UI.create_lobby_options_tab()
		end,
	},
	{
		id = "gameplay",
		label_key = "k_lobby_gameplay",
		when = function()
			return not (MP.is_coop_gamemode and MP.is_coop_gamemode())
		end,
		build = function()
			return MP.UI.create_gameplay_options_tab()
		end,
	},
	{
		id = "modifiers",
		label_key = "k_lobby_modifiers",
		when = function()
			return not (MP.is_coop_gamemode and MP.is_coop_gamemode())
		end,
		build = function()
			return MP.UI.create_gamemode_modifiers_tab()
		end,
	},
	{
		id = "bonuses",
		label_key = "k_lobby_bonuses",
		build = function()
			return MP.UI.create_bonuses_options_tab()
		end,
	},
	{
		id = "advanced",
		label_key = "k_lobby_advanced",
		build = function()
			return MP.UI.create_advanced_options_tab()
		end,
	},
}

local function is_lobby_options_tab_available(spec)
	return not spec.when or spec.when()
end

local function build_lobby_options_tab_definition(spec, chosen)
	return {
		label = localize(spec.label_key),
		chosen = chosen,
		tab_definition_function = function()
			view_model.active_lobby_options_tab = spec.id
			return spec.build()
		end,
	}
end

function view_model.create_lobby_type_options_button(text_scale, lobby_context)
	lobby_context = lobby_context or get_lobby_context()
	if lobby_context.match_in_progress or lobby_context.is_saved_coop_restore then
		return nil
	end

	local lobby_type_spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_context.lobby_type) or nil
	local button_spec = lobby_type_spec and lobby_type_spec.lobby_options_button or nil
	if not button_spec then
		return nil
	end

	return UIBox_button({
		button = button_spec.button,
		colour = button_spec.colour,
		minw = 3.15,
		minh = 1.35,
		label = {
			localize(button_spec.label_key),
		},
		scale = text_scale * 1.2,
		col = true,
	})
end

function view_model.build_lobby_menu_state()
	local text_scale = 0.45
	local lobby_context = get_lobby_context()
	local effective_deck = lobby_context.effective_deck or {}
	local self_team = lobby_context.self_team_id or 1

	return {
		text_scale = text_scale,
		lobby_context = lobby_context,
		back = effective_deck.back,
		stake = effective_deck.stake,
		lobby_type_options_button = view_model.create_lobby_type_options_button(text_scale, lobby_context),
		team_color = (MP.TEAM_COLORS and MP.TEAM_COLORS[self_team]) or G.C.WHITE,
		team_name = ((MP.TEAM_NAMES and MP.TEAM_NAMES[self_team]) or "RED") .. " TEAM",
	}
end

function view_model.build_lobby_options_state()
	local lobby_context = get_lobby_context()
	local active_tab_id = view_model.active_lobby_options_tab or "general"
	local tab_definitions = {}
	local active_tab_available = false

	for _, spec in ipairs(LOBBY_OPTIONS_TAB_SPECS) do
		if is_lobby_options_tab_available(spec) and spec.id == active_tab_id then
			active_tab_available = true
			break
		end
	end

	if not active_tab_available then
		active_tab_id = "general"
		view_model.active_lobby_options_tab = active_tab_id
	end

	for _, spec in ipairs(LOBBY_OPTIONS_TAB_SPECS) do
		if is_lobby_options_tab_available(spec) then
			tab_definitions[#tab_definitions + 1] = build_lobby_options_tab_definition(spec, spec.id == active_tab_id)
		end
	end

	return {
		lobby_context = lobby_context,
		show_host_notice = not lobby_context.is_host,
		tab_definitions = tab_definitions,
	}
end

-- ============================================================================
-- SECTION 7: LOBBY MENU UIBOX DEFINITION
-- (Consolidated from lobby_menu.lua)
-- ============================================================================

local function create_lobby_leave_button(text_scale)
	return UIBox_button({
		id = "lobby_menu_leave",
		button = "lobby_leave",
		colour = G.C.RED,
		minw = 3.65,
		minh = 1.55,
		label = { localize("b_leave") },
		scale = text_scale * 1.5,
		col = true,
	})
end

local function create_lobby_code_buttons(text_scale)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
		},
		nodes = {
			UIBox_button({
				button = "view_code",
				colour = G.C.PALE_GREEN,
				minw = 2.15,
				minh = 0.65,
				label = { localize("b_view_code") },
				scale = text_scale * 1.2,
			}),
			MP.UI.create_spacer(0.1, true),
			UIBox_button({
				button = "copy_to_clipboard",
				colour = G.C.PERISHABLE,
				minw = 2.15,
				minh = 0.65,
				label = { localize("b_copy_code") },
				scale = text_scale,
			}),
		},
	}
end

function G.UIDEF.create_UIBox_lobby_menu()
	local screen_state = MP.UI.LOBBY_VIEW_MODEL.build_lobby_menu_state()
	local text_scale = screen_state.text_scale
	local lobby_context = screen_state.lobby_context
	local back = screen_state.back
	local stake = screen_state.stake
	local lobby_type_options_button = screen_state.lobby_type_options_button
	local team_color = screen_state.team_color
	local team_name = screen_state.team_name

	local t = {
		n = G.UIT.ROOT,
		config = {
			align = "cm",
			colour = G.C.CLEAR,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = {
					align = "bm",
				},
				nodes = {
					MP.UI.lobby_status_display(),
					-- TEAM IDENTITY BADGE (Only in teams mode)
					(lobby_context.is_teams_mode and {
						n = G.UIT.R,
						config = { align = "cm", padding = 0.1, r = 0.1, colour = team_color, emboss = 0.05, shadow = true },
						nodes = {
							{ n = G.UIT.T, config = { text = "YOU ARE ON ", scale = 0.3, colour = G.C.UI.TEXT_LIGHT } },
							{ n = G.UIT.T, config = { text = team_name, scale = 0.45, colour = G.C.WHITE, shadow = true } },
						}
					}) or nil,
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							padding = 0.2,
							r = 0.1,
							emboss = 0.1,
							colour = G.C.L_BLACK,
							mid = true,
						},
						nodes = {
							MP.UI.create_lobby_main_button(text_scale),
							{
								n = G.UIT.C,
								config = {
									align = "cm",
								},
								nodes = {
									not lobby_context.config.forced_config and not lobby_context.match_in_progress and not lobby_context.is_saved_coop_restore and UIBox_button({
										button = "lobby_options",
										colour = G.C.ORANGE,
										minw = 3.15,
										minh = 1.35,
										label = {
											localize("b_lobby_options"),
										},
										scale = text_scale * 1.2,
										col = true,
									}) or nil,
									(not lobby_context.config.forced_config and not lobby_context.match_in_progress and not lobby_context.is_saved_coop_restore) and MP.UI.create_spacer() or nil,
									UIBox_button({
										button = "view_players_list",
										colour = G.C.BLUE,
										minw = 3.15,
										minh = 1.35,
										label = {
											localize("b_players"),
										},
										scale = text_scale * 1.45,
										col = true,
									}),
									MP.UI.create_spacer(),
									lobby_type_options_button,
									lobby_type_options_button and MP.UI.create_spacer() or nil,
									MP.UI.create_lobby_deck_button(text_scale, back, stake),
									MP.UI.create_spacer(),
									create_lobby_code_buttons(text_scale),
								},
							},
							create_lobby_leave_button(text_scale),
						},
					},
				},
			},
		},
	}
	return t
end

MP.UI.create_UIBox_lobby_menu = G.UIDEF.create_UIBox_lobby_menu

function G.UIDEF.create_UIBox_lobby_options()
	local screen_state = MP.UI.LOBBY_VIEW_MODEL.build_lobby_options_state()
	return create_UIBox_generic_options({
		contents = {
			{
				n = G.UIT.R,
				config = {
					id = "lobby_options_overlay",
					padding = 0,
					align = "cm",
				},
				nodes = {
					screen_state.show_host_notice and MP.UI.UTILS.create_row({ align = "cm", padding = 0.3 }, {
						MP.UI.UTILS.create_text_node(localize("k_opts_only_host"), {
							scale = 0.6,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}) or nil,
					create_tabs({
						snap_to_nav = true,
						colour = G.C.BOOSTER,
						tabs = screen_state.tab_definitions,
					}),
				},
			},
		},
	})
end

-- ============================================================================
-- SECTION 8: LOBBY MENU RUNTIME & REFRESH
-- (Consolidated from lobby_menu_runtime.lua)
-- ============================================================================

local lobby_menu_runtime = {}

local last_lobby_main_menu_signature = nil
local in_lobby = false
local lobby_menu_transition_active = false
local pending_lobby_main_menu_refresh = false

local function build_lobby_main_menu_signature()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local config = lobby_context.config or {}
	local run_deck = lobby_context.run_deck or {}
	local client = lobby_context.client or {}

	local parts = {
		tostring(lobby_context.code),
		tostring(lobby_context.lobby_type),
		tostring(lobby_context.is_host),
		tostring(lobby_context.match_in_progress),
		tostring(lobby_context.is_saved_coop_restore),
		tostring(client.username),
		tostring(client.role),
		tostring((MP.SPECTATOR and MP.SPECTATOR.is_spectator_role) or client.is_spectator),
		tostring(config.forced_config),
		tostring(config.different_decks),
		tostring(config.random_loadout),
		tostring(config.ruleset),
		tostring(run_deck.back),
		tostring(run_deck.stake),
		tostring(run_deck.sleeve),
		tostring(run_deck.challenge),
		tostring(run_deck.cocktail),
	}

	for _, player in ipairs(lobby_context.players or {}) do
		local p_conf = player.config or {}
		parts[#parts + 1] = string.format(
			"%s:%s:%s:%s:%s:%s:%s:%s:%s",
			tostring(player.id),
			tostring(player.team),
			tostring(player.is_host),
			tostring(player.is_owner),
			tostring(player.is_ready),
			tostring(player.is_in_match),
			tostring(player.is_spectator),
			tostring(player.role),
			tostring(p_conf.hash_str or "")
		)
	end

	return table.concat(parts, "|")
end

local function is_screenwipe_active()
	local root = G or G
	return not not (root and root.screenwipe)
end

local function should_defer_lobby_main_menu_refresh()
	return lobby_menu_transition_active or is_screenwipe_active()
end

local function defer_lobby_main_menu_refresh()
	pending_lobby_main_menu_refresh = true
	return false
end

function lobby_menu_runtime.get_lobby_main_menu_ui(e)
	return UIBox({
		definition = G.UIDEF.create_UIBox_lobby_menu(),
		config = {
			align = "bmi",
			offset = {
				x = 0,
				y = 10,
			},
			major = BALATRO.get_room_attach and BALATRO.get_room_attach() or nil,
			bond = "Weak",
		},
	})
end

function lobby_menu_runtime.display_lobby_main_menu_ui(e, options)
	options = options or {}
	local main_menu_ui = lobby_menu_runtime.get_lobby_main_menu_ui(e)
	BALATRO.set_main_menu_ui(main_menu_ui)
	main_menu_ui.is_mp_lobby_menu = true
	main_menu_ui.alignment.offset.y = 0
	BALATRO.align_to_major(main_menu_ui)
	if not options.skip_focus_snap then
		BALATRO.snap_controller_to_ui_element(main_menu_ui, "lobby_menu_start")
	end
end

local function is_in_lobby_session()
	return not not (MP.LOBBY and MP.LOBBY.code)
end

function lobby_menu_runtime.refresh_lobby_main_menu(options)
	if MP.RESUME and MP.RESUME.is_resume_transition_active and MP.RESUME.is_resume_transition_active() then
		return false
	end

	if not is_in_lobby_session() or not ((G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false)) then
		return false
	end

	options = options or {}
	if not options.force and should_defer_lobby_main_menu_refresh() then
		return defer_lobby_main_menu_refresh()
	end

	local new_signature = build_lobby_main_menu_signature()
	local main_menu_ui = (G and G.MAIN_MENU_UI or nil)
	if main_menu_ui and main_menu_ui.is_mp_lobby_menu and last_lobby_main_menu_signature == new_signature then
		pending_lobby_main_menu_refresh = false
		return true
	end
	local had_existing_lobby_ui = main_menu_ui and main_menu_ui.is_mp_lobby_menu
	last_lobby_main_menu_signature = new_signature
	pending_lobby_main_menu_refresh = false

	BALATRO.clear_main_menu_ui()

	lobby_menu_runtime.display_lobby_main_menu_ui(nil, {
		skip_focus_snap = had_existing_lobby_ui and not options.snap_focus,
	})
	if MP.UI and MP.UI.update_coop_blind_curve_demonstration then
		MP.UI.update_coop_blind_curve_demonstration()
	end
	return true
end

function lobby_menu_runtime.set_main_menu_ui(set_main_menu_ui_ref)
	if MP.RESUME and MP.RESUME.is_resume_transition_active and MP.RESUME.is_resume_transition_active() then
		return
	end

	lobby_menu_transition_active = false
	if is_in_lobby_session() then
		return lobby_menu_runtime.refresh_lobby_main_menu({ force = true })
	else
		pending_lobby_main_menu_refresh = false
		last_lobby_main_menu_signature = nil
		return set_main_menu_ui_ref()
	end
end

function lobby_menu_runtime.update_game_runtime(self)
	local in_lobby_session = is_in_lobby_session()
	if (in_lobby_session and not in_lobby) or (not in_lobby_session and in_lobby) then
		in_lobby = in_lobby_session
		BALATRO.set_no_saving(in_lobby)
		local resume_transition_active = MP.RESUME
			and MP.RESUME.is_resume_transition_active
			and MP.RESUME.is_resume_transition_active()
		local entering_active_match_session = in_lobby_session
			and MP.is_lobby_match_in_progress
			and MP.is_lobby_match_in_progress()
		if (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false) and not resume_transition_active and not entering_active_match_session then
			if is_screenwipe_active() then
				lobby_menu_transition_active = in_lobby_session
				pending_lobby_main_menu_refresh = in_lobby_session
			else
				lobby_menu_transition_active = true
				pending_lobby_main_menu_refresh = in_lobby_session
				BALATRO.go_to_menu()
				match_domain.reset_state()
			end
		end
	end
end

function lobby_menu_runtime.update_after_game()
	if MP.RESUME and MP.RESUME.update_pending_snapshot_capture then
		MP.RESUME.update_pending_snapshot_capture()
	end
	if MP.UI and MP.UI.flush_requested_refreshes then
		MP.UI.flush_requested_refreshes()
	end
	if pending_lobby_main_menu_refresh and not should_defer_lobby_main_menu_refresh() then
		lobby_menu_runtime.refresh_lobby_main_menu()
	end
end

function lobby_menu_runtime.update_connection_status()
	BALATRO.clear_hud_connection_status()
	if (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false) then
		BALATRO.set_hud_connection_status(BALATRO.create_connection_status_ui())
	end
end


-- ============================================================================
-- SECTION 9: LOBBY MENU HOOKS
-- (Consolidated from lobby_menu_hooks.lua)
-- ============================================================================

MP.UI.LOBBY_MENU_RUNTIME = lobby_menu_runtime
MP.UI.lobby_menu_runtime = lobby_menu_runtime

G.FUNCS.get_lobby_main_menu_UI = lobby_menu_runtime.get_lobby_main_menu_ui
G.FUNCS.display_lobby_main_menu_UI = lobby_menu_runtime.display_lobby_main_menu_ui

MP.UI.refresh_lobby_main_menu = lobby_menu_runtime.refresh_lobby_main_menu

local set_main_menu_UI_ref = set_main_menu_UI
---@diagnostic disable-next-line: lowercase-global
function set_main_menu_UI()
	return lobby_menu_runtime.set_main_menu_ui(set_main_menu_UI_ref)
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_before then
	MP.GAME_UPDATE_CYCLE.register_before("mp.ui.lobby_runtime", function(ctx, self)
		return lobby_menu_runtime.update_game_runtime(self)
	end, 10)
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.lobby_runtime", function()
		return lobby_menu_runtime.update_after_game()
	end, 30)
end

MP.UI.update_connection_status = lobby_menu_runtime.update_connection_status

if MP.HOOKS and MP.HOOKS.register_method_hook then
	MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.ui.lobby_menu_connection_status", {
		after = function(ctx)
			lobby_menu_runtime.update_connection_status()
			ctx.results = { n = 0 }
		end,
	})
end

-- ============================================================================
-- SECTION 10: LOBBY ACTIONS & BUTTON CALLBACKS
-- (Consolidated from lobby_actions.lua)
-- ============================================================================


local function open_overlay_definition(definition)
	G.FUNCS.overlay_menu({
		definition = definition,
	})
end

local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}

local function request_lobby_main_menu_refresh()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		return MP.UI.request_lobby_main_menu_refresh()
	end
	return false
end

local function apply_local_ready_state(player, is_ready)
	if not player then
		return false
	end

	player.is_ready = not not is_ready
	if MP.lobby_uses_ready and MP.lobby_uses_ready() then
		player.status_text = player.is_ready and localize("b_ready") or localize("b_unready")
		player.status_kind = player.is_ready and "ready" or "waiting"
	end

	return true
end

local function toggle_lobby_ready()
	if not (MP.lobby_uses_ready and MP.lobby_uses_ready()) then
		return false
	end
	if MP.LOBBY.client and MP.LOBBY.client.pending_lobby_ready ~= nil then
		return false
	end

	local self_player = MP.get_self_lobby_player and MP.get_self_lobby_player() or nil
	local is_ready = not (self_player and self_player.is_ready)
	if lobby_domain.set_pending_ready then
		lobby_domain.set_pending_ready(is_ready)
	end
	apply_local_ready_state(self_player, is_ready)
	request_lobby_main_menu_refresh()

	if is_ready then
		MP.ACTIONS.ready_lobby()
	else
		MP.ACTIONS.unready_lobby()
	end

	return true
end

local function open_lobby_options_overlay(preserve_active_tab)
	if MP.is_lobby_match_in_progress() then
		return false
	end

	if not preserve_active_tab and MP.UI and MP.UI.LOBBY_VIEW_MODEL then
		MP.UI.LOBBY_VIEW_MODEL.active_lobby_options_tab = "general"
	end
	open_overlay_definition(G.UIDEF.create_UIBox_lobby_options())

	return true
end

local function finalize_lobby_leave()
	G.FUNCS.exit_overlay_menu()
	if MP.UI and MP.UI.reset_version_mismatch_warning then
		MP.UI.reset_version_mismatch_warning()
	end
	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.suspend_team_card_sync then
		MP.MATCH_LIFECYCLE.suspend_team_card_sync()
	end
	MP.ACTIONS.leave_lobby()
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = false,
		})
	end

	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.go_to_menu()
		match_domain.reset_state()
	else
		G.STATE = G.STATES.MENU
	end
end

local function leave_lobby()
	if G.STAGE ~= G.STAGES.MAIN_MENU then
		G.FUNCS.confirm_selection(function()
			finalize_lobby_leave()
		end)
	else
		finalize_lobby_leave()
	end
end

local function process_pending_lobby_option_failure()
	local runtime = MP.UI and MP.UI.get_lobby_session_runtime and MP.UI.get_lobby_session_runtime() or nil
	local failure_message = runtime and runtime.pending_option_failure_message or nil
	if not failure_message then
		return false
	end

	runtime.pending_option_failure_message = nil
	leave_lobby()

	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(failure_message)
	end

	return true
end

local function update_coop_save_button_label(e)
	if MP.COOP_SAVE and MP.COOP_SAVE.update_button_node then
		return MP.COOP_SAVE.update_button_node(e)
	end

	return false
end

local function can_choose_lobby_deck()
	if not MP.LOBBY or MP.LOBBY.is_saved_coop_restore then
		return false
	end

	return MP.LOBBY.is_host or (MP.LOBBY.config and MP.LOBBY.config.different_decks)
end

local function get_center(key)
	return G and G.P_CENTERS and G.P_CENTERS[key] or nil
end

local function append_back_name(names, seen, center)
	local name = center and center.name or nil
	if name and name ~= "" and not seen[name] then
		seen[name] = true
		names[#names + 1] = name
	end
end

local function get_cocktail_deck_keys()
	local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or {}
	if content_runtime.get_cocktail_decks then
		local deck_keys = content_runtime.get_cocktail_decks(false)
		if type(deck_keys) == "table" then
			return deck_keys
		end
	end

	if MP.get_cocktail_decks then
		local deck_keys = MP.get_cocktail_decks(false)
		if type(deck_keys) == "table" then
			return deck_keys
		end
	end

	return nil
end

local function get_random_back_pool()
	local names, seen = {}, {}
	local cocktail_deck_keys = get_cocktail_deck_keys()

	for _, key in ipairs(cocktail_deck_keys or {}) do
		append_back_name(names, seen, get_center(key))
	end
	append_back_name(names, seen, get_center("b_mp_cocktail"))

	if #names == 0 and G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back then
		for _, center in ipairs(G.P_CENTER_POOLS.Back) do
			if center.unlocked and center.name ~= "Challenge Deck" and center.name ~= "Random Deck" then
				append_back_name(names, seen, center)
			end
		end
	end

	return names
end

local function scoped_random(seed, salt, max)
	max = math.max(1, math.floor(tonumber(max) or 1))
	if seed and seed ~= "" and pseudohash then
		math.randomseed(pseudohash(seed .. "_mp_random_" .. tostring(salt or "")))
	end
	return math.random(1, max)
end

local function roll_random_back_name(seed, salt)
	local names = get_random_back_pool()
	if #names == 0 then
		return "Red Deck"
	end
	return names[scoped_random(seed, "deck_" .. tostring(salt or ""), #names)]
end

local function roll_random_stake(seed, salt)
	local max_stake = MP.DECK and tonumber(MP.DECK.MAX_STAKE) or 0
	local cap = max_stake > 0 and max_stake or 8
	return scoped_random(seed, "stake_" .. tostring(salt or ""), cap)
end

local function get_random_loadout_salt()
	local client = MP.LOBBY and MP.LOBBY.client or nil
	if client and client.username then
		return client.username
	end
	if MP.LOBBY and MP.LOBBY.username then
		return MP.LOBBY.username
	end
	return (G and G.MP_ID or nil) or ""
end

local function build_random_loadout(seed, salt)
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY and MP.LOBBY.run_deck or {}

	return {
		back = roll_random_back_name(seed, salt),
		challenge = "",
		stake = roll_random_stake(seed, salt),
		sleeve = run_deck.sleeve or config.sleeve or "sleeve_casl_none",
		cocktail = run_deck.cocktail or config.cocktail or "",
	}
end

local function apply_random_loadout_to_run_deck(loadout)
	if lobby_domain.update_run_deck then
		return lobby_domain.update_run_deck(loadout)
	end
	if MP.LOBBY then
		MP.LOBBY.run_deck = loadout
	end
	return loadout
end

local function apply_shared_random_loadout()
	local loadout = build_random_loadout()
	local config = MP.LOBBY and MP.LOBBY.config or nil
	if config then
		for key, value in pairs(loadout) do
			config[key] = value
		end
	end
	apply_random_loadout_to_run_deck(loadout)

	if MP.ACTIONS and MP.ACTIONS.lobby_options then
		MP.ACTIONS.lobby_options(loadout)
	end
	request_lobby_main_menu_refresh()
	return loadout
end

---@type fun(e: table | nil, args: { deck: string, stake: number | nil, seed: string | nil })
function G.FUNCS.lobby_start_run(e, args)
	args = args or {}
	local config = MP.LOBBY and MP.LOBBY.config or {}

	if config.different_decks == false and lobby_domain.sync_run_deck_from_config then
		lobby_domain.sync_run_deck_from_config()
	elseif config.different_decks and config.random_loadout then
		apply_random_loadout_to_run_deck(build_random_loadout(args.seed, get_random_loadout_salt()))
	end

	local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck

	local challenge = nil
	if run_deck.back == "Challenge Deck" then
		challenge = G.CHALLENGES[get_challenge_int_from_id(run_deck.challenge)]
	else
		if G and G.GAME then
			G.GAME["viewed_back"] = G and G.P_CENTERS and G.P_CENTERS[MP.UTILS.get_deck_key_from_name(run_deck.back)] or nil
		end
	end

	G.FUNCS.start_run(e, {
		mp_start = true,
		challenge = challenge,
		stake = tonumber(run_deck.stake),
		seed = args.seed,
		savetext = args.savetext,
	})
end

if MP.HOOKS and MP.HOOKS.register_method_hook then
	MP.HOOKS.register_method_hook(Back, "Back", "generate_UI", "mp.lobby_actions.challenge_deck_overlay", {
		before = function(ctx, self)
		local other = ctx.args[1]
		local challenge = ctx.args[4]
		local name = other and other.name or self.name
		if not (not challenge and name == "Challenge Deck" and MP.LOBBY.code) then
			return
		end

		local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck
		ctx.args[4] = run_deck and run_deck.challenge -- very generous assumption
		if (ctx.args.n or 0) < 4 then
			ctx.args.n = 4
		end
		ctx.mp_lobby_challenge_overlay = true
	end,
	after = function(ctx)
		if not ctx.mp_lobby_challenge_overlay then
			return
		end

		-- essentially the button opens the correct challenge menu
		-- exiting this challenge menu results in a crash that's difficult to figure out
		-- (some sort of jank when removing the ui elements)
		-- Force the borrowed challenge overlay to exit cleanly instead of tearing down stale UI.
		local ret = ctx.results and ctx.results[1]
		local btn = ret and ret.nodes and ret.nodes[1] and ret.nodes[1].nodes and ret.nodes[1].nodes[1]
		if btn and btn.config then
			btn.config.button = "exit_overlay_menu"
		end
	end,
})
end

function G.FUNCS.lobby_start_game(e)
	if MP.UI and MP.UI.show_version_mismatch_if_needed and MP.UI.show_version_mismatch_if_needed() then
		return
	end

	if
		MP.LOBBY
		and MP.LOBBY.is_host
		and MP.LOBBY.config
		and MP.LOBBY.config.random_loadout
		and not MP.LOBBY.config.different_decks
	then
		apply_shared_random_loadout()
	end

	MP.ACTIONS.start_game()
end

function G.FUNCS.lobby_ready_up(e)
	if MP.UI and MP.UI.show_version_mismatch_if_needed and MP.UI.show_version_mismatch_if_needed() then
		return
	end

	toggle_lobby_ready()
end

function G.FUNCS.lobby_options(e)
	if MP.LOBBY and MP.LOBBY.is_saved_coop_restore then
		return
	end

	local preserve_active_tab = e and e.config and e.config.preserve_active_lobby_options_tab
	open_lobby_options_overlay(preserve_active_tab)
end

function G.FUNCS.view_code(e)
	local text_config = e.children[1].children[1].config
	if text_config.text ~= MP.LOBBY.code then
		e.config.colour = G.C.ETERNAL
		text_config.text = MP.LOBBY.code
	else
		e.config.colour = G.C.GREEN
		text_config.text = localize("b_view_code")
	end
	e.UIBox:recalculate()
end

function G.FUNCS.lobby_leave(e)
	leave_lobby()
end

function G.FUNCS.mp_end_game_leave_lobby(e)
	if MP.GAME and MP.GAME.is_coop_ante8_win then
		G.FUNCS.confirm_selection(function()
			finalize_lobby_leave()
		end, "overlay_endgame_menu")
		return
	end
	finalize_lobby_leave()
end

MP.UI.process_pending_lobby_option_failure = process_pending_lobby_option_failure

local function ensure_stake_option_hook_installed()
	if G and G.UIDEF and G.UIDEF.stake_option and not MP.stake_option_hook_installed and MP.HOOKS and MP.HOOKS.register_method_hook then
		MP.stake_option_hook_installed = MP.HOOKS.register_method_hook(
			G.UIDEF,
			"G.UIDEF",
			"stake_option",
			"mp.deck_select.all_stakes_in_lobby",
			{
				before = function(ctx, _type)
					if MP.LOBBY and MP.LOBBY.code and G and G.PROFILES and G.SETTINGS and G.SETTINGS.profile and G.PROFILES[G.SETTINGS.profile] then
						ctx.temp_all_unlocked = G.PROFILES[G.SETTINGS.profile].all_unlocked
						G.PROFILES[G.SETTINGS.profile].all_unlocked = true
					end
				end,
				after = function(ctx)
					if ctx.temp_all_unlocked ~= nil and G and G.PROFILES and G.SETTINGS and G.SETTINGS.profile and G.PROFILES[G.SETTINGS.profile] then
						G.PROFILES[G.SETTINGS.profile].all_unlocked = ctx.temp_all_unlocked
					end
				end,
			}
		)
	end
end

ensure_stake_option_hook_installed()

function G.FUNCS.lobby_choose_deck(e)
	if not can_choose_lobby_deck() then
		return
	end

	ensure_stake_option_hook_installed()

	G.FUNCS.setup_run(e)
	if G.OVERLAY_MENU then
		G.OVERLAY_MENU:get_UIE_by_ID("run_setup_seed"):remove()
	end
end

if MP.HOOKS and MP.HOOKS.register_method_hook then
	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "start_run", "mp.lobby_actions.start_run", {
		before = function(ctx, e)
		local args = ctx.args[1] or {}
		ctx.args[1] = args
		if (ctx.args.n or 0) < 1 then
			ctx.args.n = 1
		end

		if not MP.LOBBY.code then
			return
		end

		if args.mp_resume then
			return
		end

		if MP.LOBBY.is_saved_coop_restore and not args.mp_start then
			ctx.skip_original = true
			ctx.results = { n = 0 }
			return
		end

		if not args.mp_start then
			G.FUNCS.exit_overlay_menu()
			local chosen_stake = tonumber(G.viewed_stake) or tonumber(args.stake) or 1

			local content_runtime = MP.CONTENT and MP.CONTENT.RUNTIME or {}
			local selected_cocktail = content_runtime.get_cocktail_config and content_runtime.get_cocktail_config()
				or MP.LOBBY.config.cocktail
			local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck or {}
			local selected_back = args.challenge and "Challenge Deck"
				or (args.deck and args.deck.name)
				or ((G and G.GAME and G.GAME["viewed_back"] or nil) or {}).name
				or run_deck.back
				or "Red Deck"
			local selected_challenge = args.challenge and args.challenge.id or ""
			local selected_sleeve = G.viewed_sleeve
			local selected_run_deck = {
				back = selected_back,
				stake = chosen_stake,
				sleeve = selected_sleeve,
				challenge = selected_challenge,
				cocktail = selected_cocktail,
			}

			if MP.LOBBY.is_host and not MP.LOBBY.config.different_decks then
				MP.ACTIONS.lobby_options(selected_run_deck)
			end

			if lobby_domain.update_run_deck then
				lobby_domain.update_run_deck(selected_run_deck)
			end

			request_lobby_main_menu_refresh()
			if MP.UI and MP.UI.update_coop_blind_curve_demonstration then
				MP.UI.update_coop_blind_curve_demonstration()
			end
			ctx.skip_original = true
			ctx.results = { n = 0 }
		else
			local run_deck = lobby_domain.get_run_deck and lobby_domain.get_run_deck() or MP.LOBBY.run_deck
			ctx.args[1] = {
				challenge = args.challenge,
				stake = tonumber(run_deck.stake),
				seed = args.seed,
			}
		end
	end,
})
end

local function return_to_lobby_from_run()
	if MP.COOP_SAVE and MP.COOP_SAVE.consume_active_resumed_save then
		MP.COOP_SAVE.consume_active_resumed_save()
	end
	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.suspend_team_card_sync then
		MP.MATCH_LIFECYCLE.suspend_team_card_sync()
	end
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
	if MP.ACTIONS.cache_end_game_state then
		MP.ACTIONS.cache_end_game_state()
	end
	MP.ACTIONS.return_to_lobby()
	G.FUNCS.go_to_menu()
	match_domain.reset_state()
end

function G.FUNCS.mp_return_to_lobby()
	if MP.LOBBY.is_host then
		G.FUNCS.confirm_selection(function()
			return_to_lobby_from_run()
		end)
	else
		return_to_lobby_from_run()
	end
end

function G.FUNCS.mp_end_game_return_to_lobby()
	if MP.GAME and MP.GAME.is_coop_ante8_win then
		G.FUNCS.confirm_selection(function()
			return_to_lobby_from_run()
		end, "overlay_endgame_menu")
		return
	end
	return_to_lobby_from_run()
end

function G.FUNCS.mp_end_game_endless_mode(e)
	if MP.GAME then
		MP.GAME.is_coop_ante8_win = nil
		MP.GAME.won = false
	end
	G.FUNCS.exit_overlay_menu()
	if G.SETTINGS then
		G.SETTINGS.paused = false
	end
	if BALATRO.set_paused then
		BALATRO.set_paused(false)
	end
end

function G.FUNCS.mp_unstuck()
	open_overlay_definition(G.UIDEF.create_UIBox_unstuck())
end

function G.FUNCS.mp_unstuck_blind()
	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
	if MP.GAME.next_blind_context then
		G.FUNCS.select_blind(MP.GAME.next_blind_context)
	else
		sendErrorMessage("No next blind context", "MULTIPLAYER")
	end
end

function G.FUNCS.mp_coop_save_run(e)
	if MP.ACTIONS and MP.ACTIONS.save_coop_run then
		if MP.ACTIONS.save_coop_run() then
			update_coop_save_button_label(e)
		end
	end
end

function G.FUNCS.copy_to_clipboard(e)
	MP.UTILS.copy_to_clipboard(MP.LOBBY.code)
end

function G.FUNCS.reconnect(e)
	MP.ACTIONS.connect()
	G.FUNCS.exit_overlay_menu()
end

