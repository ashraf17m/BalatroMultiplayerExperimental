MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

if team_card_sync._identity_loaded then
	return
end
team_card_sync._identity_loaded = true

local BALATRO = MP.PLATFORM.BALATRO

local require_snapshot_api = assert(team_card_sync.require_snapshot_api, "Team card sync snapshot API missing: require_snapshot_api")
local get_card_front_key = require_snapshot_api("get_card_front_key")
local cache_all_playing_card_snapshots = require_snapshot_api("cache_all_playing_card_snapshots")

function team_card_sync.is_syncable_playing_card(card)
	return card and ((card.base and card.base.suit and card.base.value) or get_card_front_key(card))
end

function team_card_sync.assign_card_id(card)
	if not card or card.mp_card_id then return end
	local game = BALATRO.get_game()
	if not game then return end
	local next_id = BALATRO.get_mp_card_next_id() or 0
	local prefix = BALATRO.get_player_id() or "LOCAL"
	card.mp_card_id = prefix .. "_" .. next_id
	BALATRO.set_mp_card_next_id(next_id + 1)
end

function team_card_sync.is_main_team_area(area)
	if not area or not area.config or area.config.mp_preview_only then return false end
	return area == BALATRO.get_deck_area() or area == BALATRO.get_hand_area()
end

function team_card_sync.get_card_by_id(id)
	if id == nil then
		return nil
	end
	local want = tostring(id)
	local playing_cards = BALATRO.get_playing_cards()
	if playing_cards then
		for _, card in ipairs(playing_cards) do
			if card and card.mp_card_id and tostring(card.mp_card_id) == want then
				return card
			end
		end
	end
	local G = _G.G
	if G then
		for _, area in ipairs({ G.hand, G.deck, G.discard, G.play }) do
			if area and area.cards then
				for _, card in ipairs(area.cards) do
					if card and card.mp_card_id and tostring(card.mp_card_id) == want then
						return card
					end
				end
			end
		end
	end
	return nil
end

function team_card_sync.get_card_id_suffix(card_id)
	if type(card_id) ~= "string" then
		return nil
	end

	local suffix = string.match(card_id, "_(%d+)$")
	return suffix and tonumber(suffix) or nil
end

function team_card_sync.mark_card_ready_for_team_sync(card, card_id)
	if not card then
		return
	end

	if card_id ~= nil then
		card.mp_card_id = card_id
	end

	card.mp_synced_as_added = true
end

function team_card_sync.finalize_team_card_setup(next_card_id)
	cache_all_playing_card_snapshots()
	BALATRO.set_mp_card_next_id(next_card_id)
end

function team_card_sync.assign_initial_team_card_ids()
	local playing_cards = BALATRO.get_playing_cards() or {}
	-- Index-based TEAM ids are deterministic across clients in the same
	-- lobby regardless of the shared-deck option; spectator boards rely on
	-- that to resolve sync deltas against the watched player's deck.
	local prefix = (MP.LOBBY and MP.LOBBY.code) and "TEAM"
		or (BALATRO.get_player_id() or "LOCAL")
	for index, card in ipairs(playing_cards) do
		team_card_sync.mark_card_ready_for_team_sync(card, prefix .. "_" .. (index - 1))
	end
	team_card_sync.finalize_team_card_setup(#playing_cards)
end
