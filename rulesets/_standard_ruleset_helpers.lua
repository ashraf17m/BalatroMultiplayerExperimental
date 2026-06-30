local function apply_ruleset_options(definition, options)
	for key, value in pairs(options or {}) do
		if key ~= "forced_gamemode_text" and key ~= "create_info_menu" then
			definition[key] = value
		end
	end
	return definition
end

local function normalize_layers(layers)
	if layers == nil then
		return {}
	end
	if type(layers) == "string" then
		return { layers }
	end
	return layers
end

local function has_layer(layers, layer_name)
	for _, name in ipairs(layers) do
		if name == layer_name then
			return true
		end
	end
	return false
end

local function with_standard_ruleset_layer(definition)
	local layers = normalize_layers(definition.layers)
	if not has_layer(layers, "standard") then
		table.insert(layers, 1, "standard")
	end
	definition.layers = layers
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
	return MP.Ruleset(with_standard_ruleset_layer(definition)):inject()
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
