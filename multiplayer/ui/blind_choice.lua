-- ============================================================================
-- multiplayer/ui/blind_choice.lua
-- Consolidated Blind Choice UI: State, Rows, Text, Ready/Skip, Preview, Overlay & Handlers
-- ============================================================================

MP.UI = MP.UI or {}
MP.UI.BLIND_CHOICE_STATE = MP.UI.BLIND_CHOICE_STATE or {}
MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}
MP.UI.BLIND_CHOICE_OVERLAY = MP.UI.BLIND_CHOICE_OVERLAY or {}
MP.UI.BLIND_CHOICE_PREVIEW = MP.UI.BLIND_CHOICE_PREVIEW or {}

local blind_choice_state = MP.UI.BLIND_CHOICE_STATE
local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local blind_choice_overlay = MP.UI.BLIND_CHOICE_OVERLAY
local blind_choice_preview = MP.UI.BLIND_CHOICE_PREVIEW
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

-- ----------------------------------------------------------------------------
-- SECTION 1: Blind Choice State & Target Resolution
-- ----------------------------------------------------------------------------
local PREVIEW_BLIND_ROWS = { "Small", "Big", "Boss" }
local NO_NEMESIS_LABEL = "No Nemesis"

local function can_sync_coop_blind_preview()
	return MP.LOBBY
		and MP.LOBBY.code
		and MP.ACTIONS
		and MP.ACTIONS.blind_preview
		and ((MP.is_coop_gamemode and MP.is_coop_gamemode()) or (MP.is_coop_run and MP.is_coop_run()))
		and MP.uses_shared_sync_group
		and MP.uses_shared_sync_group()
end

local function normalize_preview_key_part(value)
	if value == nil then
		return ""
	end

	return tostring(value)
end

function blind_choice_state.get_preview_key()
	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["blind_ante"] or nil)
	if ante == nil then
		ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil)
	end

	local parts = {
		"ante:" .. normalize_preview_key_part(ante),
		"deck:" .. normalize_preview_key_part((G and G.GAME and G.GAME.blind_on_deck or nil)),
	}
	for _, row in ipairs(PREVIEW_BLIND_ROWS) do
		local blind_key = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[row]) or nil
		local pvp_flag = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[row] or nil) and "pvp" or "coop"
		parts[#parts + 1] = row .. ":" .. normalize_preview_key_part(blind_key) .. ":" .. pvp_flag
	end

	return table.concat(parts, "|")
end

local function parse_preview_target(value)
	if value == nil then
		return nil
	end
	if BALATRO.to_score_number then
		local numeric_value = BALATRO.to_score_number(value)
		if numeric_value ~= nil then
			return numeric_value
		end
	elseif type(value) == "number" then
		return value
	end

	if type(to_big) == "function" then
		local ok, parsed = pcall(to_big, value)
		if ok and parsed ~= nil then
			local numeric_value = BALATRO.to_score_number and BALATRO.to_score_number(parsed) or nil
			if numeric_value ~= nil then
				return numeric_value
			end
			if type(parsed) ~= "string" then
				return parsed
			end
		end
	end

	return tonumber(value)
end

local function get_server_preview_target(row)
	if not (MP.GAME and row) then
		return nil
	end

	local preview_key = blind_choice_state.get_preview_key and blind_choice_state.get_preview_key() or nil
	if MP.GAME.coop_blind_preview_key ~= preview_key then
		return nil
	end

	local targets = MP.GAME.coop_blind_preview_targets
	return targets and targets[row] or nil
end

local function send_debounced_coop_blind_preview()
	if not (can_sync_coop_blind_preview() and BALATRO.queue_event) then
		return
	end
	if MP.GAME.coop_blind_preview_send_scheduled then
		return
	end

	MP.GAME.coop_blind_preview_send_scheduled = true
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.05,
		func = function()
			if MP.GAME then
				MP.GAME.coop_blind_preview_send_scheduled = false
			end
			if can_sync_coop_blind_preview() and MP.GAME then
				MP.ACTIONS.blind_preview(
					MP.GAME.local_coop_blind_preview_key,
					MP.GAME.local_coop_blind_preview_targets or {}
				)
			end
			return true
		end,
	})
end

local function record_local_coop_blind_preview(row, target)
	if not (MP.GAME and row and target ~= nil and can_sync_coop_blind_preview()) then
		return
	end

	local preview_key = blind_choice_state.get_preview_key()
	if MP.GAME.local_coop_blind_preview_key ~= preview_key then
		MP.GAME.local_coop_blind_preview_key = preview_key
		MP.GAME.local_coop_blind_preview_targets = {}
	end
	MP.GAME.local_coop_blind_preview_targets[row] = target

	send_debounced_coop_blind_preview()
end

local function is_active_lobby_player(player)
	if not player or player.is_disconnected == true then
		return false
	end
	if player.is_spectator or player.role == "spectator" or player.spectator == true then
		return false
	end
	if MP.is_coop_run and MP.is_coop_run() then
		return true
	end
	return player.is_in_match ~= false
end

local function get_self_lobby_player()
	local self_id = (G and G.MP_ID or nil)
	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.id == self_id then
			return player
		end
	end
	return nil
end

