MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO

if G and G.C and not G.C.MULTIPLAYER then
	G.C.MULTIPLAYER = HEX("AC3232")
end

local function clamp_blind_col(num)
	return math.max(1, math.min(25, tonumber(num) or 1))
end

local function finite_score_number(value)
	if value == nil or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function normalize_score_number(value)
	if type(value) == "number" then
		return finite_score_number(value)
	end
	if value == nil then
		return nil
	end

	local numeric_value = tonumber(value)
	if numeric_value ~= nil then
		return finite_score_number(numeric_value)
	end

	local value_text = tostring(value)
	if value_text == "" then
		return nil
	end
	return finite_score_number(tonumber((string.gsub(value_text, ",", ""))))
end

function BALATRO.to_score_number(value)
	return normalize_score_number(value)
end

local function get_player_profile_atlas()
	return BALATRO.get_animation_atlas("mp_player_blind_col")
		or BALATRO.get_animation_atlas("player_blind_col")
end

function BALATRO.get_player_blind_pos(player)
	local blind_col = player and player.blind_col
	if blind_col == nil and player and player.is_self and MP.UTILS and MP.UTILS.get_blind_col then
		blind_col = MP.UTILS.get_blind_col()
	end
	local blind_key = MP.UTILS and MP.UTILS.blind_col_numtokey and MP.UTILS.blind_col_numtokey(clamp_blind_col(blind_col)) or nil
	local blind_def = blind_key and (G and G.P_BLINDS and G.P_BLINDS[blind_key]) or nil
	local blind_pos = blind_def and blind_def.pos or { x = 0, y = 0 }
	return {
		x = blind_pos.x or 0,
		y = blind_pos.y or 0,
	}
end

function BALATRO.get_player_blind_main_colour(player, fallback)
	local root = G or nil
	local default_col = fallback or (root and (root.C.MULTIPLAYER or root.C.DYN_UI.MAIN or root.C.RED)) or nil
	if not (MP and MP.UTILS and MP.UTILS.blind_col_numtokey and get_blind_main_colour) then
		return default_col
	end

	local blind_key = MP.UTILS.blind_col_numtokey(clamp_blind_col(player and player.blind_col))
	if not blind_key then
		return default_col
	end

	local ok, blind_col = pcall(get_blind_main_colour, blind_key)
	if ok and blind_col then
		return blind_col
	end

	return default_col
end

function BALATRO.get_blind_main_colour(row, fallback)
	if type(get_blind_main_colour) ~= "function" then
		return fallback
	end

	local ok, colour = pcall(get_blind_main_colour, row)
	return ok and colour or fallback
end

function BALATRO.get_blind_amount(ante)
	if type(get_blind_amount) ~= "function" then
		return nil
	end

	local ok, amount = pcall(get_blind_amount, ante)
	return ok and amount or nil
end

function BALATRO.get_stake_sprite(stake, scale)
	if type(get_stake_sprite) ~= "function" then
		return nil
	end

	local ok, sprite = pcall(get_stake_sprite, stake, scale)
	return ok and sprite or nil
end

function BALATRO.create_blind_style_palette(base_colour)
	local root = G or nil
	local main = base_colour or (root and (root.C.MULTIPLAYER or root.C.DYN_UI.MAIN or root.C.RED)) or nil
	local header_colour = main
	local body_colour = mix_colours(main, root.C.BLACK, 0.54)
	local slot_colour = mix_colours(main, root.C.BLACK, 0.72)
	return {
		header = header_colour,
		body = body_colour,
		left_slot = slot_colour,
		center_slot = slot_colour,
		right_slot = mix_colours(main, root.C.BLACK, 0.76),
		far_right_slot = mix_colours(main, root.C.BLACK, 0.76),
	}
end

-- Same object as the HUD blind chip: Blind (drag, hover zoom, Blind:align bob).
-- Spawn is snapped once so a standings rebuild does not ease the sprite in from 0,0.
local MPPlayerBlindIcon = Blind:extend()

function MPPlayerBlindIcon:init(player, size)
	local blind_size = size or 0.56
	Blind.init(self, 0, 0, blind_size, blind_size)

	local atlas = get_player_profile_atlas()
	local blind_pos = BALATRO.get_player_blind_pos(player)
	self.pos = blind_pos
	self.config = self.config or {}
	self.config.blind = self.config.blind or {}
	self.config.blind.pos = blind_pos

	self.float = true
	self.zoom = true
	self.shadow_height = 0
	self.states.visible = true
	self.states.hover.can = true
	self.states.drag.can = true
	self.states.collide.can = true
	self.states.click.can = false
	self.states.release_on.can = false
	self.created_on_pause = true

	local previous_sprite = self.children and self.children.animatedSprite
	local sprite
	if atlas and BALATRO.create_animated_sprite then
		sprite = BALATRO.create_animated_sprite(self.T.x, self.T.y, blind_size, blind_size, atlas, blind_pos)
	else
		sprite = previous_sprite
		if sprite and sprite.set_sprite_pos then
			sprite:set_sprite_pos(blind_pos)
		end
	end

	if previous_sprite and previous_sprite ~= sprite and previous_sprite.remove then
		previous_sprite:remove()
	end

	self.children = self.children or {}
	self.children.animatedSprite = sprite
	if sprite then
		sprite.states = self.states
		sprite.states.visible = true
		sprite.states.drag.can = true
		sprite.states.collide.can = true
		sprite.created_on_pause = true
		if sprite.rescale then
			sprite:rescale()
		end
	end
