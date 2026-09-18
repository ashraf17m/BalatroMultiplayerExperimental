-- Consolidated Steamodded Integration Module (Config, Credits, Customization & Menu Hooks)
-- Replaces 4 fragmented files with a unified, cohesive vertical module.

MP.UI = MP.UI or {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local current_mod = MP.PLATFORM and MP.PLATFORM.SMODS and MP.PLATFORM.SMODS.get_current_mod
    and MP.PLATFORM.SMODS.get_current_mod() or MP

-- ============================================================================
-- SECTION 1: SMODS CREDITS TAB
-- (Consolidated from smods_credits_tab.lua)
-- ============================================================================

function MP.UI.create_credits_tab()
	local scale = 0.75
	return {
		n = G.UIT.ROOT,
		config = {
			emboss = 0.05,
			minh = 6,
			r = 0.1,
			minw = 6,
			align = "cm",
			padding = 0.2,
			colour = G.C.BLACK,
		},
		nodes = {
			MP.UI.UTILS.create_row({ padding = 0.2, align = "cm" }, {
				MP.UI.UTILS.create_text_node(localize("k_created_by"), {
					scale = scale * 0.8,
					colour = G.C.UI.TEXT_LIGHT,
				}),
				MP.UI.UTILS.create_text_node("Virtualized", {
					scale = scale * 0.8,
					colour = G.C.DARK_EDITION,
				}),
			}),
			MP.UI.UTILS.create_row({ align = "cm", padding = 0 }, {
				MP.UI.UTILS.create_text_node(localize("k_major_contributors"), {
					scale = scale * 0.8,
					colour = G.C.UI.TEXT_LIGHT,
				}),
			}),
			MP.UI.UTILS.create_row({ align = "cm", padding = 0.2 }, {
				MP.UI.UTILS.create_text_node(
					localize({
						type = "variable",
						key = "k_credits_list",
						vars = { "TGMM, Senfinbrare, CUexter, Brawmario, Divvy, Andy, Steph," },
					}),
					{
						scale = scale * 0.8,
						colour = G.C.RED,
					}
				),
			}),
			MP.UI.UTILS.create_row({ align = "cm", padding = 0 }, {
				UIBox_button({
					minw = 3.85,
					button = "bmp_github",
					label = { localize("b_github_project") },
				}),
			}),
			MP.UI.UTILS.create_row({ align = "cm", padding = 0 }, {
				UIBox_button({
					minw = 3.85 * 2,
					button = "bmp_discord",
					label = { localize("b_mp_discord") },
				}),
			}),
		},
	}
end

-- ============================================================================
-- SECTION 2: SMODS CONFIG TAB
-- (Consolidated from smods_config_tab.lua)
-- ============================================================================

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

-- ============================================================================
-- SECTION 3: SMODS CUSTOMIZATION TAB
-- (Consolidated from smods_customization_tab.lua)
-- ============================================================================


local function create_calculator_label_row(padding, scale, text_key)
	return {
		n = G.UIT.R,
		config = {
			padding = padding,
			align = "cm",
			id = "calculator_text_input",
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					scale = scale,
					text = localize(text_key),
					colour = G.C.UI.TEXT_LIGHT,
				},
			},
		},
	}
end

local function save_calculator_label_settings()
	MP.UTILS.save_calculator_labels(MP.CALCULATOR_LABELS)
end

local function create_calculator_text_input(input_spec)
	return create_text_input({
		id = input_spec.id,
		w = 4,
		max_length = 25,
		prompt_text = input_spec.prompt_text,
		colour = copy_table(input_spec.colour),
		hooked_colour = darken(copy_table(input_spec.colour), 0.3),
		ref_table = MP.CALCULATOR_LABELS,
		ref_value = input_spec.ref_value,
		extended_corpus = true,
		keyboard_offset = -3,
		callback = save_calculator_label_settings,
	})
end

