-- Universal game speed (Handy-style): SPEEDFACTOR + event-queue acceleration.
-- Setting G.SETTINGS.GAMESPEED to 8–128 does not speed the whole game: many events use
-- delay * GAMESPEED, which cancels SPEEDFACTOR, and EventManager still ticks ~once per frame.

local SPEED_OPTIONS = { 0.5, 1, 2, 4, 8, 16, 32, 64, 128 }
local VANILLA_GAMESPEED = 1

local function selected_speed()
	return tonumber(G and G.SETTINGS and G.SETTINGS.MP_GAME_SPEED) or 1
end

local function pin_vanilla_gamespeed()
	if not (G and G.SETTINGS) then
		return
	end
	if G.SETTINGS.MP_GAME_SPEED == nil then
		G.SETTINGS.MP_GAME_SPEED = tonumber(G.SETTINGS.GAMESPEED) or 1
	end
	G.SETTINGS.GAMESPEED = VANILLA_GAMESPEED
end

local function current_speed_option()
	local speed = selected_speed()
	local best_index = 3
	local best_dist = math.huge
	for index, option in ipairs(SPEED_OPTIONS) do
		if option == speed then
			return index
		end
		local dist = math.abs(option - speed)
		if dist < best_dist then
			best_index = index
			best_dist = dist
		end
	end
	return best_index
end

local function build_gamespeed_cycle()
	pin_vanilla_gamespeed()
	return create_option_cycle({
		label = localize("b_set_gamespeed"),
		scale = 0.8,
		options = SPEED_OPTIONS,
		opt_callback = "change_gamespeed",
		current_option = current_speed_option(),
	})
end

function MP.apply_game_speed_factor(game)
	if not game then
		return
	end
	pin_vanilla_gamespeed()
	local speed = selected_speed()
	if speed <= 0 then
		return
	end
	local in_run = G.STAGE == G.STAGES.RUN and not G.SETTINGS.paused and not G.screenwipe
	local use_in_menu = Handy and Handy.ARGS and Handy.ARGS.use_gamespeed
	if not in_run and not use_in_menu then
		return
	end
	local vanilla = tonumber(G.SETTINGS.GAMESPEED) or VANILLA_GAMESPEED
	if vanilla <= 0 then
		vanilla = VANILLA_GAMESPEED
	end
	game.SPEEDFACTOR = game.SPEEDFACTOR * (speed / vanilla)
end

local function event_retriggers()
	local speed = selected_speed()
	if speed <= 1 then
		return 0
	end
	if G.SCORING_COROUTINE then
		return 0
	end
	-- Handy uses floor(speed/64)-1 (1 extra tick at 128x). That is not enough to drain
	-- 0-delay scoring chains; extra ticks process one blocking event each.
	return math.max(0, math.floor(speed / 8) - 1)
end

local function install_event_queue_acceleration()
	if not EventManager or type(EventManager.update) ~= "function" then
		return false
	end
	if EventManager._mp_speed_queue_accel then
		return true
	end
	EventManager._mp_speed_queue_accel = true

	local em_update = EventManager.update
	function EventManager:update(real_dt, forced, ...)
		local result = em_update(self, real_dt, forced, ...)
		if forced or (real_dt or 0) <= 0 then
			return result
		end
		local extra = event_retriggers()
		for _ = 1, extra do
			em_update(self, 0, true, ...)
		end
		return result
	end

	return true
end

local function install_change_gamespeed()
	if not (G and G.FUNCS and type(G.FUNCS.change_gamespeed) == "function") then
		return false
	end
	if G.FUNCS._mp_change_gamespeed then
		return true
	end
	G.FUNCS._mp_change_gamespeed = true

	function G.FUNCS.change_gamespeed(args)
		local speed = tonumber(args and args.to_val) or 1
		G.SETTINGS.MP_GAME_SPEED = speed
		G.SETTINGS.GAMESPEED = VANILLA_GAMESPEED
	end

	return true
end

local function install_gamespeed_cycle()
	if not (G and G.UIDEF and type(G.UIDEF.settings_tab) == "function") then
		return false
	end
	if G.UIDEF._mp_gamespeed_extended then
		return true
	end
	G.UIDEF._mp_gamespeed_extended = true

	local settings_tab_ref = G.UIDEF.settings_tab
	function G.UIDEF.settings_tab(tab)
		local setting_tab = settings_tab_ref(tab)
		if tab == "Game" and type(setting_tab) == "table" and type(setting_tab.nodes) == "table" then
			setting_tab.nodes[1] = build_gamespeed_cycle()
		end
		return setting_tab
	end

	return true
end

local function install_all()
	pin_vanilla_gamespeed()
	install_change_gamespeed()
	install_event_queue_acceleration()
	install_gamespeed_cycle()
end

install_all()

if Game and type(Game.start_up) == "function" and not Game._mp_gamespeed_startup then
	Game._mp_gamespeed_startup = true
	local game_start_ref = Game.start_up
	function Game:start_up(...)
		local result = game_start_ref(self, ...)
		install_all()
		return result
	end
end

if Game and type(Game.update) == "function" and not Game._mp_gamespeed_update_install then
	Game._mp_gamespeed_update_install = true
	local update_ref = Game.update
	function Game:update(...)
		if not (EventManager and EventManager._mp_speed_queue_accel and G.UIDEF and G.UIDEF._mp_gamespeed_extended) then
			install_all()
		end
		return update_ref(self, ...)
	end
end