local function get_active_preview_group_players()
	local players = {}
	if not (MP.LOBBY and MP.LOBBY.players) then
		return players
	end

	if (MP.is_coop_lobby_type and MP.is_coop_lobby_type()) or (MP.is_coop_gamemode and MP.is_coop_gamemode()) then
		for _, player in ipairs(MP.LOBBY.players) do
			if is_active_lobby_player(player) then
				players[#players + 1] = player
			end
		end
		return players
	end

	local self_player = get_self_lobby_player()
	for _, player in ipairs(MP.LOBBY.players) do
		if
			is_active_lobby_player(player)
			and MP.lobby_players_share_sync_group
			and MP.lobby_players_share_sync_group(self_player, player)
		then
			players[#players + 1] = player
		end
	end
	return players
end

local function get_current_blind_target_scale()
	local scale = (G and G.GAME and G.GAME.starting_params and G.GAME.starting_params.ante_scaling or nil) or 1
	local paperback = (G and G.GAME and G.GAME["paperback"] or nil)
	if paperback and paperback.blind_multiplier ~= nil then
		scale = scale * paperback.blind_multiplier
	end
	return scale
end

local function sync_local_blind_target_scale(scale)
	if MP.ACTIONS and MP.ACTIONS.sync_blind_target_scale then
		MP.ACTIONS.sync_blind_target_scale(scale)
	end
end


local function get_blind_choice_poker_hands()
	local poker_hands = {}
	if MP.should_use_the_order() then
		return MP.sorted_hand_list()
	end

	for key in pairs((G and G.GAME and G.GAME.hands) or {}) do
		if MP.PLATFORM.SMODS.is_poker_hand_visible(key) then
			poker_hands[#poker_hands + 1] = key
		end
	end
	return poker_hands
end

function blind_choice_state.ensure_orbital_choice_for_blind(type)
	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil)
	local choices = nil
	if G and G.GAME and ante ~= nil then
		G.GAME.orbital_choices = G.GAME.orbital_choices or {}
		G.GAME.orbital_choices[ante] = G.GAME.orbital_choices[ante] or {}
		choices = G.GAME.orbital_choices[ante]
	end
	if not choices then
		return
	end

	if not choices[type] then
		choices[type] = pseudorandom_element(get_blind_choice_poker_hands(), pseudoseed("orbital"))
	end
end

local function build_blind_choice_animation(blind_choice_config, pvp_blind_key, is_pvp_blind)
	local blind_atlas = "blind_chips"
	local blind_pos = blind_choice_config.pos
	if blind_choice_config and blind_choice_config.atlas then
		blind_atlas = blind_choice_config.atlas
	end
	if is_pvp_blind then
		blind_atlas = "mp_player_blind_col"
		local pvp_blind = (G and G.P_BLINDS and G.P_BLINDS[pvp_blind_key]) or nil
		blind_pos = pvp_blind and pvp_blind.pos or blind_pos
	end

	local animation = BALATRO.create_animated_sprite(0, 0, 1.4, 1.4, BALATRO.get_animation_atlas(blind_atlas), blind_pos)
	animation:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})

	return animation
end

local function build_blind_name(blind_choice_config, is_pvp_blind)
	if is_pvp_blind then
		local opponents = MP.OPPONENTS or {}
		local nemesis = opponents.get_nemesis_lobby_player and opponents.get_nemesis_lobby_player() or nil
		return (nemesis and nemesis.username) or NO_NEMESIS_LABEL
	end

	return localize({ type = "name_text", key = blind_choice_config.key, set = "Blind" })
end

local function build_blind_text_table(blind_choice_config, type)
	local loc_target = localize({
		type = "raw_descriptions",
		key = blind_choice_config.key,
		set = "Blind",
		vars = {
			blind_choice_config.key == "bl_ox"
					and localize((G and G.GAME and G.GAME.current_round and G.GAME.current_round["most_played_poker_hand"] or nil), "poker_hands")
				or "",
		},
	})

	if (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[type] or nil) then
		loc_target[#loc_target + 1] = localize("k_bl_mostchips")
	end

	return loc_target
end

local function build_blind_amount(blind_choice_config, type, is_pvp_blind)
	local blind_ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["blind_ante"] or nil)
	local base_blind_amt = BALATRO.get_blind_amount(blind_ante)
		* blind_choice_config.mult
	local local_blind_target_scale = get_current_blind_target_scale()
	sync_local_blind_target_scale(local_blind_target_scale)
	local blind_amt = base_blind_amt * local_blind_target_scale

	if is_pvp_blind or ((G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[type] or nil)) then
		if MP.is_duel_bye_blind_row and MP.is_duel_bye_blind_row(type) then
			local num_fmt = number_format or (type(number_format) == "function" and number_format)
			return num_fmt and num_fmt(blind_amt) or tostring(blind_amt)
		end
		return "????"
	end

	if MP.is_coop_run and MP.is_coop_run() and MP.scale_coop_blind_amount then
		blind_amt = MP.scale_coop_blind_amount(blind_amt, blind_ante, blind_choice_config.mult)
	end

	if can_sync_coop_blind_preview() then
		record_local_coop_blind_preview(type, blind_amt)
		local preview_target = get_server_preview_target(type)
		if preview_target ~= nil then
			return preview_target
		end
	end

	return blind_amt
end

local function get_preview_score_node(row)
	local box = (G and G.blind_select_opts and row and G.blind_select_opts[string.lower(row)] or nil)
	if not (box and box.get_UIE_by_ID) then
		return nil, nil
	end

	return box:get_UIE_by_ID("mp_blind_preview_score_" .. tostring(row)), box
end

function blind_choice_state.refresh_coop_blind_preview_scores()
	for _, row in ipairs(PREVIEW_BLIND_ROWS) do
		local target = get_server_preview_target(row)
		if target ~= nil then
			local score_node, box = get_preview_score_node(row)
			if score_node and score_node.config then
				score_node.config.text = number_format(target)
				score_node.config.scale = score_number_scale(0.9, target)
				BALATRO.recalculate_ui(score_node)
				BALATRO.recalculate_ui(box)
			end
		end
	end
end

function blind_choice_state.handle_coop_blind_preview(preview_key, targets)
	if not MP.GAME then
		return
	end

	local parsed_targets = {}
	if type(targets) == "table" then
		for _, row in ipairs(PREVIEW_BLIND_ROWS) do
			local parsed = parse_preview_target(targets[row])
			if parsed ~= nil then
				parsed_targets[row] = parsed
			end
		end
	end

	MP.GAME.coop_blind_preview_key = tostring(preview_key or "")
	MP.GAME.coop_blind_preview_targets = parsed_targets
	blind_choice_state.refresh_coop_blind_preview_scores()
