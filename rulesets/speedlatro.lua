local RULESET_KEY = "speedlatro"
local BASE_TIMER_SECONDS = 147
local PVP_BLIND_TIMER_SECONDS = BASE_TIMER_SECONDS / 2
local NORMAL_TIMER_MULTIPLIER = 1
local STARTED_NON_PVP_TIMER_MULTIPLIER = 2
local HUD_TIMER_SENTINEL = 999
local DISPLAY_DECIMAL_PADDING_SECONDS = 100
local DISPLAY_DECIMAL_SCALE = 100

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

MP.inject_custom_standard_ruleset(RULESET_KEY, 6, "k_speedlatro_description", {
	forced_gamemode = "gamemode_mp_attrition",
	forced_gamemode_text = "k_attrition",
})

local function is_readying_pvp_blind()
	local blind_choice = MP.BLIND_CHOICE_INTERNAL or {}
	return blind_choice.is_readying_pvp_blind and blind_choice.is_readying_pvp_blind()
end

local function create_speedlatro_timer_ui(timer)
	timer.text = UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = G.C.CLEAR, padding = 0.2 },
			nodes = {
				{
					n = G.UIT.R,
					config = { align = "cm", maxw = 1 },
					nodes = {
						{
							n = G.UIT.O,
							config = {
								object = DynaText({
									scale = 1.1,
									string = { { ref_table = timer, ref_value = "display" } },
									maxw = 18,
									colours = { G.C.WHITE },
									float = true,
									shadow = true,
									silent = true,
									pop_in = 0,
									pop_in_rate = 6,
								}),
							},
						},
					},
				},
			},
		},
		config = {
			align = "cm",
			offset = { x = 0.3, y = -2.9 },
			major = G.deck,
		},
	})
end

local function ensure_speedlatro_timer(create_ui)
	if not MP.speedlatro_timer then
		MP.speedlatro_timer = { real = BASE_TIMER_SECONDS, display = BASE_TIMER_SECONDS }
	end

	if create_ui and not MP.speedlatro_timer.text then
		create_speedlatro_timer_ui(MP.speedlatro_timer)
	end

	return MP.speedlatro_timer
end

local function remove_speedlatro_timer()
	if MP.speedlatro_timer and MP.speedlatro_timer.text then
		MP.speedlatro_timer.text:remove()
	end

	MP.speedlatro_timer = nil
end

local function is_speedlatro_run_active()
	return MP.is_ruleset_active(RULESET_KEY) and G.STAGE == G.STAGES.RUN
end

local function is_waiting_for_last_pvp_hand_resolution()
	return (
		G.STATE == G.STATES.HAND_PLAYED
		and G.GAME.current_round.hands_left < 1
		and G.STATE_COMPLETE
		and MP.LOBBY.client.connected
		and MP.LOBBY.code
		and MP.is_pvp_boss()
	)
end

local function is_pvp_blind_entry_locked()
	return G.CONTROLLER.locks.enter_pvp or is_readying_pvp_blind()
end

local function should_tick_speedlatro_timer()
	return not is_waiting_for_last_pvp_hand_resolution() and not is_pvp_blind_entry_locked()
end

local function get_speedlatro_timer_multiplier()
	if MP.GAME.timer_started and not MP.is_pvp_boss() then
		return STARTED_NON_PVP_TIMER_MULTIPLIER
	end

	return NORMAL_TIMER_MULTIPLIER
end

local function handle_speedlatro_timeout(timer)
	timer.real = 0
	if MP.LOBBY.code then
		if not timer.failed then
			trace_runtime_event("speedlatro.timeout", {
				multiplayer = true,
				timer_started = not not MP.GAME.timer_started,
			})
			MP.ACTIONS.fail_timer()
			timer.failed = true
		end
	elseif G.STATE ~= G.STATES.GAME_OVER then
		trace_runtime_event("speedlatro.timeout", {
			multiplayer = false,
			timer_started = not not MP.GAME.timer_started,
		})
		G.STATE = G.STATES.GAME_OVER
		G.STATE_COMPLETE = false
	end
end

local function update_speedlatro_timer_display(timer)
	MP.GAME.timer = HUD_TIMER_SENTINEL

	local suffix = string.sub(
		math.floor((timer.real + DISPLAY_DECIMAL_PADDING_SECONDS) * DISPLAY_DECIMAL_SCALE),
		-2
	)
	timer.display = math.floor(timer.real) .. "." .. suffix
end

local function tick_speedlatro_timer(dt)
	local timer = ensure_speedlatro_timer(true)
	if should_tick_speedlatro_timer() then
		timer.real = timer.real - dt * get_speedlatro_timer_multiplier()
	end

	if timer.real <= 0 then
		handle_speedlatro_timeout(timer)
	end

	update_speedlatro_timer_display(timer)
end

local function reset_speedlatro_timer(seconds, reset_failed, reason)
	local timer = ensure_speedlatro_timer(false)
	timer.real = seconds
	if reset_failed then
		timer.failed = false
	end
	trace_runtime_event("speedlatro.timer_reset", {
		multiplayer = not not MP.LOBBY.code,
		reason = reason,
		reset_failed = reset_failed == true,
		seconds = seconds,
	})
end

local function reset_speedlatro_timer_for_new_round()
	if not MP.is_ruleset_active(RULESET_KEY) then
		return
	end

	if MP.LOBBY.code then
		if G.GAME.round_resets.blind == G.P_BLINDS["bl_mp_nemesis"] then
			reset_speedlatro_timer(PVP_BLIND_TIMER_SECONDS, true, "new_round_nemesis")
		end
	elseif G.GAME.round_resets.blind ~= G.P_BLINDS["bl_small"]
	and G.GAME.round_resets.blind ~= G.P_BLINDS["bl_big"] then
		reset_speedlatro_timer(PVP_BLIND_TIMER_SECONDS, false, "new_round_non_small_big")
	end
end

local function reset_speedlatro_timer_for_end_round()
	if not MP.is_ruleset_active(RULESET_KEY) then
		return
	end

	if MP.LOBBY.code then
		if MP.is_pvp_boss() then
			reset_speedlatro_timer(BASE_TIMER_SECONDS, true, "end_round_pvp_boss")
		end
	elseif G.GAME.blind:get_type() == "Boss" then
		reset_speedlatro_timer(BASE_TIMER_SECONDS, false, "end_round_boss")
	end
end

MP.GAME_UPDATE_CYCLE.register_before("mp.ruleset.speedlatro_timer", function(ctx)
	local dt = ctx.args[1]
	if is_speedlatro_run_active() then
		tick_speedlatro_timer(dt)
	elseif MP.speedlatro_timer then
		remove_speedlatro_timer()
	end
end, 20)

local new_round_ref = new_round
function new_round()
	reset_speedlatro_timer_for_new_round()
	return new_round_ref()
end

local end_round_ref = end_round
function end_round()
	reset_speedlatro_timer_for_end_round()
	return end_round_ref()
end
