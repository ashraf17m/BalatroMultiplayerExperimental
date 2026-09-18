-- Consolidated Overlays & Dialogs Module
-- Replaces 6 fragmented files with a unified, cohesive vertical module.

G = G or {}
G.UIDEF = G.UIDEF or {}
G.FUNCS = G.FUNCS or {}
MP = MP or {}
MP.UI = MP.UI or {}
MP.SHORTCUTS = MP.SHORTCUTS or {
	visible = false,
	ui = nil,
	current_shortcuts = nil,
}
MP.HOOKS = MP.HOOKS or {}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- ============================================================================
-- SECTION 1: CONFIRMATION DIALOG
-- (Consolidated from confirmation_overlay.lua)
-- ============================================================================

function G.UIDEF.confirmation_dialog(back_func)
	return create_UIBox_generic_options({
		back_func = back_func or "options",
		contents = {
			MP.UI.UTILS.create_row({ align = "cm", padding = 0 }, {
				MP.UI.UTILS.create_row({ align = "cm", padding = 0.5 }, {
					MP.UI.UTILS.create_text_node(localize("k_are_you_sure"), {
						scale = 0.6,
						colour = G.C.UI.TEXT_LIGHT,
					}),
				}),
				UIBox_button({
					label = { localize("k_yes") },
					button = "confirmation_dialog_yes",
					minw = 5,
				}),
			}),
		},
	})
end

do
	local confirm_selection_callback = nil

	BALATRO.set_ui_function("confirm_selection", function(callback, back_func)
		confirm_selection_callback = callback
		BALATRO.open_overlay_menu({
			definition = G.UIDEF.confirmation_dialog(back_func),
		})
	end)

	BALATRO.set_ui_function("confirmation_dialog_yes", function()
		BALATRO.exit_overlay_menu()
		if confirm_selection_callback then
			confirm_selection_callback()
			confirm_selection_callback = nil
		end
	end)
end

-- ============================================================================
-- SECTION 2: VERSION MISMATCH WARNING MODAL
-- (Consolidated from version_mismatch_warning.lua)
-- ============================================================================

local UPDATE_DOCS_URL = "https://balatromp.com/docs/getting-started/installation"

local function create_column(config, nodes)
	return { n = G.UIT.C, config = config or {}, nodes = nodes or {} }
end

local function create_blank(width, height)
	return { n = G.UIT.B, config = { w = width or 0.1, h = height or 0.1 } }
end

local function text_node(text, scale, colour, extra)
	extra = extra or {}
	extra.text = text
	extra.scale = scale
	extra.colour = colour
	return MP.UI.UTILS.create_text_node(text, extra)
end

local function mismatch_player_name(mismatch)
	local player = mismatch and mismatch.player or nil
	return (player and player.username) or "Player"
end

local function create_mismatch_row(mismatch)
	return MP.UI.UTILS.create_row({ align = "cm", padding = 0.08 }, {
		text_node(tostring(mismatch.mod or "Mod") .. " -", 0.4, G.C.UI.TEXT_LIGHT, { maxw = 2.6 }),
		create_blank(0.18, 0.1),
		text_node("Host: " .. tostring(mismatch.our or "?"), 0.35, G.C.BLUE, { maxw = 3.2 }),
		create_blank(0.2, 0.1),
		text_node(mismatch_player_name(mismatch) .. ": " .. tostring(mismatch.their or "?"), 0.35, G.C.ORANGE, { maxw = 3.8 }),
	})
end

