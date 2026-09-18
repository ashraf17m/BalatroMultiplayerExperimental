-- Consolidated network_state_apply.lua (absorbs state_apply_runtime.lua)
local network_state_apply = MP.STATE_APPLY or {}
MP.STATE_APPLY = network_state_apply
local state_apply_runtime = MP.STATE_APPLY_RUNTIME or {}
MP.STATE_APPLY_RUNTIME = state_apply_runtime

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local teams_domain = MP.DOMAIN and MP.DOMAIN.TEAMS or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local load_required_domain = MP.UTILS and MP.UTILS.load_required_domain
local load_required_service = MP.UTILS and MP.UTILS.load_required_service
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

-- === State Apply UI & Runtime Effects ===

local function refresh_primary_enemy_view(enemy)
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view(enemy)
	end
end


local function call_state_effect(effect_name, ...)
	local state_effects = MP.UI and MP.UI.STATE_APPLY_EFFECTS or nil
	local effect = state_effects and state_effects[effect_name] or nil
	if type(effect) == "function" then
		return effect(...)
	end
end

local function recalculate_team_state()
	if teams_domain.recalculate_state then
		teams_domain.recalculate_state()
	end
end

local function refresh_player_list(options)
	if
		options
		and options.force_now
		and MP.UI
		and MP.UI.refresh_active_pvp_player_list
		and MP.UI.refresh_active_pvp_player_list()
	then
		return
	end

	if MP.UI and MP.UI.request_player_list_refresh then
		return MP.UI.request_player_list_refresh()
	end
	return false
end

local function request_lobby_main_menu_refresh()
	if MP.UI and MP.UI.request_lobby_main_menu_refresh then
		return MP.UI.request_lobby_main_menu_refresh()
	end
	return false
end

local function request_overlay_menu_close()
	if MP.UI and MP.UI.request_overlay_menu_close then
		return MP.UI.request_overlay_menu_close()
	end
	return false
end

local function request_active_lobby_overlay_refresh()
	if MP.UI and MP.UI.request_lobby_overlay_refresh then
		return MP.UI.request_lobby_overlay_refresh()
	end
	return false
end

local function request_match_lobby_info_refresh()
	if MP.UI and MP.UI.request_match_lobby_info_refresh then
		return MP.UI.request_match_lobby_info_refresh()
	end
	return false
end

local function apply_pvp_timer_score_gate()
	if MP.apply_pvp_timer_score_gate then
		MP.apply_pvp_timer_score_gate()
	end
end

local function restore_skip_timer_bonus_once(skip_delta, total_skips, increment)
	if not (MP.GAME and MP.UI and MP.UI.restore_timer) then
		return
	end

	local normalized_delta = math.max(0, math.floor(tonumber(skip_delta) or 0))
	local normalized_total = math.floor(tonumber(total_skips) or 0)
	if normalized_delta <= 0 or normalized_total <= 0 then
		return
	end

	MP.GAME.timer_skip_bonus_applied_for_skips = MP.GAME.timer_skip_bonus_applied_for_skips or {}
	local seen = MP.GAME.timer_skip_bonus_applied_for_skips
	local first_skip = math.max(1, normalized_total - normalized_delta + 1)

	for skip_count = first_skip, normalized_total do
		if not seen[skip_count] then
			seen[skip_count] = true
			MP.UI.restore_timer(increment)
		end
	end
end

local function apply_enemy_skip_timer_bonus(skip_delta, total_skips)
	if
		(skip_delta or 0) <= 0
		or not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer)
		or not (MP.GAME and MP.GAME.timer)
		or MP.GAME.timer_started
		or MP.GAME.nemesis_timer_started
		or MP.GAME.timer_consumed
		or not (MP.is_any_layer_active and MP.is_any_layer_active({ "no_animation_timer", "pressure_timer" }))
	then
		return
	end

	local increment = tonumber(MP.LOBBY.config.timer_increment_seconds) or 0
	if increment <= 0 then
		return
	end

	restore_skip_timer_bonus_once(skip_delta, total_skips, increment)
end

local function request_group_options_overlay_refresh()
	if MP.UI and MP.UI.request_group_options_overlay_refresh then
		return MP.UI.request_group_options_overlay_refresh()
	end
	return false
end

local function should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	if MP.UI and MP.UI.should_refresh_group_options_for_lobby_type_change then
		return MP.UI.should_refresh_group_options_for_lobby_type_change(previous_lobby_type, lobby_type)
	end

	return previous_lobby_type ~= lobby_type
end

local function refresh_lobby_main_menu_if_needed()
	if (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false) then
		request_lobby_main_menu_refresh()
	end
end

