MP.LOCAL_TIMER_RUNTIME = MP.LOCAL_TIMER_RUNTIME or {}
MP.UI = MP.UI or {}

local local_timer_runtime = MP.LOCAL_TIMER_RUNTIME
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local ANIMATION_BUDGET_CAPACITY = 40
local ANIMATION_BUDGET_RESTORE_RATE = 2.5
local ANIMATION_BUDGET_DECAY_RATE = 0

MP.TIMER_ANIMATION_BUDGET = MP.TIMER_ANIMATION_BUDGET or ANIMATION_BUDGET_CAPACITY

local function local_timer_context_enabled()
	if not (MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config and MP.LOBBY.config.timer) then
		return false
	end
	if MP.is_ruleset_active and MP.is_ruleset_active("speedlatro") then
		return false
	end
	return MP.timer_is_local and MP.timer_is_local()
end

local function get_wall_delta()
	local now = BALATRO.get_wall_time and BALATRO.get_wall_time() or 0
	local previous = MP.TIMER_CLOCK or now
	MP.TIMER_CLOCK = now
	return math.max(0, now - previous)
end

local function is_state(state_name)
	local states = BALATRO.get_states and BALATRO.get_states() or nil
	return states and BALATRO.get_state and BALATRO.get_state() == states[state_name]
end

local function should_tick_timer()
	local is_pvp_boss = MP.is_pvp_boss and MP.is_pvp_boss()
	local is_pvp_timer = is_pvp_boss and MP.is_layer_active and MP.is_layer_active("pvp_timer")
	local is_pressure_timer = MP.is_layer_active and MP.is_layer_active("pressure_timer")
	local is_no_animation_timer = MP.is_layer_active and MP.is_layer_active("no_animation_timer")

	if is_pvp_timer then
		if not MP.GAME.nemesis_timer_started then
			return false, true, false
		end
		if (BALATRO.get_hands_left and BALATRO.get_hands_left() or 0) <= 0 then
			return false, true, false
		end
		if is_state("NEW_ROUND") or is_state("ROUND_EVAL") then
			return false, true, false
		end
		return true, true, true
	end

	if is_pressure_timer then
		if MP.GAME.pvp_reached and not MP.GAME.nemesis_timer_started then
			return false, true, false
		end
		if MP.GAME.ready_blind or is_pvp_boss then
			return false, true, false
		end
		return true, true, false
	end

	if is_no_animation_timer then
		if not MP.GAME.nemesis_timer_started then
			return false, true, false
		end
		if MP.GAME.ready_blind or is_pvp_boss then
			return false, true, false
		end
		return true, true, false
	end

	return false, false, false
end

local function animation_budget_allows_tick(timer_dt)
	MP.TIMER_FORCE_GAMESPEED = true

	local controller = G and G.CONTROLLER or nil
	local locked = controller and controller.locked and not (controller.locks and controller.locks.frame)
	local stop_use_active = G and G.GAME and (G.GAME.STOP_USE or 0) > 0
	local interactive = not (locked or stop_use_active)
	local menu_or_paused = G and (G.OVERLAY_MENU or (G.SETTINGS and G.SETTINGS.paused))

	if interactive or menu_or_paused then
		return true
	end

	MP.TIMER_ANIMATION_BUDGET = math.max(
		0,
		MP.TIMER_ANIMATION_BUDGET - timer_dt * (ANIMATION_BUDGET_RESTORE_RATE + ANIMATION_BUDGET_DECAY_RATE)
	)
	return MP.TIMER_ANIMATION_BUDGET <= 0
end

local function consume_expired_timer(is_pvp_timer)
	MP.GAME.timer_consumed = true
	if is_pvp_timer then
		if MP.GAME.nemesis_timer_started and MP.ACTIONS and MP.ACTIONS.fail_pvp_timer then
			MP.ACTIONS.fail_pvp_timer()
		end
		return
	end

	if not (MP.is_layer_active and MP.is_layer_active("pressure_timer")) and not MP.GAME.nemesis_timer_started then
		return
	end

	local forgiveness = tonumber(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer_forgiveness) or 0
	MP.GAME.timers_forgiven = tonumber(MP.GAME.timers_forgiven) or 0
	if MP.GAME.timers_forgiven < forgiveness then
		MP.GAME.timers_forgiven = MP.GAME.timers_forgiven + 1
	elseif MP.ACTIONS and MP.ACTIONS.fail_timer then
		MP.ACTIONS.fail_timer()
	end