local function build_version_mismatch_modal(mismatches)
	local rows = {
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.1 }, {
			text_node("VERSION MISMATCH", 0.8, G.C.RED),
		}),
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
			text_node("Players have mismatched mod versions.", 0.4, G.C.UI.TEXT_LIGHT),
		}),
		MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
			text_node("Seeds, shops and jokers can desync.", 0.4, G.C.UI.TEXT_LIGHT),
		}),
	}

	for _, mismatch in ipairs(mismatches or {}) do
		rows[#rows + 1] = create_mismatch_row(mismatch)
	end

	rows[#rows + 1] = MP.UI.UTILS.create_row({ align = "cm", padding = 0.12 }, {
		text_node("Update so everyone matches before playing.", 0.4, G.C.UI.TEXT_LIGHT),
	})
	rows[#rows + 1] = MP.UI.UTILS.create_row({ align = "cm", padding = 0.15 }, {
		UIBox_button({
			label = { "How to update" },
			button = "mp_open_update_docs",
			colour = HEX("72A5F2"),
			minw = 4.2,
			scale = 0.5,
			col = true,
		}),
		create_blank(0.25, 0.1),
		UIBox_button({
			label = { "Continue anyway" },
			button = "exit_overlay_menu",
			colour = G.C.RED,
			minw = 3.4,
			scale = 0.5,
			col = true,
		}),
	})

	G.FUNCS.overlay_menu({
		definition = create_UIBox_generic_options({
			no_back = true,
			contents = {
				create_column({ align = "cm", padding = 0.15 }, rows),
			},
		}),
	})
end

function G.FUNCS.mp_open_update_docs(e)
	if love and love.system and love.system.openURL then
		love.system.openURL(UPDATE_DOCS_URL)
	end
end

function MP.UI.reset_version_mismatch_warning()
	MP._version_mismatch_shown = false
end

function MP.UI.show_version_mismatch_if_needed()
	if MP._version_mismatch_shown then return false end
	if G.screenwipe or G.OVERLAY_MENU then return false end
	if not (MP.LOBBY and MP.LOBBY.code and MP.UTILS and MP.UTILS.version_mismatches) then return false end

	local mismatches = MP.UTILS.version_mismatches(MP.LOBBY.players)
	if #mismatches == 0 then
		MP._version_mismatch_shown = false
		return false
	end

	build_version_mismatch_modal(mismatches)
	MP._version_mismatch_shown = true
	return true
end

if MP.HOOKS and MP.HOOKS.register_method_hook then
	MP.HOOKS.register_method_hook(Game, "Game", "update", "mp.ui.version_mismatch_warning", {
		after = function()
			if not (MP.LOBBY and MP.LOBBY.code and MP.LOBBY.is_host) then return end
			if G.STAGE ~= G.STAGES.MAIN_MENU then return end
			MP.UI.show_version_mismatch_if_needed()
		end,
	})
end

-- ============================================================================
-- SECTION 3: KEYBOARD SHORTCUTS OVERLAY
-- (Consolidated from shortcuts_menu.lua)
-- ============================================================================

local function is_main_menu()
	return (G and G.STAGES and G.STAGE == G.STAGES.MAIN_MENU or false)
end

local function is_overlay_open()
	return (G and G.OVERLAY_MENU) ~= nil
end

local function call_ui_function(name, ...)
	if BALATRO.call_ui_function then
		return BALATRO.call_ui_function(name, ...)
	end
	if G and G.FUNCS and type(G.FUNCS[name]) == "function" then
		return G.FUNCS[name](...)
	end
	return nil
end

local function add_shortcut(shortcuts, label_key, key, action)
	shortcuts[#shortcuts + 1] = {
		label = localize(label_key),
		key = key,
		action = action,
	}
end

local function get_shortcuts()
	local shortcuts = {}
	local lobby = MP.LOBBY or {}
	local config = lobby.config or {}
	local client = lobby.client or {}
	local in_lobby = lobby.code ~= nil
	local connected = client.connected == true

	if not is_main_menu() then
		return shortcuts
	end

	if in_lobby then
		add_shortcut(shortcuts, "b_copy_code", "C", function()
			MP.UTILS.copy_to_clipboard(lobby.code)
		end)
		add_shortcut(shortcuts, "b_view_code", "V", function()
			MP.UI.UTILS.overlay_message(lobby.code)
		end)
		if lobby.is_host or config.different_decks then
			add_shortcut(shortcuts, "b_sc_choose_deck", "D", function()
				call_ui_function("lobby_choose_deck", { config = {} })
			end)
		end
		add_shortcut(shortcuts, "b_leave_lobby", "L", function()
			call_ui_function("lobby_leave")
		end)
	elseif connected then
		add_shortcut(shortcuts, "k_paste", "V", function()
			call_ui_function("join_from_clipboard")
		end)
		add_shortcut(shortcuts, "b_join_lobby", "J", function()
			call_ui_function("join_lobby")
		end)
		add_shortcut(shortcuts, "b_create_lobby", "C", function()
			call_ui_function("create_group_lobby")
		end)
	else
		add_shortcut(shortcuts, "b_reconnect", "R", function()
			call_ui_function("reconnect")
		end)
	end

	return shortcuts
