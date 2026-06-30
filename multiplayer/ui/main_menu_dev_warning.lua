MP.UI = MP.UI or {}
MP.UI.MAIN_MENU = MP.UI.MAIN_MENU or {}

local main_menu = MP.UI.MAIN_MENU
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function create_column(config, nodes)
	config = config or {}
	return { n = G.UIT.C, config = config, nodes = nodes or {} }
end

local function create_blank(width, height)
	return {
		n = G.UIT.C,
		config = {
			minw = width or 0,
			minh = height or 0,
		},
		nodes = {},
	}
end

local function get_client_version()
	return MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.client and tostring(MP.RUNTIME_POLICY.client.version or "")
		or tostring(MP.version or "")
end

BALATRO.set_ui_function("mp_open_install_docs", function()
	if love and love.system and love.system.openURL then
		love.system.openURL("https://balatromp.com/docs/getting-started/installation")
	end
end)

function main_menu.show_dev_build_warning()
	if MP._dev_warning_shown then
		return
	end
	if MP.EXPERIMENTAL and MP.EXPERIMENTAL.suppress_dev_warning then
		return
	end

	local version = get_client_version()
	if not version:lower():match("dev") then
		return
	end

	MP._dev_warning_shown = true

	BALATRO.set_paused(true)
	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			no_back = true,
			no_esc = true,
			contents = {
				create_column({ align = "cm", padding = 0.15 }, {
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.1 }, {
						MP.UI.UTILS.create_text_node("MULTIPLAYER", {
							scale = 0.8,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.05 }, {
						MP.UI.UTILS.create_text_node("Hand of cards, off the workbench - " .. version, {
							scale = 0.55,
							colour = G.C.MULT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("You're playing a dev build - jokers may misbehave.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("Ranked is locked. You may desync your nemesis.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.04 }, {
						MP.UI.UTILS.create_text_node("For a clean shuffle, get the launcher below.", {
							scale = 0.4,
							colour = G.C.UI.TEXT_LIGHT,
						}),
					}),
					MP.UI.UTILS.create_row({ align = "cm", padding = 0.15 }, {
						UIBox_button({
							label = { "Grab the launcher" },
							button = "mp_open_install_docs",
							colour = HEX("72A5F2"),
							minw = 4.2,
							scale = 0.5,
							col = true,
						}),
						create_blank(0.25, 0.1),
						UIBox_button({
							label = { "OK, I'll risk it" },
							button = "exit_overlay_menu",
							colour = G.C.RED,
							minw = 3.2,
							scale = 0.5,
							col = true,
						}),
					}),
				}),
			},
		}),
	})
end

MP.UI.show_dev_build_warning = main_menu.show_dev_build_warning