end

local function get_run_info_colour(run_info, blind_state)
	if not run_info then
		return nil
	end

	return blind_state == "Defeated" and G.C.GREY
		or blind_state == "Skipped" and G.C.BLUE
		or blind_state == "Upcoming" and G.C.ORANGE
		or blind_state == "Current" and G.C.RED
		or G.C.GOLD
end

function blind_choice_state.build_context(type, run_info)
	local blind_key = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[type]) or nil
	local is_pvp_blind = blind_key == "bl_mp_nemesis"
	local uses_pvp_ready_flow = is_pvp_blind or ((G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[type] or nil))
	local uses_duel_ready_flow = MP.is_duel_bye_blind_row and MP.is_duel_bye_blind_row(type)
	local pvp_blind_key = is_pvp_blind and MP.UTILS.get_pvp_blind_key()
	local blind_choice = {
		config = (G and G.P_BLINDS and G.P_BLINDS[blind_key]) or nil,
	}

	blind_choice.animation = build_blind_choice_animation(blind_choice.config, pvp_blind_key, is_pvp_blind)

	blind_choice_state.ensure_orbital_choice_for_blind(type)
	if (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["blind_ante"] or nil) == nil then
		if G and G.GAME and G.GAME.round_resets then
			G.GAME.round_resets["blind_ante"] = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil)
		end
	end

	local blind_state = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states[type]) or nil
	local reward = true
	local no_blind_reward = (G and G.GAME and G.GAME.modifiers and G.GAME.modifiers["no_blind_reward"] or nil)
	if no_blind_reward and no_blind_reward[type] then
		reward = nil
	end
	if blind_state == "Select" then
		blind_state = "Current"
	end

	return {
		row = type,
		blind_choice = blind_choice,
		blind_col = BALATRO.get_blind_main_colour and BALATRO.get_blind_main_colour(type) or nil,
		blind_amt = build_blind_amount(blind_choice.config, type, is_pvp_blind),
		blind_state = blind_state,
		loc_name = build_blind_name(blind_choice.config, is_pvp_blind),
		reward = reward,
		run_info_colour = get_run_info_colour(run_info, blind_state),
		stake_sprite = BALATRO.get_stake_sprite and BALATRO.get_stake_sprite((G and G.GAME and G.GAME.stake or nil) or 1, 0.5) or nil,
		text_table = build_blind_text_table(blind_choice.config, type),
		use_mp_ready_flow = uses_pvp_ready_flow or uses_duel_ready_flow or MP.is_teams_mode() or (MP.is_coop_lobby_type and MP.is_coop_lobby_type()),
	}
end


-- ----------------------------------------------------------------------------
-- SECTION 2: Blind Choice Rows & Match Mode Detection
-- ----------------------------------------------------------------------------
INTERNAL.original_skip_blind = INTERNAL.original_skip_blind or BALATRO.get_ui_function("skip_blind")

function INTERNAL.get_blind_choice_row_type(e)
	local el = e
	for _ = 1, 12 do
		if not el or not el.config then
			break
		end
		local id = el.config.id
		if id == "Small" or id == "Big" or id == "Boss" then
			return id
		end
		el = el.parent
	end
	return nil
end

local BLIND_KIND_BY_ROW = {
	Small = "small",
	Big = "big",
	Boss = "boss",
}

function INTERNAL.get_blind_choice_row_kind_for_row(row)
	local round_resets = (G and G.GAME and G.GAME.round_resets) or nil
	if not row or not round_resets then
		return nil
	end
	local rs = round_resets
	if rs.blind_choices[row] == "bl_mp_nemesis" or rs.pvp_blind_choices[row] then
		return "pvp"
	end
	return BLIND_KIND_BY_ROW[row]
end

function INTERNAL.get_blind_choice_row_kind(e)
	local row = INTERNAL.get_blind_choice_row_type(e)
	if not row then
		return nil
	end
	return INTERNAL.get_blind_choice_row_kind_for_row(row)
end

function INTERNAL.get_match_ready_blind_kind()
	local game = MP and MP.GAME or nil
	if not (game and game.ready_blind) then
		return nil
	end

	return game.ready_blind_kind
end

local function get_match_ready_blind_mode()
	local ready_blind_kind = INTERNAL.get_match_ready_blind_kind and INTERNAL.get_match_ready_blind_kind() or nil
	if ready_blind_kind == "pvp" then
		return "pvp"
	end
	if ready_blind_kind ~= nil then
		return "team"
	end

	return nil
end

function INTERNAL.is_readying_pvp_blind()
	return get_match_ready_blind_mode() == "pvp"
end

