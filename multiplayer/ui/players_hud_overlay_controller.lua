-- Player HUD Runtime and Overlay Actions
-- Keeps the live blind HUD injection, overlay controls, and refresh behavior
-- separate from the standings-node rendering files.

local shared = MP.UI.PLAYERS_HUD_SHARED or {}
local get_shared_team_lives = shared.get_shared_team_lives
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}
local PLAYER_LIST_ANCHOR_OFFSET = { x = 0.0, y = -0.35 }

local function get_player_list_mode()
	if MP.is_teams_mode and MP.is_teams_mode() then
		return "teams"
	end
	if (MP.is_ffa_mode and MP.is_ffa_mode()) or (MP.is_duels_mode and MP.is_duels_mode()) then
		return "ffa"
	end
	return nil
end

local function stringify_signature_value(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function build_player_list_signature(mode)
	if not mode then
		return "none"
	end

	local players = MP.UI.get_sorted_players and MP.UI.get_sorted_players() or {}
	local parts = {
		mode,
		"layout=" .. stringify_signature_value(shared.PVP_HUD_LAYOUT_REVISION),
		stringify_signature_value(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.pvp_score_rule),
		stringify_signature_value(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.pvp_custom_winners),
	}

	for _, player in ipairs(players) do
		parts[#parts + 1] = table.concat({
			stringify_signature_value(player.id),
			stringify_signature_value(player.username),
			stringify_signature_value(player.hands),
			stringify_signature_value(player.lives),
			stringify_signature_value(player.team),
			stringify_signature_value(player.blind_col),
			stringify_signature_value(player.is_self),
			stringify_signature_value(player.is_spectator),
			stringify_signature_value(player.role),
		}, "|")
	end

	if mode == "teams" and type(get_shared_team_lives) == "function" then
		for team_idx = 1, (MP.MAX_TEAMS or 0) do
			parts[#parts + 1] = "teamLives=" .. tostring(team_idx) .. ":" .. stringify_signature_value(get_shared_team_lives(team_idx))
		end
	end

	return table.concat(parts, ";")
end

local function refresh_score_targets(mode)
	local players = MP.UI.get_sorted_players and MP.UI.get_sorted_players() or nil
	if mode == "teams" and MP.UI.refresh_team_standings_score_targets then
		MP.UI.refresh_team_standings_score_targets(players)
		if MP.UI.refresh_team_standings_stat_targets then
			MP.UI.refresh_team_standings_stat_targets(players)
		end
	elseif mode == "ffa" and MP.UI.refresh_ffa_standings_score_targets then
		MP.UI.refresh_ffa_standings_score_targets(players)
		if MP.UI.refresh_ffa_standings_stat_targets then
			MP.UI.refresh_ffa_standings_stat_targets(players)
		end
	end
end

local function clear_player_list_ui(player_list_runtime)
	if player_list_runtime.ui then
		player_list_runtime.ui:remove()
		player_list_runtime.ui = nil
	end
	if player_list_runtime.ui_boxes then
		for _, box in ipairs(player_list_runtime.ui_boxes) do
			if box and box.remove then
				box:remove()
			end
		end
		player_list_runtime.ui_boxes = nil
	end
	player_list_runtime.ui_signature = nil
	player_list_runtime.ui_mode = nil
	player_list_runtime.ui_major = nil
end

local function set_internal_area_children_visible(internal_area, is_visible)
	if not (internal_area and internal_area.children) then
		return
	end

	for _, child in ipairs(internal_area.children) do
		child.states.visible = not not is_visible
	end
end

local function save_blind_hud_theme(blind_root)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	if player_list_runtime.saved_theme or not blind_root then
		return
	end

	local blind_header = blind_root.children and blind_root.children[1]
	local blind_body = blind_root.children and blind_root.children[2]
	player_list_runtime.saved_theme = {
		root = blind_root.config and blind_root.config.colour and copy_table(blind_root.config.colour) or copy_table(G.C.BLACK),
		root_emboss = blind_root.config and blind_root.config.emboss,
		header = blind_header and blind_header.config and blind_header.config.colour and copy_table(blind_header.config.colour) or copy_table(G.C.DYN_UI.MAIN),
		header_emboss = blind_header and blind_header.config and blind_header.config.emboss,
		body = blind_body and blind_body.config and blind_body.config.colour and copy_table(blind_body.config.colour) or copy_table(G.C.DYN_UI.DARK),
		body_emboss = blind_body and blind_body.config and blind_body.config.emboss,
		header_visible = blind_header and blind_header.states and blind_header.states.visible,
		header_minh = blind_header and blind_header.config and blind_header.config.minh,
		header_padding = blind_header and blind_header.config and blind_header.config.padding,
	}
end

local function restore_blind_hud_theme(blind_root)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	local saved_theme = player_list_runtime.saved_theme
	if not saved_theme then
		return
	end
	local blind_header = blind_root and blind_root.children and blind_root.children[1]
	local blind_body = blind_root and blind_root.children and blind_root.children[2]

	if blind_root and blind_root.config then
		blind_root.config.colour = copy_table(saved_theme.root or G.C.BLACK)
		blind_root.config.emboss = saved_theme.root_emboss or blind_root.config.emboss
	end
	if blind_header and blind_header.config then
		blind_header.config.colour = copy_table(saved_theme.header or G.C.DYN_UI.MAIN)
		blind_header.config.emboss = saved_theme.header_emboss or blind_header.config.emboss
		blind_header.config.minh = saved_theme.header_minh or blind_header.config.minh
		blind_header.config.padding = saved_theme.header_padding or blind_header.config.padding
	end
	if blind_header and blind_header.states then
		if saved_theme.header_visible ~= nil then
			blind_header.states.visible = saved_theme.header_visible
		else
			blind_header.states.visible = true
		end
	end
	if blind_body and blind_body.config then
		blind_body.config.colour = copy_table(saved_theme.body or G.C.DYN_UI.DARK)
		blind_body.config.emboss = saved_theme.body_emboss or blind_body.config.emboss
	end

	player_list_runtime.saved_theme = nil
end

local function restore_blind_hud_structure(blind_root)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	local blind_header = blind_root and blind_root.children and blind_root.children[1]
	local blind_body = blind_root and blind_root.children and blind_root.children[2]

	if blind_root and blind_root.config then
		blind_root.config.colour = G.C.BLACK
		blind_root.config.emboss = 0.05
	end

	if blind_header and blind_header.config then
		blind_header.config.colour = G.C.DYN_UI.MAIN
		blind_header.config.emboss = 0.05
		blind_header.config.minh = 0.7
		blind_header.config.padding = nil
	end
	if blind_header and blind_header.states then
		blind_header.states.visible = true
	end

	if blind_body and blind_body.config then
		blind_body.config.colour = G.C.DYN_UI.DARK
		blind_body.config.emboss = nil
	end

	player_list_runtime.saved_theme = nil
end

local function center_to_internal_area(ui_box, major_area)
	if not (ui_box and major_area) then
		return
	end
	if ui_box.alignment and ui_box.alignment.major ~= major_area then
		ui_box:set_alignment({
			major = major_area,
			type = "cm",
			bond = "Weak",
			offset = { x = PLAYER_LIST_ANCHOR_OFFSET.x, y = PLAYER_LIST_ANCHOR_OFFSET.y },
		})
	end
	if ui_box.recalculate then
		ui_box:recalculate()
	end
	if ui_box.align_to_major then
		ui_box:align_to_major()
	end
	if ui_box.move_with_major then
		ui_box:move_with_major(0)
	end
end

local function enable_player_list_row_clicks(node)
	if not node then
		return
	end

	if node.config and node.config.mp_open_full_standings_row and not node.config.mp_open_full_standings_click then
		node.config.mp_open_full_standings_click = true
		node.config.hover = true
		node.config.shadow = true
		if node.states then
			if node.states.collide then node.states.collide.can = true end
			if node.states.hover then node.states.hover.can = true end
			if node.states.click then node.states.click.can = true end
		end

		function node:click()
			if not (self.states and self.states.visible) or self.under_overlay or self.disable_button then
				return
			end
			if self.mp_last_full_standings_click and self.mp_last_full_standings_click + 0.1 >= G.TIMERS.REAL then
				return
			end

			self.mp_last_full_standings_click = G.TIMERS.REAL
			if G.FUNCS and G.FUNCS.mp_open_full_standings then
				G.FUNCS.mp_open_full_standings(self)
			end
			if play_sound then
				play_sound("button", 1, 0.3)
			end
		end
	end

	if node.children then
		for _, child in pairs(node.children) do
			enable_player_list_row_clicks(child)
		end
	end
end

local function open_standings_overlay(contents, reset_existing)
	if reset_existing and BALATRO.get_overlay_menu() then
		BALATRO.exit_overlay_menu()
	end
	if reset_existing then
		BALATRO.set_paused(true)
	end

	BALATRO.open_overlay_menu({
		definition = create_UIBox_generic_options({
			contents = contents,
		}),
		-- Page flips rebuild this overlay; without an explicit offset, vanilla
		-- restarts its slide-up entrance every flip and the just-seated icons
		-- lag behind the moving rows mid-slide.
		config = reset_existing and { offset = { x = 0, y = 0 } } or nil,
	})
end

function MP.UI.create_unified_player_list()
	local mode = get_player_list_mode()
	if not (BALATRO.get_hud_blind and BALATRO.get_hud_blind()) or not mode then
		return
	end

	local blind_root = BALATRO.get_hud_blind_element_by_id("HUD_blind")
	if blind_root then
		save_blind_hud_theme(blind_root)
		blind_root.config.colour = G.C.CLEAR
		blind_root.config.emboss = 0
		if blind_root.children and blind_root.children[1] then
			blind_root.children[1].config.colour = G.C.CLEAR
			blind_root.children[1].config.emboss = 0
			blind_root.children[1].states.visible = false
			blind_root.children[1].config.minh = 0.001
			blind_root.children[1].config.padding = 0
		end
	end

	if blind_root and blind_root.children[2] then
		local internal_area = blind_root.children[2]
		internal_area.config.colour = G.C.CLEAR
		internal_area.config.emboss = 0

		set_internal_area_children_visible(internal_area, false)

		local player_list_runtime = MP.UI.get_player_list_runtime()
		refresh_score_targets(mode)
		local signature = build_player_list_signature(mode)
		local major_target = internal_area
		local needs_rebuild = not player_list_runtime.ui
			or player_list_runtime.ui_mode ~= mode
			or player_list_runtime.ui_signature ~= signature
			or player_list_runtime.ui_major ~= major_target

		if needs_rebuild then
			clear_player_list_ui(player_list_runtime)
			local standings_nodes = mode == "teams"
				and MP.UI.create_teams_standings_nodes(false)
				or MP.UI.create_ffa_standings_nodes(false)
			if standings_nodes and #standings_nodes > 0 then
				local standings_ui = UIBox({
					definition = {
						n = G.UIT.ROOT,
						config = { id = "MP_PLAYER_LIST_CONTAINER", align = "cm", colour = G.C.CLEAR },
						nodes = standings_nodes,
					},
					config = {
						align = "cm",
						bond = "Weak",
						offset = { x = PLAYER_LIST_ANCHOR_OFFSET.x, y = PLAYER_LIST_ANCHOR_OFFSET.y },
						major = major_target,
						type = "cm",
						colour = G.C.CLEAR,
					},
				})
				center_to_internal_area(standings_ui, major_target)
				enable_player_list_row_clicks(standings_ui.UIRoot)
				player_list_runtime.ui = standings_ui
			end

			player_list_runtime.ui_signature = signature
			player_list_runtime.ui_mode = mode
			player_list_runtime.ui_major = major_target

			if not player_list_runtime.ui then
				for _, child in ipairs(internal_area.children) do
					child.states.visible = true
				end
				internal_area.config.colour = G.C.DYN_UI.DARK
				internal_area.config.emboss = nil
				if blind_root and blind_root.children and blind_root.children[1] then
					local blind_header = blind_root.children[1]
					blind_header.states.visible = true
					blind_header.config.minh = 0.7
					blind_header.config.padding = nil
					blind_header.config.colour = G.C.DYN_UI.MAIN
					blind_header.config.emboss = 0.05
				end
				blind_root.config.colour = G.C.BLACK
				blind_root.config.emboss = 0.05
			end
		end

		BALATRO.recalculate_hud_blind()
		center_to_internal_area(player_list_runtime.ui, major_target)
	end
end

function MP.UI.refresh_player_list()
	if (BALATRO.is_game_over_or_win and BALATRO.is_game_over_or_win()) or MP.GAME.won then
		return
	end

	if MP.is_pvp_boss() then
		MP.UI.create_unified_player_list()
	else
		MP.UI.remove_player_list(true)
	end
end

function MP.UI.remove_player_list(skip_theme_restore)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	if not (player_list_runtime.ui or player_list_runtime.ui_boxes or player_list_runtime.saved_theme) then
		return
	end

	clear_player_list_ui(player_list_runtime)
	if not (BALATRO.get_hud_blind and BALATRO.get_hud_blind()) then
		player_list_runtime.saved_theme = nil
		return
	end

	local blind_root = BALATRO.get_hud_blind_element_by_id("HUD_blind")
	if blind_root and blind_root.children[2] then
		set_internal_area_children_visible(blind_root.children[2], true)
	end
	if skip_theme_restore then
		restore_blind_hud_structure(blind_root)
	else
		restore_blind_hud_theme(blind_root)
	end
	BALATRO.recalculate_hud_blind()
end

local function change_full_standings_page(delta)
	local player_list_runtime = MP.UI.get_player_list_runtime()
	local page = math.max(1, math.floor(tonumber(player_list_runtime and player_list_runtime.full_standings_page) or 1))
	local page_count = math.max(1, math.floor(tonumber(player_list_runtime and player_list_runtime.full_standings_page_count) or 1))
	if page_count > 1 then
		page = ((page - 1 + delta) % page_count) + 1
	end
	if player_list_runtime then
		player_list_runtime.full_standings_page = page
	end

	if MP.is_teams_mode() then
		open_standings_overlay(MP.UI.create_teams_standings_nodes(true), true)
		return
	end

	open_standings_overlay(MP.UI.create_ffa_standings_nodes(true), true)
end

G.FUNCS.mp_full_standings_prev_page = function()
	return change_full_standings_page(-1)
end

G.FUNCS.mp_full_standings_next_page = function()
	return change_full_standings_page(1)
end

BALATRO.set_ui_function("mp_open_full_standings", function()
	local player_list_runtime = MP.UI.get_player_list_runtime()
	if player_list_runtime then
		player_list_runtime.full_standings_page = 1
	end
	if MP.is_teams_mode() then
		open_standings_overlay(MP.UI.create_teams_standings_nodes(true), false)
		return
	end

	open_standings_overlay(MP.UI.create_ffa_standings_nodes(true), false)
end)
