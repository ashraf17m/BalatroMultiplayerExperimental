local create_UIBox_blind_choice_ref = create_UIBox_blind_choice
local blind_choice_state = MP.UI and MP.UI.BLIND_CHOICE_STATE or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

---@diagnostic disable-next-line: lowercase-global
function create_UIBox_blind_choice(type, run_info)
	if MP.LOBBY.code then
		type = type or "Small"
		if not (BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck()) then
			BALATRO.set_blind_on_deck("Small")
		end
		if not run_info then
			BALATRO.set_blind_state(BALATRO.get_blind_on_deck and BALATRO.get_blind_on_deck() or "Small", "Select")
		end

		local blind_context = blind_choice_state.build_context(type, run_info)
		local overlay = MP.UI.BLIND_CHOICE_OVERLAY
		if overlay and overlay.create_box then
			return overlay.create_box(type, run_info, blind_context)
		end

		return create_UIBox_blind_choice_ref(type, run_info)
	else
		return create_UIBox_blind_choice_ref(type, run_info)
	end
end
