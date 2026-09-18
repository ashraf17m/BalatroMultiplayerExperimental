-- Consolidated Match Lobby Info Overlay Module
-- Replaces 5 fragmented files with a unified, cohesive vertical module.

MP.UI = MP.UI or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- ============================================================================
-- SECTION 1: TEAM MONEY TRANSFER STATE & POPUP
-- (Consolidated from match_lobby_info_team_money.lua)
-- ============================================================================

local team_money_ui = MP.UI.TEAM_MONEY or {}
MP.UI.TEAM_MONEY = team_money_ui

local function get_transfer_slider_max()
	local local_money = MP.get_local_money and MP.get_local_money() or 0
	return math.max(0, math.floor(tonumber(local_money) or 0))
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
	if not row_state then
		row_state = {
			value = 0,
			text = "0",
			slider_max = 0,
			pending = false,
		}
		ui_state.players[player_id] = row_state
	end
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

function team_money_ui.normalize_amount(amount, max_amount)
	local normalized_max = math.max(0, math.floor(tonumber(max_amount) or 0))
	local normalized_amount = math.floor(tonumber(amount) or 0)
	if normalized_amount < 0 then
		normalized_amount = 0
	elseif normalized_amount > normalized_max then
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

function team_money_ui.reset_row(player_id)
	local row_state = team_money_ui.get_row_state(player_id)
	row_state.pending = false
	return team_money_ui.sync_row_state(player_id, 0)
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

function team_money_ui.get_popup_box(player_id)
	local ui_state = team_money_ui.get_ui_state()
	local anchor = ui_state.popup_anchor
	local popup = anchor and anchor.children and anchor.children.mp_team_money_popup or nil
	if not popup or (player_id ~= nil and ui_state.active_player_id ~= player_id) then
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

