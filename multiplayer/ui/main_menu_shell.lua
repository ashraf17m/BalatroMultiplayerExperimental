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
	end,
})

local create_UIBox_main_menu_buttons_ref = create_UIBox_main_menu_buttons
---@diagnostic disable-next-line: lowercase-global
function create_UIBox_main_menu_buttons()
	local menu = create_UIBox_main_menu_buttons_ref()
	menu.nodes[1].nodes[1].nodes[1].nodes[1].config.button = "play_options"
	return menu
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