end

local function create_keycap(key)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.04,
			r = 0.05,
			colour = G.C.PURPLE,
			minw = 0.6,
		},
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = key,
					scale = 0.4,
					colour = G.C.UI.TEXT_LIGHT,
					shadow = true,
				},
			},
		},
	}
end

local function create_shortcut_row(shortcut)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			padding = 0.04,
			r = 0.08,
			colour = G.C.L_BLACK,
			hover = true,
			button = "mp_shortcut_exec",
			ref_table = shortcut,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minw = 1 },
				nodes = { create_keycap(shortcut.key) },
			},
			{
				n = G.UIT.C,
				config = { align = "cl", minw = 3.5 },
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = " " .. shortcut.label,
							scale = 0.38,
							colour = G.C.UI.TEXT_LIGHT,
						},
					},
				},
			},
		},
	}
end

local function create_shortcuts_ui(shortcuts)
	local rows = {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = localize("k_sc_title"),
						scale = 0.5,
						colour = G.C.UI.TEXT_LIGHT,
						shadow = true,
					},
				},
			},
		},
	}

	for _, shortcut in ipairs(shortcuts) do
		rows[#rows + 1] = create_shortcut_row(shortcut)
	end

	rows[#rows + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.06 },
		nodes = {
			{
				n = G.UIT.T,
				config = {
					text = localize("k_sc_hint"),
					scale = 0.3,
					colour = G.C.UI.TEXT_INACTIVE,
				},
			},
		},
	}

	return {
		n = G.UIT.ROOT,
		config = {
			align = "cl",
			colour = { 0, 0, 0, 0.4 },
			r = 0.15,
			padding = 0.15,
			minw = 5,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cl", padding = 0.05 },
				nodes = rows,
			},
		},
	}
end

function G.FUNCS.mp_shortcut_exec(e)
	local shortcut = e and e.config and e.config.ref_table or nil
	if shortcut and shortcut.action then
		MP.SHORTCUTS.hide()
		shortcut.action()
	end
end

function MP.SHORTCUTS.show()
	if MP.SHORTCUTS.visible or is_overlay_open() then
		return
	end

	local shortcuts = get_shortcuts()
	if #shortcuts == 0 then
		return
	end

	MP.SHORTCUTS.visible = true
	MP.SHORTCUTS.current_shortcuts = shortcuts
	MP.SHORTCUTS.ui = UIBox({
		definition = create_shortcuts_ui(shortcuts),
		config = {
			align = "cm",
			offset = { x = -5, y = 0 },
			major = BALATRO.get_room_attach and BALATRO.get_room_attach() or G.ROOM_ATTACH,
			bond = "Weak",
		},
	})
end

function MP.SHORTCUTS.hide()
	if not MP.SHORTCUTS.visible then
		return
	end

	MP.SHORTCUTS.visible = false
	if MP.SHORTCUTS.ui then
		MP.SHORTCUTS.ui:remove()
		MP.SHORTCUTS.ui = nil
	end
	MP.SHORTCUTS.current_shortcuts = nil
end

function MP.SHORTCUTS.execute_key(key)
	if type(key) ~= "string" or not MP.SHORTCUTS.current_shortcuts then
		return false
	end

	local upper_key = string.upper(key)
	for _, shortcut in ipairs(MP.SHORTCUTS.current_shortcuts) do
		if shortcut.key == upper_key then
			MP.SHORTCUTS.hide()
			shortcut.action()
			return true
		end
	end
	return false
end

