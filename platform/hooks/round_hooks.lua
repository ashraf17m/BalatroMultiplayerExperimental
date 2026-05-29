MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}

function MP.PLATFORM.HOOKS.install_round_hooks()
	if MP.PLATFORM.HOOKS.round_hooks_installed then
		return true
	end

	local ease_ante_ref = ease_ante
	function ease_ante(mod)
		if MP.LOBBY.code and not MP.LOBBY.config.disable_live_and_timer_hud then
			if MP.GAME.antes_keyed[MP.GAME.ante_key] then return end

			if MP.GAME.pizza_discards > 0 then
				local pizza_discards = MP.consume_match_pizza_discards and MP.consume_match_pizza_discards() or MP.GAME.pizza_discards
				G.GAME.round_resets.discards = G.GAME.round_resets.discards - pizza_discards
				ease_discard(-pizza_discards)
			end

			if MP.mark_match_ante_key_processed then
				MP.mark_match_ante_key_processed()
			end
			MP.ACTIONS.set_ante(G.GAME.round_resets.ante + mod)
			G.E_MANAGER:add_event(Event({
				trigger = "immediate",
				func = function()
					G.GAME.round_resets.ante = G.GAME.round_resets.ante + mod
					check_and_set_high_score("furthest_ante", G.GAME.round_resets.ante)
					return true
				end,
			}))
		end
		return ease_ante_ref(mod)
	end

	local ease_round_ref = ease_round
	function ease_round(mod)
		if MP.LOBBY.code and not MP.LOBBY.config.disable_live_and_timer_hud and MP.LOBBY.config.timer then return end
		ease_round_ref(mod)
	end

	local reset_blinds_ref = reset_blinds
	function reset_blinds()
		reset_blinds_ref()
		G.GAME.round_resets.pvp_blind_choices = {}
		if MP.LOBBY.code then
			if MP.resolve_lobby_blinds_for_ante then
				local mp_small_choice, mp_big_choice, mp_boss_choice, mp_pvp_blind_choices =
					MP.resolve_lobby_blinds_for_ante(G.GAME.round_resets.ante)
				G.GAME.round_resets.pvp_blind_choices = mp_pvp_blind_choices or {}
				G.GAME.round_resets.blind_choices.Small = mp_small_choice or G.GAME.round_resets.blind_choices.Small
				G.GAME.round_resets.blind_choices.Big = mp_big_choice or G.GAME.round_resets.blind_choices.Big
				G.GAME.round_resets.blind_choices.Boss = mp_boss_choice or G.GAME.round_resets.blind_choices.Boss
			end
		end
	end

	MP.HOOKS.register_method_hook(Blind, "Blind", "get_type", "mp.round_hooks.nemesis_type", {
		before = function(ctx, self)
			if self.name == "bl_mp_nemesis" then
				ctx.skip_original = true
				ctx.results = { G.GAME.blind_on_deck, n = 1 }
			end
		end,
	})

	MP.HOOKS.register_method_hook(EventManager, "EventManager", "add_event", "mp.round_hooks.suppress_next_event", {
		before = function(ctx)
			if MP.suppress_next_event then
				MP.suppress_next_event = false
				ctx.skip_original = true
				ctx.results = { n = 0 }
			end
		end,
	})

	MP.PLATFORM.HOOKS.round_hooks_installed = true
	return true
end

return MP.PLATFORM.HOOKS.install_round_hooks()
