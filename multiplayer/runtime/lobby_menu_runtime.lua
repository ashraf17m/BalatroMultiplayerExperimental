local lobby_menu_runtime = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local last_lobby_main_menu_signature = nil
local in_lobby = false
local lobby_menu_transition_active = false
local pending_lobby_main_menu_refresh = false

local function stable_signature_value(value, seen)
	local value_type = type(value)
	if value_type == "nil" then
		return "nil"
	end
	if value_type == "boolean" or value_type == "number" then
		return tostring(value)
	end
	if value_type == "string" then
		return string.format("%q", value)
	end
	if value_type ~= "table" then
		return string.format("<%s>", value_type)
	end

	seen = seen or {}
	if seen[value] then
		return '"<cycle>"'
	end
	seen[value] = true

	local parts = {}
	local count = #value
	local is_array = count > 0

	for i = 1, count do
		parts[#parts + 1] = stable_signature_value(value[i], seen)
	end

	local keys = {}
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > count or key % 1 ~= 0 then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in ipairs(keys) do
		parts[#parts + 1] = stable_signature_value(key, seen) .. ":" .. stable_signature_value(value[key], seen)
	end

	seen[value] = nil
	return is_array and ("[" .. table.concat(parts, ",") .. "]") or ("{" .. table.concat(parts, ",") .. "}")
end

local function build_lobby_main_menu_snapshot()
	local lobby_context = MP.get_lobby_state_context and MP.get_lobby_state_context() or {}
	local players = {}
	for i, player in ipairs(lobby_context.players or {}) do
		players[i] = {
			id = player.id,
			username = player.username,
			team = player.team,
			is_host = player.is_host,
			is_owner = player.is_owner,
			is_ready = player.is_ready,
			is_in_match = player.is_in_match,
			config = player.config or {},
		}
	end

	return {
		code = lobby_context.code,
		lobby_type = lobby_context.lobby_type,
		is_host = lobby_context.is_host,
		match_in_progress = lobby_context.match_in_progress,
		username = lobby_context.client and lobby_context.client.username,
		config = lobby_context.config or {},
		run_deck = lobby_context.run_deck or {},
		players = players,
	}
end

local function build_lobby_main_menu_signature()
	return stable_signature_value(build_lobby_main_menu_snapshot())
end

local function is_screenwipe_active()
	local root = BALATRO.get_root and BALATRO.get_root() or G
	return not not (root and root.screenwipe)
end

local function should_defer_lobby_main_menu_refresh()
	return lobby_menu_transition_active or is_screenwipe_active()
end

local function defer_lobby_main_menu_refresh()
	pending_lobby_main_menu_refresh = true
	return false
end

function lobby_menu_runtime.get_lobby_main_menu_ui(e)
	return UIBox({
		definition = G.UIDEF.create_UIBox_lobby_menu(),
		config = {
			align = "bmi",
			offset = {
				x = 0,
				y = 10,
			},
			major = BALATRO.get_room_attach and BALATRO.get_room_attach() or nil,
			bond = "Weak",
		},
	})
end

function lobby_menu_runtime.display_lobby_main_menu_ui(e)
	local main_menu_ui = lobby_menu_runtime.get_lobby_main_menu_ui(e)
	BALATRO.set_main_menu_ui(main_menu_ui)
	main_menu_ui.is_mp_lobby_menu = true
	main_menu_ui.alignment.offset.y = 0
	BALATRO.align_to_major(main_menu_ui)
	BALATRO.snap_controller_to_ui_element(main_menu_ui, "lobby_menu_start")
end

function lobby_menu_runtime.refresh_lobby_main_menu(options)
	if MP.RESUME and MP.RESUME.is_resume_transition_active and MP.RESUME.is_resume_transition_active() then
		return false
	end

	if not (MP.is_in_lobby_session and MP.is_in_lobby_session()) or not (BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage()) then
		return false
	end

	options = options or {}
	if not options.force and should_defer_lobby_main_menu_refresh() then
		return defer_lobby_main_menu_refresh()
	end

	local new_signature = build_lobby_main_menu_signature()
	local main_menu_ui = BALATRO.get_main_menu_ui and BALATRO.get_main_menu_ui() or nil
	if main_menu_ui and main_menu_ui.is_mp_lobby_menu and last_lobby_main_menu_signature == new_signature then
		pending_lobby_main_menu_refresh = false
		return true
	end
	last_lobby_main_menu_signature = new_signature
	pending_lobby_main_menu_refresh = false

	BALATRO.clear_main_menu_ui()

	lobby_menu_runtime.display_lobby_main_menu_ui()
	return true
end

function lobby_menu_runtime.set_main_menu_ui(set_main_menu_ui_ref)
	if MP.RESUME and MP.RESUME.is_resume_transition_active and MP.RESUME.is_resume_transition_active() then
		return
	end

	lobby_menu_transition_active = false
	if MP.is_in_lobby_session and MP.is_in_lobby_session() then
		return lobby_menu_runtime.refresh_lobby_main_menu({ force = true })
	else
		pending_lobby_main_menu_refresh = false
		last_lobby_main_menu_signature = nil
		return set_main_menu_ui_ref()
	end
end

function lobby_menu_runtime.update_game_runtime(self)
	local in_lobby_session = MP.is_in_lobby_session and MP.is_in_lobby_session() or false
	if (in_lobby_session and not in_lobby) or (not in_lobby_session and in_lobby) then
		in_lobby = in_lobby_session
		BALATRO.set_no_saving(in_lobby)
		local resume_transition_active = MP.RESUME
			and MP.RESUME.is_resume_transition_active
			and MP.RESUME.is_resume_transition_active()
		local entering_active_match_session = in_lobby_session
			and MP.is_lobby_match_in_progress
			and MP.is_lobby_match_in_progress()
		if BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage() and not resume_transition_active and not entering_active_match_session then
			if is_screenwipe_active() then
				lobby_menu_transition_active = in_lobby_session
				pending_lobby_main_menu_refresh = in_lobby_session
			else
				lobby_menu_transition_active = true
				pending_lobby_main_menu_refresh = in_lobby_session
				BALATRO.go_to_menu()
				MP.reset_game_states()
			end
		end
	end
end

function lobby_menu_runtime.update_after_game()
	if MP.RESUME and MP.RESUME.update_pending_snapshot_capture then
		MP.RESUME.update_pending_snapshot_capture()
	end
	if MP.UI and MP.UI.flush_requested_refreshes then
		MP.UI.flush_requested_refreshes()
	end
	if pending_lobby_main_menu_refresh and not should_defer_lobby_main_menu_refresh() then
		lobby_menu_runtime.refresh_lobby_main_menu()
	end
end

function lobby_menu_runtime.update_connection_status()
	BALATRO.clear_hud_connection_status()
	if BALATRO.is_main_menu_stage and BALATRO.is_main_menu_stage() then
		BALATRO.set_hud_connection_status(BALATRO.create_connection_status_ui())
	end
end

return lobby_menu_runtime