function state_apply_runtime.resolve_enemy_location_text(location)
	return MP.UTILS.resolve_location_text(location)
end

function state_apply_runtime.handle_lobby_snapshot(snapshot_result)
	if not snapshot_result then
		return
	end

	if not snapshot_result.previous_match_in_progress and snapshot_result.match_in_progress and (G and G.OVERLAY_MENU) then
		request_overlay_menu_close()
	end

	if (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false) then
		request_lobby_main_menu_refresh()
		request_active_lobby_overlay_refresh()
	end

	request_match_lobby_info_refresh()

	if should_refresh_group_options_for_lobby_type_change(snapshot_result.previous_lobby_type, snapshot_result.lobby_type) then
		request_group_options_overlay_refresh()
	end

	recalculate_team_state()
	refresh_primary_enemy_view()
	refresh_player_list()

	if MP.UI and MP.UI.refresh_lobby_options_tab then
		MP.UI.refresh_lobby_options_tab()
	end
	if MP.UI and MP.UI.update_coop_blind_curve_demonstration then
		MP.UI.update_coop_blind_curve_demonstration()
	end
end

function state_apply_runtime.handle_lobby_player_joined(snapshot_result)
	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function state_apply_runtime.handle_lobby_player_updated(snapshot_result)
	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function state_apply_runtime.handle_lobby_player_left(snapshot_result)
	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function state_apply_runtime.handle_lobby_type_changed(snapshot_result)
	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function state_apply_runtime.handle_lobby_team_assignment()
	refresh_lobby_main_menu_if_needed()
	request_active_lobby_overlay_refresh()

	recalculate_team_state()
	refresh_primary_enemy_view()
end

function state_apply_runtime.handle_lobby_nemesis_assignments()
	refresh_lobby_main_menu_if_needed()

	refresh_primary_enemy_view()
	request_match_lobby_info_refresh()
end

function state_apply_runtime.handle_local_player_info(update_result)
	if not update_result then
		return
	end

	if update_result.changed then
		call_state_effect("ease_lives", update_result.lives - update_result.previous_lives)
		call_state_effect("log_life_loss_reason", "Life lost", update_result, { log_missing_reason = true })
		if MP.LOBBY.config.no_gold_on_round_loss then
			BALATRO.set_current_blind_dollars(0)
		end
	end

	recalculate_team_state()
	request_match_lobby_info_refresh()
	refresh_player_list()
end

function state_apply_runtime.handle_remote_money_update(money, delta, source_player_id)
	local game = (G and G.GAME) or nil
	if game and (G and G.STAGES and G.STAGE == G.STAGES.RUN or false) then
		local delta_value = tonumber(delta)
		local current_money = MP.get_local_money()
		local diff = money - current_money
		trace_runtime_event("team_money.remote_apply_start", {
			money = money,
			current_money = current_money,
			diff = diff,
			delta = delta,
			source_player_id = source_player_id,
		})
		if diff ~= 0 then
			if match_domain.set_applying_remote_money then
				match_domain.set_applying_remote_money(true)
			end
			local ok, err = pcall(function()
				BALATRO.ease_dollars(diff, true)
			end)
			if match_domain.set_applying_remote_money then
				match_domain.set_applying_remote_money(false)
			end
			if not ok then
				trace_runtime_event("team_money.remote_apply_failed", {
					money = money,
					diff = diff,
					source_player_id = source_player_id,
					error = tostring(err),
				})
				sendWarnMessage("Failed to apply remote money update: " .. tostring(err), "MULTIPLAYER")
				if G and G.GAME then
					G.GAME["dollars"] = money
				end
			end
		end
		trace_runtime_event("team_money.remote_apply_complete", {
			money = money,
			diff = diff,
			delta = delta,
			source_player_id = source_player_id,
		})
	end

	call_state_effect("handle_money_update", money, delta, source_player_id)
end

function state_apply_runtime.handle_enemy_info(update_result)
	if not update_result then
		return
	end

	if update_result.removed_self then
		recalculate_team_state()
		refresh_player_list({ force_now = true })
		return
	end

	if update_result.invalid then
		sendDebugMessage("Invalid score or hands_left", "MULTIPLAYER")
		return
	end

	local enemy = update_result.enemy
	local score = update_result.score

	apply_enemy_skip_timer_bonus(update_result.skip_delta, update_result.skips)
	call_state_effect("ease_enemy_score", enemy, score)

	if update_result.life_lost then
		call_state_effect("log_life_loss_reason", "Enemy life lost", update_result)
		call_state_effect("play_enemy_life_loss_sounds")
	end

	recalculate_team_state()
	refresh_primary_enemy_view(enemy)
	request_match_lobby_info_refresh()
	refresh_player_list({ force_now = true })

	apply_pvp_timer_score_gate()

	call_state_effect("juice_up_pvp_hud")