end

function local_timer_runtime.update()
	local timer_dt = get_wall_delta()
	MP.TIMER_FORCE_GAMESPEED = false
	MP.TIMER_ANIMATION_BUDGET = math.min(
		ANIMATION_BUDGET_CAPACITY,
		(MP.TIMER_ANIMATION_BUDGET or ANIMATION_BUDGET_CAPACITY) + timer_dt * ANIMATION_BUDGET_RESTORE_RATE
	)

	if not (MP.GAME and local_timer_context_enabled()) then
		return
	end
	if BALATRO.is_game_over_or_win and BALATRO.is_game_over_or_win() then
		return
	end
	if MP.GAME.timer_consumed or not MP.GAME.timer or MP.GAME.timer <= 0 then
		return
	end

	local should_tick, check_animations, is_pvp_timer = should_tick_timer()
	if not should_tick then
		return
	end
	if check_animations and not animation_budget_allows_tick(timer_dt) then
		return
	end

	local speedup = is_pvp_timer and 1
		or (MP.current_ruleset and MP.current_ruleset().timer_speedup_multiplier)
		or 1
	local tick_mult = MP.GAME.nemesis_timer_started and speedup or 1
	MP.GAME.timer = math.max(0, (tonumber(MP.GAME.timer) or 0) - timer_dt * tick_mult)

	if MP.GAME.timer <= 0 then
		MP.GAME.timer = 0
		consume_expired_timer(is_pvp_timer)
	end
end

local function juice_timer_ui()
	local timer_ui = BALATRO.get_hud_element_by_id and BALATRO.get_hud_element_by_id("timer_UI_count") or nil
	local object = timer_ui and timer_ui.config and timer_ui.config.object or nil
	if object and object.juice_up then
		object:juice_up()
	end
end

function MP.UI.consume_timer(amount, silent, min_timer)
	amount = tonumber(amount) or 0
	if amount <= 0 or not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer and MP.GAME and MP.GAME.timer) then
		return false
	end
	if MP.GAME.timer <= (tonumber(min_timer) or 0) then
		return false
	end

	MP.GAME.timer = math.max(0, MP.GAME.timer - amount)
	if not silent then
		juice_timer_ui()
	end
	return true
end

function MP.UI.restore_timer(amount, silent, max_timer)
	amount = tonumber(amount) or 0
	if amount <= 0 or not (MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer and MP.GAME and MP.GAME.timer) then
		return false
	end
	if max_timer and MP.GAME.timer >= max_timer then
		return false
	end

	MP.GAME.timer = math.max(0, MP.GAME.timer + amount)
	if not silent then
		juice_timer_ui()
	end
	return true
end

local function restore_hand_played_time()
	if not (MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config and MP.LOBBY.config.timer and MP.GAME) then
		return
	end
	if MP.GAME.timer_consumed then
		return
	end
	if G and G.play and G.play.cards and G.play.cards[1] then
		return
	end

	if MP.is_pvp_boss and MP.is_pvp_boss() then
		if MP.is_layer_active and MP.is_layer_active("pvp_timer") then
			local increment = MP.LOBBY.config.pvp_timer_hand_played_increment_seconds
				or (MP.current_ruleset and MP.current_ruleset().pvp_timer_hand_played_increment_seconds)
				or 0
			MP.UI.restore_timer(increment)
		end
	elseif MP.is_any_layer_active and MP.is_any_layer_active({ "no_animation_timer", "pressure_timer" }) then
		local increment = MP.LOBBY.config.timer_hand_played_increment_seconds
			or (MP.current_ruleset and MP.current_ruleset().timer_hand_played_increment_seconds)
			or 0
		MP.UI.restore_timer(increment)
	end
end

if MP.HOOKS and MP.HOOKS.register_method_hook and G and G.FUNCS and G.FUNCS.play_cards_from_highlighted then
	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "play_cards_from_highlighted", "mp.local_timer.restore_hand_time", {
		after = function()
			restore_hand_played_time()
		end,
	})
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.runtime.local_timer_runtime", local_timer_runtime.update, 30)
end

trace_runtime_event("local_timer_runtime.loaded", {})

return local_timer_runtime