local function create_popup_definition(player_id)
	local row_state = team_money_ui.refresh_row_state(player_id)
	local slider = create_slider({
		w = 3.1,
		h = 0.34,
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
		minw = 1.2,
		maxw = 1.1,
		minh = 0.42,
		scale = 0.3,
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

	team_money_ui.close_popup({ clear_active = false })

	anchor_node.children = anchor_node.children or {}
	anchor_node.children.mp_team_money_popup = UIBox({
		definition = create_popup_definition(player_id),
		config = {
			align = "tm",
			offset = { x = 0, y = -0.14 },
			major = anchor_node,
			bond = "Weak",
			instance_type = "POPUP",
		},
	})

	local ui_state = team_money_ui.get_ui_state()
	ui_state.active_player_id = player_id
	ui_state.popup_anchor = anchor_node
	return true
end

function team_money_ui.handle_money_update(money, delta, source_player_id)
	local ui_state = team_money_ui.get_ui_state()
	local delta_value = tonumber(delta) or 0

	if ui_state.pending_target_id and delta_value < 0 and source_player_id == ui_state.pending_target_id then
		team_money_ui.clear_pending_target_row()
		team_money_ui.close_popup({ clear_active = true })
		return true
	end

	return false
end

local function get_team_money_event_player_id(e, action_suffix)
	if not e or not e.config or not e.config.id then
		return nil
	end
	return string.match(e.config.id, "(.+)_" .. action_suffix)
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
		team_money_ui.close_popup({ reset_row = true })
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

	local raw_value = slider_config.ref_table and slider_config.ref_table[slider_config.ref_value]
	local row_state = team_money_ui.sync_row_state(slider_config.player_id, raw_value)
	slider_config.ref_table[slider_config.ref_value] = row_state.value
	slider_config.text = row_state.text
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
	team_money_ui.close_popup({ clear_active = true })

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


-- ============================================================================
-- SECTION 2: PLAYER ROW VIEW MODEL
-- (Consolidated from match_lobby_info_player_row_view_model.lua)
-- ============================================================================

local ROW_VIEW_MODEL = MP.UI and MP.UI.PLAYER_ROW_VIEW_MODEL or {}
local score_shared = MP.UI and MP.UI.PLAYERS_HUD_SHARED or {}
local parse_score_int = score_shared.try_parse_score_int
local SCORE_LANE_WIDTH = 2.87

local function same_insane_int(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return false
	end

	return (tonumber(left.e_count) or 0) == (tonumber(right.e_count) or 0)
		and (tonumber(left.exponent) or 0) == (tonumber(right.exponent) or 0)
		and (tonumber(left.coefficient) or 0) == (tonumber(right.coefficient) or 0)
end

local function get_localized_text(key, fallback)
	local value = localize(key)
	if type(value) == "string" and value ~= "" and value ~= "ERROR" and value ~= key then
		return value
	end
	return fallback
end

local function get_player_skips(enemy_state, is_self)
	if is_self then
		local local_skips = (G and G.GAME and G.GAME.skips or nil) or (G and G.GAME and G.GAME.skips)
		return tonumber(local_skips) or 0
	end
	return tonumber(enemy_state and enemy_state.skips) or 0
end

local function build_match_lobby_row_runtime_fields(player, lobby_context, is_self)
	local enemy_state = is_self and nil or (MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player.id] or nil)
	local capabilities = lobby_context.capabilities or {}
	local same_sync_group = MP.lobby_players_share_sync_group
		and MP.lobby_players_share_sync_group(lobby_context.self_player, player, capabilities)
	local can_show_money_action = lobby_context.can_show_shared_money_actions
		and not is_self
		and same_sync_group
		and (G and G.STAGES and G.STAGE == G.STAGES.RUN or false)

	local raw_location
	local location
	if is_self then
		raw_location = (MP.GAME and MP.GAME.location) or "loc_selecting"
		location = MP.UI.localize_location(raw_location)
	elseif player.is_disconnected then
		raw_location = "loc_disconnected"
		location = player.location or MP.UI.localize_location("loc_disconnected")
	else
		raw_location = (enemy_state and enemy_state.raw_location) or player.raw_location or "loc_selecting"
		location = (enemy_state and enemy_state.location) or player.location or MP.UI.localize_location(raw_location)
	end

	local lives
	local highest_score
	local score_display_int
	local skips = get_player_skips(enemy_state, is_self)
	if is_self then
		lives = (MP.GAME and MP.GAME.lives) or 0
		highest_score = (MP.GAME and MP.GAME.highest_score) or 0
		local latest_score = parse_score_int(MP.GAME and MP.GAME.score_text)
		if same_insane_int(highest_score, latest_score) then
			score_display_int = MP.GAME and MP.GAME.score_display
		end
	else
		lives = (enemy_state and enemy_state.lives) or 0
		highest_score = (enemy_state and enemy_state.highest_score) or 0
		if same_insane_int(highest_score, enemy_state and enemy_state.synced_score) then
			score_display_int = enemy_state and enemy_state.score
		end
	end

	return {
		raw_location = raw_location,
		location = location,
		lives = lives,
		skips = skips,
		highest_score = highest_score,
		score_display_int = score_display_int,
		can_show_money_action = can_show_money_action,
		can_send_money = can_show_money_action,
		row_colour = lobby_context.uses_team_colours and (MP.TEAM_COLORS[player.team or 1] or G.C.WHITE)
			or darken(G.C.JOKER_GREY, 0.1),
	}
end

local function build_match_lobby_player_row_model(player, index, opts)
	local options = opts or {}
	local lobby_context = options.lobby_context or (MP.get_lobby_state_context and MP.get_lobby_state_context()) or {}
	local row_model = ROW_VIEW_MODEL.build_lobby_player_row_model(player, index, {
		lobby_context = lobby_context,
	})
	local runtime_fields = build_match_lobby_row_runtime_fields(player, lobby_context, row_model.is_self)
	row_model.is_host = not not lobby_context.is_host

	for key, value in pairs(runtime_fields) do
		row_model[key] = value
	end

	-- Spectator means spectator; eliminated players are conveyed by lives = 0
	-- in the lives lane, not by a spectator chip.
	row_model.is_spectator = not not (
		row_model.is_spectator
		or player.is_spectator
		or player.role == "spectator"
	)

	row_model.show_lives_lane = not lobby_context.is_coop_gamemode
	if row_model.show_lives_lane then
		row_model.lives_lane_spec = {
			kind = "chip",
			text = tostring(row_model.lives) .. " " .. tostring(localize("k_lives") or "Lives"),
			colour = G.C.RED,
			minw = 1.95,
			scale = 0.45,
			slot_minw = 1.95,
		}
	end
	row_model.skip_chip_spec = {
		text = tostring(row_model.skips or 0) .. " " .. get_localized_text("k_skips", "Skips"),
		colour = G.C.PURPLE,
		minw = 1.75,
		scale = 0.45,
		slot_minw = 1.75,
	}
	row_model.kick_match_action = row_model.can_kick
			and ROW_VIEW_MODEL.create_kick_action(row_model, "_kick_match", "kick_player_match")
		or nil
	row_model.location_lane_spec = {
		kind = "location_lane",
		raw_location = row_model.raw_location,
		display = MP.UI.UTILS.resolve_location_display(row_model.raw_location, row_model.location, {
			player = player,
			is_self = row_model.is_self,
		}),
		text = row_model.location,
		minw = 4.05,
		scale = 0.45,
		text_colour = G.C.UI.TEXT_LIGHT,
		slot_minw = 4.05,
	}
	local score_text = type(row_model.highest_score) == "table"
			and MP.INSANE_INT.to_string(row_model.highest_score)
			or tostring(row_model.highest_score)
	local score_display = row_model.score_display_int and score_shared.get_score_display
		and score_shared.get_score_display(score_text, row_model.score_display_int, { prefer_score_int = true })
		or nil
	if score_display then
		score_display.is_self = not not row_model.is_self
	end
	row_model.score_lane_spec = {
		kind = "score_lane",
		text = score_text,
		score_display = score_display,
		minw = SCORE_LANE_WIDTH,
		scale = 0.45,
		text_colour = G.C.WHITE,
		slot_minw = SCORE_LANE_WIDTH,
		minh = 0.46,
		stake_scale = 0.38,
		show_stake_icon = true,
	}
	row_model.money_action_spec = row_model.can_show_money_action and {
		kind = "action",
		disableable = true,
		id = row_model.id .. "_view_team_money_transfer",
		button = "view_team_money_transfer",
		label = localize("b_send_money"),
		disabled_text = localize("b_send_money"),
		colour = G.C.MONEY,
		text_colour = G.C.UI.TEXT_LIGHT,
		tooltip = { localize("k_transfer_money") },
		minw = 1.95,
		minh = 0.42,
		scale = 0.45,
		slot_minw = 1.95,
		slot_minh = 0.42,
		enabled_ref_table = { enabled = row_model.can_send_money },
		enabled_ref_value = "enabled",
	} or nil

	return row_model
end
ROW_VIEW_MODEL.build_match_lobby_player_row_model = build_match_lobby_player_row_model

-- ============================================================================
-- SECTION 3: PLAYERS TAB VIEW
-- (Consolidated from match_lobby_info_players_view.lua)
-- ============================================================================

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
		ROW_LAYOUT.create_spectator_chip(model.is_spectator or model.role == "spectator"),
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

-- ============================================================================
-- SECTION 4: SETTINGS TAB VIEW
-- (Consolidated from match_lobby_info_settings_view.lua)
-- ============================================================================

local SETTING_TOGGLE_SPECS = {
	{ label = "b_opts_cb_money", ref_value = "gold_on_life_loss" },
	{ label = "b_opts_no_gold_on_loss", ref_value = "no_gold_on_round_loss" },
	{ label = "b_opts_death_on_loss", ref_value = "death_on_round_loss" },
	{ label = "b_opts_diff_seeds", ref_value = "different_seeds" },
	{ label = "b_opts_player_diff_deck", ref_value = "different_decks" },
	{ label = "b_opts_multiplayer_jokers", ref_value = "multiplayer_jokers" },
	{ label = "b_opts_normal_bosses", ref_value = "normal_bosses" },
}

local function create_settings_toggle_row(Disableable_Toggle, toggle_spec)
	local label_key = toggle_spec.label or toggle_spec.label_key
	local ref_value = toggle_spec.ref_value or toggle_spec.option_key
	if not (label_key and ref_value) then
		return nil
	end

	return MP.UI.UTILS.create_row({ padding = 0, align = "cr" }, {
		Disableable_Toggle({
			enabled_ref_table = MP.LOBBY,
			label = localize(label_key),
			ref_table = MP.LOBBY.config,
			ref_value = ref_value,
		}),
	})
end

local function get_scoring_rule_label()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local score_rule = config.pvp_score_rule
	if score_rule == "median" then
		return localize("k_median")
	elseif score_rule == "geometric" then
		return localize("k_geometric")
	elseif score_rule == "custom" then
		return localize("k_custom_score")
	elseif score_rule == "average" then
		return localize("k_beat_average")
	end
	return localize("k_highest_score")
end

local function create_settings_value_row(label_key, value_text)
	return MP.UI.UTILS.create_row({ align = "cm", padding = 0.03 }, {
		MP.UI.UTILS.create_text_node(localize(label_key) .. ": " .. value_text, {
			colour = G.C.UI.TEXT_LIGHT,
			scale = 0.45,
		}),
	})
end

local function append_settings_toggle_rows(nodes, Disableable_Toggle, toggle_specs)
	for _, toggle_spec in ipairs(toggle_specs or {}) do
		if not toggle_spec.when or toggle_spec.when(toggle_spec) then
			local row = create_settings_toggle_row(Disableable_Toggle, toggle_spec)
			if row then
				nodes[#nodes + 1] = row
			end
		end
	end
end

function MP.UI.create_UIBox_settings()
	if MP.UI and MP.UI.set_match_lobby_info_active_tab then
		MP.UI.set_match_lobby_info_active_tab("settings")
	end

	local Disableable_Toggle = MP.UI and MP.UI.Disableable_Toggle
	local ruleset = string.sub(MP.LOBBY.config.ruleset, 12, -1)
	local gamemode = string.sub(MP.LOBBY.config.gamemode, 13, -1)
	local seed = (MP.LOBBY.config.custom_seed == "random" and localize("k_random")) or MP.LOBBY.config.custom_seed or localize("k_random") or ""
	local nodes = {
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
			MP.UI.UTILS.create_text_node((localize("k_" .. ruleset) .. " " .. localize("k_" .. gamemode)), {
				colour = G.C.UI.TEXT_LIGHT,
				scale = 0.6,
			}),
		}),
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
			MP.UI.UTILS.create_text_node((localize("k_current_seed") .. seed), {
				colour = G.C.UI.TEXT_LIGHT,
				scale = 0.6,
			}),
		}),
	}

	append_settings_toggle_rows(nodes, Disableable_Toggle, SETTING_TOGGLE_SPECS)

	if MP.is_group_lobby_type and MP.is_group_lobby_type(MP.LOBBY and MP.LOBBY.lobby_type) then
		nodes[#nodes + 1] = create_settings_value_row("b_beat_average_mode", get_scoring_rule_label())
	end

	local lobby_capabilities = MP.get_lobby_capabilities and MP.get_lobby_capabilities() or {}
	if lobby_capabilities.can_show_shared_progress_options then
		local lobby_option_tab_specs = MP.UI.LOBBY_OPTION_TAB_SPECS or {}
		append_settings_toggle_rows(nodes, Disableable_Toggle, lobby_option_tab_specs.team_options)
	end

	return {
		n = G.UIT.ROOT,
		config = {
			emboss = 0.05,
			minh = 6,
			r = 0.1,
			minw = 10,
			align = "tm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = nodes,
	}
end

-- ============================================================================
-- SECTION 5: MATCH LOBBY INFO OVERLAY CONTROLLER
-- (Consolidated from match_lobby_info_overlay.lua)
-- ============================================================================


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

function MP.UI.set_match_lobby_info_active_tab(tab_name)
	local runtime = get_match_lobby_info_runtime()
	if runtime then
		runtime.active_tab = tab_name
		if tab_name == "players" then
			runtime.pending_refresh = false
		end
	end
end

function MP.UI.request_match_lobby_info_refresh()
	local runtime = get_match_lobby_info_runtime()
	if runtime then
		runtime.pending_refresh = true
	end
	if MP.UI and MP.UI.request_pending_match_lobby_info_refresh then
		return MP.UI.request_pending_match_lobby_info_refresh()
	end
	return true
end

function MP.UI.refresh_pending_match_lobby_info()
	local runtime = get_match_lobby_info_runtime()
	local pending_refresh = runtime and runtime.pending_refresh or false
	if not pending_refresh then
		return false
	end
	if not BALATRO.get_overlay_property("is_mp_match_lobby_info") then
		return false
	end
	if runtime.active_tab ~= "players" then
		return false
	end

	local refreshed = MP.UI and MP.UI.refresh_match_lobby_info_players and MP.UI.refresh_match_lobby_info_players() or false
	if refreshed then
		runtime.pending_refresh = false
	end
	return refreshed
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

