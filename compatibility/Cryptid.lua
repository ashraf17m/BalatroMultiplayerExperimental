if MP.PLATFORM.SMODS.is_mod_loadable("Cryptid") then
	sendDebugMessage("Cryptid compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_cry_fleshpanopticon",
		"j_cry_candy_sticks",
		"j_cry_redeo",
		"j_cry_chocolate_dice",
		"j_cry_carved_pumpkin",
		"j_cry_pumpkin",
		"v_cry_asteroglyph",
		"c_cry_semicolon",
		"c_cry_crash",
		"c_cry_revert",
		"c_cry_analog",
		"c_cry_reboot",
	})
	MP.DECK.ban_blind("bl_cry_joke")

	MP.HOOKS.register_method_hook(Blind, "Blind", "defeat", "mp.cryptid.nil_blind_key", {
		before = function(ctx, self)
			if self.config.blind.key == nil then self.config.blind.key = "bl_nil" end
		end,
		after = function(ctx)
			ctx.results = { n = 0 }
		end,
	})

	function wheel_of_fortune_the_title_card()
		return true
	end

	local function is_card_banned(card)
		if not card or not card.key then
			return false
		end
		if G and G.GAME and G.GAME.banned_keys and G.GAME.banned_keys[card.key] then
			return true
		end
		for _, banned in ipairs(MP.DECK.BANNED_CARDS or {}) do
			if card.key == banned.id then
				return true
			end
		end
		return false
	end

	local wrapped_generators = {}
	local function wrap_random_consumable(target_fn)
		if type(target_fn) ~= "function" or wrapped_generators[target_fn] then
			return target_fn
		end
		local wrapped
		wrapped = function(seed, excluded_flags, banned_card, pool, no_undiscovered)
			if not (MP.LOBBY and MP.LOBBY.code) then
				return target_fn(seed, excluded_flags, banned_card, pool, no_undiscovered)
			end
			local max_tries = 10
			local card
			for attempt = 1, max_tries do
				local current_seed = seed
				if attempt > 1 and seed then
					current_seed = seed .. "_retry_" .. attempt
				end
				card = target_fn(current_seed, excluded_flags, banned_card, pool, no_undiscovered)
				if not is_card_banned(card) then
					return card
				end
				sendWarnMessage("Attempted to create banned card: " .. tostring(card and card.key) .. ", trying again (attempt " .. attempt .. ")", "MULTIPLAYER")
			end
			sendWarnMessage("Attempted to create banned cards too many times, falling back.", "MULTIPLAYER")
			if G and G.P_CENTERS and G.P_CENTERS["c_strength"] and not is_card_banned(G.P_CENTERS["c_strength"]) then
				return G.P_CENTERS["c_strength"]
			end
			return card
		end
		wrapped_generators[wrapped] = true
		return wrapped
	end

	local function try_hook_consumable_generators()
		if type(get_random_consumable) == "function" and not wrapped_generators[get_random_consumable] then
			get_random_consumable = wrap_random_consumable(get_random_consumable)
		end
		if Cryptid and type(Cryptid.random_consumable) == "function" and not wrapped_generators[Cryptid.random_consumable] then
			Cryptid.random_consumable = wrap_random_consumable(Cryptid.random_consumable)
		end
	end

	try_hook_consumable_generators()
	if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
		MP.GAME_UPDATE_CYCLE.register_after("mp.compatibility.cryptid_consumable_hook", function()
			try_hook_consumable_generators()
			if (type(get_random_consumable) == "function" and wrapped_generators[get_random_consumable])
				or (Cryptid and type(Cryptid.random_consumable) == "function" and wrapped_generators[Cryptid.random_consumable]) then
				if MP.GAME_UPDATE_CYCLE.unregister_after then
					MP.GAME_UPDATE_CYCLE.unregister_after("mp.compatibility.cryptid_consumable_hook")
				end
			end
		end, 20)
	end

	MP.DECK.set_max_stake("stake_cry_emerald")
end