end

function state_apply_runtime.handle_enemy_location(enemy)
	refresh_primary_enemy_view(enemy)
	if MP.UI and MP.UI.refresh_enemy_location_ui then
		MP.UI.refresh_enemy_location_ui()
	end
	request_match_lobby_info_refresh()
end


-- === Network State Apply Logic ===
local LOBBY_PLAYER_SNAPSHOT_METHODS = {
	"get_local_player_in_match",
	"normalize_player_payload",
}

local LOBBY_DOMAIN_METHODS = {
	"apply_info_snapshot",
	"apply_player_joined",
	"apply_player_updated",
	"apply_player_left",
	"apply_type_changed",
	"get_players",
	"update_player_team",
	"apply_nemesis_assignments",
}

local MATCH_DOMAIN_METHODS = {
	"sync_enemies_from_lobby_snapshot",
	"apply_enemy_team_assignment",
	"apply_local_player_info",
	"apply_remote_money_update",
	"apply_enemy_info",
	"apply_enemy_location",
	"sync_resume_enemies_from_lobby_players",
	"seed_enemies_from_lobby_players",
}

local function to_finite_number(value)
	local numeric_value = tonumber(value)
	if
		not numeric_value
		or numeric_value ~= numeric_value
		or numeric_value == math.huge
		or numeric_value == -math.huge
	then
		return nil
	end
	return numeric_value
end

local lobby_domain = load_required_domain(
	"LOBBY",
	LOBBY_DOMAIN_METHODS,
	"multiplayer/domain/lobby.lua",
	"Multiplayer lobby domain is missing required state-apply methods."
)
if not lobby_domain then
	return nil
end

local match_domain = load_required_domain(
	"MATCH",
	MATCH_DOMAIN_METHODS,
	"multiplayer/domain/match.lua",
	"Multiplayer match domain is missing required state-apply methods."
)
if not match_domain then
	return nil
end

local lobby_player_snapshot = (MP.LOBBY_PLAYER_SNAPSHOT and MP.LOBBY_PLAYER_SNAPSHOT.normalize_player_payload and MP.LOBBY_PLAYER_SNAPSHOT)
	or load_required_service(
		"multiplayer/runtime/lobby_runtime.lua",
		LOBBY_PLAYER_SNAPSHOT_METHODS,
		"Multiplayer lobby player snapshot service is missing.",
		function()
			return MP.LOBBY_PLAYER_SNAPSHOT
		end
	)
if not lobby_player_snapshot then
	return nil
end

function network_state_apply.lobby_info(players, is_host, is_in_game, lobby_type, is_coop_save_restore)
	local lobby_players = players or {}
	local normalized_players = {}

	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local is_saved_restore = not not is_coop_save_restore

	for _, player_wire in ipairs(lobby_players) do
		local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready, is_saved_restore)
		table.insert(normalized_players, player_state)
	end

	local snapshot_result = lobby_domain.apply_info_snapshot({
		lobby_type = lobby_type,
		is_host = is_host,
		is_in_game = is_in_game,
		is_coop_save_restore = is_coop_save_restore,
		players = normalized_players,
	})

	if match_domain.sync_enemies_from_lobby_snapshot then
		local is_spec = (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
			or (MP.is_spectator and MP.is_spectator())
			or (MP.SPECTATOR and MP.SPECTATOR.is_spectator_role)
		local local_player_in_match = is_spec or lobby_player_snapshot.get_local_player_in_match(lobby_players)
		match_domain.sync_enemies_from_lobby_snapshot(
			normalized_players,
			is_in_game,
			local_player_in_match,
			(G and G.MP_ID or nil)
		)
	end

	state_apply_runtime.handle_lobby_snapshot(snapshot_result)
end

function network_state_apply.lobby_player_joined(player_wire)
	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local is_host = MP.LOBBY and MP.LOBBY.is_host or false
	local is_saved_restore = MP.LOBBY and MP.LOBBY.is_saved_coop_restore or false
	local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready, is_saved_restore)
	local snapshot_result = lobby_domain.apply_player_joined(player_state)

	state_apply_runtime.handle_lobby_player_joined(snapshot_result)
end

