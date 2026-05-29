MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION

function selection.set_ruleset_selection_mode(mode)
	mode = mode or "mp"
	selection.ruleset_selection_mode = mode
	MP.UI.ruleset_selection_mode = mode
	return mode
end

function selection.get_ruleset_selection_mode()
	return selection.ruleset_selection_mode or MP.UI.ruleset_selection_mode or "mp"
end

local function create_selection_options(area_id, default_area, change_callback, buttons_data)
	return MP.UI.Main_Lobby_Options(area_id, default_area, change_callback, buttons_data)
end

local function build_default_area(definition)
	return UIBox({
		definition = definition,
		config = { align = "cm" },
	})
end

function selection.build_gamemode_selection_options()
	MP.set_lobby_creation_gamemode(MP.DEFAULT_LOBBY_CREATION_GAMEMODE)

	local gamemode_buttons_data = MP.build_gamemode_selection_buttons_data and MP.build_gamemode_selection_buttons_data()
		or {}

	return create_selection_options(
		"gamemode_area",
		build_default_area(G.UIDEF.gamemode_info("attrition")),
		"change_gamemode_selection",
		gamemode_buttons_data
	)
end

local function get_default_ruleset_name()
	return string.sub(MP.DEFAULT_LOBBY_CREATION_RULESET, 12, -1)
end

function selection.apply_ruleset_selection(mode, ruleset_name)
	if mode == "sp" then
		MP.SP.ruleset = "ruleset_mp_" .. ruleset_name
	else
		MP.set_lobby_creation_ruleset("ruleset_mp_" .. ruleset_name)
	end

	MP.LoadReworks(ruleset_name)
end

local function apply_default_ruleset(mode, ruleset_name)
	if MP.set_lobby_setup_fetched_weekly then
		MP.set_lobby_setup_fetched_weekly("smallworld")
	end

	selection.apply_ruleset_selection(mode, ruleset_name)
end

function selection.build_ruleset_selection_options(mode)
	mode = selection.set_ruleset_selection_mode(mode or "mp")

	local default_ruleset = get_default_ruleset_name()
	apply_default_ruleset(mode, default_ruleset)

	local ruleset_buttons_data = MP.build_ruleset_selection_buttons_data and MP.build_ruleset_selection_buttons_data()
		or {}

	return create_selection_options(
		"ruleset_area",
		build_default_area(G.UIDEF.ruleset_info(default_ruleset, mode)),
		"change_ruleset_selection",
		ruleset_buttons_data
	)
end