function INTERNAL.is_pvp_timer_context()
	if not (MP and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return false
	end
	if INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind() then
		return true
	end

	return not not (MP.GAME and MP.GAME.timer_started)
end

function INTERNAL.is_teams_cooperative_row(row)
	local blind_kind = INTERNAL.get_blind_choice_row_kind_for_row(row)
	return blind_kind == "small" or blind_kind == "big" or blind_kind == "boss"
end

function INTERNAL.is_team_skip_ready_row(row)
	return MP.LOBBY
		and MP.LOBBY.code
		and (
			MP.is_teams_mode()
			or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
		)
		and (row == "Small" or row == "Big")
		and INTERNAL.is_teams_cooperative_row(row)
end


-- ----------------------------------------------------------------------------
-- SECTION 3: Dynamic Text & Font Sizing
-- ----------------------------------------------------------------------------
function INTERNAL.restore_blind_select_label(e, row)
	local label = e and e.children and e.children[1] and e.children[1].config
	local round_resets = (G and G.GAME and G.GAME.round_resets) or nil
	if not label or not row or not round_resets then
		return
	end
	label.ref_table = round_resets.loc_blind_states
	label.ref_value = row
end

function INTERNAL.set_ui_text(node, text)
	if not node or not node.config then
		return
	end

	text = tostring(text or "")
	local current_text = tostring(node.config.text or "")
	if current_text == text then
		return
	end

	node.config.text = text
	node.config.lang = node.config.lang or G.LANG
	if node.config.text_drawable then
		node.config.text_drawable:set(text)
	elseif node.update_text then
		node:update_text()
	end

	if node.T and node.parent then
		local scale = node.config.scale or 1
		local tx = node.config.lang.font.FONT:getWidth(text)
			* node.config.lang.font.squish
			* scale
			* G.TILESCALE
			* node.config.lang.font.FONTSCALE
		local ty = node.config.lang.font.FONT:getHeight()
			* scale
			* G.TILESCALE
			* node.config.lang.font.FONTSCALE
			* node.config.lang.font.TEXT_HEIGHT_SCALE
		if node.config.vert then
			tx, ty = ty, tx
		end

		node.T.w = tx / (G.TILESIZE * G.TILESCALE)
		node.T.h = ty / (G.TILESIZE * G.TILESCALE)
		node.VT.w = node.T.w
		node.VT.h = node.T.h

		local padding = (node.parent.config and node.parent.config.padding) or G.UIT.padding
		node.parent.content_dimensions = node.parent.content_dimensions or {}
		node.parent.content_dimensions.w = node.T.w + 2 * padding
		node.parent.content_dimensions.h = node.T.h + 2 * padding

		if node.role and node.role.offset then
			node.role.offset.x = (node.parent.role and node.parent.role.offset and node.parent.role.offset.x or 0) + padding
			node.role.offset.y = (node.parent.role and node.parent.role.offset and node.parent.role.offset.y or 0) + padding
		end

		node.parent:set_alignments()
		node.parent:initialize_VT()
	end
end


-- ----------------------------------------------------------------------------
-- SECTION 4: Team Ready Voting & Status
-- ----------------------------------------------------------------------------
function INTERNAL.get_team_skip_ready_progress(row)
	local target_location = "loc_ready_to_skip_for_team_row-" .. tostring(row)
	local self_team_id = MP.get_self_team_id and MP.get_self_team_id() or nil
	if not MP.LOBBY or not MP.LOBBY.players then
		return 0, 0
	end
	local use_coop_group = (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
		or (MP.is_coop_gamemode and MP.is_coop_gamemode())
		or (MP.is_coop_run and MP.is_coop_run())
	if not use_coop_group and not self_team_id then
		return 0, 0
	end

	local ready_count = 0
	local total_count = 0
	for _, player in ipairs(MP.LOBBY.players) do
		local is_spec = not not (player.is_spectator or player.role == "spectator" or player.spectator == true)
		local is_active = not is_spec and player.is_disconnected ~= true and (use_coop_group or player.is_in_match ~= false)
		local is_vote_member = is_active and (use_coop_group or (player.team or 1) == self_team_id)
		if is_vote_member then
			total_count = total_count + 1
			if player.id == (G and G.MP_ID or nil) then
				if MP.GAME and (MP.GAME.skip_ready_blind_row == row or MP.GAME.location == target_location) then
					ready_count = ready_count + 1
				end
			else
				local enemy = MP.GAME and MP.GAME.enemies and MP.GAME.enemies[player.id]
				if enemy and enemy.raw_location == target_location then
					ready_count = ready_count + 1
				end
			end
		end
	end

	return ready_count, total_count
end

function INTERNAL.reset_ready_blind_state()
	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
end

function INTERNAL.set_selecting_location()
	MP.ACTIONS.set_location("loc_selecting")
end

function INTERNAL.refresh_timer_hud()
	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

function INTERNAL.finish_unready_blind(was_readying_pvp_blind, reset_location)
	if reset_location then
		INTERNAL.set_selecting_location()
	end
	local is_group_mode = MP.is_group_lobby_type and MP.is_group_lobby_type(MP.LOBBY and MP.LOBBY.lobby_type)
	if was_readying_pvp_blind and not is_group_mode then
		MP.ACTIONS.pause_ante_timer()
	end
	MP.ACTIONS.unready_blind()
end

function INTERNAL.get_ready_blind_location(row)
	local uses_row_ready_location = row
		and (
			(MP.is_teams_mode() and INTERNAL.is_teams_cooperative_row(row))
			or (MP.is_coop_lobby_type and MP.is_coop_lobby_type())
		)
	if uses_row_ready_location then
		return "loc_ready_for_team_row-" .. row
	end
	return "loc_ready"
end

function INTERNAL.clear_skip_ready_state(options)
	local had_skip_ready = not not (MP.GAME and MP.GAME.skip_ready_blind_row)
	if MP.GAME and match_domain.set_skip_ready_blind_row then
		match_domain.set_skip_ready_blind_row(nil)
	end
	if had_skip_ready and options and options.notify_server and MP.ACTIONS and MP.ACTIONS.unready_skip_blind then
		MP.ACTIONS.unready_skip_blind()
	end
end

function INTERNAL.clear_ready_blind_for_skip_toggle()
	if not MP.GAME.ready_blind then
		return
	end
	local was_readying_pvp_blind = INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind()
	INTERNAL.reset_ready_blind_state()
	INTERNAL.finish_unready_blind(was_readying_pvp_blind, false)
	INTERNAL.refresh_timer_hud()
end

function INTERNAL.clear_skip_ready_for_blind_toggle(reset_location)
	if not MP.GAME.skip_ready_blind_row then
		return
	end
	INTERNAL.clear_skip_ready_state({ notify_server = true })
	if reset_location then
		INTERNAL.set_selecting_location()
	end
end


-- ----------------------------------------------------------------------------
-- SECTION 5: Team Skip Execution & Synchronization
-- ----------------------------------------------------------------------------
local function find_skip_button(node)
	if not node then
		return nil
	end
	if node.config and node.config.button == "skip_blind" then
		return node
	end
	local children = node.children
	if not children then
		return nil
	end
	for i = 1, #children do
		local found = find_skip_button(children[i])
		if found then
			return found
		end
	end
	return nil
end

local function find_skip_blind_button(blind_row)
	if not blind_row then
		return nil
	end
	local box = (G and G.blind_select_opts and blind_row and G.blind_select_opts[string.lower(blind_row)] or nil)
	if not box or not box.get_UIE_by_ID then
		return nil
	end
	local tag_container = box:get_UIE_by_ID("tag_container")
	if not tag_container then
		return nil
	end

	return find_skip_button(tag_container)
end

local function normalize_ante(value)
	local ante = tonumber(value)
	if not ante then
		return nil
	end
	return math.floor(ante)
end

local function get_current_ante()
	return normalize_ante((G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil))
end

local function is_current_skip_context(blind_row, ante)
	if ante ~= nil and get_current_ante() ~= normalize_ante(ante) then
		return false
	end
	if (G and G.GAME and G.GAME.blind_on_deck or nil) ~= blind_row then
		return false
	end
	return true
end

function INTERNAL.finish_skip_blind()
	if not MP.LOBBY.code then
		return
	end

	INTERNAL.reset_ready_blind_state()
	INTERNAL.set_selecting_location()
	if
		MP.ANTE_TIMER_RUNTIME
		and MP.ANTE_TIMER_RUNTIME.apply_skip_for_ante
		and not (MP.is_any_layer_active and MP.is_any_layer_active({ "no_animation_timer", "pressure_timer" }))
	then
		MP.ANTE_TIMER_RUNTIME.apply_skip_for_ante(1)
	end
	MP.ACTIONS.skip((G and G.GAME and G.GAME.skips or nil))

	local temp_furthest_blind = 0
	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or nil) or 0
	if (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states["Big"]) == "Skipped" then
		temp_furthest_blind = ante * 10 + 2
	elseif (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states["Small"]) == "Skipped" then
		temp_furthest_blind = ante * 10 + 1
	end

	if match_domain.advance_furthest_blind then
		match_domain.advance_furthest_blind(temp_furthest_blind)
	end

	MP.ACTIONS.set_furthest_blind(MP.GAME.furthest_blind)
end

function INTERNAL.perform_actual_skip(e)
	local skip_blind_ref = INTERNAL.original_skip_blind
	if not skip_blind_ref then
		sendTraceMessage("perform_actual_skip: missing original skip_blind reference", "MULTIPLAYER")
		return false
	end
	skip_blind_ref(e)
	INTERNAL.finish_skip_blind()
	return true
end

local function perform_headless_skip(target_row)
	if not (G and G.GAME) then
		return false
	end

	if type(stop_use) == "function" then
		stop_use()
	end

	local round_resets = G.GAME.round_resets or nil
	local tag_key = round_resets and round_resets.blind_tags and round_resets.blind_tags[target_row] or nil
	if tag_key and type(Tag) == "function" and type(add_tag) == "function" then
		add_tag(Tag(tag_key))
	end

	G.GAME.skips = (G.GAME.skips or 0) + 1
	local skipped = target_row
	local skip_to = (skipped == "Small" and "Big") or "Boss"
	if round_resets and round_resets.blind_states then
		round_resets.blind_states[skipped] = "Skipped"
		round_resets.blind_states[skip_to] = "Select"
	end
	G.GAME.blind_on_deck = skip_to

	if type(play_sound) == "function" then
		play_sound("generic1")
	end

	if G.E_MANAGER and G.E_MANAGER.add_event and type(Event) == "function" then
		G.E_MANAGER:add_event(Event({
			trigger = "immediate",
			func = function()
				if SMODS and SMODS.calculate_context then
					SMODS.calculate_context({ skip_blind = true })
				end
				if type(save_run) == "function" then
					save_run()
				end
				if G.GAME and G.GAME.tags then
					for i = 1, #G.GAME.tags do
						G.GAME.tags[i]:apply_to_run({ type = "immediate" })
					end
					for i = 1, #G.GAME.tags do
						if G.GAME.tags[i]:apply_to_run({ type = "new_blind_choice" }) then
							break
						end
					end
				end
				return true
			end,
		}))
	end

	INTERNAL.finish_skip_blind()
	return true
end

function INTERNAL.perform_team_skip(blind_row, ante)
	local target_row = blind_row or ((G and G.GAME and G.GAME.blind_on_deck or nil))
	if not target_row or not is_current_skip_context(target_row, ante) then
		sendTraceMessage(
			"teamSkipBlind: ignored stale skip for "
				.. tostring(target_row)
				.. " ante "
				.. tostring(ante),
			"MULTIPLAYER"
		)
		return false
	end

	INTERNAL.reset_ready_blind_state()
	if (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states[target_row]) == "Skipped" then
		return true
	end

	local btn = find_skip_blind_button(target_row)
	if btn then
		return INTERNAL.perform_actual_skip(btn)
	end

	return perform_headless_skip(target_row)
end


-- ----------------------------------------------------------------------------
-- SECTION 6: Blind Choice Preview Nodes
-- ----------------------------------------------------------------------------
local function should_show_blind_tag(type, run_info)
	if type ~= "Small" and type ~= "Big" then
		return false
	end

	local blind_state = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states[type]) or nil
	if blind_state == "Skipped" or blind_state == "Defeated" then
		return false
	end

	return true
