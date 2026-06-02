MP.NETWORKING_INTERNAL = MP.NETWORKING_INTERNAL or {}

local ante_timer_runtime = MP.ANTE_TIMER_RUNTIME or {}
MP.ANTE_TIMER_RUNTIME = ante_timer_runtime
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local TIMER_STARTED = true
local TIMER_PAUSED = false
local PLAY_TIMER_SFX = true
local SKIP_TIMER_SFX = false
local DISPLAY_REFRESH_SECONDS = 0.25
local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function normalize_ante_timer_time(time)
	if type(time) == "string" then
		time = tonumber(time)
	end

	return math.max(0, math.floor(tonumber(time) or 0))
end

local function normalize_optional_number(value)
	local numeric_value = tonumber(value)
	if numeric_value and numeric_value == numeric_value then
		return numeric_value
	end
	return nil
end

local function get_local_clock_ms()
	if BALATRO.get_monotonic_time_ms then
		return BALATRO.get_monotonic_time_ms()
	end

	return os.clock() * 1000
end

local function set_timer_event_handle(timer_event)
	MP.timer_event = timer_event
	return timer_event
end

local function clear_timer_event_handle()
	MP.timer_event = nil
	return nil
end

local function stop_local_ante_timer_runtime()
	if match_domain.stop_timer_runtime then
		match_domain.stop_timer_runtime()
	end
	clear_timer_event_handle()
end

local function get_local_ante_timer_base_time()
	return normalize_ante_timer_time(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer_base_seconds)
end

function ante_timer_runtime.get_match_start_time()
	local base_time = get_local_ante_timer_base_time()
	if MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.ruleset == "ruleset_mp_speedlatro" then
		return math.max(0, base_time - 3)
	end

	return base_time
end

local function get_local_ante_timer_increment()
	return normalize_ante_timer_time(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.timer_increment_seconds)
end

local function get_current_local_ante_timer_value(time)
	if time ~= nil then
		return normalize_ante_timer_time(time)
	end

	if MP.GAME and MP.GAME.timer ~= nil then
		return normalize_ante_timer_time(MP.GAME.timer)
	end

	return get_local_ante_timer_base_time()
end

local function clear_timer_sync()
	if MP.GAME then
		MP.GAME.timer_server_sync = nil
	end
end

local function set_timer_sync(time, timer_started, server_now, deadline_at, timer_generation)
	if not MP.GAME then
		return
	end

	local normalized_time = get_current_local_ante_timer_value(time)
	MP.GAME.timer = normalized_time
	MP.GAME.timer_server_sync = {
		time = normalized_time,
		timer_started = not not timer_started,
		server_now_ms = normalize_optional_number(server_now),
		deadline_at_ms = normalize_optional_number(deadline_at),
		timer_generation = normalize_optional_number(timer_generation),
		local_received_ms = get_local_clock_ms(),
	}
end

local function refresh_synced_timer_display()
	if not (MP.GAME and MP.GAME.timer_started) then
		return false
	end

	local sync = MP.GAME.timer_server_sync
	if not (sync and sync.server_now_ms and sync.deadline_at_ms) then
		return true
	end

	local estimated_server_now = sync.server_now_ms + math.max(0, get_local_clock_ms() - sync.local_received_ms)
	local remaining_seconds = math.max(0, math.ceil((sync.deadline_at_ms - estimated_server_now) / 1000))
	if match_domain.set_timer_value then
		match_domain.set_timer_value(remaining_seconds)
	else
		MP.GAME.timer = remaining_seconds
	end
	if remaining_seconds <= 0 then
		trace_runtime_event("ante_timer.display_reached_zero", {
			generation = sync.timer_generation,
		})
	end

	return remaining_seconds > 0
end

local function ensure_local_ante_timer_runtime()
	if MP.is_ruleset_active("speedlatro") or MP.GAME.timer_runtime_active then
		return
	end

	local runtime_generation = match_domain.start_timer_runtime and match_domain.start_timer_runtime() or MP.GAME.timer_runtime_generation
	local timer_event = set_timer_event_handle(ante_timer_runtime.create_timer_event(runtime_generation))
	if timer_event then
		BALATRO.add_event(timer_event)
	end
end

function ante_timer_runtime.create_timer_event(runtime_generation)
	local timer_event

	timer_event = BALATRO.create_event({
		blockable = false,
		blocking = false,
		pause_force = true,
		no_delete = true,
		trigger = "after",
		delay = 1,
		timer = "UPTIME",
		func = function()
			if runtime_generation ~= (MP.GAME.timer_runtime_generation or 0) then
				return true
			end

			local still_running = refresh_synced_timer_display()
			if not still_running then
				clear_timer_event_handle()
				return true
			end

			timer_event.start_timer = false
			timer_event.delay = DISPLAY_REFRESH_SECONDS
		end,
	})

	return timer_event
