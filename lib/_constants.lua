MP.BANNED_MODS = {
	["Incantation"] = true,
	["Brainstorm"] = true,
	["DVPreview"] = true,
	["Aura"] = true,
	["NotJustYet"] = true,
	["Showman"] = true,
	["TagPreview"] = true,
	["FantomsPreview"] = true,
}

MP.LOBBY_TYPES = {
	ONE_V_ONE = "1v1",
	FFA = "ffa",
	TEAMS = "teams",
}

MP.LOBBY_TYPE_SPECS = {
	[MP.LOBBY_TYPES.ONE_V_ONE] = {
		id = MP.LOBBY_TYPES.ONE_V_ONE,
		selection_order = 1,
		is_group = false,
		uses_teams = false,
		create_button_id = "create_1v1_lobby",
		create_button_localize_key = "b_create_1v1_lobby",
		create_button_colour = G.C.GREEN,
	},
	[MP.LOBBY_TYPES.FFA] = {
		id = MP.LOBBY_TYPES.FFA,
		selection_order = 2,
		is_group = true,
		uses_teams = false,
		create_button_id = "create_ffa_lobby",
		create_button_localize_key = "b_create_ffa_lobby",
		create_button_colour = G.C.PURPLE,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.BLUE,
		},
	},
	[MP.LOBBY_TYPES.TEAMS] = {
		id = MP.LOBBY_TYPES.TEAMS,
		selection_order = 3,
		is_group = true,
		uses_teams = true,
		create_button_id = "create_teams_lobby",
		create_button_localize_key = "b_create_teams_lobby",
		create_button_colour = G.C.ORANGE,
		lobby_options_button = {
			button = "view_group_options",
			label_key = "k_group_options",
			colour = G.C.BLUE,
		},
	},
}

function MP.get_lobby_type_spec(lobby_type)
	return MP.LOBBY_TYPE_SPECS and MP.LOBBY_TYPE_SPECS[lobby_type] or nil
end

function MP.get_lobby_type_specs()
	local ordered_specs = {}

	for _, spec in pairs(MP.LOBBY_TYPE_SPECS or {}) do
		ordered_specs[#ordered_specs + 1] = spec
	end

	table.sort(ordered_specs, function(a, b)
		if (a.selection_order or 99) ~= (b.selection_order or 99) then
			return (a.selection_order or 99) < (b.selection_order or 99)
		end

		return tostring(a.id or "") < tostring(b.id or "")
	end)

	return ordered_specs
end

function MP.is_group_lobby_type(lobby_type)
	local spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
	return not not (spec and spec.is_group)
end

function MP.is_team_lobby_type(lobby_type)
	local spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_type) or nil
	return not not (spec and spec.uses_teams)
end

function MP.is_head_to_head_lobby_type(lobby_type)
	return lobby_type == MP.LOBBY_TYPES.ONE_V_ONE
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
MP.MAX_GROUP_LOBBY_PLAYERS = 32
MP.DEFAULT_STARTING_LIVES = 4
MP.DEFAULT_HANDS_PER_ROUND = 4
MP.DEFAULT_LOBBY_CREATION_RULESET = "ruleset_mp_standard_ranked"
MP.DEFAULT_LOBBY_CREATION_GAMEMODE = "gamemode_mp_attrition"
