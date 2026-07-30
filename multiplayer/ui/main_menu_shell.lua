MP.UI = MP.UI or {}
MP.UI.MAIN_MENU = MP.UI.MAIN_MENU or {}

local main_menu = MP.UI.MAIN_MENU
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local multiplayer_name = (MP.display_name or MP.name) or "Multiplayer"
local multiplayer_version = MP.RUNTIME_POLICY and MP.RUNTIME_POLICY.client and MP.RUNTIME_POLICY.client.version or MP.version or ""

function main_menu.build_multiplayer_version_display(name, version)
	if version == "" then
		return name
	end

	return name .. " " .. version
end

local multiplayer_version_display = main_menu.build_multiplayer_version_display(multiplayer_name, multiplayer_version)

function main_menu.add_version_display()
	UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = {
				align = "cm",
				colour = G.C.UI.TRANSPARENT_DARK,
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						scale = 0.3,
						text = multiplayer_version_display,
						colour = G.C.UI.TEXT_LIGHT,
					},
				},
			},
		},
		config = {
			align = "tri",
			bond = "Weak",
			offset = {
				x = 0,
				y = 0.6,
			},
			major = G.ROOM_ATTACH,
		},
	})
end

MP.HOOKS.register_method_hook(Game, "Game", "main_menu", "mp.ui.main_menu_shell", {
	after = function(ctx)
		local change_context = ctx.args and ctx.args[1]
		if main_menu.add_custom_title_card then
			main_menu.add_custom_title_card(change_context)
		end
		main_menu.add_version_display()
		if main_menu.show_dev_build_warning then
			main_menu.show_dev_build_warning()
		end
	end,
})

local create_UIBox_main_menu_buttons_ref = create_UIBox_main_menu_buttons
local function get_main_menu_primary_button(menu)
	return menu
		and menu.nodes
		and menu.nodes[1]
		and menu.nodes[1].nodes
		and menu.nodes[1].nodes[1]
		and menu.nodes[1].nodes[1].nodes
		and menu.nodes[1].nodes[1].nodes[1]
		and menu.nodes[1].nodes[1].nodes[1].nodes
		and menu.nodes[1].nodes[1].nodes[1].nodes[1]
		or nil
end

local function get_main_menu_button_panel(menu_ui)
	local play_button = menu_ui
		and menu_ui.get_UIE_by_ID
		and menu_ui:get_UIE_by_ID("main_menu_play")
		or nil
	return play_button and play_button.parent and play_button.parent.parent or nil
end

local function remove_multiplayer_main_menu_row()
	if G.MP_MAIN_MENU_BUTTONS_UI then
		G.MP_MAIN_MENU_BUTTONS_UI:remove()
		G.MP_MAIN_MENU_BUTTONS_UI = nil
	end
end

local function add_multiplayer_main_menu_row(options)
	options = options or {}
	remove_multiplayer_main_menu_row()

	if BALATRO.is_main_menu_stage and not BALATRO.is_main_menu_stage() then
		return
	end

	local main_menu_ui = BALATRO.get_main_menu_ui and BALATRO.get_main_menu_ui() or G.MAIN_MENU_UI
	if not main_menu_ui or main_menu_ui.is_mp_lobby_menu then
		return
	end

	local panel = get_main_menu_button_panel(main_menu_ui)
	if not panel then
		return
	end

	local main_menu_play = MP.UI and MP.UI.MAIN_MENU_PLAY or nil
	local row = main_menu_play
		and main_menu_play.create_main_menu_button_row
		and main_menu_play.create_main_menu_button_row()
	if row then
		G.MP_MAIN_MENU_BUTTONS_UI = UIBox({
			definition = {
				n = G.UIT.ROOT,
				config = {
					align = "cm",
					colour = G.C.CLEAR,
				},
				nodes = { row },
			},
			config = {
				align = "tm",
				offset = { x = 0, y = -0.08 },
				major = panel,
				bond = "Weak",
			},
		})
		if options.select_text_input_id then
			local input = G.MP_MAIN_MENU_BUTTONS_UI:get_UIE_by_ID(options.select_text_input_id)
			if input and BALATRO.select_text_input then
				BALATRO.select_text_input(input)
			end
		end
	end
end

