if MP.PLATFORM.SMODS.is_mod_loadable("HotPotato") then
	sendDebugMessage("HotPotato compatibility detected", "MULTIPLAYER")
	MP.DECK.ban_cards({
		"j_hpot_antidsestablishmentarianism", -- sic
		"j_hpot_brainfuck",
		"j_hpot_goldenchicot",
		"j_hpot_lockin",
		"j_joker",
		"j_hpot_lotus",
		"j_hpot_c_sharp",
		"j_hpot_goblin_tinkerer", -- too easy to infinite
	})

	-- essentially we're just hooking a bunch of functions to separate and normalise rng
	-- i was gonna hook more but it ended up only being 2 so whatever

	local pack_values = MP.UTILS.pack_values
	local unpack_packed = MP.UTILS.unpack_packed
	local build_traceback = MP.UTILS.build_traceback

	local function set_round_reset_ante(ante)
		G.GAME.round_resets.ante = ante
	end

	local function set_used_jokers(used_jokers)
		G.GAME.used_jokers = used_jokers
	end

	local function mark_joker_used(joker_key)
		G.GAME.used_jokers[joker_key] = true
	end

	local function disable_the_order_rng()
		MP.should_use_the_order = function()
			return false
		end
	end

	local function set_wheel_rotation(rotation)
		G.wheel_arrow.cards[1].T.r = rotation
		G.GAME.keep_rotation = rotation
	end

	local function reset_wheel_vval()
		G.GAME.vval = 0
		G.GAME.winning_vval = (G.GAME.vval / 10)
		Wheel.KeepVval = G.GAME.vvals
	end

	local function set_wheel_starting_accel(accel)
		Wheel.starting_accel = accel
	end

	local function with_hotpot_rng_isolation(temp_ante, fn, ...)
		local original_ante = G.GAME.round_resets.ante
		local original_used_jokers = G.GAME.used_jokers
		local original_should_use_the_order = MP.should_use_the_order
		local args = pack_values(...)
		local results = nil

		set_round_reset_ante(temp_ante)
		set_used_jokers({})
		disable_the_order_rng()

		local ok, err = xpcall(function()
			results = pack_values(fn(unpack_packed(args)))
		end, build_traceback)

		set_round_reset_ante(original_ante)
		set_used_jokers(original_used_jokers)
		MP.should_use_the_order = original_should_use_the_order

		if not ok then
			error(err, 0)
		end

		return unpack_packed(results)
	end

	local function should_replace_center(center)
		if G.OVERLAY_MENU or not center then
			return false
		end

		if center.mp_include and type(center.mp_include) == "function" and not center:mp_include() then
			return true
		end

		return not not G.GAME.banned_keys[center.key]
	end

	local function get_next_pool_center(center)
		local pool = center and center.set and G.P_CENTER_POOLS[center.set] or nil
		if not pool or #pool == 0 then
			return nil
		end

		local found_center = false
		for _, pool_center in ipairs(pool) do
			if found_center then
				return pool_center
			end
			if pool_center == center then
				found_center = true
			end
		end

		return found_center and pool[1] or nil
	end

	local function get_next_allowed_pool_center(center)
		local replacement_center = get_next_pool_center(center)
		local visited = 0
		while replacement_center and should_replace_center(replacement_center) and visited < #(G.P_CENTER_POOLS[center.set] or {}) do
			replacement_center = get_next_pool_center(replacement_center)
			visited = visited + 1
		end

		if replacement_center and not should_replace_center(replacement_center) then
			return replacement_center
		end

		return nil
	end

	local hooks = {
		{ tbl = _G, str = "hotpot_delivery_refresh_card" },
		{ tbl = _G, str = "hotpot_jtem_generate_special_deals" },
	}

	local function hook(orig, ante)
		return function(...)
			return with_hotpot_rng_isolation(ante or 89, orig, ...)
		end
	end
	for i, v in pairs(hooks) do
		local orig = v.tbl[v.str]
		v.tbl[v.str] = hook(orig)
	end
	local grant_wheel_reward_ref = grant_wheel_reward
	function grant_wheel_reward(card)
		if not card then
			card = G.wheel_rewards.cards[1]
		end
		if card.ability.set ~= "bottlecap" then
			mark_joker_used(card.config.center.key) -- if there's no room, card will be removed so this is safe
		end
		return grant_wheel_reward_ref(card)
	end
	local generate_wheel_rewards_ref = generate_wheel_rewards
	function generate_wheel_rewards(_amount)
		-- randomise rotation
		local rot = pseudorandom("hpot_wheel_rotation") * 2 * math.pi
		set_wheel_rotation(rot)

		-- constants from experimentation
		-- this range encompasses an entire wheel spin, making every endpos equally likely
		local min = 0.486225001705432
		local max = 0.502020498677871
		set_wheel_starting_accel((pseudorandom("hpot_wheel_starting_accel") * (max - min)) + min)

		-- nullify any vval (idk what this does exactly but it's annoying)
		reset_wheel_vval()

		return with_hotpot_rng_isolation(78, generate_wheel_rewards_ref, _amount)
	end
	local spin_wheel_ref = spin_wheel
	function spin_wheel(...) -- this function name sucks
		local ret = spin_wheel_ref(...)
		Wheel.accel = Wheel.starting_accel
		return ret
	end
	local set_ability_ref = Card.set_ability
	function Card:set_ability(center, initial, delay_sprites)
		if should_replace_center(center) then
			local replacement_center = get_next_allowed_pool_center(center)
			if replacement_center then
				return set_ability_ref(self, replacement_center, initial, delay_sprites)
			end
		end
		return set_ability_ref(self, center, initial, delay_sprites)
	end
end
