G.P_CENTER_POOLS.Gamemode = {}
MP.Gamemodes = {}
local selection_utils = MP.UTILS

MP.Gamemode = SMODS.GameObject:extend({
	obj_table = {},
	obj_buffer = {},
	required_params = {
		"key",
		"get_blinds_by_ante", -- Define custom logic for determining Small, Big, and Boss Blind based on the ante number.
		"banned_jokers",
		"banned_consumables",
		"banned_vouchers",
		"banned_enhancements",
		"banned_tags",
		"banned_blinds",
		"reworked_jokers",
		"reworked_consumables",
		"reworked_vouchers",
		"reworked_enhancements",
		"reworked_tags",
		"reworked_blinds",
		"create_info_menu",
	},
	class_prefix = "gamemode",
	inject = function(self)
		MP.Gamemodes[self.key] = self
		if not G.P_CENTER_POOLS.Gamemode then G.P_CENTER_POOLS.Gamemode = {} end
		if not selection_utils.pool_contains_key(G.P_CENTER_POOLS.Gamemode, self.key) then
			table.insert(G.P_CENTER_POOLS.Gamemode, self)
		end
	end,
	process_loc_text = function(self)
		SMODS.process_loc_text(G.localization.descriptions["Gamemode"], self.key, self.loc_txt)
	end,
})

local function make_row_spacer(size)
	local spacer_size = size or 0.2
	return {
		n = G.UIT.R,
		config = {
			minw = spacer_size,
			minh = spacer_size,
		},
	}
end

local function make_chip_spacer()
	return {
		n = G.UIT.C,
		config = {
			minw = 0.2,
			minh = 0.2,
		},
	}
end

local function make_blind_chip_node(chip_key)
	return {
		n = G.UIT.O,
		config = {
			object = MP.UI.BlindChip[chip_key](),
		},
	}
end

local function make_blind_chip_nodes(chip_keys)
	local nodes = {}
	for index, chip_key in ipairs(chip_keys) do
		if index > 1 then
			nodes[#nodes + 1] = make_chip_spacer()
		end
		nodes[#nodes + 1] = make_blind_chip_node(chip_key)
	end
	return nodes
end

local function make_blind_row(row)
	return {
		n = G.UIT.R,
		config = {
			align = "cm",
		},
		nodes = {
			MP.UI.BackgroundGrouping(localize(row.label), make_blind_chip_nodes(row.chips), { text_scale = 0.6 }),
		},
	}
end

local function make_blind_column(blind_rows)
	local nodes = {}
	for index, row in ipairs(blind_rows or {}) do
		if index > 1 then
			nodes[#nodes + 1] = make_row_spacer(0.2)
		end
		nodes[#nodes + 1] = make_blind_row(row)
	end

	return {
		n = G.UIT.C,
		config = {
			align = "cm",
		},
		nodes = nodes,
	}
end

local function make_lives_column(lives)
	return {
		n = G.UIT.C,
		config = {
			align = "cm",
		},
		nodes = {
			{
				n = G.UIT.R,
				config = {
					align = "cm",
				},
				nodes = {
					MP.UI.BackgroundGrouping(localize("k_lives"), {
						{
							n = G.UIT.T,
							config = {
								text = tostring(lives),
								scale = 1.5,
								colour = G.C.UI.TEXT_LIGHT,
							},
						},
					}, { text_scale = 0.6 }),
				},
			},
		},
	}
end

function MP.build_gamemode_info_menu(args)
	local info_columns = {
		make_blind_column(args.blind_rows),
	}
	if args.lives ~= nil then
		info_columns[#info_columns + 1] = make_lives_column(args.lives)
	end

	local nodes = {
		{
			n = G.UIT.R,
			config = {
				align = "tm",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = MP.UTILS.wrapText(localize(args.description_key), 70),
						scale = 0.6,
						colour = G.C.UI.TEXT_LIGHT,
					},
				},
			},
		},
		make_row_spacer(args.spacer_size),
		{
			n = G.UIT.R,
			config = {
				align = "cm",
				padding = 0.3,
			},
			nodes = info_columns,
		},
	}

	if args.show_values_note then
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = {
				align = "bm",
			},
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = localize("k_values_are_modifiable"),
						scale = 0.4,
						colour = G.C.UI.TEXT_LIGHT,
					},
				},
			},
		}
	end

	return nodes
end
