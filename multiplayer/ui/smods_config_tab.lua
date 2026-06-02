local function create_config_row(nodes, tooltip_text, padding)
	local row_config = {
		padding = padding or 0,
		align = "cm",
	}

	if tooltip_text then
		row_config.on_demand_tooltip = { text = tooltip_text }
	end

	return {
		n = G.UIT.R,
		config = row_config,
		nodes = nodes,
	}
end

local function create_inactive_text(text_key)
	return {
		n = G.UIT.T,
		config = {
			text = localize(text_key),
			shadow = true,
			scale = 0.375,
			colour = G.C.UI.TEXT_INACTIVE,
		},
	}
end

function MP.UI.get_score_calculator_backend_tooltip(backend)
	if tonumber(backend) == 2 then
		return { localize("k_score_calculator_experimental_desc") }
	end
	return { localize("k_score_calculator_original_desc") }
end

function MP.UI.create_config_tab()
	local config = MP.PLATFORM.SMODS.get_config(MP) or {}
	config.integrations = config.integrations or {}
	config.preview = config.preview or {}
	config.calculator = config.calculator or {}
	if config.calculator.backend == nil then
		config.calculator.backend = 1
	end
	config.calculator.backend = tonumber(config.calculator.backend) or 1

	local ret = {
		n = G.UIT.ROOT,
		config = {
			r = 0.1,
			minw = 5,
			align = "cm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = {
			create_config_row({
				create_toggle({
					id = "fantoms_preview_integration_toggle",
					label = localize("b_preview_integration"),
					ref_table = config.integrations,
					ref_value = "Preview",
				}),
			}, {
				localize("k_preview_integration_desc"),
				localize("k_preview_credit"),
			}),
			create_config_row({
				create_inactive_text("k_preview_credit"),
				{
					n = G.UIT.B,
					config = {
						w = 0.1,
						h = 0.1,
					},
				},
				create_inactive_text("k_requires_restart"),
			}),
			create_config_row({
				{
					n = G.UIT.C,
					config = { align = "cm" },
					nodes = {
						create_option_cycle({
							id = "score_calculator_backend",
							label = localize("k_score_calculator"),
							w = 4,
							scale = 0.8,
							options = localize("ml_score_calculator_backend_opt"),
							opt_callback = "mp_change_score_calculator_backend",
							current_option = config.calculator.backend,
							on_demand_tooltip = {
								text = MP.UI.get_score_calculator_backend_tooltip(config.calculator.backend),
							},
						}),
					},
				},
			}),
			create_config_row({
				create_toggle({
					id = "singleplayer_hide_content_toggle",
					label = localize("k_hide_mp_content"),
					ref_table = config,
					ref_value = "hide_mp_content",
				}),
			}, {
				localize("k_applies_singleplayer_vanilla_rulesets"),
			}),
			create_config_row({
				{
					n = G.UIT.C,
					config = { align = "cm" },
					nodes = {
						create_option_cycle({
							label = localize("k_timer_sfx"),
							w = 4,
							scale = 0.8,
							options = localize("ml_mp_timersfx_opt"),
							opt_callback = "mp_change_timersfx",
							current_option = MP.PLATFORM.SMODS.get_config_value("timersfx", 1, MP),
						}),
					},
				},
			}, nil, 0.1),
		},
	}
	return ret
end
