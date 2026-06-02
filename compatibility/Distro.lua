if MP.PLATFORM.SMODS.is_mod_loadable("Distro") then
	G.E_MANAGER:add_event(Event({
		trigger = "immediate",
		no_delete = true,
		blockable = false,
		blocking = false,
		timer = "REAL",
		func = function()
			if DiscordIPC and DiscordIPC.send_activity then
				local send_activity_ref = DiscordIPC.send_activity
				DiscordIPC.send_activity = function(bypass_block)
					if MP.LOBBY.code and not bypass_block then return end
					send_activity_ref()
				end
				return true
			end
		end,
	}))

	local function get_multiplayer_details()
		local opponents = MP.OPPONENTS or {}
		local opponent = opponents.get_primary_lobby_player and opponents.get_primary_lobby_player() or nil
		local enemy_username = opponent and opponent.username or "Opponent"

		return "Multiplayer Versus " .. enemy_username .. " | " .. tostring(MP.GAME.lives) .. " Lives Left"
	end

	local function send_multiplayer_activity_state(state)
		if G.STATE_COMPLETE or not MP.LOBBY.code then return end
		DiscordIPC.activity.details = get_multiplayer_details()
		DiscordIPC.activity.state = state
		DiscordIPC.send_activity(true)
	end

	MP.HOOKS.register_method_hook(Game, "Game", "start_run", "mp.distro.discord_run_activity", {
		after = function(ctx)
			if not MP.LOBBY.code then
				ctx.results = { n = 0 }
				return
			end

			local back_key, back_name = Distro.get_back_name()
			local stake_key, stake_name = Distro.get_stake_name()

			DiscordIPC.activity = {
				details = get_multiplayer_details(),
				state = "Selecting Blind",
				timestamps = {
					start = os.time() * 1000,
				},
				assets = {
					large_image = back_key,
					large_text = back_name,
					small_image = stake_key,
					small_text = stake_name,
				},
			}

			DiscordIPC.send_activity(true)
			ctx.results = { n = 0 }
		end,
	})

	MP.HOOKS.register_method_hook(Game, "Game", "update_selecting_hand", "mp.distro.discord_hand_activity", {
		before = function()
			send_multiplayer_activity_state(
				G.GAME.current_round.hands_left .. " Hands, " .. G.GAME.current_round.discards_left .. " Discards left"
			)
		end,
		after = function(ctx)
			ctx.results = { n = 0 }
		end,
	})

	MP.HOOKS.register_method_hook(Game, "Game", "update_shop", "mp.distro.discord_shop_activity", {
		before = function()
			send_multiplayer_activity_state("Shopping")
		end,
		after = function(ctx)
			ctx.results = { n = 0 }
		end,
	})

	MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.distro.discord_lobby_activity", {
		after = function(ctx)
			if MP.LOBBY.code then
				local opponents = MP.OPPONENTS or {}
				local opponent = opponents.get_primary_lobby_player and opponents.get_primary_lobby_player() or nil
				local enemy_username = opponent and opponent.username or nil

				DiscordIPC.activity = {
					details = enemy_username and "In Multiplayer Lobby with " .. enemy_username or "In Multiplayer Lobby",
					timestamps = {
						start = os.time() * 1000,
					},
					assets = {
						large_image = "default",
					},
				}
				DiscordIPC.send_activity(true)
			end

			ctx.results = { n = 0 }
		end,
	})
end
