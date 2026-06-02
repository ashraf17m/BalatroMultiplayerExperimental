MP.EC.register_sandbox_joker({
	key = "couponsheet_sandbox",
	blueprint_compat = false,
	eternal_compat = true,

	rarity = 3,
	cost = 7,
	pos = { x = 8, y = 3 },

	config = {
		extra = {},
	},

	loc_vars = function(self, info_queue, card)
		info_queue[#info_queue + 1] = { key = "tag_coupon", set = "Tag" }
		info_queue[#info_queue + 1] = { key = "tag_voucher", set = "Tag" }
		return { vars = {} }
	end,

	calculate = function(self, card, context)
		if
			context.end_of_round
			and not context.repetition
			and not context.individual
			and G.GAME.blind.boss
			and not context.blueprint
		then
			card_eval_status_text(
				context.blueprint_card or card,
				"extra",
				nil,
				nil,
				nil,
				{ message = "+1 Coupon Tag!", colour = G.C.FILTER }
			)
			MP.EC.queue_tag("tag_coupon")
			delay(0.3)
			card_eval_status_text(
				context.blueprint_card or card,
				"extra",
				nil,
				nil,
				nil,
				{ message = "+1 Voucher Tag!", colour = G.C.FILTER }
			)
			MP.EC.queue_tag("tag_voucher")
		end
	end,

	mp_credits = {
		code = { "CampfireCollective" },
		art = { "neatoqueen" },
	},
})