end

local function create_pvp_extra_text(localization_key, string_colour, text_colours, scale, bump)
	return DynaText({
		string = { { string = localize(localization_key), colour = string_colour } },
		colours = { text_colours },
		scale = scale,
		silent = true,
		pop_delay = 4.5,
		shadow = true,
		bump = bump,
		maxw = 3,
	})
end

local function create_centered_object_row(object)
	return { n = G.UIT.R, config = { align = "cm" }, nodes = { { n = G.UIT.O, config = { object = object } } } }
end

local function create_text_node(text, scale, colour, shadow)
	return {
		n = G.UIT.T,
		config = {
			text = text,
			scale = scale,
			colour = colour,
			shadow = shadow,
		},
	}
end

local function create_pvp_blind_extras()
	return {
		n = G.UIT.R,
		config = { align = "cm" },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.07, r = 0.1, colour = { 0, 0, 0, 0.12 }, minw = 2.9 },
				nodes = {
					create_centered_object_row(create_pvp_extra_text("k_bl_life", G.C.FILTER, G.C.BLACK, 0.55, true)),
					create_centered_object_row(create_pvp_extra_text("k_bl_or", G.C.WHITE, G.C.CHANCE, 0.35, nil)),
					create_centered_object_row(create_pvp_extra_text("k_bl_death", G.C.FILTER, G.C.BLACK, 0.55, true)),
				},
			},
		},
	}
