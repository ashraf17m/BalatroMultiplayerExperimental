local BANNED_MODS = {
	["Incantation"] = true,
	["Brainstorm"] = true,
	["DVPreview"] = true,
	["Aura"] = true,
	["NotJustYet"] = true,
	["Showman"] = true,
	["TagPreview"] = true,
	["FantomsPreview"] = true,
}

local function format_mod_display_text(mod_name, mod_version)
	if mod_name == "Multiplayer" then
		local display_name = MP.display_name or MP.name or mod_name
		if mod_version then
			return display_name .. " " .. mod_version
		end
		return display_name
	end

	if mod_version then
		return mod_name .. "-" .. mod_version
	end

	return mod_name
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
		config = { align = "cm", colour = G.C.JOKER_GREY, r = 0.1, emboss = 0.05, padding = 0.03 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", colour = G.C.L_BLACK, r = 0.1, emboss = 0.05, padding = 0.08 },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm" },
						nodes = nodes,
					},
				},
			},
		},
	}
end

function MP.UI.modlist_to_view(mods, text_colour)
	local nodes = {}

	if not mods then
		return nodes
	end

	for mod_name, mod_version in pairs(mods) do
		local display_text = format_mod_display_text(mod_name, mod_version)
		local color = BANNED_MODS[mod_name] and G.C.RED or text_colour
		table.insert(nodes, {
			n = G.UIT.R,
			config = {
				padding = 0.02,
				align = "cm",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = display_text,
						shadow = true,
						scale = 0.4,
						colour = color,
					},
				},
			},
		})
	end

	return nodes
end

function MP.UI.create_UIBox_mods_list(player_id)
	local mods_table = get_player_mods(player_id)
	return create_modlist_container(MP.UI.modlist_to_view(mods_table, G.C.WHITE))
end
