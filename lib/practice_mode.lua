MP.SP = MP.SP or {
	ruleset = nil,
	gamemode = nil,
	practice = false,
	unlimited_slots = false,
	edition_cycling = false,
}

local function normalize_ruleset_key(ruleset_key)
	if not ruleset_key or ruleset_key == "" then
		return MP.DEFAULT_LOBBY_CREATION_RULESET
	end
	ruleset_key = tostring(ruleset_key)
	if string.sub(ruleset_key, 1, 11) == "ruleset_mp_" then
		return ruleset_key
	end
	return "ruleset_mp_" .. ruleset_key
end

local function strip_ruleset_prefix(ruleset_key)
	ruleset_key = normalize_ruleset_key(ruleset_key)
	return string.sub(ruleset_key, 12, -1)
end

function MP.is_practice_mode()
	return MP.SP and MP.SP.practice == true
end

function MP.clear_practice_mode(options)
	options = options or {}
	MP.SP = MP.SP or {}
	MP.SP.ruleset = nil
	MP.SP.gamemode = nil
	MP.SP.practice = false
	MP.SP.unlimited_slots = false
	MP.SP.edition_cycling = false

	if options.clear_modifiers ~= false then
		MP.MODIFIERS = {}
	end
	if MP.GHOST and MP.GHOST.clear then
		MP.GHOST.clear()
	end
end

function MP.set_practice_ruleset(ruleset_key, options)
	options = options or {}
	MP.SP = MP.SP or {}
	local normalized_key = normalize_ruleset_key(ruleset_key)
	MP.SP.ruleset = normalized_key
	MP.SP.practice = true

	if MP.LOBBY and MP.LOBBY.config then
		MP.LOBBY.config.ruleset = nil
		MP.LOBBY.config.gamemode = nil
	end

	local ruleset_name = strip_ruleset_prefix(normalized_key)
	if not options.preserve_modifiers and MP.apply_default_modifiers then
		MP.apply_default_modifiers(ruleset_name)
	end
	if MP.LoadReworks then
		MP.LoadReworks(ruleset_name)
	end

	return normalized_key
end

function MP.start_practice_mode(ruleset_key)
	MP.clear_practice_mode({ clear_modifiers = true })
	return MP.set_practice_ruleset(ruleset_key or MP.DEFAULT_LOBBY_CREATION_RULESET)
end
