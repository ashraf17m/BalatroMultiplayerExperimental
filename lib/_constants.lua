MP.LOBBY_TYPES = {
	ONE_V_ONE = "1v1",
	FFA = "ffa",
	TEAMS = "teams",
	DUELS = "duels",
	COOP = "coop",
}

MP.LOBBY_TYPE_SPECS = {
	[MP.LOBBY_TYPES.ONE_V_ONE] = {
		id = MP.LOBBY_TYPES.ONE_V_ONE,
		selection_order = 1,
		is_group = false,
		uses_teams = false,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.GREEN,
		},
	},
	[MP.LOBBY_TYPES.FFA] = {
		id = MP.LOBBY_TYPES.FFA,
		selection_order = 2,
		is_group = true,
		uses_teams = false,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.GREEN,
		},
	},
	[MP.LOBBY_TYPES.TEAMS] = {
		id = MP.LOBBY_TYPES.TEAMS,
		selection_order = 3,
		is_group = true,
		uses_teams = true,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.GREEN,
		},
	},
	[MP.LOBBY_TYPES.DUELS] = {
		id = MP.LOBBY_TYPES.DUELS,
		selection_order = 4,
		is_group = true,
		uses_teams = false,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.GREEN,
		},
	},
	[MP.LOBBY_TYPES.COOP] = {
		id = MP.LOBBY_TYPES.COOP,
		selection_order = 5,
		is_group = true,
		uses_teams = false,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.GREEN,
		},
	},
}

function MP.get_lobby_type_spec(lobby_type)
	return MP.LOBBY_TYPE_SPECS and MP.LOBBY_TYPE_SPECS[lobby_type] or nil
end

function MP.is_group_lobby_type(lobby_type)
	local spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
	return not not (spec and spec.is_group)
end

MP.TEAM_COLORS = {
	HEX("E43D3D"),
	HEX("3F5BFF"),
	HEX("24B24B"),
	HEX("F08A1A"),
	HEX("8A4DFF"),
	HEX("10B8E8"),
	HEX("F7C948"),
	HEX("D94BC8"),
}

MP.TEAM_NAMES = {
	"RED",
	"BLUE",
	"GREEN",
	"ORANGE",
	"PURPLE",
	"CYAN",
	"YELLOW",
	"MAGENTA"
}

MP.MAX_TEAMS = #MP.TEAM_NAMES
MP.MIN_GROUP_LOBBY_PLAYERS = 3
MP.DEFAULT_GROUP_LOBBY_PLAYERS = 16
MP.MAX_GROUP_LOBBY_PLAYERS = 100
MP.DEFAULT_STARTING_LIVES = 4
MP.DEFAULT_HANDS_PER_ROUND = 4
MP.DEFAULT_LOBBY_CREATION_RULESET = "ruleset_mp_standard_ranked"
MP.DEFAULT_LOBBY_CREATION_GAMEMODE = "gamemode_mp_attrition"
