SMODS.Atlas({
	key = "player_blind_chip",
	path = "player_blind_row.png",
	atlas_table = "ANIMATION_ATLAS",
	frames = 21,
	px = 34,
	py = 34,
})

SMODS.Atlas({
	key = "player_blind_col",
	path = "blind_col.png",
	atlas_table = "ANIMATION_ATLAS",
	frames = 21,
	px = 34,
	py = 34,
})

SMODS.Blind({
	key = "nemesis",
	dollars = 5,
	mult = 2, -- Boss Blind mult (was 1, which caused PvP baseline to fall back to Small Blind)
	boss_colour = G.C.MULTIPLAYER,
	boss = { min = 1, max = 10 },
	atlas = "player_blind_col",
	discovered = true,
	in_pool = function(self)
		return false
	end,
})
