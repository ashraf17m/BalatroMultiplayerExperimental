SMODS.Atlas({
	key = "decks",
	path = "decks.png",
	px = 71,
	py = 95,
})

local function draw_back_sticker_shader(sticker, shader, send_to_shader, card, offset)
	sticker:draw_shader(
		shader,
		nil,
		send_to_shader,
		true,
		card.children.center,
		nil,
		card.sticker_rotation,
		offset.x,
		offset.y
	)
end

SMODS.DrawStep({
	key = "back_multiplayer",
	order = 11,
	func = function(self)
		if Galdur or G.STAGE ~= G.STAGES.MAIN_MENU then
			return
		end

		local viewed_center = G.GAME.viewed_back and G.GAME.viewed_back.effect and G.GAME.viewed_back.effect.center or nil
		if not (viewed_center and viewed_center.mod and viewed_center.mod.id == MP.id) then
			return
		end

		local sticker = G.shared_stickers["mp_sticker_balanced"]
		local sticker_offset = self.sticker_offset or {}
		sticker.role.draw_major = self
		draw_back_sticker_shader(sticker, "dissolve", nil, self, sticker_offset)
		draw_back_sticker_shader(sticker, "voucher", self.ARGS.send_to_shader, self, sticker_offset)
	end,
	conditions = { vortex = false, facing = "back" },
})
