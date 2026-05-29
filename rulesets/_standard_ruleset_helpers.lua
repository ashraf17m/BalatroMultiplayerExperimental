local function apply_ruleset_options(definition, options)
	for key, value in pairs(options or {}) do
		if key ~= "forced_gamemode_text" and key ~= "create_info_menu" then
			definition[key] = value
		end
	end
	return definition
end

function MP.create_standard_ruleset_info_menu(description_key, options)
	options = options or {}
	local info_options = {}
	for key, value in pairs(options) do
		info_options[key] = value
	end
	info_options.multiplayer_content = true
	return MP.create_ruleset_info_menu(description_key, info_options)
end

function MP.create_ruleset_info_menu(description_key, options)
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

function MP.inject_standard_ruleset_in_group(group_key, group_order, key, selection_order, description_key, options)
	options = options or {}
	local definition = {
		key = key,
		selection_group_key = group_key,
		selection_group_order = group_order,
		selection_order = selection_order,
		create_info_menu = options.create_info_menu or MP.create_standard_ruleset_info_menu(description_key, options),
	}
	apply_ruleset_options(definition, options)
	return MP.Ruleset(MP.with_standard_ruleset_defaults(definition)):inject()
end

function MP.inject_custom_standard_ruleset(key, selection_order, description_key, options)
	return MP.inject_standard_ruleset_in_group("k_custom", 2, key, selection_order, description_key, options)
end

function MP.inject_matchmaking_standard_ruleset(key, selection_order, description_key, options)
	return MP.inject_standard_ruleset_in_group("k_matchmaking", 1, key, selection_order, description_key, options)
end

function MP.inject_empty_ruleset_in_group(group_key, group_order, key, selection_order, description_key, options)
	options = options or {}
	local definition = {
		key = key,
		selection_group_key = group_key,
		selection_group_order = group_order,
		selection_order = selection_order,
		multiplayer_content = options.multiplayer_content or false,
		create_info_menu = options.create_info_menu or MP.create_ruleset_info_menu(description_key, options),
	}
	apply_ruleset_options(definition, options)
	return MP.Ruleset(MP.UTILS.with_empty_content_lists(definition)):inject()
end

function MP.inject_custom_empty_ruleset(key, selection_order, description_key, options)
	return MP.inject_empty_ruleset_in_group("k_custom", 2, key, selection_order, description_key, options)
end

function MP.inject_matchmaking_empty_ruleset(key, selection_order, description_key, options)
	return MP.inject_empty_ruleset_in_group("k_matchmaking", 1, key, selection_order, description_key, options)
end

function MP.inject_tournament_empty_ruleset(key, selection_order, description_key, options)
	return MP.inject_empty_ruleset_in_group("k_tournament", 3, key, selection_order, description_key, options)
end