end

function blind_choice_preview.get_blind_choice_extras(type, run_info)
	if
		((G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices[type]) == "bl_mp_nemesis")
		or ((G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.pvp_blind_choices and G.GAME.round_resets.pvp_blind_choices[type] or nil))
	then
		return create_pvp_blind_extras()
	end

	if should_show_blind_tag(type, run_info) then
		return create_UIBox_blind_tag(type, run_info)
	end

	return nil
end

function blind_choice_preview.create_name_node(blind_context)
	return {
		n = G.UIT.R,
		config = { id = "blind_name", align = "cm", padding = 0.07 },
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					r = 0.1,
					outline = 1,
					outline_colour = blind_context.blind_col,
					colour = darken(blind_context.blind_col, 0.3),
					minw = 2.9,
					emboss = 0.1,
					padding = 0.07,
					line_emboss = 1,
				},
				nodes = {
					{
						n = G.UIT.O,
						config = {
							object = DynaText({
								string = blind_context.loc_name,
								colours = { G.C.WHITE },
								shadow = true,
								float = true,
								y_offset = -4,
								scale = 0.45,
								maxw = 2.8,
							}),
						},
					},
				},
			},
		},
	}
end

local function create_blind_description_text(text)
	return create_text_node(text or "-", 0.32, G.C.WHITE, true)
end

local function create_blind_description_row(text, blind_choice)
	local nodes = {}
	if blind_choice then
		nodes[#nodes + 1] = {
			n = G.UIT.T,
			config = {
				id = blind_choice.config.key,
				ref_table = { val = "" },
				ref_value = "val",
				scale = 0.32,
				colour = G.C.WHITE,
				shadow = true,
				func = "HUD_blind_debuff_prefix",
			},
		}
	end
	nodes[#nodes + 1] = create_blind_description_text(text)

	return {
		n = G.UIT.R,
		config = { align = "cm", maxw = 2.8 },
		nodes = nodes,
	}
end

local function create_text_rows(text_table, blind_choice)
	return {
		text_table and text_table[1] and create_blind_description_row(text_table[1], blind_choice) or nil,
		text_table[2] and create_blind_description_row(text_table[2]) or nil,
		text_table[3] and create_blind_description_row(text_table[3]) or nil,
	}
end

function blind_choice_preview.create_details_node(blind_context)
	local blind_choice = blind_context.blind_choice
	local text_table = blind_context.text_table

	return {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			{
				n = G.UIT.R,
				config = { id = "blind_desc", align = "cm", padding = 0.05 },
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm" },
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", minh = 1.5 },
								nodes = {
									{ n = G.UIT.O, config = { object = blind_choice.animation } },
								},
							},
							text_table and text_table[1] and {
								n = G.UIT.R,
								config = {
									align = "cm",
									minh = 0.7,
									padding = 0.05,
									minw = 2.9,
								},
								nodes = create_text_rows(text_table, blind_choice),
							} or nil,
						},
					},
					{
						n = G.UIT.R,
						config = {
							align = "cm",
							r = 0.1,
							padding = 0.05,
							minw = 3.1,
							colour = G.C.BLACK,
							emboss = 0.05,
						},
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "cm", maxw = 3 },
								nodes = {
									create_text_node(
										localize("ph_blind_score_at_least"),
										0.3,
										G.C.WHITE,
										true
									),
								},
							},
							{
								n = G.UIT.R,
								config = { align = "cm", minh = 0.6 },
								nodes = {
									{
										n = G.UIT.O,
										config = {
											w = 0.5,
											h = 0.5,
											colour = G.C.BLUE,
											object = blind_context.stake_sprite,
											hover = true,
											can_collide = false,
										},
									},
									{ n = G.UIT.B, config = { h = 0.1, w = 0.1 } },
									{
										n = G.UIT.T,
										config = {
											id = "mp_blind_preview_score_" .. tostring(blind_context.row or ""),
											text = number_format(blind_context.blind_amt),
											scale = score_number_scale(0.9, blind_context.blind_amt),
											colour = G.C.RED,
											shadow = true,
										},
									},
								},
							},
							blind_context.reward and {
								n = G.UIT.R,
								config = { align = "cm" },
								nodes = {
									create_text_node(
										localize("ph_blind_reward"),
										0.35,
										G.C.WHITE,
										true
									),
									create_text_node(
										string.rep(localize("$"), blind_choice.config.dollars) .. "+",
										0.35,
										G.C.MONEY,
										true
									),
								},
							} or nil,
						},
					},
				},
			},
		},
	}
end


