MP.UI = MP.UI or {}
MP.SHORTCUTS = MP.SHORTCUTS or {
	visible = false,
	ui = nil,
	current_shortcuts = nil,
}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
G.FUNCS = G.FUNCS or {}

local function is_main_menu()
	if BALATRO.is_main_menu_stage then
		return BALATRO.is_main_menu_stage()
	end
	return G and G.STAGE == G.STAGES.MAIN_MENU
end

local function is_overlay_open()
	if BALATRO.get_overlay_menu then
		return BALATRO.get_overlay_menu() ~= nil
	end
	return G and G.OVERLAY_MENU ~= nil
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
