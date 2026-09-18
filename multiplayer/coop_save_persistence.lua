MP.COOP_SAVE_PERSISTENCE = MP.COOP_SAVE_PERSISTENCE or {}

local PERSISTENCE = MP.COOP_SAVE_PERSISTENCE
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local COOP_SAVES_FILENAME = "mp_coop_saves.jkr"

local function get_profile_prefix()
	local profile = (G and G.SETTINGS and G.SETTINGS["profile"] or 1)
	return tostring(profile) .. "/"
end

function PERSISTENCE.get_save_path()
	return get_profile_prefix() .. COOP_SAVES_FILENAME
end

local function copy_sequence(source)
	local result = {}
	for index, value in ipairs(source or {}) do
		result[index] = value
	end
	return result
end

local function copy_map(source)
	local result = {}
	for key, value in pairs(source or {}) do
		result[key] = value
	end
	return result
end

local function normalize_save(save)
	if type(save) ~= "table" or type(save.saveId) ~= "string" or save.saveId == "" then
		return nil
	end
	if type(save.players) ~= "table" or type(save.snapshots) ~= "table" then
		return nil
	end

	return {
		saveId = save.saveId,
		savedAt = tonumber(save.savedAt) or os.time() * 1000,
		players = copy_sequence(save.players),
		snapshots = copy_map(save.snapshots),
		options = copy_map(save.options),
		ante = tonumber(save.ante),
		blind = save.blind,
		maxScore = save.maxScore,
	}
end

local function read_payload()
	if not (BALATRO.read_saved_table and PERSISTENCE.get_save_path) then
		return { version = 1, saves = {} }
	end

	local payload = BALATRO.read_saved_table(PERSISTENCE.get_save_path())
	if type(payload) ~= "table" or type(payload.saves) ~= "table" then
		return { version = 1, saves = {} }
	end

	local saves = {}
	for _, save in ipairs(payload.saves) do
		local normalized = normalize_save(save)
		if normalized then
			saves[#saves + 1] = normalized
		end
	end

	return { version = 1, saves = saves }
end

local function sort_saves(saves)
	table.sort(saves, function(a, b)
		return (tonumber(a.savedAt) or 0) > (tonumber(b.savedAt) or 0)
	end)
	return saves
end

local function write_saves(saves)
	if not BALATRO.write_saved_table then
		return false
	end

	return BALATRO.write_saved_table(PERSISTENCE.get_save_path(), {
		version = 1,
		saves = sort_saves(saves or {}),
	})
end

function PERSISTENCE.list_saves()
	return sort_saves(read_payload().saves)
end

function PERSISTENCE.get_save(save_id)
	if type(save_id) ~= "string" or save_id == "" then
		return nil
	end

	for _, save in ipairs(PERSISTENCE.list_saves()) do
		if save.saveId == save_id then
			return save
		end
	end

	return nil
end

function PERSISTENCE.upsert_save(save)
	local normalized = normalize_save(save)
	if not normalized then
		return false
	end

	local saves = PERSISTENCE.list_saves()
	local replaced = false
	for index, existing in ipairs(saves) do
		if existing.saveId == normalized.saveId then
			saves[index] = normalized
			replaced = true
			break
		end
	end

	if not replaced then
		saves[#saves + 1] = normalized
	end

	return write_saves(saves)
end

function PERSISTENCE.delete_save(save_id)
	if type(save_id) ~= "string" or save_id == "" then
		return false
	end

	local saves = PERSISTENCE.list_saves()
	local next_saves = {}
	local deleted = false
	for _, save in ipairs(saves) do
		if save.saveId == save_id then
			deleted = true
		else
			next_saves[#next_saves + 1] = save
		end
	end

	if not deleted then
		return false
	end

	return write_saves(next_saves)
end

return PERSISTENCE