-- ----------------------------------------------------------------------------
-- SECTION 7: Blind Choice Overlay Box Construction
-- ----------------------------------------------------------------------------
local function create_select_blind_button(type, run_info, blind_context)
	if not run_info then
		return {
			n = G.UIT.R,
			config = {
				id = "select_blind_button",
				align = "cm",
				ref_table = blind_context.blind_choice.config,
				colour = G.C.ORANGE,
				minh = 0.6,
				minw = 2.7,
				padding = 0.07,
				r = 0.1,
				shadow = true,
				hover = true,
				one_press = true,
				func = blind_context.use_mp_ready_flow and "pvp_ready_button" or nil,
				button = "select_blind",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						ref_table = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["loc_blind_states"] or {}),
						ref_value = type,
						scale = 0.45,
						colour = G.C.UI.TEXT_LIGHT,
						shadow = true,
					},
				},
			},
		}
	end

	return {
		n = G.UIT.R,
		config = {
			id = "select_blind_button",
			align = "cm",
			ref_table = blind_context.blind_choice.config,
			colour = blind_context.run_info_colour,
			minh = 0.6,
			minw = 2.7,
			padding = 0.07,
			r = 0.1,
			emboss = 0.08,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize(blind_context.blind_state, "blind_states"),
					scale = 0.45,
					colour = G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

function blind_choice_overlay.create_box(type, run_info, blind_context)
	local preview = MP.UI.BLIND_CHOICE_PREVIEW
	local extras = preview and preview.get_blind_choice_extras and preview.get_blind_choice_extras(type, run_info) or nil

	return {
		n = G.UIT.R,
		config = {
			id = type,
			align = "tm",
			func = "blind_choice_handler",
			minh = not run_info and 10 or nil,
			ref_table = { deck = nil, run_info = run_info },
			r = 0.1,
			padding = 0.05,
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
					colour = mix_colours(G.C.BLACK, G.C.L_BLACK, 0.5),
					r = 0.1,
					outline = 1,
					outline_colour = G.C.L_BLACK,
				},
				nodes = {
					{
						n = G.UIT.R,
						config = { align = "cm", padding = 0.2 },
						nodes = {
							create_select_blind_button(type, run_info, blind_context),
						},
					},
					preview and preview.create_name_node and preview.create_name_node(blind_context) or nil,
					preview and preview.create_details_node and preview.create_details_node(blind_context) or nil,
				},
			},
			{
				n = G.UIT.R,
				config = { id = "blind_extras", align = "cm" },
				nodes = {
					extras,
				},
			},
		},
	}
end


-- ----------------------------------------------------------------------------
-- SECTION 8: Button Controllers & Click Callbacks
-- ----------------------------------------------------------------------------
-- All internal row/text/ready/skip modules are defined directly in this file.

local function get_playing_location_for_selection(e, blind_kind)
	if blind_kind == "pvp" then
		return "loc_playing-bl_mp_nemesis"
	end

	local ref_table = e and e.config and e.config.ref_table or nil
	local blind_key = ref_table and (ref_table.key or ref_table.name) or nil
	if blind_key ~= nil and blind_key ~= "" then
		return "loc_playing-" .. blind_key
	end

	return "loc_playing"
end

local function any_other_player_ready()
	local self_id = (G and G.MP_ID or nil)
	for _, player in ipairs((MP.LOBBY and MP.LOBBY.players) or {}) do
		if player and player.id ~= self_id and player.is_ready then
			return true
		end
	end
	return false
end

local function remove_finished_blind_skip_tag(e, row)
	if e.mp_removed_finished_skip_tag == row then
		return
	end

	local blind_state = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states[row]) or nil
	if blind_state ~= "Skipped" and blind_state ~= "Defeated" then
		return
	end

	e.mp_removed_finished_skip_tag = row

	local tag_container = e.UIBox and e.UIBox:get_UIE_by_ID("tag_container")
	if tag_container and tag_container.remove then
		tag_container:remove()
	end
end

BALATRO.set_ui_function("pvp_ready_button", function(e)
	local row = INTERNAL.get_blind_choice_row_type(e)
	local blind_on_deck = (G and G.GAME and G.GAME.blind_on_deck or nil)
	local is_current_row = row and blind_on_deck == row
	if is_current_row then
		e.config.button = "mp_toggle_ready"
		e.config.one_press = false
		e.children[1].config.ref_table = MP.GAME
		e.children[1].config.ref_value = "ready_blind_text"
	else
		INTERNAL.restore_blind_select_label(e, row)
	end
	if is_current_row and e.config.button == "mp_toggle_ready" then
		e.config.colour = (MP.GAME.ready_blind and G.C.GREEN) or G.C.RED
	end
end)

BALATRO.set_ui_function("mp_toggle_ready", function(e)
	sendTraceMessage("Toggling Ready", "MULTIPLAYER")
	local row = INTERNAL.get_blind_choice_row_type(e)
	local blind_kind = INTERNAL.get_blind_choice_row_kind_for_row(row)
	local was_readying_pvp_blind = INTERNAL.is_readying_pvp_blind and INTERNAL.is_readying_pvp_blind()
	if not MP.GAME.ready_blind then
		INTERNAL.clear_skip_ready_for_blind_toggle(false)
	end
	local will_ready = not MP.GAME.ready_blind
	if will_ready and blind_kind == "pvp" then
		MP.GAME.pvp_reached_first = not any_other_player_ready()
	end
	local is_ready = match_domain.set_ready_blind_state and match_domain.set_ready_blind_state(not MP.GAME.ready_blind, blind_kind)

	if is_ready then
		MP.ACTIONS.set_location(INTERNAL.get_ready_blind_location(row))
		MP.ACTIONS.ready_blind(e)
	else
		INTERNAL.finish_unready_blind(was_readying_pvp_blind, true)
	end
	INTERNAL.refresh_timer_hud()
end)

