local match_lifecycle = MP.MATCH_LIFECYCLE or {}
MP.MATCH_LIFECYCLE = match_lifecycle
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local lobby_domain = MP.DOMAIN and MP.DOMAIN.LOBBY or {}
local match_domain = MP.DOMAIN and MP.DOMAIN.MATCH or {}

local trace_runtime_event = (MP.UTILS and MP.UTILS.trace_runtime_event) or function() end

local function close_overlay_menu_if_open()
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.request_overlay_menu_close then
		MP.CONNECTION_SESSION.request_overlay_menu_close()
	end
end

local function set_team_card_sync_suspended(is_suspended)
	MP.TEAM_CARD_SUSPENDED = not not is_suspended
	return MP.TEAM_CARD_SUSPENDED
end

function match_lifecycle.suspend_team_card_sync()
	return set_team_card_sync_suspended(true)
end

function match_lifecycle.resume_team_card_sync()
	return set_team_card_sync_suspended(false)
end

function match_lifecycle.request_resume_snapshot()
	if MP.RESUME and MP.RESUME.request_current_match_snapshot then
		MP.RESUME.request_current_match_snapshot()
	end
end

function match_lifecycle.capture_resume_snapshot()
	if MP.RESUME and MP.RESUME.capture_current_match_snapshot then
		local captured = MP.RESUME.capture_current_match_snapshot({ force = true })
		trace_runtime_event("resume.snapshot_capture", {
			captured = captured,
		})
		return captured
	end

	trace_runtime_event("resume.snapshot_capture", {
		captured = false,
		reason = "missing_capture_handler",
	})
	return false
end

function match_lifecycle.has_saved_resume()
	return not not (MP.RESUME and MP.RESUME.has_saved_resume and MP.RESUME.has_saved_resume())
end

function match_lifecycle.clear_saved_resume()
	if MP.RESUME and MP.RESUME.clear_saved_resume then
		MP.RESUME.clear_saved_resume()
	end
end

function match_lifecycle.reset_local_blind_ready_runtime()
	if not (MP.GAME and match_domain.reset_ready_blind_state) then
		return
	end

	match_domain.reset_ready_blind_state()
end

function match_lifecycle.prepare_end_game_view()
	match_lifecycle.suspend_team_card_sync()
	if MP.ACTIONS and MP.ACTIONS.cache_end_game_state then
		MP.ACTIONS.cache_end_game_state()
	end
	if MP.UI and MP.UI.reset_end_game_view_runtime then
		MP.UI.reset_end_game_view_runtime()
	end
	if MP.UI and MP.UI.capture_end_game_view_players then
		MP.UI.capture_end_game_view_players()
	end
	if MP.UI and MP.UI.prefetch_end_game_view_players then
		MP.UI.prefetch_end_game_view_players()
	end
end

local function begin_active_match_session()
	match_lifecycle.resume_team_card_sync()
	if lobby_domain.set_match_in_progress then
		lobby_domain.set_match_in_progress(true)
	end

	close_overlay_menu_if_open()
end

function match_lifecycle.begin_match_runtime()
	begin_active_match_session()
	match_domain.reset_state()
	if MP.STATE_APPLY and MP.STATE_APPLY.seed_match_enemies_from_lobby then
		MP.STATE_APPLY.seed_match_enemies_from_lobby()
	end
	if MP.OPPONENTS and MP.OPPONENTS.refresh_primary_enemy_view then
		MP.OPPONENTS.refresh_primary_enemy_view()
	end
end

function match_lifecycle.prepare_resume_runtime()
	begin_active_match_session()
end

local function resolve_connection_loss_message(message, resume_available, opts)
	local options = opts or {}
	if not (options.resume_message or options.no_resume_message) then
		return message
	end

	if resume_available then
		return options.resume_message or message
	end

	return options.no_resume_message or message
end

function match_lifecycle.transition_to_menu_after_connection_loss(message, opts)
	close_overlay_menu_if_open()
	if MP.CONNECTION_FEEDBACK and MP.CONNECTION_FEEDBACK.clear_all_countdowns then
		MP.CONNECTION_FEEDBACK.clear_all_countdowns()
	end
	match_lifecycle.suspend_team_card_sync()
	local resume_available = match_lifecycle.capture_resume_snapshot() or match_lifecycle.has_saved_resume()
	trace_runtime_event("connection.loss_transition", {
		resume_available = resume_available,
	})
	local notice_message = resolve_connection_loss_message(message, resume_available, opts)
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.set_client_connected then
		MP.CONNECTION_SESSION.set_client_connected(false)
	end
	if MP.CONNECTION_SESSION and MP.CONNECTION_SESSION.clear_local_lobby_session then
		MP.CONNECTION_SESSION.clear_local_lobby_session({
			clear_reconnect = true,
			clear_feedback = false,
			refresh_status = false,
		})
	end
	if not (BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage()) then
		match_domain.reset_state()
		BALATRO.go_to_menu()
	end
	if MP.UI and MP.UI.UTILS and MP.UI.UTILS.overlay_message then
		MP.UI.UTILS.overlay_message(notice_message)
	end
end
