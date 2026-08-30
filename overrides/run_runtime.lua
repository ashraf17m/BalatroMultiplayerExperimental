local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local function reset_multiplayer_run_transition_state()
	if match_domain.reset_ready_blind_state then
		match_domain.reset_ready_blind_state()
	end
	if match_domain.clear_end_pvp then
		match_domain.clear_end_pvp()
	end
end

local function show_enemy_location()
	if MP.UI.show_enemy_location then
		MP.UI.show_enemy_location()
	end
end

local function set_multiplayer_location(location)
	MP.ACTIONS.set_location(location)
	show_enemy_location()
end

local function get_current_location_type()
	local location = tostring((MP.GAME and MP.GAME.location) or "")
	return location:match("^([^-]+)") or location
end

local function suppress_original_result(ctx)
	ctx.results = { n = 0 }
end

MP.HOOKS.register_method_hook(Game, "Game", "update_shop", "mp.run_runtime.location_shop", {
	before = function()
		if not G.STATE_COMPLETE then
			reset_multiplayer_run_transition_state()
		end

		if MP.LOBBY.code and not G.STATE_COMPLETE and not G.GAME.USING_RUN then
			if get_current_location_type() ~= "loc_shop" then
				if match_domain.set_spent_before_shop then
					match_domain.set_spent_before_shop(to_big(MP.GAME.spent_total) + to_big(0))
				end
			end
			set_multiplayer_location("loc_shop")
		end
	end,
	after = function(ctx)
		if MP.RESUME and MP.RESUME.validate_deferred_shop_loads then
			MP.RESUME.validate_deferred_shop_loads("update_shop")
		end
		suppress_original_result(ctx)
	end,
})

MP.HOOKS.register_method_hook(Game, "Game", "update_blind_select", "mp.run_runtime.location_selecting", {
	before = function()
		if MP.LOBBY.code and not G.STATE_COMPLETE then
			set_multiplayer_location("loc_selecting")
		end
	end,
	after = suppress_original_result,
})

MP.HOOKS.register_method_hook(Game, "Game", "start_run", "mp.run_runtime.start_run", {
	before = function()
		local active_ruleset = MP.get_active_ruleset and MP.get_active_ruleset()
			or (MP.LOBBY.code and MP.LOBBY.config.ruleset)
			or nil
		MP.LoadReworks(active_ruleset)
	end,
	after = function(ctx)
		if MP.sync_local_money_state then
			MP.sync_local_money_state()
		end

		suppress_original_result(ctx)

		if not MP.LOBBY.client.connected or not MP.LOBBY.code then return end

		if MP.UI and MP.UI.refresh_lives_hud_binding and not (MP.LOBBY.config and MP.LOBBY.config.disable_live_and_timer_hud) then
			MP.UI.refresh_lives_hud_binding()
		end

		if MP.SPECTATOR and (MP.SPECTATOR.is_spectator_role or MP.SPECTATOR.is_spectating) then
			if not MP.SPECTATOR.target_player_id and MP.SPECTATOR.get_spectatable_players then
				local spectatable = MP.SPECTATOR.get_spectatable_players()
				local target = spectatable[1]
				if target and MP.SPECTATOR.start_spectating then
					MP.SPECTATOR.start_spectating(target.id, target.username)
				end
			end
			return
		end

		-- Note: RECORDER.reset() intentionally NOT called here. Match flow
		-- (match_flow_runtime.start_match_runtime) resets the recorder before
		-- starting the run; resetting again after start_run would zero the step
		-- counter after START_RUN was recorded as step 1, so the next action
		-- would reuse step 1 and get dropped by spectators as a duplicate.
	end,
})
