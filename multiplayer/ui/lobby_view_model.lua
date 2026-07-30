MP.UI = MP.UI or {}
MP.UI.LOBBY_VIEW_MODEL = MP.UI.LOBBY_VIEW_MODEL or {}

local view_model = MP.UI.LOBBY_VIEW_MODEL

local function get_lobby_context()
	return MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
end

local LOBBY_OPTIONS_TAB_SPECS = {
	{
		id = "general",
		label_key = "k_lobby_general",
		build = function()
			return MP.UI.create_lobby_options_tab()
		end,
	},
	{
		id = "gameplay",
		label_key = "k_lobby_gameplay",
		when = function()
			return not (MP.is_coop_gamemode and MP.is_coop_gamemode())
		end,
		build = function()
			return MP.UI.create_gameplay_options_tab()
		end,
	},
	{
		id = "modifiers",
		label_key = "k_lobby_modifiers",
		when = function()
			return not (MP.is_coop_gamemode and MP.is_coop_gamemode())
		end,
		build = function()
			return MP.UI.create_gamemode_modifiers_tab()
		end,
	},
	{
		id = "bonuses",
		label_key = "k_lobby_bonuses",
		build = function()
			return MP.UI.create_bonuses_options_tab()
		end,
	},
	{
		id = "advanced",
		label_key = "k_lobby_advanced",
		build = function()
			return MP.UI.create_advanced_options_tab()
		end,
	},
}

local function is_lobby_options_tab_available(spec)
	return not spec.when or spec.when()
end

local function build_lobby_options_tab_definition(spec, chosen)
	return {
		label = localize(spec.label_key),
		chosen = chosen,
		tab_definition_function = function()
			view_model.active_lobby_options_tab = spec.id
			return spec.build()
		end,
	}
end

function view_model.create_lobby_type_options_button(text_scale, lobby_context)
	lobby_context = lobby_context or get_lobby_context()
	if lobby_context.match_in_progress or lobby_context.is_saved_coop_restore then
		return nil
	end

	local lobby_type_spec = MP.get_lobby_type_spec and MP.get_lobby_type_spec(lobby_context.lobby_type) or nil
	local button_spec = lobby_type_spec and lobby_type_spec.lobby_options_button or nil
	if not button_spec then
		return nil
	end

	return UIBox_button({
		button = button_spec.button,
		colour = button_spec.colour,
		minw = 3.15,
		minh = 1.35,
		label = {
			localize(button_spec.label_key),
		},
		scale = text_scale * 1.2,
		col = true,
	})
end

function view_model.build_lobby_menu_state()
	local text_scale = 0.45
	local lobby_context = get_lobby_context()
	local effective_deck = lobby_context.effective_deck or {}
	local self_team = lobby_context.self_team_id or 1

	return {
		text_scale = text_scale,
		lobby_context = lobby_context,
		back = effective_deck.back,
		stake = effective_deck.stake,
		lobby_type_options_button = view_model.create_lobby_type_options_button(text_scale, lobby_context),
		team_color = MP.TEAM_COLORS[self_team] or G.C.WHITE,
		team_name = (MP.TEAM_NAMES[self_team] or "RED") .. " TEAM",
	}
end

function view_model.build_lobby_options_state()
	local lobby_context = get_lobby_context()
	local active_tab_id = view_model.active_lobby_options_tab or "general"
	local tab_definitions = {}
	local active_tab_available = false

	for _, spec in ipairs(LOBBY_OPTIONS_TAB_SPECS) do
		if is_lobby_options_tab_available(spec) and spec.id == active_tab_id then
			active_tab_available = true
			break
		end
	end

	if not active_tab_available then
		active_tab_id = "general"
		view_model.active_lobby_options_tab = active_tab_id
	end

	for _, spec in ipairs(LOBBY_OPTIONS_TAB_SPECS) do
		if is_lobby_options_tab_available(spec) then
			tab_definitions[#tab_definitions + 1] = build_lobby_options_tab_definition(spec, spec.id == active_tab_id)
		end
	end

	return {
		lobby_context = lobby_context,
		show_host_notice = not lobby_context.is_host,
		tab_definitions = tab_definitions,
	}
end
