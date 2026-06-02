local RESUME_SNAPSHOT = MP.RESUME or {}
MP.RESUME = RESUME_SNAPSHOT

if RESUME_SNAPSHOT._manual_apply_loaded then
	return RESUME_SNAPSHOT
end
RESUME_SNAPSHOT._manual_apply_loaded = true

local function get_reconnect_domain()
	return MP.DOMAIN and MP.DOMAIN.RECONNECT or nil
end

local function get_reconnect_persistence()
	return MP.RECONNECT_PERSISTENCE or nil
end

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local function reset_resume_runtime_state()
	local reconnect_domain = get_reconnect_domain()
	if reconnect_domain then
		reconnect_domain.reset_resume_runtime_state()
	end
end

local function load_saved_resume_snapshot(loader_name)
	local reconnect_persistence = get_reconnect_persistence()
	if not reconnect_persistence then
		return nil, "Resume persistence is unavailable."
	end

	return reconnect_persistence[loader_name](reconnect_persistence)
end

local function validate_saved_resume_meta_snapshot(meta_snapshot)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return false, "Resume domain is unavailable."
	end

	return reconnect_domain.validate_resume_meta_snapshot(meta_snapshot)
end

local function create_pending_manual_resume(run_snapshot, meta_snapshot)
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	local resume_snapshot = reconnect_domain.build_manual_resume(run_snapshot, meta_snapshot)
	reconnect_domain.set_pending_manual_resume(resume_snapshot)

	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.set_reconnect_lobby_state then
		MP.CONNECTION_SESSION.set_reconnect_lobby_state(meta_snapshot.reconnect_token, meta_snapshot.lobby_code)
	end

	return resume_snapshot
end

function RESUME_SNAPSHOT.has_saved_resume()
	local reconnect_persistence = get_reconnect_persistence()
	if not reconnect_persistence then
		return false
	end

	return reconnect_persistence.has_saved_resume()
end

function RESUME_SNAPSHOT.clear_saved_resume()
	local reconnect_persistence = get_reconnect_persistence()
	reset_resume_runtime_state()
	if reconnect_persistence then
		reconnect_persistence.clear_saved_resume_files()
	end
end

function RESUME_SNAPSHOT.begin_manual_resume()
	if not RESUME_SNAPSHOT.has_saved_resume() then
		trace_runtime_event("resume.manual_begin_blocked", {
			reason = "no_saved_match",
		})
		return nil, "No saved match was found."
	end

	local run_snapshot, run_err = load_saved_resume_snapshot("load_saved_resume_run_snapshot")
	if not run_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "run_snapshot_load_failed",
			error = run_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, run_err
	end

	local meta_snapshot, meta_err = load_saved_resume_snapshot("load_saved_resume_meta_snapshot")
	if not meta_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "meta_snapshot_load_failed",
			error = meta_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, meta_err
	end

	local is_valid_meta_snapshot, validation_err = validate_saved_resume_meta_snapshot(meta_snapshot)
	if not is_valid_meta_snapshot then
		trace_runtime_event("resume.manual_begin_failed", {
			reason = "meta_snapshot_invalid",
			error = validation_err,
			clear_saved_files = true,
		})
		RESUME_SNAPSHOT.clear_saved_resume()
		return nil, validation_err
	end

	trace_runtime_event("resume.manual_begin_ready", {
		lobby_code = meta_snapshot.lobby_code,
		has_reconnect_token = meta_snapshot.reconnect_token ~= nil,
	})
	return create_pending_manual_resume(run_snapshot, meta_snapshot)
end

function RESUME_SNAPSHOT.get_pending_manual_resume()
	local reconnect_domain = get_reconnect_domain()
	if not reconnect_domain then
		return nil
	end

	return reconnect_domain.get_pending_manual_resume()
end

function RESUME_SNAPSHOT.complete_manual_resume()
	local reconnect_domain = get_reconnect_domain()
	if reconnect_domain then
		reconnect_domain.clear_pending_manual_resume()
	end
	trace_runtime_event("resume.manual_complete", {})
end

function RESUME_SNAPSHOT.fail_manual_resume(clear_saved_files)
	trace_runtime_event("resume.manual_fail", {
		clear_saved_files = clear_saved_files,
	})
	if clear_saved_files then
		RESUME_SNAPSHOT.clear_saved_resume()
		return
	end

	reset_resume_runtime_state()
end

function RESUME_SNAPSHOT.refresh_saved_resume_metadata(token, code, player_id)
	local reconnect_domain = get_reconnect_domain()
	local reconnect_persistence = get_reconnect_persistence()
	if not (reconnect_domain and reconnect_persistence) then
		return false
	end

	if not RESUME_SNAPSHOT.has_saved_resume() then
		return false
	end

	local meta_snapshot = load_saved_resume_snapshot("load_saved_resume_meta_snapshot")
	if not meta_snapshot then
		return false
	end

	meta_snapshot = reconnect_domain.refresh_resume_meta_snapshot(meta_snapshot, token, code, player_id)
	return reconnect_persistence.save_resume_meta_snapshot(meta_snapshot)
end

function RESUME_SNAPSHOT.apply_saved_mp_state(saved_state)
	if type(saved_state) ~= "table" or not (MP.GAME and match_domain.apply_saved_state) then
		return
	end

	match_domain.apply_saved_state(saved_state)
end

return RESUME_SNAPSHOT