local function install_controller_shortcut_hooks()
	if not (Controller and MP.HOOKS and MP.HOOKS.register_method_hook) then
		return false
	end

	local installed_press = MP.HOOKS.register_method_hook(Controller, "Controller", "key_press_update", "mp.shortcuts.key_press", {
		before = function(ctx)
			local key = ctx.args[1]
			if MP.SHORTCUTS.visible and type(key) == "string" and #key == 1 then
				if MP.SHORTCUTS.execute_key(key) then
					ctx.skip_original = true
					ctx.results = { n = 0 }
				end
				return
			end

			if key == "tab" then
				MP.SHORTCUTS.show()
				if MP.SHORTCUTS.visible then
					ctx.skip_original = true
					ctx.results = { n = 0 }
				end
			end
		end,
	})

	local installed_release = MP.HOOKS.register_method_hook(Controller, "Controller", "key_release_update", "mp.shortcuts.key_release", {
		before = function(ctx)
			if ctx.args[1] == "tab" then
				MP.SHORTCUTS.hide()
			end
		end,
	})

	return installed_press and installed_release
end

install_controller_shortcut_hooks()

-- ============================================================================
-- SECTION 4: RULESET INFO POPUP MENU
-- (Consolidated from ruleset_info_view.lua)
-- ============================================================================

function MP.UI.CreateRulesetInfoMenu(config)
	local has_mp_content = config.multiplayer_content and "k_yes" or "k_no"
	local has_mp_color = config.multiplayer_content and G.C.GREEN or G.C.RED
	local forces_lobby = config.forced_lobby_options and "k_yes" or "k_no"
	local forces_lobby_color = config.forced_lobby_options and G.C.GREEN or G.C.RED
	local forces_gamemode_text = config.forced_gamemode_text or "k_no"
	local forces_gamemode_color = config.forced_gamemode_text and G.C.GREEN or G.C.RED

	return {
		{
			n = G.UIT.R,
			config = {
				align = "tm",
			},
			nodes = {
				MP.UI.BackgroundGrouping(localize("k_has_multiplayer_content"), {
					{
						n = G.UIT.T,
						config = {
							text = localize(has_mp_content),
							scale = 0.8,
							colour = has_mp_color,
						},
					},
				}, { col = true, text_scale = 0.6 }),
				{
					n = G.UIT.C,
					config = {
						minw = 0.1,
						minh = 0.1,
					},
				},
				MP.UI.BackgroundGrouping(localize("k_forces_lobby_options"), {
					{
						n = G.UIT.T,
						config = {
							text = localize(forces_lobby),
							scale = 0.8,
							colour = forces_lobby_color,
						},
					},
				}, { col = true, text_scale = 0.6 }),
				{
					n = G.UIT.C,
					config = {
						minw = 0.1,
						minh = 0.1,
					},
				},
				MP.UI.BackgroundGrouping(localize("k_forces_gamemode"), {
					{
						n = G.UIT.T,
						config = {
							text = localize(forces_gamemode_text),
							scale = 0.8,
							colour = forces_gamemode_color,
						},
					},
				}, { col = true, text_scale = 0.6 }),
			},
		},
		{
			n = G.UIT.R,
			config = {
				minw = 0.05,
				minh = 0.05,
			},
		},
		{
			n = G.UIT.R,
			config = {
				align = "cl",
				padding = 0.1,
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = localize(config.description_key),
						scale = 0.6,
						colour = G.C.UI.TEXT_LIGHT,
					},
				},
			},
		},
	}
end

-- ============================================================================
-- SECTION 5: MOD LIST VIEW CONTAINER
-- (Consolidated from ui_modlist_views.lua)
-- ============================================================================

local function starts_with(text, prefix)
	return type(text) == "string" and string.sub(text, 1, #prefix) == prefix
end

local function fade_colour(colour, alpha)
	if adjust_alpha then
		return adjust_alpha(colour, alpha)
	end
	return colour
end

local function get_player_mods(player_id)
	local mods_table = {}

	if MP.LOBBY.players then
		for _, player in ipairs(MP.LOBBY.players) do
			if player.id == player_id then
				mods_table = player.config and player.config.Mods or {}
				break
			end
		end
	end

	return mods_table
end

local function create_modlist_container(nodes)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
			colour = G.C.L_BLACK,
			r = 0.1,
			padding = 0.08,
		},
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm" },
				nodes = nodes,
			},
		},
	}
end

