MP.COOP_BOSS_BLIND = MP.COOP_BOSS_BLIND or {}

local coop_boss = MP.COOP_BOSS_BLIND
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local state = coop_boss.state or {}
coop_boss.state = state

state.last_ante = state.last_ante
state.last_boss_key = state.last_boss_key
state.last_start_revision = state.last_start_revision or 0
state.last_result_revision = state.last_result_revision or 0
state.pending_results = state.pending_results or {}
state.pending_mirror_starts = state.pending_mirror_starts or {}
state.consumed_reroll_keys = state.consumed_reroll_keys or {}
state.remote_mirror_active = state.remote_mirror_active or false
state.remote_mirror_generated = state.remote_mirror_generated or false
state.applying_remote = state.applying_remote or false
state.reroll_hook_original = state.reroll_hook_original
state.reroll_hook_wrapper = state.reroll_hook_wrapper

local function reset_match_state()
	state.last_ante = nil
	state.last_boss_key = nil
	state.last_start_revision = 0
	state.last_result_revision = 0
	state.pending_results = {}
	state.pending_mirror_starts = {}
	state.consumed_reroll_keys = {}
	state.remote_mirror_active = false
	state.remote_mirror_generated = false
	state.remote_mirror_ante = nil
	state.remote_mirror_revision = nil
	state.applying_remote = false
	if G and G.CONTROLLER and G.CONTROLLER.locks then
		G.CONTROLLER.locks.boss_reroll = nil
	end
end

local function trace(message)
	if sendTraceMessage then
		sendTraceMessage(tostring(message), "MULTIPLAYER")
	end
end

local function warn(message)
	if sendWarnMessage then
		sendWarnMessage(tostring(message), "MULTIPLAYER")
	end
end

local function get_player_id()
	return BALATRO.get_player_id and BALATRO.get_player_id() or nil
end

local function is_same_seed_coop_enabled()
	return MP.LOBBY
		and MP.LOBBY.code
		and MP.LOBBY.config
		and MP.LOBBY.config.different_seeds ~= true
		and MP.is_coop_lobby_type
		and MP.is_coop_lobby_type()
		and MP.ACTIONS
		and MP.ACTIONS.coop_boss_blind
		and not (BALATRO.is_game_over_or_win and BALATRO.is_game_over_or_win())
end

local function get_current_ante()
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	local ante = round_resets and (round_resets.ante or round_resets.blind_ante) or nil
	return tonumber(ante)
end

local function is_blind_select_state()
	local states = BALATRO.get_states and BALATRO.get_states() or nil
	return states and BALATRO.get_state and BALATRO.get_state() == states.BLIND_SELECT
end

local function is_current_ante(ante)
	local current_ante = get_current_ante()
	return current_ante ~= nil and tonumber(ante) == current_ante
end

local function is_safe_boss_sync_context(ante)
	return is_current_ante(ante)
		and is_blind_select_state()
		and G
		and G.blind_select_opts
		and G.blind_select_opts.boss
		and BALATRO.get_blind_on_deck
		and BALATRO.get_blind_on_deck() ~= nil
end

local function get_current_boss_key()
	return BALATRO.get_blind_choice and BALATRO.get_blind_choice("Boss") or nil
end

local function is_valid_local_boss_key(boss_key)
	return boss_key
		and boss_key ~= ""
		and BALATRO.get_blind_def
		and BALATRO.get_blind_def(boss_key) ~= nil
end

local function record_local_boss(ante, boss_key)
	state.last_ante = tonumber(ante)
	state.last_boss_key = boss_key
end

local function send_boss_result(ante, boss_key)
	if is_same_seed_coop_enabled() and boss_key then
		MP.ACTIONS.coop_boss_blind("result", ante, boss_key)
	end
end

local function send_reroll_start()
	local ante = get_current_ante()
	if is_same_seed_coop_enabled() and ante then
		MP.ACTIONS.coop_boss_blind("start", ante)
	end
end

local function refresh_coop_preview_scores()
	local blind_choice_state = MP.UI and MP.UI.BLIND_CHOICE_STATE or nil
	if blind_choice_state and blind_choice_state.refresh_coop_blind_preview_scores then
		blind_choice_state.refresh_coop_blind_preview_scores()
	end
end

local function refresh_boss_button()
	if G and G.blind_select_opts and G.blind_select_opts.boss and G.FUNCS and G.FUNCS.reroll_boss_button then
		local boss_button = G.blind_select_opts.boss:get_UIE_by_ID("reroll_boss_button")
		if boss_button then
			pcall(G.FUNCS.reroll_boss_button, boss_button)
		end
	end
end