function MP.UI.refresh_main_menu_multiplayer_buttons(options)
	return add_multiplayer_main_menu_row(options)
end

---@diagnostic disable-next-line: lowercase-global
function create_UIBox_main_menu_buttons()
	local menu = create_UIBox_main_menu_buttons_ref()
	local play_button = get_main_menu_primary_button(menu)
	if play_button and play_button.config then
		play_button.config.button = "start_vanilla_sp"
	end
	return menu
end

local set_main_menu_UI_ref = set_main_menu_UI
---@diagnostic disable-next-line: lowercase-global
function set_main_menu_UI()
	remove_multiplayer_main_menu_row()
	local ret = set_main_menu_UI_ref()
	add_multiplayer_main_menu_row()
	return ret
end

local function cancel_inline_join_lobby_input()
	local main_menu_play = MP.UI and MP.UI.MAIN_MENU_PLAY or nil
	if not (main_menu_play and main_menu_play.cancel_inline_join_lobby_input) then
		return false
	end

	local cancelled = main_menu_play.cancel_inline_join_lobby_input()
	if cancelled then
		add_multiplayer_main_menu_row()
	end
	return cancelled
end

main_menu.cancel_inline_join_lobby_input = cancel_inline_join_lobby_input

local main_menu_join_input_cancel_wrappers = {}
local function wrap_join_input_cancel_button(name)
	if main_menu_join_input_cancel_wrappers[name] then
		return
	end

	local funcs = BALATRO.ensure_ui_functions and BALATRO.ensure_ui_functions() or G.FUNCS
	local original = funcs and funcs[name] or nil
	if type(original) ~= "function" then
		return
	end

	main_menu_join_input_cancel_wrappers[name] = true
	funcs[name] = function(...)
		cancel_inline_join_lobby_input()
		return original(...)
	end
end

for _, button_name in ipairs({
	"start_vanilla_sp",
	"start_run",
	"setup_run",
	"resume_match",
	"create_group_lobby",
	"browse_lobbies",
	"join_from_clipboard",
	"play_options",
	"skip_tutorial",
	"reconnect",
	"options",
	"quit",
	"quit_cta",
	"your_collection",
	"mods_button",
	"profile_select",
	"language_selection",
	"go_to_discord",
	"go_to_discord_loc",
	"go_to_twitter",
}) do
	wrap_join_input_cancel_button(button_name)
end

local function queue_screenwipe_alpha_fade(colour)
	BALATRO.queue_event({
		trigger = "ease",
		no_delete = true,
		blockable = false,
		blocking = false,
		timer = "REAL",
		ref_table = colour,
		ref_value = 4,
		ease_to = 0,
		delay = 0.3,
		func = function(t)
			return t
		end,
	})
end

local function queue_screenwipe_after(delay_time, blocking, func)
	BALATRO.queue_event({
		trigger = "after",
		delay = delay_time,
		no_delete = true,
		blocking = blocking,
		timer = "REAL",
		func = func,
	})
end

G.FUNCS.wipe_off = function()
	remove_multiplayer_main_menu_row()
	BALATRO.queue_event({
		no_delete = true,
		func = function()
			delay(0.3)
			if not G.screenwipe then
				return true
			end
			G.screenwipe.children.particles.max = 0
			queue_screenwipe_alpha_fade(G.screenwipe.colours.black)
			queue_screenwipe_alpha_fade(G.screenwipe.colours.white)
			return true
		end,
	})
	queue_screenwipe_after(0.55, false, function()
		if not G.screenwipe then
			return true
		end
		if G.screenwipecard then
			G.screenwipecard:start_dissolve({ G.C.BLACK, G.C.ORANGE, G.C.GOLD, G.C.RED })
		end
		if G.screenwipe:get_UIE_by_ID("text") then
			for _, child in ipairs(G.screenwipe:get_UIE_by_ID("text").children) do
				child.children[1].config.object:pop_out(4)
			end
		end
		return true
	end)
	queue_screenwipe_after(1.1, false, function()
		if not G.screenwipe then
			return true
		end
		G.screenwipe.children.particles:remove()
		G.screenwipe:remove()
		G.screenwipe.children.particles = nil
		G.screenwipe = nil
		G.screenwipecard = nil
		return true
	end)
	queue_screenwipe_after(1.2, true, function()
		return true
	end)
end
