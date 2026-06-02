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
	elseif MP.SP and MP.SP.ruleset then
		return MP.SP.ruleset
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
