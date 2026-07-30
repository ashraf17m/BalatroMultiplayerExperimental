MP.UI = MP.UI or {}
MP.UI.MAIN_MENU_SELECTION = MP.UI.MAIN_MENU_SELECTION or {}

local selection = MP.UI.MAIN_MENU_SELECTION
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local selection_utils = MP.UTILS

local TOURNAMENT_RULESET_KEYS = {
	speedlatro = true,
	badlatro = true,
	chaos = true,
}

local EXPERIMENTAL_RULESET_KEYS = {
	experimental = true,
	experimental_legacy = true,
}

local RULESET_SELECTION_TABS = {
	{
		label_key = "k_mp_ruleset_tab_general",
		fallback_label = "General",
		include_ruleset = function(ruleset, selection_key)
			local group_key = ruleset.selection_group_key
			return (group_key == "k_matchmaking" or group_key == "k_custom")
				and not TOURNAMENT_RULESET_KEYS[selection_key]
				and not EXPERIMENTAL_RULESET_KEYS[selection_key]
		end,
	},
	{
		label_key = "k_mp_ruleset_tab_tournaments",
		fallback_label = "Tournaments",
		include_ruleset = function(ruleset, selection_key)
			return ruleset.selection_group_key == "k_tournament" or TOURNAMENT_RULESET_KEYS[selection_key]
		end,
		group_key = function(ruleset, selection_key)
			return TOURNAMENT_RULESET_KEYS[selection_key] and "k_custom" or (ruleset.selection_group_key or "k_tournament")
		end,
		group_order = function(_, _, group_key)
			return group_key == "k_tournament" and 1 or 2
		end,
	},
	{
		label_key = "k_mp_ruleset_tab_experimental",
		fallback_label = "Experimental",
		include_ruleset = function(ruleset, selection_key)
			return ruleset.selection_group_key == "k_experimental" or EXPERIMENTAL_RULESET_KEYS[selection_key]
		end,
		group_key = function()
			return "k_experimental"
		end,
		group_order = function()
			return 1
		end,
	},
}

local function localize_or_fallback(key, fallback)
	local ok, localized = pcall(localize, key)
	if ok and type(localized) == "string" and localized ~= "" and localized ~= key and localized ~= "ERROR" then
		return localized
	end
	return fallback
end

local function compare_selection_entries(a, b)
	if a.group_order ~= b.group_order then
		return a.group_order < b.group_order
	end
	if a.selection_order ~= b.selection_order then
		return a.selection_order < b.selection_order
	end
	return a.selection_key < b.selection_key
end

local function build_default_area(definition)
	return UIBox({
		definition = definition,
		config = { align = "cm" },
	})
end

local function get_gamemode_selection_name(gamemode_key)
	return selection_utils.strip_selection_prefix(gamemode_key, "gamemode_mp_")
end

function selection.get_gamemode_selection_button_id(gamemode_key)
	return get_gamemode_selection_name(gamemode_key) .. "_gamemode_button"
end

function selection.build_gamemode_selection_buttons_data()
	return selection_utils.build_grouped_selection_buttons_data(MP.Gamemodes, {
		key_prefix = "gamemode_mp_",
		default_group_key = "k_challenge",
		get_button_id = function(gamemode)
			return selection.get_gamemode_selection_button_id(gamemode.key)
		end,
	})
end

local function get_ruleset_selection_name(ruleset_key)
	return selection_utils.strip_selection_prefix(ruleset_key, "ruleset_mp_")
end

function selection.get_ruleset_selection_button_id(ruleset_key)
	return get_ruleset_selection_name(ruleset_key) .. "_ruleset_button"
end

