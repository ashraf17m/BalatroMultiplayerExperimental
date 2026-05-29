MP.RECONNECT_PERSISTENCE = MP.RECONNECT_PERSISTENCE or {}

local RECONNECT_PERSISTENCE = MP.RECONNECT_PERSISTENCE
local BALATRO = MP.PLATFORM.BALATRO

local RESUME_RUN_FILENAME = "mp_resume_run.jkr"
local RESUME_META_FILENAME = "mp_resume_meta.jkr"

local function get_profile_prefix()
	local profile = BALATRO.get_setting_value("profile", 1)
	return tostring(profile) .. "/"
end

function RECONNECT_PERSISTENCE.get_resume_run_path()
	return get_profile_prefix() .. RESUME_RUN_FILENAME
end

function RECONNECT_PERSISTENCE.get_resume_meta_path()
	return get_profile_prefix() .. RESUME_META_FILENAME
end

function RECONNECT_PERSISTENCE.decode_saved_table(path)
	return BALATRO.read_saved_table(path)
end

function RECONNECT_PERSISTENCE.write_saved_table(path, data)
	return BALATRO.write_saved_table(path, data)
end

function RECONNECT_PERSISTENCE.load_saved_resume_run_snapshot()
	return RECONNECT_PERSISTENCE.decode_saved_table(RECONNECT_PERSISTENCE.get_resume_run_path())
end

function RECONNECT_PERSISTENCE.load_saved_resume_meta_snapshot()
	return RECONNECT_PERSISTENCE.decode_saved_table(RECONNECT_PERSISTENCE.get_resume_meta_path())
end

function RECONNECT_PERSISTENCE.save_resume_snapshots(run_snapshot, meta_snapshot)
	local run_ok = RECONNECT_PERSISTENCE.write_saved_table(RECONNECT_PERSISTENCE.get_resume_run_path(), run_snapshot)
	local meta_ok = RECONNECT_PERSISTENCE.write_saved_table(RECONNECT_PERSISTENCE.get_resume_meta_path(), meta_snapshot)
	return not not (run_ok and meta_ok and RECONNECT_PERSISTENCE.has_saved_resume())
end

function RECONNECT_PERSISTENCE.save_resume_meta_snapshot(meta_snapshot)
	local meta_ok = RECONNECT_PERSISTENCE.write_saved_table(RECONNECT_PERSISTENCE.get_resume_meta_path(), meta_snapshot)
	return not not (meta_ok and BALATRO.file_exists(RECONNECT_PERSISTENCE.get_resume_meta_path()))
end

function RECONNECT_PERSISTENCE.has_saved_resume()
	return BALATRO.file_exists(RECONNECT_PERSISTENCE.get_resume_run_path())
		and BALATRO.file_exists(RECONNECT_PERSISTENCE.get_resume_meta_path())
end

function RECONNECT_PERSISTENCE.clear_saved_resume_files()
	BALATRO.remove_file(RECONNECT_PERSISTENCE.get_resume_run_path())
	BALATRO.remove_file(RECONNECT_PERSISTENCE.get_resume_meta_path())
	return true
end

return RECONNECT_PERSISTENCE
