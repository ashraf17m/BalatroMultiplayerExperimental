MP.BLIND_CHOICE_INTERNAL = MP.BLIND_CHOICE_INTERNAL or {}

local INTERNAL = MP.BLIND_CHOICE_INTERNAL
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

function INTERNAL.restore_blind_select_label(e, row)
	local label = e and e.children and e.children[1] and e.children[1].config
	local round_resets = BALATRO.get_round_resets and BALATRO.get_round_resets() or nil
	if not label or not row or not round_resets then
		return
	end
	label.ref_table = round_resets.loc_blind_states
	label.ref_value = row
end

function INTERNAL.set_ui_text(node, text)
	if not node or not node.config then
		return
	end

	text = tostring(text or "")
	local current_text = tostring(node.config.text or "")
	if current_text == text then
		return
	end

	node.config.text = text
	node.config.lang = node.config.lang or G.LANG
	if node.config.text_drawable then
		node.config.text_drawable:set(text)
	elseif node.update_text then
		node:update_text()
	end

	if node.T and node.parent then
		local scale = node.config.scale or 1
		local tx = node.config.lang.font.FONT:getWidth(text)
			* node.config.lang.font.squish
			* scale
			* G.TILESCALE
			* node.config.lang.font.FONTSCALE
		local ty = node.config.lang.font.FONT:getHeight()
			* scale
			* G.TILESCALE
			* node.config.lang.font.FONTSCALE
			* node.config.lang.font.TEXT_HEIGHT_SCALE
		if node.config.vert then
			tx, ty = ty, tx
		end

		node.T.w = tx / (G.TILESIZE * G.TILESCALE)
		node.T.h = ty / (G.TILESIZE * G.TILESCALE)
		node.VT.w = node.T.w
		node.VT.h = node.T.h

		local padding = (node.parent.config and node.parent.config.padding) or G.UIT.padding
		node.parent.content_dimensions = node.parent.content_dimensions or {}
		node.parent.content_dimensions.w = node.T.w + 2 * padding
		node.parent.content_dimensions.h = node.T.h + 2 * padding

		if node.role and node.role.offset then
			node.role.offset.x = (node.parent.role and node.parent.role.offset and node.parent.role.offset.x or 0) + padding
			node.role.offset.y = (node.parent.role and node.parent.role.offset and node.parent.role.offset.y or 0) + padding
		end

		node.parent:set_alignments()
		node.parent:initialize_VT()
	end
end

return INTERNAL