local function build_ruleset_buttons_data_for_tab(tab_spec)
	local grouped_categories = {}
	local category_order = {}
	local ordered_entries = {}

	for _, ruleset in pairs(MP.Rulesets or {}) do
		local selection_key = get_ruleset_selection_name(ruleset.key)
		if tab_spec.include_ruleset(ruleset, selection_key) then
			local group_key = tab_spec.group_key and tab_spec.group_key(ruleset, selection_key)
				or ruleset.selection_group_key
				or "k_custom"
			local group_order = tab_spec.group_order and tab_spec.group_order(ruleset, selection_key, group_key)
				or tonumber(ruleset.selection_group_order)
				or 99

			ordered_entries[#ordered_entries + 1] = {
				ruleset = ruleset,
				selection_key = selection_key,
				group_key = group_key,
				group_order = group_order,
				selection_order = tonumber(ruleset.selection_order) or 999,
			}
		end
	end

	table.sort(ordered_entries, compare_selection_entries)

	for _, entry in ipairs(ordered_entries) do
		local category = grouped_categories[entry.group_key]
		if not category then
			category = {
				name = entry.group_key,
				buttons = {},
			}
			grouped_categories[entry.group_key] = category
			category_order[#category_order + 1] = category
		end

		category.buttons[#category.buttons + 1] = {
			button_id = selection.get_ruleset_selection_button_id(entry.ruleset.key),
			button_localize_key = entry.ruleset.selection_localize_key or ("k_" .. entry.selection_key),
			button_col = entry.ruleset.selection_button_colour,
		}
	end

	return category_order
end

local function first_ruleset_key_from_buttons_data(buttons_data)
	for _, category in ipairs(buttons_data or {}) do
		for _, button in ipairs(category.buttons or {}) do
			local selection_key = string.match(button.button_id or "", "(.+)_ruleset_button$")
			if selection_key then
				return "ruleset_mp_" .. selection_key
			end
		end
	end
	return nil
end

local function ruleset_key_belongs_to_tab(ruleset_key, tab_spec)
	local ruleset = MP.Rulesets and MP.Rulesets[ruleset_key] or nil
	if not ruleset then
		return false
	end
	return tab_spec.include_ruleset(ruleset, get_ruleset_selection_name(ruleset_key))
end

function selection.set_ruleset_selection_mode(mode)
	selection.ruleset_selection_mode = "lobby"
	return selection.ruleset_selection_mode
end

function selection.get_ruleset_selection_mode()
	return selection.ruleset_selection_mode or "lobby"
end

function selection.build_ruleset_selection_buttons_data(args)
	args = args or {}
	if args.tab_spec then
		return build_ruleset_buttons_data_for_tab(args.tab_spec)
	end

	return selection_utils.build_grouped_selection_buttons_data(MP.Rulesets, {
		key_prefix = "ruleset_mp_",
		default_group_key = "k_custom",
		get_button_id = function(ruleset)
			return selection.get_ruleset_selection_button_id(ruleset.key)
		end,
	})
end

function selection.build_gamemode_selection_options(initial_gamemode_key, options)
	options = options or {}
	local fallback_gamemode_key = MP.DEFAULT_LOBBY_CREATION_GAMEMODE or "gamemode_mp_attrition"
	local gamemode_key = initial_gamemode_key or fallback_gamemode_key
	if not (MP.Gamemodes and MP.Gamemodes[gamemode_key]) then
		gamemode_key = fallback_gamemode_key
	end
	lobby_domain.set_creation_gamemode(gamemode_key)
	local gamemode_name = get_gamemode_selection_name(gamemode_key)

	local gamemode_buttons_data = selection.build_gamemode_selection_buttons_data()
		or {}

	return MP.UI.Main_Lobby_Options(
		"gamemode_area",
		build_default_area(G.UIDEF.gamemode_info(gamemode_name)),
		"change_gamemode_selection",
		gamemode_buttons_data,
		selection.get_gamemode_selection_button_id(gamemode_key),
		{
			raw = options.raw,
			back_func = options.back_func or "return_to_ruleset_selection",
		}
	)
end

function selection.build_gamemode_selection_tabs(initial_gamemode_key, options)
	options = options or {}
	return create_UIBox_generic_options({
		back_func = options.back_func or "return_to_ruleset_selection",
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					create_tabs({
						tabs = {
							{
								label = localize("k_gamemodes"),
								chosen = true,
								tab_definition_function = function()
									return selection.build_gamemode_selection_options(initial_gamemode_key, {
										raw = true,
									})
								end,
							},
						},
						colour = G.C.BOOSTER,
					}),
				},
			},
		},
	})
end

function selection.apply_ruleset_selection(ruleset_name)
	if MP.CUSTOM and MP.CUSTOM.clear_pending_lobby_options then
		MP.CUSTOM.clear_pending_lobby_options()
	end
	lobby_domain.set_creation_ruleset("ruleset_mp_" .. ruleset_name)
	if MP.apply_default_modifiers then
		MP.apply_default_modifiers(ruleset_name)
	end
	MP.LoadReworks(ruleset_name)
end

