MP.UI = MP.UI or {}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local function get_alive_players()
	if MP.SPECTATOR and MP.SPECTATOR.get_spectatable_players then
		return MP.SPECTATOR.get_spectatable_players()
	end
	return {}
end

local function get_target_index(alive_players, target_id)
	for i, player in ipairs(alive_players) do
		if player.id == target_id then
			return i
		end
	end
	return 1
end

local function bring_to_front(uibox)
	if not (G and G.I and G.I.UIBOX and uibox) then return end
	for i, box in ipairs(G.I.UIBOX) do
		if box == uibox then
			table.remove(G.I.UIBOX, i)
			table.insert(G.I.UIBOX, uibox)
			break
		end
	end
end

-- Final placements for the two switcher parts, recorded with the F4 UI Mover
-- tool and baked in here. Both anchor to MP.shared (the phantom joker area)
-- with middle horizontal alignment, so X stays at the area's exact center;
-- Y values are the user's tuned placement.
local SWITCHER_PART_DEFAULTS = {
	name = { align = "tm", offset = { x = 0, y = 3.76 } },
	arrows = { align = "bm", offset = { x = 0, y = 1.3 } },
}

local function build_spectator_name_definition(target_player_id)
	local alive = get_alive_players()
	local current = alive[get_target_index(alive, target_player_id)]
	local name = (current and (current.username or "Player")) or "Player"

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", minw = 2.6, minh = 0.6, r = 0.1, padding = 0.05, colour = G.C.PURPLE, emboss = 0.1, shadow = true, hover = true, can_collide = true },
						nodes = {
							{
								n = G.UIT.O,
								config = {
									object = DynaText({
										string = name,
										colours = { G.C.UI.TEXT_LIGHT },
										pop_in = 0,
										pop_in_rate = 8,
										reset_pop_in = true,
										shadow = true,
										float = true,
										silent = true,
										bump = true,
										scale = 0.45,
										-- Shrink long names to fit the fixed panel instead
										-- of letting the panel grow with the text.
										maxw = 2.4,
										non_recalc = true,
									}),
								},
							},
						},
					},
				},
			},
		},
	}
end

local function build_spectator_arrows_definition()
	local function cycle_arrow(label, button_name)
		return {
			n = G.UIT.C,
			config = { align = "cm", r = 0.1, minw = 0.7, minh = 0.6, hover = true, colour = G.C.PURPLE, shadow = true, button = button_name },
			nodes = {
				{ n = G.UIT.T, config = { text = label, scale = 0.45, colour = G.C.UI.TEXT_LIGHT } },
			},
		}
	end

	return {
		n = G.UIT.ROOT,
		config = { align = "cm", padding = 0.02, colour = G.C.CLEAR },
		nodes = {
			{
				n = G.UIT.R,
				config = { align = "cm" },
				nodes = {
					cycle_arrow("<", "mp_spectator_prev_target"),
					{ n = G.UIT.B, config = { w = 0.9, h = 0.01 } },
					cycle_arrow(">", "mp_spectator_next_target"),
				},
			},
		},
	}
end

local function spectator_switcher_major()
	return (MP and MP.shared) or G.jokers or G.consumeables or G.ROOM_ATTACH
end

local function create_spectator_part_box(definition, part)
	local defaults = SWITCHER_PART_DEFAULTS[part]
	return UIBox({
		definition = definition,
		config = {
			align = defaults.align,
			offset = { x = defaults.offset.x, y = defaults.offset.y },
			major = spectator_switcher_major(),
			bond = "Weak",
		},
	})
end

MP.UI.bring_to_front = bring_to_front

function MP.UI.bring_spectator_bars_to_front()
	bring_to_front(G.mp_spectator_bar)
	bring_to_front(G.mp_spectator_bar_arrows)
end

function MP.UI.show_spectator_viewport(target_player_id, target_username)
	if not (G and G.STAGE == G.STAGES.RUN and (G.jokers or G.ROOM_ATTACH)) then
		return
	end

	local alive = get_alive_players()
	if #alive == 0 then
		return
	end

	if G.mp_spectator_bar and not G.mp_spectator_bar.REMOVED
		and MP.UI.spectator_viewport_target_id == target_player_id then
		MP.UI.bring_spectator_bars_to_front()
		return
	end

	MP.UI.hide_spectator_viewport()

	G.mp_spectator_bar = create_spectator_part_box(build_spectator_name_definition(target_player_id), "name")
	G.mp_spectator_bar_arrows = create_spectator_part_box(build_spectator_arrows_definition(), "arrows")
	MP.UI.spectator_viewport_target_id = target_player_id

	MP.UI.bring_spectator_bars_to_front()
end

function MP.UI.hide_spectator_viewport()
	for _, bar in ipairs({ G.mp_spectator_bar, G.mp_spectator_bar_arrows }) do
		if bar then
			pcall(function()
				bar:remove()
			end)
		end
	end
	G.mp_spectator_bar = nil
	G.mp_spectator_bar_arrows = nil
	MP.UI.spectator_viewport_target_id = nil
end

-- Spectator target cycling (name and < > buttons)

G.FUNCS = G.FUNCS or {}

