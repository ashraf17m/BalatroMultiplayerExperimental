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

MP.HOOKS.register_method_hook(Game, "Game", "update", "mp.ui.version_mismatch_warning", {
	after = function()
		if not (MP.LOBBY and MP.LOBBY.code and MP.LOBBY.is_host) then return end
		if G.STAGE ~= G.STAGES.MAIN_MENU then return end
		MP.UI.show_version_mismatch_if_needed()
	end,
})
