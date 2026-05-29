if MP.EXPERIMENTAL.alt_stakes then
	local BASE_INTEREST_RATE = 5
	local PLASTIC_INTEREST_RATE = 10

	local function get_interest_rate()
		return G.GAME.modifiers and G.GAME.modifiers.mp_modified_interest_rate or BASE_INTEREST_RATE
	end

	local function scale_interest_value(value)
		return value / (BASE_INTEREST_RATE / get_interest_rate())
	end

	local function begin_fake_no_interest()
		local modifiers = G.GAME.modifiers
		if not (modifiers and modifiers.mp_modified_interest_rate) then
			return nil
		end

		-- The vanilla interest award happens mid-function, so we temporarily disable it
		-- and apply the Plastic Stake version through our own modified-interest path.
		local original_no_interest = modifiers.no_interest
		modifiers.no_interest = true
		return {
			modifiers = modifiers,
			original_no_interest = original_no_interest,
		}
	end

	local function restore_fake_no_interest(state)
		if state and state.modifiers then
			state.modifiers.no_interest = state.original_no_interest
		end
	end

	MP.STAKES.register_alt_stake({
		name = "Plastic Stake",
		key = "plastic",
		applied_stakes = { "white" },
		prefix_config = { applied_stakes = { mod = false } },
		pos = { x = 1, y = 0 },
		modifiers = function()
			G.GAME.modifiers.mp_modified_interest_rate = PLASTIC_INTEREST_RATE
		end,
		colour = HEX("FF9696"),
	})

	MP.HOOKS.register_method_hook(G.FUNCS, "G.FUNCS", "evaluate_round", "mp.plastic_stake.modified_interest", {
		before = function(ctx)
			ctx.mp_plastic_no_interest_state = begin_fake_no_interest()
		end,
		after = function(ctx)
			restore_fake_no_interest(ctx.mp_plastic_no_interest_state)
		end,
	})

	SMODS.Joker:take_ownership("to_the_moon", {
		loc_vars = function(self, info_queue, card)
			return {
				vars = { card.ability.extra, get_interest_rate() },
				key = self.key .. "_mp",
			}
		end,
	}, true)

	MP.HOOKS.register_method_hook(Card, "Card", "set_ability", "mp.plastic_stake.scale_to_the_moon", {
		after = function(ctx, self)
			local center = ctx.args and ctx.args[1]
			if center == G.P_CENTERS.j_to_the_moon and G.GAME.modifiers.mp_modified_interest_rate then
				self.ability.extra = scale_interest_value(self.ability.extra)
			end
			ctx.results = { n = 0 }
		end,
	})

	SMODS.Voucher:take_ownership("seed_money", {
		loc_vars = function(self, info_queue, card)
			return {
				vars = {
					scale_interest_value(card.ability.extra),
				},
			}
		end,
	}, true)

	SMODS.Voucher:take_ownership("money_tree", {
		loc_vars = function(self, info_queue, card)
			return {
				vars = {
					scale_interest_value(card.ability.extra),
				},
			}
		end,
	}, true)
end
