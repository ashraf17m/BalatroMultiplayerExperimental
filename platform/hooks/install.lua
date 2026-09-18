MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local known_hook_specs = {
	find_card = function()
		return SMODS, "find_card"
	end,
	calculate_context = function()
		return SMODS, "calculate_context"
	end,
	get_card_areas = function()
		return SMODS, "get_card_areas"
	end,
	is_eternal = function()
		return SMODS, "is_eternal"
	end,
	injectItems = function()
		return SMODS, "injectItems"
	end,
	create_mod_badges = function()
		return SMODS, "create_mod_badges"
	end,
	showman = function()
		return SMODS, "showman"
	end,
	poll_seal = function()
		return SMODS, "poll_seal"
	end,
	get_next_vouchers = function()
		return SMODS, "get_next_vouchers"
	end,
}

local captured_known_hooks = {}

function MP.PLATFORM.HOOKS.resolve_known_target(name)
	local resolver = known_hook_specs[name]
	if not resolver then
		sendWarnMessage("Unknown multiplayer SMODS hook target: " .. tostring(name), "MULTIPLAYER")
		return nil
	end

	local target_table, target_key = resolver()
	if not target_table or type(target_table[target_key]) ~= "function" then
		sendWarnMessage("Missing SMODS hook target: " .. tostring(name), "MULTIPLAYER")
		return nil
	end

	return target_table, target_key
end

function MP.PLATFORM.HOOKS.capture_known_target(name)
	if captured_known_hooks[name] then
		local captured = captured_known_hooks[name]
		return captured.original, captured.target_table, captured.target_key
	end

	local target_table, target_key = MP.PLATFORM.HOOKS.resolve_known_target(name)
	if not target_table then
		return nil
	end

	local original = target_table[target_key]
	captured_known_hooks[name] = {
		original = original,
		target_table = target_table,
		target_key = target_key,
	}

	return original, target_table, target_key
end

local installed_known_overrides = {}

function MP.PLATFORM.HOOKS.install_known_override(name, build_override)
	if installed_known_overrides[name] then
		return false
	end

	local original, target_table, target_key = MP.PLATFORM.HOOKS.capture_known_target(name)
	if not original or not target_table then
		return false
	end

	local replacement = build_override(original)
	if type(replacement) ~= "function" then
		return false
	end

	target_table[target_key] = replacement
	installed_known_overrides[name] = true
	return true
end

MP.PLATFORM.SMODS.override_known = MP.PLATFORM.HOOKS.install_known_override
