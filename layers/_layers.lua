MP.Layers = MP.Layers or {}

-- Reverse indices are populated for future layer-based object gating, but this
-- skeleton intentionally does not install the upstream default-deny pool hooks.
MP._JOKER_LAYERS = MP._JOKER_LAYERS or {}
MP._CONSUMABLE_LAYERS = MP._CONSUMABLE_LAYERS or {}
MP._TAG_LAYERS = MP._TAG_LAYERS or {}

MP._LAYER_ARRAY_FIELDS = MP._LAYER_ARRAY_FIELDS or {
	"banned_jokers",
	"banned_consumables",
	"banned_vouchers",
	"banned_enhancements",
	"banned_tags",
	"banned_blinds",
	"banned_silent",
	"reworked_jokers",
	"reworked_consumables",
	"reworked_vouchers",
	"reworked_enhancements",
	"reworked_tags",
	"reworked_blinds",
	"spectral_banned_enhancements",
	"stickers",
}

MP._LAYER_MAP_FIELDS = MP._LAYER_MAP_FIELDS or {
	"game_modifiers",
	"starting_params",
}

local layer_array_field_set = {}
for _, field in ipairs(MP._LAYER_ARRAY_FIELDS) do
	layer_array_field_set[field] = true
end

local layer_map_field_set = {}
for _, field in ipairs(MP._LAYER_MAP_FIELDS) do
	layer_map_field_set[field] = true
end

