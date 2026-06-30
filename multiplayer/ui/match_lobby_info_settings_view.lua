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
	local label_key = toggle_spec.label or toggle_spec.label_key
	local ref_value = toggle_spec.ref_value or toggle_spec.option_key
	if not (label_key and ref_value) then
		return nil
	end

	return MP.UI.UTILS.create_row({ padding = 0, align = "cr" }, {
		Disableable_Toggle({
			enabled_ref_table = MP.LOBBY,
			label = localize(label_key),
			ref_table = MP.LOBBY.config,
			ref_value = ref_value,
		}),
	})
end

local function get_scoring_rule_label()
	local config = MP.LOBBY and MP.LOBBY.config or {}
	local score_rule = config.pvp_score_rule
	if score_rule == "median" then
		return localize("k_median")
	elseif score_rule == "geometric" then
		return localize("k_geometric")
	elseif score_rule == "custom" then
		return localize("k_custom_score")
	elseif score_rule == "average" then
		return localize("k_beat_average")
	end
	return localize("k_highest_score")
end

local function create_settings_value_row(label_key, value_text)
	return MP.UI.UTILS.create_row({ align = "cm", padding = 0.03 }, {
		MP.UI.UTILS.create_text_node(localize(label_key) .. ": " .. value_text, {
			colour = G.C.UI.TEXT_LIGHT,
			scale = 0.45,
		}),
	})
end

local function append_settings_toggle_rows(nodes, Disableable_Toggle, toggle_specs)
	for _, toggle_spec in ipairs(toggle_specs or {}) do
		if not toggle_spec.when or toggle_spec.when(toggle_spec) then
			local row = create_settings_toggle_row(Disableable_Toggle, toggle_spec)
			if row then
				nodes[#nodes + 1] = row
			end
		end
	end
end

function MP.UI.create_UIBox_settings()
	if MP.UI and MP.UI.set_match_lobby_info_active_tab then
		MP.UI.set_match_lobby_info_active_tab("settings")
	end

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

	append_settings_toggle_rows(nodes, Disableable_Toggle, SETTING_TOGGLE_SPECS)

	if MP.is_group_lobby_type and MP.is_group_lobby_type(MP.LOBBY and MP.LOBBY.lobby_type) then
		nodes[#nodes + 1] = create_settings_value_row("b_beat_average_mode", get_scoring_rule_label())
	end

	local lobby_capabilities = MP.get_lobby_capabilities and MP.get_lobby_capabilities() or {}
	if lobby_capabilities.can_show_shared_progress_options then
		local lobby_option_tab_specs = MP.UI.LOBBY_OPTION_TAB_SPECS or {}
		append_settings_toggle_rows(nodes, Disableable_Toggle, lobby_option_tab_specs.team_options)
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
