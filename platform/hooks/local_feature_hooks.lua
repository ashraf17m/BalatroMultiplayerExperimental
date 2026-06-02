MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.HOOKS = MP.PLATFORM.HOOKS or {}

local function is_phantom_edition(card)
	return not not (card and card.edition and card.edition.type == "mp_phantom")
end

local function filter_non_phantom_cards(cards)
	local filtered_cards = {}
	for _, value in ipairs(cards or {}) do
		if not is_phantom_edition(value) then
			filtered_cards[#filtered_cards + 1] = value
		end
	end
	return filtered_cards
end

function MP.PLATFORM.HOOKS.install_local_feature_hooks()
	if MP.PLATFORM.HOOKS.local_feature_hooks_installed then
		return true
	end

	MP.HOOKS.register_method_hook(Card, "Card", "remove", "mp.local_features.phantom_remove_overlay", {
		before = function(ctx, self)
			ctx.mp_overlay_menu_restore = G.OVERLAY_MENU
			if is_phantom_edition(self) then
				G.OVERLAY_MENU = G.OVERLAY_MENU or true
			end
		end,
		after = function(ctx)
			G.OVERLAY_MENU = ctx.mp_overlay_menu_restore
		end,
	})

	MP.PLATFORM.SMODS.override_known("find_card", function(find_card_ref)
		return function(key, count_debuffed)
			return filter_non_phantom_cards(find_card_ref(key, count_debuffed))
		end
	end)

	local original_poll_edition = poll_edition
	function poll_edition(_key, _mod, _no_neg, _guaranteed, _options)
		if G.OVERLAY_MENU then
			return nil
		end
		return original_poll_edition(_key, _mod, _no_neg, _guaranteed, _options)
	end

	MP.PLATFORM.HOOKS.local_feature_hooks_installed = true
	return true
end

return MP.PLATFORM.HOOKS.install_local_feature_hooks()
