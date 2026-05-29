local create_UIBox_blind_choice_ref = create_UIBox_blind_choice
---@diagnostic disable-next-line: lowercase-global
function create_UIBox_blind_choice(type, run_info)
	if MP.LOBBY.code then
		type = type or "Small"
		if not G.GAME.blind_on_deck then G.GAME.blind_on_deck = "Small" end
		if not run_info then G.GAME.round_resets.blind_states[G.GAME.blind_on_deck] = "Select" end

		local blind_context = MP.UI.get_blind_choice_context(type, run_info)
		local overlay = MP.UI.BLIND_CHOICE_OVERLAY
		if overlay and overlay.create_box then
			return overlay.create_box(type, run_info, blind_context)
		end

		return create_UIBox_blind_choice_ref(type, run_info)
	else
		return create_UIBox_blind_choice_ref(type, run_info)
	end
end
