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
