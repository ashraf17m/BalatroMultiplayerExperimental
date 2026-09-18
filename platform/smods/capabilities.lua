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
	return not not SMODS.booted
end

function MP.PLATFORM.SMODS.get_loaded_mod(mod_id)
	return SMODS.Mods[mod_id]
end

function MP.PLATFORM.SMODS.has_found_mod(mod_id)
	return next(SMODS.find_mod(mod_id)) ~= nil
end

function MP.PLATFORM.SMODS.is_mod_loadable(mod_id)
	local mod = SMODS.Mods[mod_id]
	return not not (mod and mod.can_load)
end

function MP.PLATFORM.SMODS.get_all_loaded_mods()
	return SMODS.Mods
end

function MP.PLATFORM.SMODS.get_stake_key(index)
	if type(index) == "string" then
		return index
	end

	local num_idx = tonumber(index) or 1
	local res = SMODS.stake_from_index(num_idx)
	if res then
		return res
	end

	if G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[num_idx] then
		return G.P_CENTER_POOLS.Stake[num_idx].key
	end

	return "error"
end

function MP.PLATFORM.SMODS.is_poker_hand_visible(key)
	return not not SMODS.is_poker_hand_visible(key)
end

function MP.PLATFORM.SMODS.upgrade_poker_hands(args)
	return SMODS.upgrade_poker_hands(args)
end

function MP.PLATFORM.SMODS.calculate_context(context)
	SMODS.calculate_context(context)
	return true
end

function MP.PLATFORM.SMODS.get_probability_vars(card, numerator, denominator, key)
	return SMODS.get_probability_vars(card, numerator, denominator, key)
end

function MP.PLATFORM.SMODS.get_rank_buffer()
	return SMODS.Rank.obj_buffer or {}
end

function MP.PLATFORM.SMODS.get_suit_buffer()
	return SMODS.Suit.obj_buffer or {}
end

function MP.PLATFORM.SMODS.take_booster_ownership_by_kind(kind, definition, force)
	return SMODS.Booster:take_ownership_by_kind(kind, definition, force)
end

function MP.PLATFORM.SMODS.size_of_pool(pool)
	return SMODS.size_of_pool(pool)
end

function MP.PLATFORM.SMODS.get_gradient(name, fallback)
	return SMODS.Gradients[name] or fallback
end

function MP.PLATFORM.SMODS.are_mod_badges_disabled()
	return not not SMODS.config.no_mod_badges
end

function MP.PLATFORM.SMODS.get_scoring_calculation_definitions()
	return SMODS.Scoring_Calculations
end

function MP.PLATFORM.SMODS.refresh_score_ui_list()
	SMODS.refresh_score_UI_list()
	return true
end
