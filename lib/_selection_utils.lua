-- Shared helpers for grouped content-selection registries such as gamemodes and rulesets.

function MP.UTILS.strip_selection_prefix(raw_key, prefix)
	local key = tostring(raw_key or "")
	local normalized_prefix = tostring(prefix or "")

	if normalized_prefix ~= "" and string.sub(key, 1, #normalized_prefix) == normalized_prefix then
		return string.sub(key, #normalized_prefix + 1, -1)
	end

	return key
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

function MP.UTILS.pool_contains_key(pool, key)
	for _, entry in ipairs(pool or {}) do
		if entry and entry.key == key then
			return true
		end
	end

	return false
end

function MP.UTILS.build_grouped_selection_buttons_data(objects, opts)
	local grouped_categories = {}
	local category_order = {}
	local ordered_entries = {}
	local config = opts or {}

	for _, object in pairs(objects or {}) do
		local selection_key = MP.UTILS.strip_selection_prefix(object.key, config.key_prefix)
		ordered_entries[#ordered_entries + 1] = {
			object = object,
			selection_key = selection_key,
			group_key = object.selection_group_key or config.default_group_key,
			group_order = tonumber(object.selection_group_order) or 99,
			selection_order = tonumber(object.selection_order) or 999,
		}
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
			button_id = config.get_button_id(entry.object, entry),
			button_localize_key = entry.object.selection_localize_key or ("k_" .. entry.selection_key),
			button_col = entry.object.selection_button_colour,
		}
	end

	return category_order
end