local function apply_default_ruleset(ruleset_name)
	if lobby_domain.set_setup_fetched_weekly then
		lobby_domain.set_setup_fetched_weekly("smallworld")
	end

	selection.apply_ruleset_selection(ruleset_name)
end

function selection.build_ruleset_selection_options(initial_ruleset_key, options)
	options = options or {}
	local mode = selection.set_ruleset_selection_mode(options.mode)
	local default_ruleset_key = initial_ruleset_key or MP.DEFAULT_LOBBY_CREATION_RULESET
	if not (MP.Rulesets and MP.Rulesets[default_ruleset_key]) then
		default_ruleset_key = MP.DEFAULT_LOBBY_CREATION_RULESET
	end
	local default_ruleset = string.sub(default_ruleset_key, 12, -1)

	if options.preserve_modifiers then
		if MP.CUSTOM and MP.CUSTOM.clear_pending_lobby_options then
			MP.CUSTOM.clear_pending_lobby_options()
		end
		lobby_domain.set_creation_ruleset(default_ruleset_key)
		MP.LoadReworks(default_ruleset)
	else
		apply_default_ruleset(default_ruleset)
	end

	local ruleset_buttons_data = options.buttons_data or selection.build_ruleset_selection_buttons_data() or {}

	return MP.UI.Main_Lobby_Options(
		"ruleset_area",
		build_default_area(G.UIDEF.ruleset_info(default_ruleset)),
		"change_ruleset_selection",
		ruleset_buttons_data,
		selection.get_ruleset_selection_button_id(default_ruleset_key),
		{
			raw = options.raw,
			back_func = options.back_func or "play_options",
		}
	)
end

function selection.build_ruleset_selection_tabs(initial_ruleset_key, options)
	if type(options) == "string" then
		options = { chosen_label = options }
	end
	options = options or {}
	if initial_ruleset_key == "mp" or initial_ruleset_key == "lobby" then
		options.mode = "lobby"
		initial_ruleset_key = nil
	elseif initial_ruleset_key == "sp" then
		initial_ruleset_key = nil
	end

	local requested_ruleset_key = initial_ruleset_key
		or MP.DEFAULT_LOBBY_CREATION_RULESET
	local tabs = {}
	local has_chosen_tab = false

	for _, tab_spec in ipairs(RULESET_SELECTION_TABS) do
		local buttons_data = selection.build_ruleset_selection_buttons_data({ tab_spec = tab_spec })
		local tab_ruleset_key = first_ruleset_key_from_buttons_data(buttons_data)
		if tab_ruleset_key then
			local requested_key_belongs_here = ruleset_key_belongs_to_tab(requested_ruleset_key, tab_spec)
			local tab_label = localize_or_fallback(tab_spec.label_key, tab_spec.fallback_label)
			local chosen_by_label = options.chosen_label and tab_label == options.chosen_label
			if requested_key_belongs_here then
				tab_ruleset_key = requested_ruleset_key
			end

			local tab = {
				label = tab_label,
				chosen = chosen_by_label or (requested_key_belongs_here and not options.chosen_label),
				tab_definition_function = function()
					return selection.build_ruleset_selection_options(tab_ruleset_key, {
						mode = options.mode,
						preserve_modifiers = options.preserve_modifiers and requested_key_belongs_here,
						buttons_data = buttons_data,
						raw = true,
					})
				end,
			}

			if tab.chosen then
				has_chosen_tab = true
			end
			tabs[#tabs + 1] = tab
		end
	end

	if MP.UI.build_custom_ruleset_editor then
		local custom_label = "Custom"
		local custom_chosen = options.chosen_label == custom_label
		tabs[#tabs + 1] = {
			label = custom_label,
			chosen = custom_chosen,
			tab_definition_function = function()
				return MP.UI.build_custom_ruleset_editor(options.mode or "lobby")
			end,
		}
		if custom_chosen then
			has_chosen_tab = true
		end
	end

	if not has_chosen_tab and tabs[1] then
		tabs[1].chosen = true
	end

	if #tabs == 0 then
		return selection.build_ruleset_selection_options(requested_ruleset_key, options)
	end

	return create_UIBox_generic_options({
		back_func = options.back_func or "play_options",
		contents = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0 },
				nodes = {
					create_tabs({
						tabs = tabs,
						colour = G.C.BOOSTER,
					}),
				},
			},
		},
	})
end