local function create_calculator_inputs_row(calculator_input_specs)
	local calculator_nodes = {}

	for _, input_spec in ipairs(calculator_input_specs) do
		calculator_nodes[#calculator_nodes + 1] = create_calculator_text_input(input_spec)
	end

	return {
		n = G.UIT.R,
		config = {
			padding = 0.15,
			align = "cm",
			id = "calculator_text_input",
		},
		nodes = calculator_nodes,
	}
end

local function create_blind_colour_options(limit)
	local blind_colour_options = {}

	for blind_col = 1, limit do
		blind_colour_options[#blind_colour_options + 1] = blind_col
	end

	return blind_colour_options
end

local function create_customization_tab()
	local preview_customization_available = (MP.INTEGRATIONS and MP.INTEGRATIONS.Preview)
		or tonumber(MP.PLATFORM.SMODS.get_config_value("calculator.backend", 1, MP)) == 2
	local blind_colour_count = MP.UTILS.get_blind_col_count()
	local blind_def = (G and G.P_BLINDS and G.P_BLINDS[MP.UTILS.blind_col_numtokey(MP.LOBBY.client.blind_col)] or nil)
	local blind_anim = BALATRO.create_animated_sprite(
		0,
		0,
		1.4,
		1.4,
		BALATRO.get_animation_atlas("mp_player_blind_col"),
		blind_def and blind_def.pos or { x = 0, y = 0 }
	)
	blind_anim:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	MP.CALCULATOR_LABELS.text = MP.UTILS.get_calculator_label("text")
	MP.CALCULATOR_LABELS.button = MP.UTILS.get_calculator_label("button")
	local calculator_input_specs = {
		{
			id = "calculator_text",
			prompt_text = "CALCULATING", -- raw string but this doesn't need localization
			colour = G.C.BLACK,
			ref_value = "text",
		},
		{
			id = "calculator_button",
			prompt_text = "Calculate Score",
			colour = G.C.RED,
			ref_value = "button",
		},
	}
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
			preview_customization_available and create_calculator_label_row(0.10, 0.5, "k_customize_preview") or nil,
			preview_customization_available and create_calculator_label_row(0, 0.3, "k_enter_to_save") or nil,
			preview_customization_available and create_calculator_inputs_row(calculator_input_specs) or nil,
			{
				n = G.UIT.R,
				config = {
					padding = 0.5,
					align = "cm",
					id = "username_input_box",
				},
				nodes = {
					{
						n = G.UIT.T,
						config = {
							scale = 0.6,
							text = localize("k_username"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
					create_text_input({
						id = "enter_username",
						w = 4,
						max_length = 25,
						prompt_text = localize("k_enter_username"),
						ref_table = MP.LOBBY.client,
						ref_value = "username",
						extended_corpus = true,
						keyboard_offset = -3,
						callback = function(val)
							MP.UTILS.save_username(MP.LOBBY.client.username)
						end,
					}),
					{
						n = G.UIT.T,
						config = {
							scale = 0.3,
							text = localize("k_enter_to_save"),
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			},
			{
				n = G.UIT.R,
				config = {
					padding = 0.1,
					align = "cm",
					id = "blind_col_changer",
				},
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							{ n = G.UIT.O, config = { id = "blind_col_changer_sprite", object = blind_anim } },
						},
					},
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = {
							create_option_cycle({
								id = "blind_col_changer_option",
								label = localize({
									type = "name_text",
									key = MP.UTILS.blind_col_numtokey(MP.LOBBY.client.blind_col),
									set = "Blind",
								}),
								scale = 0.8,
								options = create_blind_colour_options(blind_colour_count),
								opt_callback = "change_blind_col",
								current_option = MP.LOBBY.client.blind_col,
							}),
						},
					},
				},
			},
		},
	}
	return ret
end

function MP.UI.create_extra_tabs()
	return {
		{
			label = localize("k_customization"),
			tab_definition_function = create_customization_tab,
		},
	}
end

-- ============================================================================
-- SECTION 4: SMODS MENU HOOKS & ACTION HANDLERS
-- (Consolidated from smods_menu_hooks.lua)
-- ============================================================================


current_mod.credits_tab = MP.UI.create_credits_tab

current_mod.config_tab = MP.UI.create_config_tab

current_mod.extra_tabs = MP.UI.create_extra_tabs

BALATRO.set_ui_function("bmp_discord", function(e)
	BALATRO.open_url("https://discord.gg/gEemz4ptuF")
end)

BALATRO.set_ui_function("bmp_github", function(e)
	BALATRO.open_url("https://github.com/Balatro-Multiplayer/BalatroMultiplayer/")
end)

BALATRO.set_ui_function("change_blind_col", function(args)
	local blind_col = MP.UTILS.save_blind_col(args.to_val)
	local sprite = BALATRO.get_overlay_element_by_id("blind_col_changer_sprite")
	local next_sprite = BALATRO.create_animated_sprite(
		0,
		0,
		1.4,
		1.4,
		BALATRO.get_animation_atlas("mp_player_blind_col"),
		(G and G.P_BLINDS and G.P_BLINDS[MP.UTILS.blind_col_numtokey(blind_col)] or nil).pos
	)
	MP.UI.UTILS.replace_config_object(sprite, next_sprite, {
		recalculate_object = false,
		recalculate_ui_box = false,
	})
	next_sprite:define_draw_steps({
		{ shader = "dissolve", shadow_height = 0.05 },
		{ shader = "dissolve" },
	})
	BALATRO.recalculate_ui(sprite)
	local option = BALATRO.get_overlay_element_by_id("blind_col_changer_option")
	option.children[1].children[1].config.text =
		localize({ type = "name_text", key = MP.UTILS.blind_col_numtokey(blind_col), set = "Blind" })
	BALATRO.recalculate_ui(option)
end)

BALATRO.set_ui_function("mp_change_timersfx", function(args)
	MP.PLATFORM.SMODS.set_config_value("timersfx", args.to_key)
	MP.save_current_config()
end)

BALATRO.set_ui_function("mp_change_score_calculator_backend", function(args)
	MP.PLATFORM.SMODS.set_config_value("calculator.backend", args.to_key)
	MP.save_current_config()

	local overlay = (G and G.OVERLAY_MENU or nil)
	local option_row = BALATRO.get_overlay_element_by_id("score_calculator_backend")
	local cycle_main = option_row and overlay and overlay.get_UIE_by_ID
		and overlay:get_UIE_by_ID("cycle_main", option_row) or nil
	if cycle_main and cycle_main.config and MP.UI and type(MP.UI.get_score_calculator_backend_tooltip) == "function" then
		cycle_main.config.on_demand_tooltip = {
			text = MP.UI.get_score_calculator_backend_tooltip(args.to_key),
		}
	end

	if MP and MP.CALCULATOR_V2 and type(MP.CALCULATOR_V2.invalidate_cache) == "function" then
		MP.CALCULATOR_V2.invalidate_cache()
	end
	if MP.COMPATIBILITY and MP.COMPATIBILITY.PREVIEW then
		MP.COMPATIBILITY.PREVIEW.refresh_after_score_calculator_backend_change(args.to_key)
	end
end)

BALATRO.set_ui_function("change_mp_speed", function(args)
	if G and G.SETTINGS then
		G.SETTINGS.mp_speed = args.to_val
		if G.save_settings then G:save_settings() end
	end
end)

if G and G.FUNCS then
	G.FUNCS.change_mp_speed = function(args)
		if G and G.SETTINGS then
			G.SETTINGS.mp_speed = args.to_val
			if G.save_settings then G:save_settings() end
		end
	end
end





