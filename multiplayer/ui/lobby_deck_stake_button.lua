local Disableable_Button = MP.UI.Disableable_Button

-- Component for deck selection button in lobby
function MP.UI.create_lobby_deck_button(text_scale, back, stake)
	local random_loadout = MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.random_loadout
	local deck_labels = {
		random_loadout and "???" or localize({
			type = "name_text",
			key = MP.UTILS.get_deck_key_from_name(back),
			set = "Back",
		}),
		random_loadout and "???" or localize({
			type = "name_text",
			key = MP.PLATFORM.SMODS.get_stake_key(type(stake) == "string" and tonumber(stake) or stake),
			set = "Stake",
		}),
	}
	local enabled_ref_table = MP.LOBBY
	local enabled_ref_value = "is_host"

	if MP.LOBBY.is_saved_coop_restore then
		enabled_ref_table = { value = false }
		enabled_ref_value = "value"
	elseif not MP.LOBBY.is_host then
		enabled_ref_table = MP.LOBBY.config
		enabled_ref_value = "different_decks"
	end

	return Disableable_Button({
		id = "lobby_choose_deck",
		button = "lobby_choose_deck",
		colour = G.C.PURPLE,
		minw = 2.15,
		minh = 1.35,
		label = deck_labels,
		scale = text_scale * 1.2,
		col = true,
		enabled_ref_table = enabled_ref_table,
		enabled_ref_value = enabled_ref_value,
	})
end
