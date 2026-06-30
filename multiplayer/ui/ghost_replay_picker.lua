MP.UI = MP.UI or {}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local picker_replays = {}
local preview_idx = nil
local preview_flipped = false

local function reopen_practice_options()
	if BALATRO.call_ui_function then
		BALATRO.call_ui_function("mp_open_practice_options_overlay")
	end
end

local function refresh_picker()
	if BALATRO.exit_overlay_menu then BALATRO.exit_overlay_menu() end
	if BALATRO.open_overlay_menu then
		BALATRO.open_overlay_menu({
			definition = G.UIDEF.ghost_replay_picker(),
		})
	end
end

local function resolve_replay_index(e)
	return tonumber(e and e.config and tostring(e.config.id or ""):match("ghost_replay_(%d+)"))
end

BALATRO.set_ui_function("open_ghost_replay_picker", function()
	if BALATRO.open_overlay_menu then
		BALATRO.open_overlay_menu({
			definition = G.UIDEF.ghost_replay_picker(),
		})
	end
end)

BALATRO.set_ui_function("preview_ghost_replay", function(e)
	local idx = resolve_replay_index(e)
	if idx ~= preview_idx then
		preview_flipped = false
	end
	preview_idx = idx
	refresh_picker()
end)

BALATRO.set_ui_function("load_previewed_ghost", function(e)
	local replay = picker_replays[preview_idx or 0]
	if not (replay and MP.GHOST and MP.GHOST.is_ruleset_supported and MP.GHOST.is_ruleset_supported(replay)) then
		return
	end

	MP.GHOST.load(replay)
	MP.GHOST.flipped = preview_flipped

	local ruleset_key = replay.ruleset or (MP.SP and MP.SP.ruleset) or MP.DEFAULT_LOBBY_CREATION_RULESET
	if MP.set_practice_ruleset then
		MP.set_practice_ruleset(ruleset_key)
	end
	if MP.SP then
		MP.SP.gamemode = replay.gamemode or MP.DEFAULT_LOBBY_CREATION_GAMEMODE
	end

	preview_idx = nil
	preview_flipped = false
	BALATRO.call_ui_function("start_practice_run", e)
end)

BALATRO.set_ui_function("select_ghost_replay", function(e)
	BALATRO.call_ui_function("preview_ghost_replay", e)
end)

BALATRO.set_ui_function("clear_ghost_replay", function()
	if MP.GHOST and MP.GHOST.clear then MP.GHOST.clear() end
	preview_idx = nil
	preview_flipped = false
	reopen_practice_options()
end)

BALATRO.set_ui_function("flip_ghost_perspective", function()
	if preview_idx then
		preview_flipped = not preview_flipped
	elseif MP.GHOST and MP.GHOST.flip then
		MP.GHOST.flip()
	end
	refresh_picker()
end)

BALATRO.set_ui_function("ghost_picker_back", function()
	preview_idx = nil
	preview_flipped = false
	reopen_practice_options()
end)

local function text_node(text, scale, colour)
	return {
		n = G.UIT.T,
		config = {
			text = tostring(text or ""),
			scale = scale or 0.3,
			colour = colour or G.C.WHITE,
		},
	}
end

local function text_row(label, value, scale, value_colour)
	return {
		n = G.UIT.R,
		config = { align = "cl", padding = 0.02 },
		nodes = {
			text_node(tostring(label or "") .. " ", scale or 0.28, G.C.UI.TEXT_INACTIVE),
			text_node(value, scale or 0.28, value_colour or G.C.WHITE),
		},
	}
end

local function section_header(title)
	return {
		n = G.UIT.R,
		config = { align = "cl", padding = 0.04 },
		nodes = {
			text_node(title, 0.32, G.C.GOLD),
		},
	}
end

local function create_button(id, button, label, colour, minw, scale)
	return UIBox_button({
		id = id,
		button = button,
		label = { label },
		minw = minw or 3,
		minh = 0.48,
		scale = scale or 0.32,
		colour = colour,
		hover = true,
		shadow = true,
	})
end

local function display_ruleset(ruleset_key)
	return tostring(ruleset_key or "?"):gsub("^ruleset_mp_", "")
end

local function display_gamemode(gamemode_key)
	return tostring(gamemode_key or "?"):gsub("^gamemode_mp_", "")
end

local function display_date(timestamp)
	if not timestamp then return "?" end
	return os.date("%Y-%m-%d %H:%M", timestamp)
end