end

local blind_align = Blind.align

function MPPlayerBlindIcon:align_to_major()
	Moveable.align_to_major(self)
	-- The drawn sprite is the child, whose VT starts at (0,0). Snap it once, the
	-- first time the UI box seats this icon, so it spawns in its row; after that
	-- the vanilla Blind easing owns the movement (float, drift between slots).
	if self.spawn_snapped then return end
	self.spawn_snapped = true
	if self.hard_set_VT then
		self:hard_set_VT()
	end
	local sprite = self.children and self.children.animatedSprite
	if sprite then
		blind_align(self)
		if sprite.hard_set_VT then
			sprite:hard_set_VT()
		end
	end
end

function BALATRO.create_player_blind_icon_object(player, size)
	return MPPlayerBlindIcon(player, size or 0.56)
end

function BALATRO.set_text_object_ref(node, ref_table, ref_value, pop_in)
	if not (node and node.config and node.config.object and node.config.object.config) then
		return false
	end

	node.config.object.config.string = {
		{
			ref_table = ref_table or {},
			ref_value = ref_value,
		},
	}
	if node.config.object.update_text then
		node.config.object:update_text()
	end
	if pop_in and node.config.object.pop_in then
		node.config.object:pop_in(0)
	end
	return true
end

function BALATRO.set_text_ref_node(node, ref_table, ref_value, func_name)
	if not (node and node.config) then
		return false
	end

	node.config.ref_table = ref_table
	node.config.ref_value = ref_value
	if func_name ~= nil then
		node.config.func = func_name
	end
	node.config.prev_value = nil
	if node.update_text then
		node:update_text()
	end
	return true
end

function BALATRO.set_hud_blind_panel_labels(top_label, bottom_label)
	local panel = BALATRO.get_hud_blind_element_by_id and BALATRO.get_hud_blind_element_by_id("HUD_blind") or nil
	if not (panel and panel.children and panel.children[2] and panel.children[2].children[2]
		and panel.children[2].children[2].children[2]) then
		return false
	end

	local label_root = panel.children[2].children[2].children[2]
	local top = label_root.children and label_root.children[1] and label_root.children[1].children and label_root.children[1].children[1]
	local bottom = label_root.children and label_root.children[3] and label_root.children[3].children and label_root.children[3].children[1]
	if top and top.config then
		top.config.text = top_label
	end
	if bottom and bottom.config then
		bottom.config.text = bottom_label
	end
	return not not (top or bottom)
end

function BALATRO.set_current_blind_floating_icon_hidden(hidden)
	local blind = (G and G.GAME and G.GAME.blind) or nil
	if not blind then
		return false
	end

	blind.hide_floating_icon = not not hidden
	return true
end

function BALATRO.set_current_blind_score(chips, chip_text)
	local blind = (G and G.GAME and G.GAME.blind) or nil
	if not blind then
		return false
	end

	local numeric_chips = normalize_score_number(chips)
	if numeric_chips == nil then
		return false
	end

	blind.chips = numeric_chips
	blind.chip_text = chip_text or number_format(numeric_chips)
	return true
end

function BALATRO.set_current_blind_dollars(dollars)
	local blind = (G and G.GAME and G.GAME.blind) or nil
	if not blind then
		return false
	end

	blind.dollars = dollars
	return true
end

function BALATRO.apply_multiplayer_blind_sprite(blind_key)
	local blind = (G and G.GAME and G.GAME.blind) or nil
	if not (blind and blind.children and blind.children.animatedSprite and blind_key) then
		return false
	end

	local blind_def = (G and G.P_BLINDS and G.P_BLINDS[blind_key]) or nil
	if not blind_def then
		return false
	end

	local atlas = BALATRO.get_animation_atlas("mp_player_blind_col")
	if atlas then
		blind.children.animatedSprite.atlas = atlas
	end
	if blind.children.animatedSprite.set_sprite_pos then
		blind.children.animatedSprite:set_sprite_pos(blind_def.pos)
	end
	return true
end