end

local function maybe_play_ante_timer_sfx()
	local option = MP.PLATFORM.SMODS.get_config_value("timersfx", 1)
	local current_ante = BALATRO.get_ante and BALATRO.get_ante() or nil
	local timer_ante = BALATRO.get_timer_ante and BALATRO.get_timer_ante() or nil
	local timersfx = (option == 1) or (option == 2 and current_ante ~= nil and timer_ante ~= current_ante)
	if current_ante ~= nil and BALATRO.set_timer_ante then
		BALATRO.set_timer_ante(current_ante)
	end

	if not timersfx then
		return
	end

	for i = 1, 3 do
		local wait_time = 0.15 * (i - 1)
		BALATRO.queue_event({
			blocking = false,
			blockable = false,
			trigger = "after",
			delay = (BALATRO.get_game_speed and BALATRO.get_game_speed() or 1) * wait_time,
			func = function()
				BALATRO.play_sound("timpani", 0.55 + 0.25 * i, 0.7)
				BALATRO.play_sound("generic1", 0.75 + 0.25 * i, 0.7)
				return true
			end,
		})
	end
end

function ante_timer_runtime.apply_state(time, timer_started, play_sfx, server_now, deadline_at, timer_generation)
	time = get_current_local_ante_timer_value(time)

	if play_sfx then
		maybe_play_ante_timer_sfx()
	end

	if match_domain.apply_timer_state then
		match_domain.apply_timer_state(time, timer_started)
	end
	set_timer_sync(time, timer_started, server_now, deadline_at, timer_generation)
	trace_runtime_event(timer_started and "ante_timer.state_started" or "ante_timer.state_paused", {
		deadline_at = deadline_at,
		generation = timer_generation,
		server_now = server_now,
		time = time,
	})

	if MP.GAME.timer_started then
		refresh_synced_timer_display()
		ensure_local_ante_timer_runtime()
	else
		clear_timer_sync()
		stop_local_ante_timer_runtime()
	end
end

function ante_timer_runtime.reset_for_ante(time)
	if match_domain.reset_timer_for_ante then
		match_domain.reset_timer_for_ante(normalize_ante_timer_time(time))
	end
	clear_timer_sync()
	clear_timer_event_handle()
end

function ante_timer_runtime.apply_skip_for_ante(skip_count_delta)
	if not MP.GAME or MP.GAME.timer_locked_for_ante then
		return false
	end

	skip_count_delta = math.max(0, math.floor(tonumber(skip_count_delta) or 0))
	if skip_count_delta <= 0 then
		return false
	end

	local result = match_domain.apply_timer_skip_for_ante and match_domain.apply_timer_skip_for_ante(
		skip_count_delta,
		get_local_ante_timer_base_time(),
		get_local_ante_timer_increment()
	)
	return not not (result and result.applied)
end

function ante_timer_runtime.start(time, server_now, deadline_at, timer_generation)
	ante_timer_runtime.apply_state(time, TIMER_STARTED, PLAY_TIMER_SFX, server_now, deadline_at, timer_generation)
end

function ante_timer_runtime.pause(time, server_now, deadline_at, timer_generation)
	ante_timer_runtime.apply_state(time, TIMER_PAUSED, SKIP_TIMER_SFX, server_now, deadline_at, timer_generation)
end

function ante_timer_runtime.restore(time, timer_started, server_now, deadline_at, timer_generation)
	ante_timer_runtime.apply_state(time, timer_started, SKIP_TIMER_SFX, server_now, deadline_at, timer_generation)
end

ante_timer_runtime.restore_local_ante_timer_state = ante_timer_runtime.restore

function ante_timer_runtime.handle_start_ante_timer(time, server_now, deadline_at, timer_generation)
	if
		MP.RESUME
		and MP.RESUME.buffer_runtime_start_ante_timer
		and MP.RESUME.buffer_runtime_start_ante_timer(time, server_now, deadline_at, timer_generation)
	then
		return
	end

	ante_timer_runtime.start(time, server_now, deadline_at, timer_generation)
end

function ante_timer_runtime.handle_pause_ante_timer(time, server_now, deadline_at, timer_generation)
	if
		MP.RESUME
		and MP.RESUME.buffer_runtime_pause_ante_timer
		and MP.RESUME.buffer_runtime_pause_ante_timer(time, server_now, deadline_at, timer_generation)
	then
		return
	end

	ante_timer_runtime.pause(time, server_now, deadline_at, timer_generation)
end

MP.NETWORKING_INTERNAL.restore_local_ante_timer_state = ante_timer_runtime.restore_local_ante_timer_state
MP.NETWORKING_INTERNAL.handle_start_ante_timer = ante_timer_runtime.handle_start_ante_timer
MP.NETWORKING_INTERNAL.handle_pause_ante_timer = ante_timer_runtime.handle_pause_ante_timer