local function cycle_spectator_target(delta)
	local alive = get_alive_players()
	if #alive == 0 then
		return
	end

	local current_index = get_target_index(alive, MP.SPECTATOR and MP.SPECTATOR.target_player_id)
	local target = alive[((current_index - 1 + delta) % #alive) + 1]
	if not target or (MP.SPECTATOR and MP.SPECTATOR.target_player_id == target.id) then
		return
	end
	if MP.SPECTATOR and MP.SPECTATOR.start_spectating then
		MP.SPECTATOR.start_spectating(target.id, target.username)
	end
end

function G.FUNCS.mp_spectator_prev_target()
	cycle_spectator_target(-1)
end

function G.FUNCS.mp_spectator_next_target()
	cycle_spectator_target(1)
end

local disabled_input_nodes = setmetatable({}, { __mode = "k" })

local INTERACTABLE_STATES = { "collide", "click", "hover" }

local function disable_node_input(node)
	if not (node and node.states) then
		return
	end
	if disabled_input_nodes[node] == nil then
		local previous = {}
		for _, state_name in ipairs(INTERACTABLE_STATES) do
			local state = node.states[state_name]
			if state then
				previous[state_name] = state.can
				state.can = false
			end
		end
		disabled_input_nodes[node] = previous
	else
		for _, state_name in ipairs(INTERACTABLE_STATES) do
			local state = node.states[state_name]
			if state then
				state.can = false
			end
		end
	end
end

local function is_deck_inspect_ui(box)
	if not (box and G and G.deck) then
		return false
	end
	local children = G.deck.children
	if children and (box == children.view_deck or box == children.peek_deck or box == children.area_uibox) then
		return true
	end
	return box.config and box.config.major == G.deck
end

local function isolate_spectator_input()
	if not G or G.OVERLAY_MENU then
		return
	end
	if G.I and G.I.UIBOX then
		for _, box in ipairs(G.I.UIBOX) do
			if box ~= G.mp_spectator_bar and box ~= G.mp_spectator_bar_arrows and not is_deck_inspect_ui(box) then
				disable_node_input(box)
			end
		end
	end
	if G.I and G.I.CARDAREA then
		for _, area in ipairs(G.I.CARDAREA) do
			if area ~= G.deck then
				disable_node_input(area)
			end
		end
	end
	for _, bar in ipairs({ G.mp_spectator_bar, G.mp_spectator_bar_arrows }) do
		if bar and bar.states then
			for _, state_name in ipairs(INTERACTABLE_STATES) do
				local state = bar.states[state_name]
				if state then
					state.can = true
				end
			end
		end
	end
end

function MP.UI.restore_spectator_input()
	for node, previous in pairs(disabled_input_nodes) do
		if node and not node.REMOVED and node.states then
			for _, state_name in ipairs(INTERACTABLE_STATES) do
				local state = node.states[state_name]
				if state and previous[state_name] ~= nil then
					state.can = previous[state_name]
				end
			end
		end
	end
	disabled_input_nodes = setmetatable({}, { __mode = "k" })
end

if MP.GAME_UPDATE_CYCLE and MP.GAME_UPDATE_CYCLE.register_after then
	MP.GAME_UPDATE_CYCLE.register_after("mp.ui.spectator_viewport", function()
		if MP.SPECTATOR and MP.SPECTATOR.is_spectating and G and G.STAGE == G.STAGES.RUN then
			isolate_spectator_input()
			if MP.SPECTATOR.flush_queued_watch then
				MP.SPECTATOR.flush_queued_watch()
			end
			if MP.SPECTATOR.flush_pending_snapshot then
				MP.SPECTATOR.flush_pending_snapshot()
			end
			if MP.SPECTATOR.ensure_target_valid then
				MP.SPECTATOR.ensure_target_valid()
			end
			if MP.SPECTATOR.drain_pending_replay_actions then
				MP.SPECTATOR.drain_pending_replay_actions()
			end
			if MP.SPECTATOR.remove_stale_eval_surfaces then
				MP.SPECTATOR.remove_stale_eval_surfaces()
			end
			if MP.SPECTATOR.sync_watched_player_lives then
				MP.SPECTATOR.sync_watched_player_lives()
			end
			if MP.is_pvp_boss and MP.is_pvp_boss() and MP.UI and MP.UI.create_unified_player_list
				and G and G.STATES
				and G.STATE ~= G.STATES.ROUND_EVAL
				and G.STATE ~= G.STATES.NEW_ROUND
				and G.STATE ~= G.STATES.SHOP
				and G.STATE ~= G.STATES.BLIND_SELECT
			then
				MP.UI.create_unified_player_list()
			end

			if G.jokers or G.consumeables then
				if not G.mp_spectator_bar or G.mp_spectator_bar.REMOVED then
					MP.UI.show_spectator_viewport(MP.SPECTATOR.target_player_id, MP.SPECTATOR.target_username)
				else
					MP.UI.bring_spectator_bars_to_front()
				end
			end
		elseif (not MP.SPECTATOR or not MP.SPECTATOR.is_spectating or not G or G.STAGE ~= G.STAGES.RUN) and G and G.mp_spectator_bar then
			MP.UI.hide_spectator_viewport()
			MP.UI.restore_spectator_input()
		end
	end, 20)
end

return MP.UI
