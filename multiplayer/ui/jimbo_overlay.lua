local mp_jimbo = nil
local mp_jimbo_pos = nil
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

local APPLY_IMMEDIATELY = true
local APPLY_SILENTLY = true

local JIMBO_POSITIONS = {
	[1] = { align = "cri", offset = { x = 1, y = 0 }, bubble_align = "cl", bubble_offset = { x = 0, y = 0 } },
	[2] = { align = "tli", offset = { x = -0.75, y = -0.75 }, bubble_align = "cr", bubble_offset = { x = 0, y = -0.5 } },
	[3] = { align = "tri", offset = { x = 1.8, y = -0.1 }, bubble_align = "bl", bubble_offset = { x = 2.1, y = 0 } },
	[4] = { align = "cmi", offset = { x = 0, y = -1.5 }, bubble_align = "cr", bubble_offset = { x = 0, y = 0 } },
}

function MP.UI.create_jimbo(pos, text)
	if mp_jimbo then MP.UI.remove_jimbo() end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo = Card_Character({
		x = 0,
		y = G.ROOM.T.h + 5,
		center = "j_perkeo",
		particle_colours = { HEX("4e997b"), HEX("e9564e"), HEX("ebecee") },
	})
	mp_jimbo.children.particles:remove()
	mp_jimbo.children.particles = nil
	mp_jimbo.children.card:set_edition({ negative = true }, APPLY_IMMEDIATELY, APPLY_SILENTLY)
	mp_jimbo.say_stuff = function(self, n, not_first)
		self.talking = true
		if not not_first then
			BALATRO.queue_event({
				trigger = "after",
				timer = "REAL",
				delay = 0.1,
				func = function()
					if self.children.speech_bubble then self.children.speech_bubble.states.visible = true end
					self:say_stuff(n, true)
					return true
				end,
			})
		else
			if n <= 0 then
				self.talking = false
				return
			end
			play_sound("voice" .. math.random(1, 11), math.random() * 0.2 + 1, 0.5)
			self.children.card:juice_up()
			BALATRO.queue_event({
				trigger = "after",
				timer = "REAL",
				blockable = false,
				blocking = false,
				delay = 0.13,
				func = function()
					self:say_stuff(n - 1, true)
					return true
				end,
			}, "tutorial")
		end
	end
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if text then MP.UI.jimbo_say(text) end
	return mp_jimbo
end

function MP.UI.move_jimbo(pos)
	if not mp_jimbo then return end
	local p = JIMBO_POSITIONS[pos] or JIMBO_POSITIONS[1]
	mp_jimbo_pos = pos or 1
	mp_jimbo:set_alignment({
		major = G.ROOM_ATTACH,
		type = p.align,
		offset = p.offset,
	})
	if mp_jimbo.children.speech_bubble then
		mp_jimbo.children.speech_bubble.alignment.type = p.bubble_align
		mp_jimbo.children.speech_bubble.alignment.offset = p.bubble_offset
		mp_jimbo.children.speech_bubble:align_to_major()
	end
end

function MP.UI.jimbo_say(text)
	if not mp_jimbo then return end
	if mp_jimbo.children.speech_bubble then mp_jimbo.children.speech_bubble:remove() end
	local lines = {}
	for line in MP.UTILS.wrapText(text, 30):gmatch("[^\n]+") do
		lines[#lines + 1] = line:match("^%s*(.-)%s*$")
	end
	local rows = {}
	for _, line in ipairs(lines) do
		rows[#rows + 1] = {
			n = G.UIT.R,
			config = { align = "cl" },
			nodes = {
				{ n = G.UIT.T, config = { text = line, scale = 0.4, colour = G.C.UI.TEXT_DARK } },
			},
		}
	end
	local definition = {
		n = G.UIT.ROOT,
		config = { align = "cm", minh = 1, r = 0.3, padding = 0.07, minw = 1, colour = G.C.JOKER_GREY, shadow = true },
		nodes = {
			{
				n = G.UIT.C,
				config = { align = "cm", minh = 1, r = 0.2, padding = 0.1, minw = 1, colour = G.C.WHITE },
				nodes = {
					{
						n = G.UIT.C,
						config = { align = "cm", minh = 1, r = 0.2, padding = 0.03, minw = 1, colour = G.C.WHITE },
						nodes = rows,
					},
				},
			},
		},
	}
	local p = JIMBO_POSITIONS[mp_jimbo_pos] or JIMBO_POSITIONS[1]
	mp_jimbo.children.speech_bubble = UIBox({
		definition = definition,
		config = { align = p.bubble_align, offset = p.bubble_offset, parent = mp_jimbo },
	})
	mp_jimbo.children.speech_bubble:set_role({
		role_type = "Minor",
		xy_bond = "Weak",
		r_bond = "Strong",
		major = mp_jimbo,
	})
	mp_jimbo.children.speech_bubble.states.visible = true
	local word_count = select(2, text:gsub("%S+", ""))
	local read_time = math.max(5, word_count * 0.3 + 1) + 5
	mp_jimbo:say_stuff(math.ceil(word_count / 2))
	local bubble_ref = mp_jimbo.children.speech_bubble
	BALATRO.queue_event({
		trigger = "after",
		timer = "REAL",
		blockable = false,
		blocking = false,
		delay = read_time,
		func = function()
			if mp_jimbo and mp_jimbo.children.speech_bubble == bubble_ref then
				mp_jimbo.children.speech_bubble:remove()
				mp_jimbo.children.speech_bubble = nil
			end
			return true
		end,
	})
end

function MP.UI.remove_jimbo()
	if not mp_jimbo then return end
	local jimbo = mp_jimbo
	mp_jimbo = nil
	if jimbo.children.speech_bubble then
		jimbo.children.speech_bubble:remove()
		jimbo.children.speech_bubble = nil
	end
	if jimbo.children.button then
		jimbo.children.button:remove()
		jimbo.children.button = nil
	end
	jimbo.children.card:start_dissolve({ HEX("4e997b") }, nil, nil, true)
	if jimbo.children.particles then jimbo.children.particles:fade(0.5) end
	BALATRO.queue_event({
		trigger = "after",
		blockable = false,
		delay = 0.8,
		func = function()
			jimbo:remove()
			return true
		end,
	})
end