local function rebuild_boss_choice_ui()
	if not (G and G.blind_select_opts and G.blind_select_opts.boss) then
		return false
	end
	if not (UIBox and UIBox_dyn_container and create_UIBox_blind_choice and get_blind_main_colour) then
		return false
	end

	local ok = pcall(function()
		local old_box = G.blind_select_opts.boss
		local parent = old_box.parent
		if not parent then
			return
		end

		local blind_choice_internal = MP.BLIND_CHOICE_INTERNAL
		local previous_suppression = blind_choice_internal and blind_choice_internal.suppress_state_touch or nil
		if blind_choice_internal then
			blind_choice_internal.suppress_state_touch = true
		end

		local ok_inner, err_inner = xpcall(function()
			old_box:remove()
			G.blind_select_opts.boss = UIBox({
				T = { parent.T.x, 0, 0, 0 },
				definition = {
					n = G.UIT.ROOT,
					config = { align = "cm", colour = G.C.CLEAR },
					nodes = {
						UIBox_dyn_container(
							{ create_UIBox_blind_choice("Boss") },
							false,
							get_blind_main_colour("Boss"),
							mix_colours(G.C.BLACK, get_blind_main_colour("Boss"), 0.8)
						),
					},
				},
				config = {
					align = "bmi",
					offset = { x = 0, y = G.ROOM.T.y + 9 },
					major = parent,
					xy_bond = "Weak",
				},
			})
			parent.config.object = G.blind_select_opts.boss
			parent.config.object:recalculate()
			G.blind_select_opts.boss.parent = parent
			G.blind_select_opts.boss.alignment.offset.y = 0
		end, function(err)
			return err
		end)

		if blind_choice_internal then
			blind_choice_internal.suppress_state_touch = previous_suppression
		end
		if not ok_inner then
			error(err_inner)
		end
	end)

	if not ok then
		trace("Failed to rebuild co-op boss blind UI.")
	end

	refresh_boss_button()
	refresh_coop_preview_scores()
	return ok
end

local function adjust_boss_usage(previous_key, next_key)
	if previous_key == next_key or not (G and G.GAME and G.GAME.bosses_used) then
		return
	end

	if previous_key and G.GAME.bosses_used[previous_key] then
		G.GAME.bosses_used[previous_key] = math.max(0, G.GAME.bosses_used[previous_key] - 1)
	end
	if next_key then
		G.GAME.bosses_used[next_key] = (G.GAME.bosses_used[next_key] or 0) + 1
	end
end

local function increment_boss_usage(boss_key)
	if boss_key and G and G.GAME and G.GAME.bosses_used then
		G.GAME.bosses_used[boss_key] = (G.GAME.bosses_used[boss_key] or 0) + 1
	end
end

local function set_boss_choice(boss_key)
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	if not (round_resets and round_resets.blind_choices and boss_key) then
		return false
	end

	round_resets.blind_choices.Boss = boss_key
	return true
end

local function clear_local_boss_ready()
	if not (MP.GAME and MP.GAME.ready_blind) then
		return
	end

	local location = tostring(MP.GAME.location or "")
	local is_boss_ready = MP.GAME.ready_blind_kind == "boss" or location == "loc_ready_for_team_row-Boss"
	if not is_boss_ready then
		return
	end

	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
	if match_domain.clear_next_blind_context then
		match_domain.clear_next_blind_context()
	end
	if MP.ACTIONS and MP.ACTIONS.set_location then
		MP.ACTIONS.set_location("loc_selecting")
	end
	if MP.UI and MP.UI.refresh_timer_hud_binding then
		MP.UI.refresh_timer_hud_binding()
	end
end

local function take_consumed_reroll_key(revision)
	local revision_number = tonumber(revision)
	if not revision_number then
		return nil
	end

	local consumed = state.consumed_reroll_keys[revision_number]
	state.consumed_reroll_keys[revision_number] = nil
	return consumed
end

local function apply_authoritative_result(ante, boss_key, revision, options)
	if not is_valid_local_boss_key(boss_key) then
		warn("Ignored unknown co-op boss blind: " .. tostring(boss_key))
		return false
	end

	options = options or {}
	local current_key = get_current_boss_key()
	state.applying_remote = true
	if options.reroll and not options.self_source then
		local consumed_key = options.consumed_key
		if consumed_key then
			adjust_boss_usage(consumed_key, boss_key)
		else
			increment_boss_usage(boss_key)
		end
	elseif current_key ~= boss_key then
		adjust_boss_usage(current_key, boss_key)
	end
	if current_key ~= boss_key then
		set_boss_choice(boss_key)
		rebuild_boss_choice_ui()
	end
	state.applying_remote = false

	record_local_boss(ante, boss_key)
	if revision then
		state.last_result_revision = math.max(state.last_result_revision or 0, tonumber(revision) or 0)
	end
	if options.save and save_run then
		pcall(save_run)
	end
	refresh_coop_preview_scores()
	return true