local function copy_value(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = copy_value(v)
	end
	return copy
end

local function merge_map(target, source)
	if type(source) ~= "table" then
		return target
	end

	target = target or {}
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			target[k] = merge_map(copy_value(target[k]), v)
		else
			target[k] = copy_value(v)
		end
	end
	return target
end

local function append_list(target, source)
	for _, item in ipairs(source or {}) do
		target[#target + 1] = item
	end
end

local function add_reverse_index_entries(index, layer_name, entries)
	for _, key in ipairs(entries or {}) do
		index[key] = index[key] or {}
		index[key][#index[key] + 1] = layer_name
	end
end

function MP.Layer(name, definition)
	if type(name) ~= "string" or name == "" then
		error("Layer name must be a non-empty string")
	end
	if type(definition) ~= "table" then
		error("Layer definition must be a table")
	end

	MP.Layers[name] = definition
	add_reverse_index_entries(MP._JOKER_LAYERS, name, definition.reworked_jokers)
	add_reverse_index_entries(MP._CONSUMABLE_LAYERS, name, definition.reworked_consumables)
	add_reverse_index_entries(MP._TAG_LAYERS, name, definition.reworked_tags)

	return definition
end

local function merge_layer_field(init, ruleset_owned, key, value)
	if layer_array_field_set[key] then
		local merged = {}
		append_list(merged, value)
		append_list(merged, init[key])
		init[key] = merged
		return
	end

	if layer_map_field_set[key] then
		init[key] = merge_map(type(init[key]) == "table" and init[key] or {}, value)
		return
	end

	if not ruleset_owned[key] then
		init[key] = copy_value(value)
	end
end

-- Resolve layers on the init table before SMODS validates required_params.
-- Scalars and map-like tables are last-layer-wins, with ruleset-owned fields
-- taking priority. Known ban/rework arrays are concatenated layer-first.
function MP.resolve_layers(init)
	if not init or not init.layers then
		return init
	end

	local ruleset_owned = {}
	local ruleset_owned_map_values = {}
	for key, value in pairs(init) do
		ruleset_owned[key] = true
		if layer_map_field_set[key] then
			ruleset_owned_map_values[key] = copy_value(value)
			init[key] = {}
		end
	end

	for _, layer_name in ipairs(init.layers) do
		local layer = MP.Layers[layer_name]
		if not layer then
			error("Unknown layer: " .. tostring(layer_name))
		end
		for key, value in pairs(layer) do
			merge_layer_field(init, ruleset_owned, key, value)
		end
	end

	for key, value in pairs(ruleset_owned_map_values) do
		init[key] = merge_map(type(init[key]) == "table" and init[key] or {}, value)
	end

	local layer_set = {}
	local layer_order = {}
	for _, layer_name in ipairs(init.layers) do
		layer_set[layer_name] = true
		layer_order[#layer_order + 1] = layer_name
	end
	init._layers = layer_set
	init._layer_order = layer_order
	init.layers = nil

	for _, field in ipairs(MP._LAYER_ARRAY_FIELDS) do
		if init[field] == nil then
			init[field] = {}
		end
	end

	return init
end

MP.MODIFIERS = MP.MODIFIERS or {}

function MP.has_modifier(name)
	for _, modifier_name in ipairs(MP.MODIFIERS) do
		if modifier_name == name then
			return true
		end
	end
	return false
end

function MP.add_modifier(name)
	if not name or name == "" or MP.has_modifier(name) then
		return
	end
	MP.MODIFIERS[#MP.MODIFIERS + 1] = name
end

function MP.remove_modifier(name)
	for i, modifier_name in ipairs(MP.MODIFIERS) do
		if modifier_name == name then
			table.remove(MP.MODIFIERS, i)
			return
		end
	end
end

function MP.modifiers_serialize()
	return table.concat(MP.MODIFIERS, ",")
end

function MP.modifiers_parse(value)
	MP.MODIFIERS = {}
	if not value or value == "" then
		return
	end
	for name in string.gmatch(value, "[^,]+") do
		MP.MODIFIERS[#MP.MODIFIERS + 1] = name
	end
end

function MP.apply_default_modifiers(ruleset_short)
	MP.MODIFIERS = {}
	if not ruleset_short then
		return
	end

	local ruleset = MP.Rulesets and MP.Rulesets["ruleset_mp_" .. ruleset_short] or nil
	if not ruleset or not ruleset.default_modifiers then
		return
	end
	for _, name in ipairs(ruleset.default_modifiers) do
		MP.add_modifier(name)
	end
end

function MP.get_active_ruleset()
	if MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config then
		return MP.LOBBY.config.ruleset
	end
	return nil
end

function MP.get_active_gamemode()
	if MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config then
		return MP.LOBBY.config.gamemode
	end
	return nil
end

local function resolve_current_field(field)
	local ruleset_key = MP.get_active_ruleset and MP.get_active_ruleset() or nil
	local ruleset = ruleset_key and MP.Rulesets and MP.Rulesets[ruleset_key] or nil

	if layer_array_field_set[field] then
		local merged = {}
		if ruleset and ruleset[field] then
			append_list(merged, ruleset[field])
		end
		for _, modifier_name in ipairs(MP.MODIFIERS or {}) do
			local layer = MP.Layers[modifier_name]
			if layer and layer[field] then
				append_list(merged, layer[field])
			end
		end
		return merged
	end

	if layer_map_field_set[field] then
		local merged = {}
		if ruleset and ruleset[field] then
			merge_map(merged, ruleset[field])
		end
		for _, modifier_name in ipairs(MP.MODIFIERS or {}) do
			local layer = MP.Layers[modifier_name]
			if layer and layer[field] then
				merge_map(merged, layer[field])
			end
		end
		return merged
	end

	for i = #(MP.MODIFIERS or {}), 1, -1 do
		local layer = MP.Layers[MP.MODIFIERS[i]]
		if layer and layer[field] ~= nil then
			return layer[field]
		end
	end
	if ruleset then
		return ruleset[field]
	end
	return nil
end

local current_ruleset_resolver = setmetatable({}, {
	__index = function(_, field)
		return resolve_current_field(field)
	end,
})

function MP.current_ruleset()
	return current_ruleset_resolver
end

function MP.active_layer_chain(target_short)
	local active_key = MP.get_active_ruleset and MP.get_active_ruleset() or nil
	local active_short = active_key and active_key:gsub("^ruleset_mp_", "") or nil
	target_short = target_short or active_short

	local result = {}
	local seen = {}
	local function add(name)
		if name and not seen[name] then
			seen[name] = true
			result[#result + 1] = name
		end
	end

	if target_short then
		local ruleset = MP.Rulesets and MP.Rulesets["ruleset_mp_" .. target_short] or nil
		if ruleset and ruleset._layer_order then
			for _, name in ipairs(ruleset._layer_order) do
				add(name)
			end
		end
		add(target_short)
	end

	if target_short == active_short then
		for _, name in ipairs(MP.MODIFIERS or {}) do
			add(name)
		end
	end

	return result
end

function MP.RunLayerHooks(hook_name, ...)
	for _, name in ipairs(MP.active_layer_chain()) do
		local layer = MP.Layers[name]
		if layer and type(layer[hook_name]) == "function" then
			layer[hook_name](...)
		end
	end
end

function MP.is_layer_active(layer_name)
	if not layer_name then
		return false
	end
	for _, name in ipairs(MP.active_layer_chain()) do
		if name == layer_name then
			return true
		end
	end
	return false
end

function MP.is_any_layer_active(layers)
	if type(layers) == "string" then
		return MP.is_layer_active(layers)
	end
	if type(layers) ~= "table" then
		return false
	end
	for _, layer_name in pairs(layers) do
		if MP.is_layer_active(layer_name) then
			return true
		end
	end
	return false
end

function MP.apply_layer_run_start_fields()
	if not (G and G.GAME and MP.current_ruleset) then
		return nil
	end

	local current_ruleset = MP.current_ruleset()
	local game_modifiers = current_ruleset.game_modifiers or {}
	local starting_params = current_ruleset.starting_params or {}

	G.GAME.modifiers = G.GAME.modifiers or {}
	G.GAME.starting_params = G.GAME.starting_params or {}

	merge_map(G.GAME.modifiers, game_modifiers)
	merge_map(G.GAME.starting_params, starting_params)

	if G.GAME.round_resets then
		for key, value in pairs(starting_params) do
			if G.GAME.round_resets[key] ~= nil then
				G.GAME.round_resets[key] = copy_value(value)
			end
		end
	end

	return {
		game_modifiers = game_modifiers,
		starting_params = starting_params,
	}
end

local function get_lobby_bonus_value(config, key, min_value, max_value)
	local value = math.floor(tonumber(config and config[key]) or 0)
	return math.max(min_value or 0, math.min(max_value or value, value))
end

function MP.apply_lobby_bonus_run_start_fields()
	if not (G and G.GAME and MP.LOBBY and MP.LOBBY.code and MP.LOBBY.config) then
		return nil
	end
	if G.GAME.mp_lobby_bonuses_applied then
		return nil
	end

	local config = MP.LOBBY.config
	local bonuses = {
		hands = get_lobby_bonus_value(config, "bonus_hands", 0, 4),
		discards = get_lobby_bonus_value(config, "bonus_discards", 0, 3),
		consumable_slots = get_lobby_bonus_value(config, "bonus_consumable_slots", 0, 2),
		joker_slots = get_lobby_bonus_value(config, "bonus_joker_slots", 0, 5),
		dollars = get_lobby_bonus_value(config, "bonus_money", 0, 50),
	}

	G.GAME.starting_params = G.GAME.starting_params or {}
	G.GAME.round_resets = G.GAME.round_resets or {}

	for key, value in pairs(bonuses) do
		if value > 0 then
			G.GAME.starting_params[key] = (tonumber(G.GAME.starting_params[key]) or 0) + value
			if G.GAME.round_resets[key] ~= nil then
				G.GAME.round_resets[key] = (tonumber(G.GAME.round_resets[key]) or 0) + value
			end
		end
	end

	if bonuses.dollars > 0 and G.GAME.dollars ~= nil then
		G.GAME.dollars = G.GAME.dollars + bonuses.dollars
	end

	G.GAME.mp_lobby_bonuses_applied = true
	return bonuses
end
