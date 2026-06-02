local function apply_ruleset_options(definition, options)
	for key, value in pairs(options or {}) do
		if key ~= "forced_gamemode_text" and key ~= "create_info_menu" then
			definition[key] = value
		end
	end
	return definition
end

local standard_ruleset_silent_bans = {
	"j_hanging_chad",
	"j_ticket",
	"j_selzer",
	"j_turtle_bean",
	"j_bloodstone",
	"c_ouija",
}

local standard_ruleset_reworked_jokers = {
	"j_mp_hanging_chad",
	"j_mp_ticket",
	"j_mp_seltzer",
	"j_mp_turtle_bean",
}

local function copy_list(list)
	local copy = {}
	for i, value in ipairs(list) do
		copy[i] = value
	end
	return copy
end

local function apply_list_default(definition, key, list)
	if definition[key] == nil then
		definition[key] = copy_list(list)
	end
end

local function with_standard_ruleset_defaults(definition)
	definition.multiplayer_content = true
	definition.standard = true
	apply_list_default(definition, "banned_silent", standard_ruleset_silent_bans)
	apply_list_default(definition, "banned_jokers", {})
	apply_list_default(definition, "banned_consumables", { "c_justice" })
	apply_list_default(definition, "banned_vouchers", {})
	apply_list_default(definition, "banned_enhancements", {})
	apply_list_default(definition, "banned_tags", {})
	apply_list_default(definition, "banned_blinds", {})
	apply_list_default(definition, "reworked_jokers", standard_ruleset_reworked_jokers)
	apply_list_default(definition, "reworked_consumables", { "c_mp_ouija_standard" })
	apply_list_default(definition, "reworked_vouchers", {})
	apply_list_default(definition, "reworked_enhancements", { "m_mp_display_glass" })
	apply_list_default(definition, "reworked_tags", {})
	apply_list_default(definition, "reworked_blinds", {})
	return definition
end

local function create_ruleset_info_menu(description_key, options)
	options = options or {}
	return function()
		return MP.UI.CreateRulesetInfoMenu({
			multiplayer_content = options.multiplayer_content or false,
			forced_lobby_options = options.forced_lobby_options or false,
			forced_gamemode_text = options.forced_gamemode_text,
			description_key = description_key,
		})
	end
end

local function create_standard_ruleset_info_menu(description_key, options)
	options = options or {}
	local info_options = {}
	for key, value in pairs(options) do
		info_options[key] = value
	end
	info_options.multiplayer_content = true
	return create_ruleset_info_menu(description_key, info_options)
end

local function inject_standard_ruleset_in_group(group_key, group_order, key, selection_order, description_key, options)
	options = options or {}
	local definition = {
		key = key,
		selection_group_key = group_key,
		selection_group_order = group_order,
		selection_order = selection_order,
		create_info_menu = options.create_info_menu or create_standard_ruleset_info_menu(description_key, options),
	}
	apply_ruleset_options(definition, options)
	return MP.Ruleset(with_standard_ruleset_defaults(definition)):inject()
end

function MP.inject_custom_standard_ruleset(key, selection_order, description_key, options)
	return inject_standard_ruleset_in_group("k_custom", 2, key, selection_order, description_key, options)
end

function MP.inject_matchmaking_standard_ruleset(key, selection_order, description_key, options)
	return inject_standard_ruleset_in_group("k_matchmaking", 1, key, selection_order, description_key, options)
end

local function inject_empty_ruleset_in_group(group_key, group_order, key, selection_order, description_key, options)
	options = options or {}
	local definition = {
		key = key,
		selection_group_key = group_key,
		selection_group_order = group_order,
		selection_order = selection_order,
		multiplayer_content = options.multiplayer_content or false,
		create_info_menu = options.create_info_menu or create_ruleset_info_menu(description_key, options),
	}
	apply_ruleset_options(definition, options)
	return MP.Ruleset(MP.UTILS.with_empty_content_lists(definition)):inject()
end

function MP.inject_custom_empty_ruleset(key, selection_order, description_key, options)
	return inject_empty_ruleset_in_group("k_custom", 2, key, selection_order, description_key, options)
end

function MP.inject_matchmaking_empty_ruleset(key, selection_order, description_key, options)
	return inject_empty_ruleset_in_group("k_matchmaking", 1, key, selection_order, description_key, options)
end

function MP.inject_tournament_empty_ruleset(key, selection_order, description_key, options)
	return inject_empty_ruleset_in_group("k_tournament", 3, key, selection_order, description_key, options)
end