local function display_joker_list(jokers)
	if not jokers or #jokers == 0 then return nil end
	local names = {}
	for _, joker in ipairs(jokers) do
		local key = type(joker) == "table" and joker.key or joker
		local center = key and G.P_CENTERS and G.P_CENTERS[key] or nil
		names[#names + 1] = center and center.name or tostring(key or "?")
	end
	return table.concat(names, ", ")
end

local function build_header(replay)
	local result = replay.winner == "player" and "VICTORY" or "DEFEAT"
	local result_colour = replay.winner == "player" and G.C.GREEN or G.C.RED
	return {
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.03 },
			nodes = { text_node(result, 0.42, result_colour) },
		},
		{
			n = G.UIT.R,
			config = { align = "cm", padding = 0.02, maxw = 7.5 },
			nodes = {
				text_node(
					tostring(replay.player_name or "?") .. " vs " .. tostring(replay.nemesis_name or "?"),
					0.34,
					G.C.WHITE
				),
			},
		},
	}
end

local function build_ante_rows(replay)
	local rows = {}
	if not replay.ante_snapshots then return rows end

	local antes = {}
	for key in pairs(replay.ante_snapshots) do
		antes[#antes + 1] = tonumber(key)
	end
	table.sort(antes)

	for _, ante in ipairs(antes) do
		local snap = replay.ante_snapshots[ante] or replay.ante_snapshots[tostring(ante)]
		if snap then
			local result = snap.result == "win" and "W" or "L"
			local result_colour = snap.result == "win" and G.C.GREEN or G.C.RED
			local player_score = MP.GHOST.format_score(snap.player_score or 0)
			local enemy_score = MP.GHOST.format_score(snap.enemy_score or 0)
			rows[#rows + 1] = {
				n = G.UIT.R,
				config = { align = "cl", padding = 0.01, maxw = 7 },
				nodes = {
					text_node("A" .. tostring(ante) .. " ", 0.26, G.C.UI.TEXT_INACTIVE),
					text_node(result, 0.26, result_colour),
					text_node("  " .. player_score .. " - " .. enemy_score, 0.26, G.C.WHITE),
				},
			}
		end
	end
	return rows
end

local function build_spending_rows(replay)
	local rows = {}
	local stats = replay.player_stats or {}
	if stats.reroll_count then
		rows[#rows + 1] = text_row("Rerolls:", stats.reroll_count, 0.26)
	end
	if stats.reroll_cost_total then
		rows[#rows + 1] = text_row("Reroll $:", "$" .. tostring(stats.reroll_cost_total), 0.26)
	end
	if replay.shop_spending then
		local total = 0
		local antes = {}
		for key, value in pairs(replay.shop_spending) do
			antes[#antes + 1] = tonumber(key)
			total = total + (tonumber(value) or 0)
		end
		table.sort(antes)
		rows[#rows + 1] = text_row("Shop $:", "$" .. tostring(total), 0.26)
	end
	return rows
end

local function build_stats_panel(replay)
	if not replay then
		return {
			n = G.UIT.C,
			config = { align = "cm", padding = 0.2, minw = 7.7, minh = 5.6, r = 0.1, colour = G.C.L_BLACK },
			nodes = {
				text_node(localize("k_select_match_replay"), 0.35, G.C.UI.TEXT_INACTIVE),
			},
		}
	end

	local nodes = {}
	for _, row in ipairs(build_header(replay)) do nodes[#nodes + 1] = row end
	nodes[#nodes + 1] = section_header("Match")
	nodes[#nodes + 1] = text_row("Ruleset:", display_ruleset(replay.ruleset), 0.26)
	nodes[#nodes + 1] = text_row("Gamemode:", display_gamemode(replay.gamemode), 0.26)
	nodes[#nodes + 1] = text_row("Deck:", replay.deck or "?", 0.26)
	nodes[#nodes + 1] = text_row("Stake:", replay.stake or "?", 0.26)
	nodes[#nodes + 1] = text_row("Seed:", replay.seed or "?", 0.26)
	nodes[#nodes + 1] = text_row("Date:", display_date(replay.timestamp), 0.26)

	local ante_rows = build_ante_rows(replay)
	if #ante_rows > 0 then
		nodes[#nodes + 1] = section_header("Antes")
		for _, row in ipairs(ante_rows) do nodes[#nodes + 1] = row end
	end

	local your_jokers = display_joker_list(replay.player_jokers)
	local enemy_jokers = display_joker_list(replay.nemesis_jokers)
	if your_jokers or enemy_jokers then
		nodes[#nodes + 1] = section_header("Jokers")
		if your_jokers then nodes[#nodes + 1] = text_row("You:", your_jokers, 0.24) end
		if enemy_jokers then nodes[#nodes + 1] = text_row("Them:", enemy_jokers, 0.24) end
	end

	local spending_rows = build_spending_rows(replay)
	if #spending_rows > 0 then
		nodes[#nodes + 1] = section_header("Spending")
		for _, row in ipairs(spending_rows) do nodes[#nodes + 1] = row end
	end

	local supported = MP.GHOST.is_ruleset_supported(replay)
	if supported then
		local playing_as = preview_flipped and (replay.nemesis_name or "?") or (replay.player_name or "?")
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				create_button("flip_ghost_perspective", "flip_ghost_perspective", "Playing as: " .. playing_as, G.C.BLUE, 3.6, 0.28),
				create_button("load_previewed_ghost", "load_previewed_ghost", localize("b_play_match"), G.C.GREEN, 3, 0.32),
			},
		}
	else
		nodes[#nodes + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.08 },
			nodes = {
				text_node(localize("k_unsupported_replay_ruleset"), 0.3, G.C.RED),
			},
		}
	end

	return {
		n = G.UIT.C,
		config = { align = "tm", padding = 0.12, minw = 7.7, maxw = 7.7, minh = 5.6, maxh = 7.2, r = 0.1, colour = G.C.L_BLACK },
		nodes = nodes,
	}
end

local function load_all_replays()
	if not (MP.GHOST and MP.GHOST.load_folder_replays) then return {} end

	local all = MP.GHOST.load_folder_replays()
	local seen = {}
	for _, replay in ipairs(all) do
		seen[(replay._filename or "") .. ":" .. tostring(replay._game_index or 0)] = true
	end
	for _, replay in ipairs(MP.GHOST.load_lovely_log_replays(10)) do
		local key = (replay._filename or "") .. ":" .. tostring(replay._game_index or 0)
		if not seen[key] then
			seen[key] = true
			all[#all + 1] = replay
		end
	end

	table.sort(all, function(a, b)
		return (a.timestamp or 0) > (b.timestamp or 0)
	end)
	return all
end

local function build_replay_list(replays)
	local rows = {}
	if #replays == 0 then
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.2, maxw = 5.4 },
			nodes = {
				text_node(localize("k_no_ghost_replays"), 0.34, G.C.UI.TEXT_INACTIVE),
			},
		}
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.02, maxw = 5.4 },
			nodes = {
				text_node(localize("k_ghost_replay_hint"), 0.25, G.C.UI.TEXT_INACTIVE),
			},
		}
		return rows
	end

	local last_filename = nil
	for index, replay in ipairs(replays) do
		if replay._filename and replay._game_count and replay._game_count > 1 and replay._filename ~= last_filename then
			last_filename = replay._filename
			rows[#rows + 1] = {
				n = G.UIT.R,
				config = { align = "cl", padding = 0.02, maxw = 5.4 },
				nodes = {
					text_node(replay._filename:gsub("%.log$", "") .. " (" .. tostring(replay._game_count) .. " games)", 0.23, G.C.UI.TEXT_INACTIVE),
				},
			}
		elseif not replay._filename then
			last_filename = nil
		end

		local selected = preview_idx == index
		local colour = selected and G.C.WHITE or (replay._source == "file" and G.C.BLUE or G.C.GREY)
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.03 },
			nodes = {
				create_button("ghost_replay_" .. tostring(index), "preview_ghost_replay", MP.GHOST.build_label(replay), colour, 5.4, 0.28),
			},
		}
	end
	return rows
end

function G.UIDEF.ghost_replay_picker()
	local replays = load_all_replays()
	picker_replays = replays

	local replay_rows = build_replay_list(replays)
	local controls = {}
	if MP.GHOST and MP.GHOST.is_active and MP.GHOST.is_active() then
		controls[#controls + 1] = {
			n = G.UIT.R,
			config = { align = "cm", padding = 0.03 },
			nodes = {
				create_button("clear_ghost_replay", "clear_ghost_replay", localize("b_clear_replay"), G.C.RED, 3, 0.3),
			},
		}
	end
	controls[#controls + 1] = {
		n = G.UIT.R,
		config = { align = "cm", padding = 0.05 },
		nodes = {
			create_button("ghost_picker_back", "ghost_picker_back", localize("b_back"), G.C.ORANGE, 3, 0.34),
		},
	}

	local left_col = {
		n = G.UIT.C,
		config = { align = "tm", padding = 0.1, minw = 5.9, maxw = 5.9, r = 0.1, colour = G.C.L_BLACK },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.06 },
				nodes = {
					text_node(localize("k_ghost_replays"), 0.45, G.C.WHITE),
				},
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.05, maxh = 5.5 },
				nodes = replay_rows,
			},
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.05 },
				nodes = controls,
			},
		},
	}

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", colour = G.C.CLEAR, minw = 13, minh = 7 },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm", padding = 0.15 },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "tm", padding = 0.15, r = 0.1, colour = G.C.BLACK, maxw = 15.8, maxh = 8 },
						nodes = {
							{
								n = G.UIT.R,
								config = { align = "tm", padding = 0.05 },
								nodes = {
									left_col,
									build_stats_panel(preview_idx and picker_replays[preview_idx] or nil),
								},
							},
						},
					},
				},
			},
		},
	}
end
