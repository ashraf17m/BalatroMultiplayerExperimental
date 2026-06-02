local display = {}

local cocktail_default_back_vars = {
	["Blue Deck"] = function(center) return { center.config.hands } end,
	["Red Deck"] = function(center) return { center.config.discards } end,
	["Yellow Deck"] = function(center) return { center.config.dollars } end,
	["Green Deck"] = function(center) return { center.config.extra_hand_bonus, center.config.extra_discard_bonus } end,
	["Black Deck"] = function(center) return { center.config.joker_slot, -center.config.hands } end,
	["Magic Deck"] = function()
		return {
			localize({ type = "name_text", key = "v_crystal_ball", set = "Voucher" }),
			localize({ type = "name_text", key = "c_fool", set = "Tarot" }),
		}
	end,
	["Nebula Deck"] = function()
		return { localize({ type = "name_text", key = "v_telescope", set = "Voucher" }), -1 }
	end,
	["Zodiac Deck"] = function()
		return {
			localize({ type = "name_text", key = "v_tarot_merchant", set = "Voucher" }),
			localize({ type = "name_text", key = "v_planet_merchant", set = "Voucher" }),
			localize({ type = "name_text", key = "v_overstock_norm", set = "Voucher" }),
		}
	end,
	["Painted Deck"] = function(center) return { center.config.hand_size, center.config.joker_slot } end,
	["Anaglyph Deck"] = function()
		return { localize({ type = "name_text", key = "tag_double", set = "Tag" }) }
	end,
	["Plasma Deck"] = function(center) return { center.config.ante_scaling } end,
}

local function build_cocktail_default_back_vars(center)
	local builder = cocktail_default_back_vars[center.name]
	return builder and builder(center) or nil
end

local function install_generate_card_ui_override(runtime)
	local generate_card_ui_ref = generate_card_ui
	function generate_card_ui(_c, full_UI_table, specific_vars, card_type, badges, hide_desc, main_start, main_end, card)
		if card and card.mp_cocktail_select then
			_c = G.P_CENTERS[card.mp_cocktail_select]
			local ret = generate_card_ui_ref(
				_c,
				full_UI_table,
				specific_vars,
				"Back",
				badges,
				hide_desc,
				main_start,
				main_end,
				card
			)
			if not _c.generate_ui or type(_c.generate_ui) ~= "function" then
				specific_vars = build_cocktail_default_back_vars(_c) or specific_vars

				localize({ type = "descriptions", key = _c.key, set = _c.set, nodes = ret.main, vars = specific_vars })
			end
			return ret
		end
		return generate_card_ui_ref(
			_c,
			full_UI_table,
			specific_vars,
			card_type,
			badges,
			hide_desc,
			main_start,
			main_end,
			card
		)
	end
end

local function install_localize_override(runtime)
	local localize_ref = localize
	function localize(args, misc_cat)
		local ret = localize_ref(args, misc_cat)
		if args and type(args) == "table" and args.key then
			local key = args.key or args.node and args.node.config.center.key or "NULL"
			if args.type == "name_text" and key == "b_mp_cocktail" and runtime.check_edited() then return ret .. "*" end
		end
		return ret
	end
end

local function get_cocktail_sticker_sprite(runtime, deck_key, num)
	local key = "mp_cocktail_" .. deck_key .. num
	if not G.shared_stickers[key] then
		runtime.cache_sticker(key, Sprite(
			0,
			0,
			G.CARD_W,
			G.CARD_H,
			G.ASSET_ATLAS["mp_cocktail_deck_stickers"],
			{ x = runtime.sticker_x_pos[deck_key], y = num - 1 }
		))
	end
	return G.shared_stickers[key]
end

local function draw_cocktail_deck_stickers(runtime, self)
	local sticker_decks = G.GAME.modifiers.mp_cocktail_sticker
	for i, deck_key in ipairs(sticker_decks) do
		local num = math.min(i, 3)
		local sprite = get_cocktail_sticker_sprite(runtime, deck_key, num)
		sprite.role.draw_major = self
		local sticker_offset = self.sticker_offset or {}
		sprite:draw_shader(
			"dissolve",
			nil,
			nil,
			true,
			self.children.center,
			nil,
			self.sticker_rotation,
			sticker_offset.x,
			sticker_offset.y
		)
	end
end

local function install_cocktail_sticker_draw_step(runtime)
	SMODS.Atlas({
		key = "cocktail_deck_stickers",
		path = "deck_stickers.png",
		px = 71,
		py = 95,
	})

	SMODS.DrawStep({
		key = "back_cocktail",
		order = 11,
		func = function(self)
			if G.STAGE ~= G.STAGES.RUN or not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.mp_cocktail_sticker) then
				return
			end

			if self.area and self.area.config.type == "deck" then
				draw_cocktail_deck_stickers(runtime, self)
			end
		end,
		conditions = { vortex = false, facing = "back" },
	})
end

function display.install(runtime)
	if type(runtime) ~= "table" then
		sendWarnMessage("Missing Cocktail deck runtime module.", "MULTIPLAYER")
		return false
	end

	install_generate_card_ui_override(runtime)
	install_localize_override(runtime)
	install_cocktail_sticker_draw_step(runtime)
	return true
end

return display