end

local function queue_pending_result(result)
	local revision = tonumber(result and result.revision)
	if not revision then
		return
	end
	state.pending_results[revision] = result
end

local function get_pending_authoritative_result(ante, revision)
	local pending = state.pending_results[tonumber(revision)]
	if pending and tonumber(pending.ante) == tonumber(ante) and pending.boss_key then
		state.pending_results[tonumber(revision)] = nil
		return pending
	end
	return nil
end

local function apply_pending_result_for_current_ante()
	local ante = get_current_ante()
	if not (ante and is_safe_boss_sync_context(ante)) then
		return false
	end

	local best_revision = nil
	local best_result = nil
	for revision, result in pairs(state.pending_results or {}) do
		local revision_number = tonumber(revision) or tonumber(result and result.revision) or 0
		if
			result
			and tonumber(result.ante) == ante
			and result.boss_key
			and revision_number > (state.last_result_revision or 0)
			and (not best_revision or revision_number > best_revision)
		then
			best_revision = revision_number
			best_result = result
		end
	end
	if not best_result then
		return false
	end

	state.pending_results[best_revision] = nil
	return apply_authoritative_result(ante, best_result.boss_key, best_revision, {
		reroll = best_result.is_reroll,
		self_source = best_result.self_source,
		consumed_key = take_consumed_reroll_key(best_revision),
		save = best_result.is_reroll and not best_result.self_source,
	})
end

local start_remote_mirror_reroll

local function finish_remote_mirror_after_unlock()
	state.remote_mirror_active = false
	state.remote_mirror_generated = false
	state.remote_mirror_ante = nil
	state.remote_mirror_revision = nil
	local next_start = table.remove(state.pending_mirror_starts, 1)
	if next_start then
		start_remote_mirror_reroll(next_start.ante, next_start.revision)
	end
end

local function complete_remote_mirror_reroll()
	local ante = state.remote_mirror_ante or get_current_ante()
	local revision = state.remote_mirror_revision
	local consumed_key = nil
	if type(get_new_boss) == "function" then
		consumed_key = get_new_boss()
		local revision_number = tonumber(revision)
		if consumed_key and revision_number then
			state.consumed_reroll_keys[revision_number] = consumed_key
		end
	end

	local pending = get_pending_authoritative_result(ante, revision)
	if pending and not is_valid_local_boss_key(pending.boss_key) then
		warn("Ignored unknown co-op boss blind: " .. tostring(pending.boss_key))
		pending = nil
	end

	state.remote_mirror_generated = true
	if pending then
		apply_authoritative_result(ante, pending.boss_key, revision, {
			reroll = true,
			consumed_key = take_consumed_reroll_key(revision) or consumed_key,
			save = true,
		})
	else
		rebuild_boss_choice_ui()
	end
	refresh_coop_preview_scores()
end

function start_remote_mirror_reroll(ante, revision)
	if state.remote_mirror_active then
		state.pending_mirror_starts[#state.pending_mirror_starts + 1] = {
			ante = tonumber(ante),
			revision = tonumber(revision) or 0,
		}
		return
	end

	clear_local_boss_ready()
	state.remote_mirror_active = true
	state.remote_mirror_generated = false
	state.remote_mirror_ante = tonumber(ante)
	state.remote_mirror_revision = tonumber(revision) or 0

	if G and G.GAME and G.GAME.round_resets then
		G.GAME.round_resets.boss_rerolled = true
	end

	if not (G and G.blind_select_opts and G.blind_select_opts.boss and BALATRO.queue_event) then
		complete_remote_mirror_reroll()
		finish_remote_mirror_after_unlock()
		return
	end

	if stop_use then
		pcall(stop_use)
	end
	if G.CONTROLLER and G.CONTROLLER.locks then
		G.CONTROLLER.locks.boss_reroll = true
	end

	BALATRO.queue_event({
		trigger = "immediate",
		func = function()
			if BALATRO.play_sound then
				BALATRO.play_sound("other1")
			elseif play_sound then
				play_sound("other1")
			end
			if G.blind_select_opts and G.blind_select_opts.boss then
				G.blind_select_opts.boss:set_role({ xy_bond = "Weak" })
				G.blind_select_opts.boss.alignment.offset.y = 20
			end
			return true
		end,
	})

	BALATRO.queue_event({
		trigger = "after",
		delay = 0.3,
		func = function()
			complete_remote_mirror_reroll()
			BALATRO.queue_event({
				blocking = false,
				trigger = "after",
				delay = 0.5,
				func = function()
					if G.CONTROLLER and G.CONTROLLER.locks then
						G.CONTROLLER.locks.boss_reroll = nil
					end
					finish_remote_mirror_after_unlock()
					return true
				end,
			})
			return true
		end,
	})
