local function reset_multiplayer_run_transition_state()
	if MP.reset_match_ready_blind_state then
		MP.reset_match_ready_blind_state()
	end
	if MP.clear_match_end_pvp then
		MP.clear_match_end_pvp()
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

local function suppress_original_result(ctx)
	ctx.results = { n = 0 }
end

MP.HOOKS.register_method_hook(Game, "Game", "update_shop", "mp.run_runtime.location_shop", {
	before = function()
		if not G.STATE_COMPLETE then
			reset_multiplayer_run_transition_state()
		end

		if MP.LOBBY.code and not G.STATE_COMPLETE and not G.GAME.USING_RUN then
			if MP.GAME.location ~= "loc_shop" then
				if MP.set_match_spent_before_shop then
					MP.set_match_spent_before_shop(to_big(MP.GAME.spent_total) + to_big(0))
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
		MP.LoadReworks(MP.LOBBY.config.ruleset or MP.SP.ruleset)
	end,
	after = function(ctx)
		if MP.sync_local_money_state then
			MP.sync_local_money_state()
		end

		suppress_original_result(ctx)

		if not MP.LOBBY.client.connected or not MP.LOBBY.code or MP.LOBBY.config.disable_live_and_timer_hud then return end

		if MP.UI and MP.UI.refresh_lives_hud_binding then
			MP.UI.refresh_lives_hud_binding()
		end
	end,
})
