local SETTING_TOGGLE_SPECS = {
	{ label = "b_opts_cb_money", ref_value = "gold_on_life_loss" },
	{ label = "b_opts_no_gold_on_loss", ref_value = "no_gold_on_round_loss" },
	{ label = "b_opts_death_on_loss", ref_value = "death_on_round_loss" },
	{ label = "b_opts_diff_seeds", ref_value = "different_seeds" },
	{ label = "b_opts_player_diff_deck", ref_value = "different_decks" },
	{ label = "b_opts_multiplayer_jokers", ref_value = "multiplayer_jokers" },
	{ label = "b_opts_normal_bosses", ref_value = "normal_bosses" },
}

local function create_settings_toggle_row(Disableable_Toggle, toggle_spec)
	return MP.UI.UTILS.create_row({ padding = 0, align = "cr" }, {
		Disableable_Toggle({
			enabled_ref_table = MP.LOBBY,
			label = localize(toggle_spec.label),
			ref_table = MP.LOBBY.config,
			ref_value = toggle_spec.ref_value,
		}),
	})
end

function MP.UI.create_UIBox_settings()
	local Disableable_Toggle = MP.UI and MP.UI.Disableable_Toggle
	local ruleset = string.sub(MP.LOBBY.config.ruleset, 12, -1)
	local gamemode = string.sub(MP.LOBBY.config.gamemode, 13, -1)
	local seed = MP.LOBBY.config.custom_seed == "random" and localize("k_random") or MP.LOBBY.config.custom_seed
	local nodes = {
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
			MP.UI.UTILS.create_text_node((localize("k_" .. ruleset) .. " " .. localize("k_" .. gamemode)), {
				colour = G.C.UI.TEXT_LIGHT,
				scale = 0.6,
			}),
		}),
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
			MP.UI.UTILS.create_text_node((localize("k_current_seed") .. seed), {
				colour = G.C.UI.TEXT_LIGHT,
				scale = 0.6,
			}),
		}),
	}

	for _, toggle_spec in ipairs(SETTING_TOGGLE_SPECS) do
		nodes[#nodes + 1] = create_settings_toggle_row(Disableable_Toggle, toggle_spec)
	end

	if MP.is_group_mode() then
		nodes[#nodes + 1] = create_settings_toggle_row(Disableable_Toggle, {
			label = "b_beat_average_mode",
			ref_value = "ffa_scoring_beat_average",
		})
	end

	return {
		n = G.UIT.ROOT,
		config = {
			emboss = 0.05,
			minh = 6,
			r = 0.1,
			minw = 10,
			align = "tm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = nodes,
	}
end
