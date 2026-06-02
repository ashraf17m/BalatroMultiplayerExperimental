MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.SMODS = MP.PLATFORM.SMODS or {}

local phase_order = {
	ALPHA = 1,
	BETA = 2,
	RC = 3,
}

local function build_parsed_version(major, minor, patch, phase, build, suffix)
	return {
		major = tonumber(major),
		minor = tonumber(minor),
		patch = tonumber(patch),
		phase = phase,
		build = build,
		suffix = suffix,
	}
end

local function parse_version(version)
	version = tostring(version or "")

	local major, minor, patch, phase, build, suffix = version:match("^(%d+)%.(%d+)%.(%d+)~([A-Za-z]+)%-(%d+)(%a?)$")
	if major then
		phase = string.upper(phase)
		return build_parsed_version(
			major,
			minor,
			patch,
			phase_order[phase] or 0,
			tonumber(build),
			suffix ~= "" and string.byte(string.lower(suffix)) or 0
		)
	end

	major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)$")
	if major then
		return build_parsed_version(major, minor, patch, math.huge, math.huge, math.huge)
	end

	major, minor = version:match("^(%d+)%.(%d+)$")
	if major then
		return build_parsed_version(major, minor, 0, math.huge, math.huge, math.huge)
	end

	return nil
end

function MP.PLATFORM.SMODS.compare_versions(a, b)
	local parsed_a = parse_version(a)
	local parsed_b = parse_version(b)
	if not parsed_a or not parsed_b then
		return nil
	end

	for _, key in ipairs({ "major", "minor", "patch", "phase", "build", "suffix" }) do
		if parsed_a[key] ~= parsed_b[key] then
			return parsed_a[key] < parsed_b[key] and -1 or 1
		end
	end

	return 0
end

function MP.PLATFORM.SMODS.is_version_at_least(current_version, minimum_version)
	local comparison = MP.PLATFORM.SMODS.compare_versions(current_version, minimum_version)
	if comparison == nil then
		return tostring(current_version or "") == tostring(minimum_version or "")
	end

	return comparison >= 0
end

function MP.PLATFORM.SMODS.is_booted()
	return not not (SMODS and SMODS.booted)
end

function MP.PLATFORM.SMODS.get_loaded_mod(mod_id)
	if not (SMODS and type(SMODS.Mods) == "table") then
		return nil
	end

	return SMODS.Mods[mod_id]
end

function MP.PLATFORM.SMODS.find_mod(mod_id)
	if not (SMODS and type(SMODS.find_mod) == "function") then
		return {}
	end

	return SMODS.find_mod(mod_id) or {}
end

function MP.PLATFORM.SMODS.has_found_mod(mod_id)
	return next(MP.PLATFORM.SMODS.find_mod(mod_id)) ~= nil
end

function MP.PLATFORM.SMODS.is_mod_loadable(mod_id)
	local mod = MP.PLATFORM.SMODS.get_loaded_mod(mod_id)
	return not not (mod and mod.can_load)
end

function MP.PLATFORM.SMODS.get_all_loaded_mods()
	return (SMODS and type(SMODS.Mods) == "table" and SMODS.Mods) or {}
end

function MP.PLATFORM.SMODS.get_stake_key(index)
	if SMODS and type(SMODS.stake_from_index) == "function" then
		return SMODS.stake_from_index(index)
	end

	return "error"
end

function MP.PLATFORM.SMODS.is_poker_hand_visible(key)
	if SMODS and type(SMODS.is_poker_hand_visible) == "function" then
		return not not SMODS.is_poker_hand_visible(key)
	end

	return not not (G and G.GAME and G.GAME.hands and G.GAME.hands[key] and G.GAME.hands[key].visible)
end

function MP.PLATFORM.SMODS.upgrade_poker_hands(args)
	if SMODS and type(SMODS.upgrade_poker_hands) == "function" then
		return SMODS.upgrade_poker_hands(args)
	end

	return nil
end

function MP.PLATFORM.SMODS.calculate_context(context)
	if SMODS and type(SMODS.calculate_context) == "function" then
		SMODS.calculate_context(context)
		return true
	end

	return false
end

function MP.PLATFORM.SMODS.has_enhancement(card, enhancement_key)
	if SMODS and type(SMODS.has_enhancement) == "function" then
		return not not SMODS.has_enhancement(card, enhancement_key)
	end

	return false
end

function MP.PLATFORM.SMODS.get_probability_vars(card, numerator, denominator, key)
	if SMODS and type(SMODS.get_probability_vars) == "function" then
		return SMODS.get_probability_vars(card, numerator, denominator, key)
	end

	return numerator, denominator
end

function MP.PLATFORM.SMODS.get_rank_buffer()
	return (SMODS and SMODS.Rank and SMODS.Rank.obj_buffer) or {}
end

function MP.PLATFORM.SMODS.get_suit_buffer()
	return (SMODS and SMODS.Suit and SMODS.Suit.obj_buffer) or {}
end

function MP.PLATFORM.SMODS.take_booster_ownership_by_kind(kind, definition, force)
	if SMODS and SMODS.Booster and type(SMODS.Booster.take_ownership_by_kind) == "function" then
		return SMODS.Booster:take_ownership_by_kind(kind, definition, force)
	end

	return false
end

function MP.PLATFORM.SMODS.poll_seal(args)
	if SMODS and type(SMODS.poll_seal) == "function" then
		return SMODS.poll_seal(args)
	end

	return nil
end

function MP.PLATFORM.SMODS.size_of_pool(pool)
	if SMODS and type(SMODS.size_of_pool) == "function" then
		return SMODS.size_of_pool(pool)
	end

	return type(pool) == "table" and #pool or 0
end

function MP.PLATFORM.SMODS.get_gradient(name, fallback)
	if SMODS and type(SMODS.Gradients) == "table" and SMODS.Gradients[name] ~= nil then
		return SMODS.Gradients[name]
	end

	return fallback
end

function MP.PLATFORM.SMODS.are_mod_badges_disabled()
	return not not (SMODS and type(SMODS.config) == "table" and SMODS.config.no_mod_badges)
end

function MP.PLATFORM.SMODS.get_scoring_calculation_definitions()
	return SMODS and SMODS.Scoring_Calculations or nil
end

function MP.PLATFORM.SMODS.refresh_score_ui_list()
	if SMODS and type(SMODS.refresh_score_UI_list) == "function" then
		SMODS.refresh_score_UI_list()
		return true
	end

	return false
end