end

local function should_announce_local_reroll()
	return is_same_seed_coop_enabled()
		and not state.remote_mirror_active
		and not state.applying_remote
end

function coop_boss.ensure_reroll_hook()
	if not (G and G.FUNCS and type(G.FUNCS.reroll_boss) == "function") then
		return false
	end

	if G.FUNCS.reroll_boss == state.reroll_hook_wrapper then
		return true
	end

	state.reroll_hook_original = G.FUNCS.reroll_boss
	state.reroll_hook_wrapper = function(...)
		if should_announce_local_reroll() then
			send_reroll_start()
		end
		return state.reroll_hook_original(...)
	end
	G.FUNCS.reroll_boss = state.reroll_hook_wrapper
	return true
end

function coop_boss.observe_current_boss()
	if not is_same_seed_coop_enabled() then
		state.last_ante = nil
		state.last_boss_key = nil
		return
	end

	local ante = get_current_ante()
	local boss_key = get_current_boss_key()
	if not (ante and boss_key and is_valid_local_boss_key(boss_key)) then
		return
	end
	if not is_safe_boss_sync_context(ante) then
		return
	end

	if state.last_ante == ante and state.last_boss_key == boss_key then
		return
	end

	record_local_boss(ante, boss_key)
	if not state.remote_mirror_active and not state.applying_remote then
		send_boss_result(ante, boss_key)
	end
end

function coop_boss.handle_server_update(update)
	if not is_same_seed_coop_enabled() or type(update) ~= "table" then
		return
	end

	local phase = update.phase
	local ante = tonumber(update.ante)
	local revision = tonumber(update.revision) or 0
	local source_player_id = update.source_player_id
	local boss_key = update.boss_key
	local is_reroll = update.is_reroll == true
	local is_self_source = source_player_id ~= nil and source_player_id == get_player_id()

	if not ante then
		return
	end

	if phase == "start" then
		if revision <= (state.last_start_revision or 0) then
			return
		end
		state.last_start_revision = revision
		clear_local_boss_ready()
		if not is_self_source then
			start_remote_mirror_reroll(ante, revision)
		end
		return
	end

	if phase ~= "result" or not boss_key then
		return
	end
	if revision <= (state.last_result_revision or 0) then
		return
	end

	if state.remote_mirror_active and tonumber(state.remote_mirror_ante) == ante then
		queue_pending_result({
			ante = ante,
			revision = revision,
			boss_key = boss_key,
			is_reroll = is_reroll,
			self_source = is_self_source,
		})
		if state.remote_mirror_generated then
			state.pending_results[revision] = nil
			if is_safe_boss_sync_context(ante) then
				apply_authoritative_result(ante, boss_key, revision, {
					reroll = is_reroll,
					self_source = is_self_source,
					consumed_key = take_consumed_reroll_key(revision),
					save = is_reroll and not is_self_source,
				})
			else
				queue_pending_result({
					ante = ante,
					revision = revision,
					boss_key = boss_key,
					is_reroll = is_reroll,
					self_source = is_self_source,
				})
			end
		end
		return
	end

	for _, queued_start in ipairs(state.pending_mirror_starts) do
		if tonumber(queued_start.revision) == revision then
			queue_pending_result({
				ante = ante,
				revision = revision,
				boss_key = boss_key,
				is_reroll = is_reroll,
				self_source = is_self_source,
			})
			return
		end
	end

	if not is_safe_boss_sync_context(ante) then
		queue_pending_result({
			ante = ante,
			revision = revision,
			boss_key = boss_key,
			is_reroll = is_reroll,
			self_source = is_self_source,
		})
		return
	end

	apply_authoritative_result(ante, boss_key, revision, {
		reroll = is_reroll,
		self_source = is_self_source,
		consumed_key = take_consumed_reroll_key(revision),
		save = is_reroll and not is_self_source,
	})
end

function coop_boss.update()
	coop_boss.ensure_reroll_hook()
	coop_boss.observe_current_boss()
	apply_pending_result_for_current_ante()
end

function coop_boss.reset_runtime()
	reset_match_state()
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.runtime.coop_boss_blind", coop_boss.update, 35)
end

return coop_boss
