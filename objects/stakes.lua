-- Consolidated objects/stakes.lua
-- Combines all 12 micro-files from objects/stakes/ into a single file

-- === _alt_stake_utils.lua ===
MP.STAKES = MP.STAKES or {}

function MP.STAKES.register_alt_stake(definition)
	if not (MP.EXPERIMENTAL and MP.EXPERIMENTAL.alt_stakes) then
		return nil
	end

	local stake_definition = {}
	for key, value in pairs(definition or {}) do
		stake_definition[key] = value
	end

	stake_definition.mp_alt_stake = true
	if stake_definition.unlocked == nil then
		stake_definition.unlocked = true
	end
	stake_definition.atlas = stake_definition.atlas or "alt_mp_stakes"
	stake_definition.sticker_pos = stake_definition.sticker_pos or { x = 3, y = 1 }

	return SMODS.Stake(stake_definition)
end

-- === atlas.lua ===
SMODS.Atlas({
	key = "sandbox_stakes",
	path = "stakes-chips.png",
	px = 29,
	py = 29,
})

SMODS.Atlas({
	key = "alt_mp_stakes",
	path = "alt_mp_stakes.png",
	px = 29,
	py = 29,
})

-- === 00_planet.lua ===
SMODS.Stake({
	name = "Planet Stake",
	key = "planet",
	unlocked = true,
	applied_stakes = {},
	above_stake = "gold",
	atlas = "sandbox_stakes",
	pos = { x = 0, y = 0 },
	sticker_pos = { x = 3, y = 1 },
	modifiers = function()
		G.GAME.modifiers.no_blind_reward = G.GAME.modifiers.no_blind_reward or {}
		G.GAME.modifiers.no_blind_reward.Small = true
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
		G.GAME.modifiers.enable_eternals_in_shop = true
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
		G.GAME.modifiers.enable_perishables_in_shop = true
	end,
	colour = G.C.Planet,
})

-- === 01_spectral.lua ===
SMODS.Stake({
	name = "Spectral Stake",
	unlocked = true,
	key = "spectral",
	applied_stakes = { "planet" },
	atlas = "sandbox_stakes",
	pos = { x = 1, y = 0 },
	sticker_pos = { x = 3, y = 1 },
	modifiers = function()
		G.GAME.modifiers.enable_rentals_in_shop = true -- gold
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("000000"),
	above_stake = "planet",
})

-- === 02_spectralplus.lua ===
SMODS.Stake({
	name = "Spectral+ Stake",
	unlocked = true,
	key = "spectralplus",
	applied_stakes = { "spectral" },
	atlas = "sandbox_stakes",
	pos = { x = 2, y = 0 },
	sticker_pos = { x = 3, y = 1 },
	modifiers = function()
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("000000"),
	shiny = true,
	above_stake = "spectral",
})

-- === 1_plastic.lua ===
if MP.EXPERIMENTAL.alt_stakes then
	local BASE_INTEREST_RATE = 5
	local PLASTIC_INTEREST_RATE = 10

	local function get_interest_rate()
		return G.GAME.modifiers and G.GAME.modifiers.mp_modified_interest_rate or BASE_INTEREST_RATE
	end

	local function scale_interest_value(value)
		return value / (BASE_INTEREST_RATE / get_interest_rate())
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

-- === 2_pebble.lua ===
MP.STAKES.register_alt_stake({
	name = "Pebble Stake",
	key = "pebble",
	applied_stakes = { "plastic" },
	above_stake = "plastic",
	pos = { x = 2, y = 0 },
	modifiers = function()
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("949494"),
})

-- === 3_ferrite.lua ===
MP.STAKES.register_alt_stake({
	name = "Ferrite Stake",
	key = "ferrite",
	applied_stakes = { "pebble" },
	above_stake = "pebble",
	pos = { x = 3, y = 0 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_persistent_jokers = true
	end,
	colour = HEX("B2B2B2"),
})

-- === 4_pyrite.lua ===
MP.STAKES.register_alt_stake({
	name = "Pyrite Stake",
	key = "pyrite",
	applied_stakes = { "ferrite" },
	above_stake = "ferrite",
	pos = { x = 4, y = 0 },
	modifiers = function()
		G.GAME.modifiers.mp_extra_reroll_increment = 1
	end,
	colour = HEX("F2D955"),
})

if MP.EXPERIMENTAL.alt_stakes and not MP._extra_reroll_cost_patch_installed then
	MP._extra_reroll_cost_patch_installed = true
	local calculate_reroll_cost_ref = calculate_reroll_cost
	function calculate_reroll_cost(skip_increment)
		calculate_reroll_cost_ref(skip_increment)
		if G.GAME.modifiers and G.GAME.modifiers.mp_extra_reroll_increment then
			if not skip_increment then
				G.GAME.current_round.reroll_cost_increase = G.GAME.current_round.reroll_cost_increase
					+ G.GAME.modifiers.mp_extra_reroll_increment
			end
			G.GAME.current_round.reroll_cost = (G.GAME.round_resets.temp_reroll_cost or G.GAME.round_resets.reroll_cost)
				+ G.GAME.current_round.reroll_cost_increase
		end
	end
end

-- === 5_jade.lua ===
MP.STAKES.register_alt_stake({
	name = "Jade Stake",
	key = "jade",
	applied_stakes = { "pyrite" },
	above_stake = "pyrite",
	pos = { x = 0, y = 1 },
	modifiers = function()
		G.GAME.modifiers.scaling = (G.GAME.modifiers.scaling or 1) + 1
	end,
	colour = HEX("3EA93C"),
})

-- === 6_crystal.lua ===
MP.STAKES.register_alt_stake({
	name = "Crystal Stake",
	key = "crystal",
	applied_stakes = { "jade" },
	above_stake = "jade",
	pos = { x = 1, y = 1 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_unreliable_jokers = true
	end,
	colour = HEX("BCF9FF"),
	shiny = true,
})

-- === 7_antimatter.lua ===
MP.STAKES.register_alt_stake({
	name = "Antimatter Stake",
	key = "antimatter",
	applied_stakes = { "crystal" },
	above_stake = "crystal",
	pos = { x = 2, y = 1 },
	modifiers = function()
		G.GAME.modifiers.mp_enable_draining_jokers = true
	end,
	colour = HEX("4F6367"),
	shiny = true,
})