function MP.UI.modlist_to_view(mods, text_colour)
	text_colour = text_colour or G.C.WHITE
	local nodes = {}

	if not mods then
		return nodes
	end

	local special_mods_targets = {
		"Lovely",
		"Steamodded",
		"Multiplayer",
		"Preview",
	}
	local special_mods_found = {}
	local other_mods = {}
	for mod_name, mod_version in pairs(mods) do
		local found = false
		for _, id in ipairs(special_mods_targets) do
			if not special_mods_found[id] and starts_with(mod_name, id) then
				special_mods_found[id] = { name = mod_name, version = mod_version }
				found = true
				break
			end
		end
		if not found then
			other_mods[#other_mods + 1] = { name = mod_name, version = mod_version }
		end
	end

	table.sort(other_mods, function(a, b)
		return a.name < b.name
	end)

	local function add_mod_row(mod)
		if not mod then return end

		local mod_name = mod.name
		local mod_version = mod.version
		if MP.UTILS and MP.UTILS.resolve_mod_name_and_version then
			mod_name, mod_version = MP.UTILS.resolve_mod_name_and_version(mod_name, mod_version)
		end
		local color = MP.BANNED_MODS and MP.BANNED_MODS[mod.name] and G.C.RED or text_colour
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = {
				padding = 0.025,
				align = "cm",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = mod_name,
						scale = 0.32,
						colour = color,
					},
				},
				mod_version and {
					n = G.UIT.T,
					config = {
						text = " " .. mod_version,
						scale = 0.32,
						colour = fade_colour(color, 0.6),
					},
				} or nil,
			},
		}
	end

	local function add_separator()
		if #nodes == 0 then return end
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = {
				minh = 0.025,
				colour = fade_colour(text_colour, 0.25),
			},
		}
	end

	local function add_group(group)
		local group_rows = {}
		for _, mod in ipairs(group) do
			if mod then
				group_rows[#group_rows + 1] = mod
			end
		end
		if #group_rows == 0 then return end

		add_separator()
		for _, mod in ipairs(group_rows) do
			add_mod_row(mod)
		end
	end

	add_group({ special_mods_found.Lovely, special_mods_found.Steamodded })
	add_group({ special_mods_found.Multiplayer, special_mods_found.Preview })
	add_group(other_mods)
	return nodes
end

function MP.UI.create_UIBox_mods_list(player_id)
	local mods_table = get_player_mods(player_id)
	return create_modlist_container(MP.UI.modlist_to_view(mods_table, G.C.WHITE))
end

-- ============================================================================
-- SECTION 6: JIMBO CHARACTER OVERLAY
-- (Consolidated from jimbo_overlay.lua)
-- ============================================================================

local mp_jimbo = nil
local mp_jimbo_pos = nil
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local APPLY_IMMEDIATELY = true
local APPLY_SILENTLY = true

local JIMBO_POSITIONS = {
	[1] = { align = "cri", offset = { x = 1, y = 0 }, bubble_align = "cl", bubble_offset = { x = 0, y = 0 } },
	[2] = { align = "tli", offset = { x = -0.75, y = -0.75 }, bubble_align = "cr", bubble_offset = { x = 0, y = -0.5 } },
	[3] = { align = "tri", offset = { x = 1.8, y = -0.1 }, bubble_align = "bl", bubble_offset = { x = 2.1, y = 0 } },
	[4] = { align = "cmi", offset = { x = 0, y = -1.5 }, bubble_align = "cr", bubble_offset = { x = 0, y = 0 } },
}

function MP.UI.create_jimbo(pos, text)
	if mp_jimbo then MP.UI.remove_jimbo() end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo = Card_Character({
		x = 0,
		y = G.ROOM.T.h + 5,
		center = "j_perkeo",
		particle_colours = { HEX("4e997b"), HEX("e9564e"), HEX("ebecee") },
	})
	mp_jimbo.children.particles:remove()
	mp_jimbo.children.particles = nil
	mp_jimbo.children.card:set_edition({ negative = true }, APPLY_IMMEDIATELY, APPLY_SILENTLY)
	mp_jimbo.say_stuff = function(self, n, not_first)
		self.talking = true
		if not not_first then
			BALATRO.queue_event({
				trigger = "after",
				timer = "REAL",
				delay = 0.1,
				func = function()
					if self.children.speech_bubble then self.children.speech_bubble.states.visible = true end
					self:say_stuff(n, true)
					return true
				end,
			})
		else
			if n <= 0 then
				self.talking = false
				return
			end
			play_sound("voice" .. math.random(1, 11), math.random() * 0.2 + 1, 0.5)
			self.children.card:juice_up()
			BALATRO.queue_event({
				trigger = "after",
				timer = "REAL",
				blockable = false,
				blocking = false,
				delay = 0.13,
				func = function()
					self:say_stuff(n - 1, true)
					return true
				end,
			}, "tutorial")
		end
	end
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if text then MP.UI.jimbo_say(text) end
	return mp_jimbo
end

function MP.UI.move_jimbo(pos)
	if not mp_jimbo then return end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if mp_jimbo.children.speech_bubble then
		mp_jimbo.children.speech_bubble.alignment.type = p.bubble_align
		mp_jimbo.children.speech_bubble.alignment.offset = p.bubble_offset
		mp_jimbo.children.speech_bubble:align_to_major()
	end
end

function MP.UI.jimbo_say(text)
	if not mp_jimbo then return end
	if mp_jimbo.children.speech_bubble then mp_jimbo.children.speech_bubble:remove() end
	local lines = {}
	for line in MP.UTILS.wrapText(text, 30):gmatch("[^\n]+") do
		lines[#lines + 1] = line:match("^%s*(.-)%s*$")
	end
	local rows = {}
	for _, line in ipairs(lines) do
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cl" },
			nodes = {
				{ n = G.UIT.T, config = { text = line, scale = 0.4, colour = G.C.UI.TEXT_DARK } },
			},
		}
	end
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "cm", minh = 1, r = 0.3, padding = 0.07, minw = 1, colour = G.C.JOKER_GREY, shadow = true },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minh = 1, r = 0.2, padding = 0.1, minw = 1, colour = G.C.WHITE },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", minh = 1, r = 0.2, padding = 0.03, minw = 1, colour = G.C.WHITE },
						nodes = rows,
					},
				},
			},
		},
	}
	local p = JIMBO_POSITIONS[mp_jimbo_pos] or JIMBO_POSITIONS[1]
	mp_jimbo.children.speech_bubble = UIBox({
		definition = definition,
		config = { align = p.bubble_align, offset = p.bubble_offset, parent = mp_jimbo },
	})
	mp_jimbo.children.speech_bubble:set_role({
		role_type = "Minor",
		xy_bond = "Weak",
		r_bond = "Strong",
		major = mp_jimbo,
	})
	mp_jimbo.children.speech_bubble.states.visible = true
	local word_count = select(2, text:gsub("%S+", ""))
	local read_time = math.max(5, word_count * 0.3 + 1) + 5
	mp_jimbo:say_stuff(math.ceil(word_count / 2))
	local bubble_ref = mp_jimbo.children.speech_bubble
	BALATRO.queue_event({
		trigger = "after",
		timer = "REAL",
		blockable = false,
		blocking = false,
		delay = read_time,
		func = function()
			if mp_jimbo and mp_jimbo.children.speech_bubble == bubble_ref then
				mp_jimbo.children.speech_bubble:remove()
				mp_jimbo.children.speech_bubble = nil
			end
			return true
		end,
	})
end

function MP.UI.remove_jimbo()
	if not mp_jimbo then return end
	local jimbo = mp_jimbo
	mp_jimbo = nil
	if jimbo.children.speech_bubble then
		jimbo.children.speech_bubble:remove()
		jimbo.children.speech_bubble = nil
	end
	if jimbo.children.button then
		jimbo.children.button:remove()
		jimbo.children.button = nil
	end
	jimbo.children.card:start_dissolve({ HEX("4e997b") }, nil, nil, true)
	if jimbo.children.particles then jimbo.children.particles:fade(0.5) end
	BALATRO.queue_event({
		trigger = "after",
		blockable = false,
		delay = 0.8,
		func = function()
			jimbo:remove()
			return true
		end,
	})
end