local blind_choice_handler_ref = BALATRO.get_ui_function("blind_choice_handler")
BALATRO.set_ui_function("blind_choice_handler", function(e)
	blind_choice_handler_ref(e)

	if not (G and G.blind_select and G.blind_select.VT and G.blind_select.VT.y < 10) then
		return
	end

	local blind_on_deck = (G and G.GAME and G.GAME.blind_on_deck or nil)
	if not MP.LOBBY.code or not e or not e.config or not blind_on_deck or e.config.ref_table.run_info then
		return
	end

	local row = e.config.id
	if row ~= blind_on_deck then
		INTERNAL.restore_blind_select_label(e, row)
		remove_finished_blind_skip_tag(e, row)
		return
	end

	if not INTERNAL.is_team_skip_ready_row(row) then
		return
	end

	local blind_state = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states and G.GAME.round_resets.blind_states[row]) or nil
	if blind_state ~= "Select" then
		return
	end

	local tag = e.UIBox and e.UIBox:get_UIE_by_ID("tag_" .. row)
	local button = tag and tag.children and tag.children[2]
	if not button or not button.children or not button.children[1] then
		return
	end

	local is_ready = MP.GAME.skip_ready_blind_row == row
	button.config.one_press = false
	button.config.colour = is_ready and G.C.GREEN or G.C.RED
	if is_ready then
		local ready_count, total_count = INTERNAL.get_team_skip_ready_progress(row)
		INTERNAL.set_ui_text(button.children[1], tostring(ready_count) .. "/" .. tostring(total_count))
	else
		INTERNAL.set_ui_text(button.children[1], localize("b_skip_blind"))
	end
	button.children[1].config.colour = G.C.UI.TEXT_LIGHT
	tag.config.outline_colour = adjust_alpha(is_ready and G.C.GREEN or G.C.BLUE, 0.5)
end)

local can_play_ref = BALATRO.get_ui_function("can_play")
BALATRO.set_ui_function("can_play", function(e)
	if ((G and G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or nil) or 0) <= 0 then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
	else
		can_play_ref(e)
	end
end)

local can_open_ref = BALATRO.get_ui_function("can_open")
BALATRO.set_ui_function("can_open", function(e)
	if MP.GAME.ready_blind then
		e.config.colour = G.C.UI.BACKGROUND_INACTIVE
		e.config.button = nil
		return
	end
	can_open_ref(e)
end)

local select_blind_ref = BALATRO.get_ui_function("select_blind")
BALATRO.set_ui_function("select_blind", function(e)
	local selected_blind_kind = INTERNAL.get_blind_choice_row_kind and INTERNAL.get_blind_choice_row_kind(e) or nil
	if match_domain.prepare_blind_selection then
		match_domain.prepare_blind_selection()
	end
	INTERNAL.clear_skip_ready_state({ notify_server = true })
	if teams_domain.reset_round_score_state then
		teams_domain.reset_round_score_state()
	end
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
	-- Blind selection recording happens in spectator_record_hooks.lua
	-- (single source of truth) when G.FUNCS.select_blind itself runs.

	select_blind_ref(e)
	if MP.LOBBY.code then
		local is_cooperative_blind = (teams_domain.is_cooperative_blind and teams_domain.is_cooperative_blind())
			or (MP.is_coop_blind and MP.is_coop_blind())
		if not is_cooperative_blind then
			MP.ACTIONS.play_hand(0, (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets["hands"] or nil))
		end
		MP.ACTIONS.new_round()
		MP.ACTIONS.set_location(get_playing_location_for_selection(e, selected_blind_kind))
		if MP.UI.hide_enemy_location then
			MP.UI.hide_enemy_location()
		end
	end
end)

BALATRO.set_ui_function("skip_blind", function(e)
	local row = INTERNAL.get_blind_choice_row_type(e) or ((G and G.GAME and G.GAME.blind_on_deck or nil))
	-- Skip-blind recording happens in spectator_record_hooks.lua
	-- (single source of truth) when G.FUNCS.skip_blind itself runs.

	if INTERNAL.is_team_skip_ready_row(row) then
		if MP.GAME.skip_ready_blind_row == row then
			INTERNAL.clear_skip_ready_for_blind_toggle(true)
		else
			INTERNAL.clear_ready_blind_for_skip_toggle()
			if match_domain.set_skip_ready_blind_row then
				match_domain.set_skip_ready_blind_row(row)
			end
			MP.ACTIONS.set_location("loc_ready_to_skip_for_team_row-" .. row)
			MP.ACTIONS.ready_skip_blind(row)
		end
		return
	end
	INTERNAL.perform_actual_skip(e)
end)


-- ----------------------------------------------------------------------------
-- SECTION 9: create_UIBox_blind_choice Hook
-- ----------------------------------------------------------------------------
local create_UIBox_blind_choice_ref = create_UIBox_blind_choice


local function ensure_blind_on_deck()
	local blind_on_deck = (G and G.GAME and G.GAME.blind_on_deck or nil)
	if not blind_on_deck then
		blind_on_deck = "Small"
		if G and G.GAME then
			G.GAME.blind_on_deck = blind_on_deck
		end
	end
	if G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states then
		G.GAME.round_resets.blind_states[blind_on_deck] = "Select"
	end
end

---@diagnostic disable-next-line: lowercase-global
function create_UIBox_blind_choice(type, run_info)
	if MP.LOBBY.code then
		type = type or "Small"
		local should_touch_state = not (MP.BLIND_CHOICE_INTERNAL and MP.BLIND_CHOICE_INTERNAL.suppress_state_touch)
		if should_touch_state and not run_info then
			ensure_blind_on_deck()
		end

		local blind_context = blind_choice_state.build_context(type, run_info)
		local overlay = MP.UI.BLIND_CHOICE_OVERLAY
		if overlay and overlay.create_box then
			return overlay.create_box(type, run_info, blind_context)
		end

		return create_UIBox_blind_choice_ref(type, run_info)
	else
		return create_UIBox_blind_choice_ref(type, run_info)
	end
end


return INTERNAL
