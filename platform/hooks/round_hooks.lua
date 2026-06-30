MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}

local function get_match_domain()
	return MP.DOMAIN and MP.DOMAIN.MATCH or {}
end

local function get_teams_domain()
	return MP.DOMAIN and MP.DOMAIN.TEAMS or {}
end

local function is_ghost_replay_active()
	return MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active()
end

local function has_round_ui()
	return G
		and G.hand_text_area
		and G.hand_text_area.round
		and G.hand_text_area.round.config
		and G.hand_text_area.round.config.object
		and G.HUD
end

local function ease_round_without_ui(mod)
	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
		func = function()
			mod = mod or 0
			if G and G.GAME then
				G.GAME.round = (G.GAME.round or 0) + mod
				check_and_set_high_score("furthest_round", G.GAME.round)
				if G.GAME.round_resets then
					check_and_set_high_score("furthest_ante", G.GAME.round_resets.ante)
				end
			end
			return true
		end,
	}))
end

function MP.PLATFORM.HOOKS.install_round_hooks()
	if MP.PLATFORM.HOOKS.round_hooks_installed then
		return true
	end

	local ease_ante_ref = ease_ante
	function ease_ante(mod)
		local lobby_config = MP.LOBBY and MP.LOBBY.config or {}
		if (MP.LOBBY.code or is_ghost_replay_active()) and not lobby_config.disable_live_and_timer_hud then
			if MP.GAME.antes_keyed[MP.GAME.ante_key] then return end

			local match_domain = get_match_domain()
			if (MP.GAME.pizza_discards or 0) > 0 then
				local pizza_discards = match_domain.consume_pizza_discards and match_domain.consume_pizza_discards() or MP.GAME.pizza_discards
				G.GAME.round_resets.discards = G.GAME.round_resets.discards - pizza_discards
				ease_discard(-pizza_discards)
			end

			if match_domain.mark_ante_key_processed then
				match_domain.mark_ante_key_processed()
			end
			if not is_ghost_replay_active() then
				MP.ACTIONS.set_ante(G.GAME.round_resets.ante + mod)
			end
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
		if MP.LOBBY.code then
			if not MP.LOBBY.config.disable_live_and_timer_hud and MP.LOBBY.config.timer then return end
			if MP.LOBBY.config.disable_live_and_timer_hud or not has_round_ui() then
				ease_round_without_ui(mod)
				return
			end
		end
		ease_round_ref(mod)
	end

	local reset_blinds_ref = reset_blinds
	function reset_blinds()
		reset_blinds_ref()
		G.GAME.round_resets.pvp_blind_choices = {}
		G.GAME.round_resets.duel_bye_blind_choices = {}
		if MP.LOBBY.code then
			local teams_domain = get_teams_domain()
			if teams_domain.resolve_lobby_blinds_for_ante then
				local mp_small_choice, mp_big_choice, mp_boss_choice, mp_pvp_blind_choices =
					teams_domain.resolve_lobby_blinds_for_ante(G.GAME.round_resets.ante)
				local pvp_blind_choices = mp_pvp_blind_choices or {}
				if MP.is_duels_bye and MP.is_duels_bye() then
					local duel_bye_blind_choices = {}
					if mp_small_choice == "bl_mp_nemesis" or pvp_blind_choices.Small then
						duel_bye_blind_choices.Small = true
						mp_small_choice = nil
						pvp_blind_choices.Small = nil
					end
					if mp_big_choice == "bl_mp_nemesis" or pvp_blind_choices.Big then
						duel_bye_blind_choices.Big = true
						mp_big_choice = nil
						pvp_blind_choices.Big = nil
					end
					if mp_boss_choice == "bl_mp_nemesis" or pvp_blind_choices.Boss then
						duel_bye_blind_choices.Boss = true
						mp_boss_choice = nil
						pvp_blind_choices.Boss = nil
					end
					G.GAME.round_resets.duel_bye_blind_choices = duel_bye_blind_choices
				end
				G.GAME.round_resets.pvp_blind_choices = pvp_blind_choices
				G.GAME.round_resets.blind_choices.Small = mp_small_choice or G.GAME.round_resets.blind_choices.Small
				G.GAME.round_resets.blind_choices.Big = mp_big_choice or G.GAME.round_resets.blind_choices.Big
				G.GAME.round_resets.blind_choices.Boss = mp_boss_choice or G.GAME.round_resets.blind_choices.Boss
			end
		elseif is_ghost_replay_active() then
			local gamemode_key = MP.get_active_gamemode and MP.get_active_gamemode() or nil
			local gamemode = gamemode_key and MP.Gamemodes and MP.Gamemodes[gamemode_key] or nil
			if gamemode and gamemode.get_blinds_by_ante then
				local mp_small_choice, mp_big_choice, mp_boss_choice = gamemode:get_blinds_by_ante(G.GAME.round_resets.ante)
				G.GAME.round_resets.blind_choices.Small = mp_small_choice or G.GAME.round_resets.blind_choices.Small
				G.GAME.round_resets.blind_choices.Big = mp_big_choice or G.GAME.round_resets.blind_choices.Big
				G.GAME.round_resets.blind_choices.Boss = mp_boss_choice or G.GAME.round_resets.blind_choices.Boss
			end
			if MP.GHOST.init_playback then
				MP.GHOST.init_playback(G.GAME.round_resets.ante)
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