function network_state_apply.lobby_player_updated(player_wire)
	local uses_lobby_ready = MP.lobby_uses_ready and MP.lobby_uses_ready() or false
	local is_host = MP.LOBBY and MP.LOBBY.is_host or false
	local is_saved_restore = MP.LOBBY and MP.LOBBY.is_saved_coop_restore or false
	local player_state = lobby_player_snapshot.normalize_player_payload(player_wire, is_host, uses_lobby_ready, is_saved_restore)
	local snapshot_result = lobby_domain.apply_player_updated(player_state)

	if match_domain.sync_enemies_from_lobby_snapshot then
		match_domain.sync_enemies_from_lobby_snapshot(
			lobby_domain.get_players(),
			MP.LOBBY and MP.LOBBY.match_in_progress,
			nil,
			(G and G.MP_ID or nil)
		)
	end

	state_apply_runtime.handle_lobby_player_updated(snapshot_result)
end

function network_state_apply.lobby_player_left(player_id, is_host, owner_player_id, assignments)
	local snapshot_result = lobby_domain.apply_player_left(player_id, is_host, owner_player_id, assignments)

	if match_domain.sync_enemies_from_lobby_snapshot then
		match_domain.sync_enemies_from_lobby_snapshot(
			lobby_domain.get_players(),
			MP.LOBBY and MP.LOBBY.match_in_progress,
			nil,
			(G and G.MP_ID or nil)
		)
	end

	state_apply_runtime.handle_lobby_player_left(snapshot_result)
end

function network_state_apply.lobby_type_changed(lobby_type, players)
	local snapshot_result = lobby_domain.apply_type_changed(lobby_type, players)

	if match_domain.sync_enemies_from_lobby_snapshot then
		match_domain.sync_enemies_from_lobby_snapshot(
			lobby_domain.get_players(),
			MP.LOBBY and MP.LOBBY.match_in_progress,
			nil,
			(G and G.MP_ID or nil)
		)
	end

	state_apply_runtime.handle_lobby_type_changed(snapshot_result)
end

function network_state_apply.lobby_player_team(player_id, team_id)
	local updated_player, normalized_team = lobby_domain.update_player_team(player_id, team_id)

	if MP.LOBBY.match_in_progress then
		return
	end

	match_domain.apply_enemy_team_assignment(
		player_id,
		normalized_team,
		updated_player and updated_player.is_in_match
	)

	state_apply_runtime.handle_lobby_team_assignment()
end

function network_state_apply.lobby_nemesis_assignments(assignments)
	local changed = lobby_domain.apply_nemesis_assignments(assignments)

	if not changed then
		return
	end

	state_apply_runtime.handle_lobby_nemesis_assignments()
end

function network_state_apply.player_info(lives, life_loss_reason, previous_lives, team)
	local update_result = match_domain.apply_local_player_info(lives, life_loss_reason, previous_lives, team)
	state_apply_runtime.handle_local_player_info(update_result)
end

function network_state_apply.money_update(money, delta, source_player_id)
	if MP.uses_shared_sync_group() and not MP.is_shared_money_sync_enabled() then
		trace_runtime_event("team_money.update_ignored", {
			reason = "disabled",
			money = money,
			delta = delta,
			source_player_id = source_player_id,
		})
		return
	end

	local update_result
	if money ~= nil then
		update_result = match_domain.apply_remote_money_update(money)
	else
		local delta_value = to_finite_number(delta)
		if not delta_value then
			update_result = { invalid = true }
		else
			local current_money = MP.get_local_money and MP.get_local_money() or 0
			update_result = match_domain.apply_remote_money_update(current_money + delta_value)
		end
	end

	if update_result.invalid then
		trace_runtime_event("team_money.update_invalid", {
			money = money,
			delta = delta,
			source_player_id = source_player_id,
		})
		return
	end

	money = update_result.money

	trace_runtime_event("team_money.update_apply", {
		money = money,
		delta = delta,
		source_player_id = source_player_id,
	})
	state_apply_runtime.handle_remote_money_update(money, delta, source_player_id)
end

function network_state_apply.enemy_info(enemy_info)
	local update_result = match_domain.apply_enemy_info(
		enemy_info,
		(G and G.MP_ID or nil)
	)

	state_apply_runtime.handle_enemy_info(update_result)
end

function network_state_apply.enemy_location(options)
	local player_id = options.playerId
	local username = options.username
	local _, resolved_location = state_apply_runtime.resolve_enemy_location_text(options.location)
	local enemy = match_domain.apply_enemy_location(player_id, username, options.location, resolved_location)

	state_apply_runtime.handle_enemy_location(enemy)
end

function network_state_apply.sync_resume_enemies_from_lobby()
	match_domain.sync_resume_enemies_from_lobby_players(
		MP.LOBBY.players,
		(G and G.MP_ID or nil)
	)
end

function network_state_apply.seed_match_enemies_from_lobby()
	match_domain.seed_enemies_from_lobby_players(
		MP.LOBBY.players,
		(G and G.MP_ID or nil)
	)
end



return network_state_apply
