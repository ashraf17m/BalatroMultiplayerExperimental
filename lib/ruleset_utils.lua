local EMPTY_CONTENT_LIST_KEYS = {
	"banned_jokers",
	"banned_consumables",
	"banned_vouchers",
	"banned_enhancements",
	"banned_tags",
	"banned_blinds",
	"reworked_jokers",
	"reworked_consumables",
	"reworked_vouchers",
	"reworked_enhancements",
	"reworked_tags",
	"reworked_blinds",
}

function MP.UTILS.with_empty_content_lists(definition)
	for _, key in ipairs(EMPTY_CONTENT_LIST_KEYS) do
		if definition[key] == nil then
			definition[key] = {}
		end
	end
	return definition
end

function MP.UTILS.get_standard_rulesets(add)
	local ret = {}
	for k, v in pairs(MP.Rulesets) do
		if v.standard then ret[#ret + 1] = string.sub(v.key, 12, #v.key) end
	end
	if add then
		if type(add) == "string" then add = { add } end
		for i, v in ipairs(add) do
			ret[#ret + 1] = v
		end
	end
	return ret
end

local function get_active_ruleset()
	if MP.LOBBY.code then
		return MP.LOBBY.config.ruleset
	end
	return nil
end

function MP.UTILS.is_standard_ruleset()
	local active = get_active_ruleset()
	if active == nil then return false end
	for _, ruleset in ipairs(MP.UTILS.get_standard_rulesets()) do
		if active == "ruleset_mp_" .. ruleset then return true end
	end
	return false
end

function MP.UTILS.get_weekly()
	return MP.PLATFORM.SMODS.get_config_value("weekly")
end

function MP.UTILS.timer_base()
	local ruleset = MP.current_ruleset and MP.current_ruleset() or {}
	local lobby_config = MP.LOBBY and MP.LOBBY.config or {}
	local base = lobby_config.timer_base_seconds or ruleset.timer_base_seconds or 150
	local mult = ruleset.timer_base_multiplier or 1
	return base * mult
end

function MP.UTILS.pvp_timer_base()
	if not (MP.is_layer_active and MP.is_layer_active("pvp_timer")) then
		return MP.UTILS.timer_base()
	end

	local ruleset = MP.current_ruleset and MP.current_ruleset() or {}
	local lobby_config = MP.LOBBY and MP.LOBBY.config or {}
	local base = lobby_config.pvp_timer_base_seconds or ruleset.pvp_timer_base_seconds or 90
	local mult = ruleset.pvp_timer_base_multiplier or 1
	return base * mult
end

function MP.timer_is_local()
	return (MP.is_layer_active and MP.is_layer_active("pressure_timer"))
		or (MP.is_layer_active and MP.is_layer_active("no_animation_timer"))
		or (
			MP.is_pvp_boss
			and MP.is_pvp_boss()
			and MP.is_layer_active
			and MP.is_layer_active("pvp_timer")
		)
end

function MP.UTILS.is_ranked_ruleset_key(ruleset_key)
	local key = tostring(ruleset_key or "")
	if key ~= "" and key:sub(1, 11) ~= "ruleset_mp_" then
		key = "ruleset_mp_" .. key
	end

	if key == "ruleset_mp_standard_ranked" or key == "ruleset_mp_legacy_ranked" then
		return true
	end

	local ruleset = MP.Rulesets and MP.Rulesets[key] or nil
	if not (ruleset and type(ruleset._layer_order) == "table") then
		return false
	end

	for _, layer_key in ipairs(ruleset._layer_order) do
		if layer_key == "ranked" then
			return true
		end
	end
	return false
end

local function normalize_smods_version(version)
	return tostring(version or "")
		:gsub("%-STEAMODDED$", "")
		:gsub("~BETA%-", "-beta-")
		:lower()
end

function MP.UTILS.get_recommended_smods_version()
	return MP.RUNTIME_POLICY
		and MP.RUNTIME_POLICY.smods
		and MP.RUNTIME_POLICY.smods.recommended_version
		or "1.0.0-beta-1814a"
end

function MP.UTILS.is_recommended_smods_version()
	local recommended_smods_version = MP.UTILS.get_recommended_smods_version()
	local current_smods_version = SMODS and SMODS.version or ""
	return normalize_smods_version(current_smods_version) == normalize_smods_version(recommended_smods_version)
end

function MP.UTILS.check_smods_recommended_version()
	local recommended_smods_version = MP.UTILS.get_recommended_smods_version()
	if not MP.UTILS.is_recommended_smods_version() then
		return localize({
			type = "variable",
			key = "k_ruleset_recommended_smods_version",
			vars = { recommended_smods_version },
		})
	end
	return false
end

function MP.UTILS.check_smods_version()
	return false
end

function MP.UTILS.check_lovely_version()
	local lovely_mod = MP.PLATFORM.SMODS.get_loaded_mod("Lovely")
	local lovely_ver = lovely_mod and lovely_mod.version or ""
	local required_lovely_version = MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.lovely and MP.RUNTIME_POLICY.lovely.minimum_version or "0.9"
	local is_supported = MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.is_version_at_least
		and MP.PLATFORM.SMODS.is_version_at_least(lovely_ver, required_lovely_version)
	if not is_supported then
			return localize({
				type = "variable",
			key = "k_ruleset_disabled_lovely_version",
			vars = { required_lovely_version },
		})
	end
	return false
end
