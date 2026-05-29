MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
MP.TEAM_CARD = team_card_sync

if team_card_sync._snapshot_loaded then
	return
end
team_card_sync._snapshot_loaded = true

local ok_json, json = pcall(require, "json")
if not ok_json then json = rawget(_G, "json") end
local BALATRO = MP.PLATFORM.BALATRO

local APPLY_IMMEDIATELY = true
local APPLY_SILENTLY = true
local INITIAL_ASSIGNMENT = true
local DELAY_SPRITES = true

local PERSISTENT_ABILITY_FIELDS = {
	"perma_bonus",
	"perma_x_chips",
	"perma_mult",
	"perma_x_mult",
	"perma_h_chips",
	"perma_h_x_chips",
	"perma_h_mult",
	"perma_h_x_mult",
	"perma_p_dollars",
	"perma_h_dollars",
	"perma_repetitions",
	"perma_score",
	"perma_h_score",
	"perma_x_score",
	"perma_h_x_score",
	"perma_blind_size",
	"perma_h_blind_size",
	"perma_x_blind_size",
	"perma_h_x_blind_size",
}

local SNAPSHOT_EXTENSIONS = team_card_sync.snapshot_extensions or {}
team_card_sync.snapshot_extensions = SNAPSHOT_EXTENSIONS

local EXTENSION_SNAPSHOT_MAX_DEPTH = 4
local VANILLA_SUIT_TO_KEY = { Spades = "S", Hearts = "H", Clubs = "C", Diamonds = "D" }
local NUMERIC_RANK_TO_KEY = { [14] = "A", [13] = "K", [12] = "Q", [11] = "J", [10] = "T" }
local VANILLA_RANK_TO_KEY = { Ace = "A", King = "K", Queen = "Q", Jack = "J", ["10"] = "T" }

local get_card_snapshot

function team_card_sync.require_snapshot_api(name)
	local value = team_card_sync[name]
	if not value then
		error("Team card sync snapshot API missing: " .. tostring(name))
	end
	return value
end

local function is_json_safe_snapshot_value(value, depth)
	local value_type = type(value)
	if value == nil or value_type == "string" or value_type == "boolean" then
		return true
	end
	if value_type == "number" then
		return value == value and value < math.huge and value > -math.huge
	end
	if value_type ~= "table" or depth <= 0 then
		return false
	end

	for key, child_value in pairs(value) do
		local key_type = type(key)
		if key_type ~= "string" and key_type ~= "number" then
			return false
		end
		if not is_json_safe_snapshot_value(child_value, depth - 1) then
			return false
		end
	end

	return true
end

local function is_valid_extension_snapshot(extensions)
	if extensions == nil then
		return true
	end
	if type(extensions) ~= "table" then
		return false
	end

	for key, value in pairs(extensions) do
		if type(key) ~= "string" or key == "" or not is_json_safe_snapshot_value(value, EXTENSION_SNAPSHOT_MAX_DEPTH) then
			return false
		end
	end

	return true
end

local function capture_extension_snapshots(card)
	local extensions = nil
	for key, extension in pairs(SNAPSHOT_EXTENSIONS) do
		if type(extension) == "table" and type(extension.capture) == "function" then
			local ok, value = pcall(extension.capture, card)
			if ok and value ~= nil and is_json_safe_snapshot_value(value, EXTENSION_SNAPSHOT_MAX_DEPTH) then
				extensions = extensions or {}
				extensions[key] = value
			end
		end
	end
	return extensions
end

local function apply_extension_snapshots(card, snapshot)
	local extensions = snapshot and snapshot.x or nil
	if type(extensions) ~= "table" then
		return
	end

	for key, value in pairs(extensions) do
		local extension = SNAPSHOT_EXTENSIONS[key]
		if type(extension) == "table" and type(extension.apply) == "function" then
			local should_apply = true
			if type(extension.validate) == "function" then
				local ok, valid = pcall(extension.validate, value, snapshot)
				should_apply = ok and valid ~= false
			end
			if should_apply then
				pcall(extension.apply, card, value, snapshot)
			end
		end
	end
end

local function get_card_front_key(card)
	local key = card and card.config and card.config.card_key
	if type(key) == "string" and key ~= "" and BALATRO.get_card_front(key) then
		return key
	end

	local front = card and card.config and card.config.card
	if front and G and G.P_CARDS then
		for candidate_key, candidate_front in pairs(G.P_CARDS) do
			if candidate_front == front then
				return candidate_key
			end
		end
	end

	return nil
end

team_card_sync.get_card_front_key = get_card_front_key

function team_card_sync.register_snapshot_extension(key, extension)
	if type(key) ~= "string" or key == "" or type(extension) ~= "table" then
		return false
	end
	if type(extension.capture) ~= "function" and type(extension.apply) ~= "function" then
		return false
	end

	SNAPSHOT_EXTENSIONS[key] = extension
	return true
end

local function is_valid_persistent_snapshot(persistent)
	if persistent == nil then
		return true
	end
	if type(persistent) ~= "table" then
		return false
	end

	for _, key in ipairs(PERSISTENT_ABILITY_FIELDS) do
		local value = persistent[key]
		if value ~= nil and type(value) ~= "number" then
			return false
		end
	end

	return persistent.perma_debuff == nil or type(persistent.perma_debuff) == "boolean"
end

local function is_valid_card_snapshot(snapshot)
	if type(snapshot) ~= "table" then
		return false
	end

	local has_front_key = type(snapshot.fk) == "string" and snapshot.fk ~= ""
	local has_rank_and_suit = (type(snapshot.r) == "string" or type(snapshot.r) == "number") and type(snapshot.s) == "string"
	if not has_front_key and not has_rank_and_suit then
		return false
	end

	for _, key in ipairs({ "e", "sl", "ak", "fk" }) do
		if snapshot[key] ~= nil and type(snapshot[key]) ~= "string" then
			return false
		end
	end
	return is_valid_persistent_snapshot(snapshot.p) and is_valid_extension_snapshot(snapshot.x)
end

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
	local playing_cards = BALATRO.get_playing_cards()
	if not playing_cards then return nil end
	for _, card in ipairs(playing_cards) do
		if card.mp_card_id == id then
			return card
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

function team_card_sync.get_persistent_ability_snapshot(card)
	local ability = card and card.ability or nil
	if not ability then
		return nil
	end

	local persistent = nil
	for _, key in ipairs(PERSISTENT_ABILITY_FIELDS) do
		local value = ability[key]
		if value ~= nil and value ~= 0 and value ~= false then
			persistent = persistent or {}
			persistent[key] = value
		end
	end

	if ability.perma_debuff then
		persistent = persistent or {}
		persistent.perma_debuff = true
	end

	return persistent
end

function team_card_sync.apply_persistent_ability_snapshot(card, persistent)
	local ability = card and card.ability or nil
	if not ability then
		return
	end

	for _, key in ipairs(PERSISTENT_ABILITY_FIELDS) do
		local value = persistent and persistent[key]
		ability[key] = value ~= nil and value or 0
	end

	ability.perma_debuff = not not (persistent and persistent.perma_debuff)
	if ability.perma_debuff then
		card.debuff = true
	end
end

function team_card_sync.snapshot_to_base_key(snapshot)
	if type(snapshot) ~= "table" then return nil end

	if type(snapshot.fk) == "string" and BALATRO.get_card_front(snapshot.fk) then
		return snapshot.fk
	end

	if not snapshot.r or not snapshot.s then return nil end
	local suit = tostring(snapshot.s)
	local rank = snapshot.r

	local suit_str = (SMODS and SMODS.Suits and SMODS.Suits[suit] and SMODS.Suits[suit].card_key)
		or VANILLA_SUIT_TO_KEY[suit]
		or (#suit == 1 and suit or string.sub(suit, 1, 1))

	local rank_str = nil
	if SMODS and SMODS.Ranks and SMODS.Ranks[tostring(rank)] and SMODS.Ranks[tostring(rank)].card_key then
		rank_str = SMODS.Ranks[tostring(rank)].card_key
	elseif type(rank) == "number" then
		rank_str = NUMERIC_RANK_TO_KEY[rank] or (rank >= 2 and rank <= 9 and tostring(rank) or nil)
	elseif type(rank) == "string" then
		rank_str = VANILLA_RANK_TO_KEY[rank] or (#rank == 1 and rank or nil)
	end
	if not rank_str then return nil end
	local key = suit_str .. "_" .. rank_str
	return BALATRO.get_card_front(key) and key or nil
end

function team_card_sync.encode_snapshot(snapshot)
	if not snapshot or not json or type(json.encode) ~= "function" then
		return nil
	end

	local ok, encoded = pcall(json.encode, snapshot)
	return ok and encoded or nil
end

function team_card_sync.decode_snapshot_data(card_data)
	if not (card_data and json and type(json.decode) == "function") then
		return nil
	end

	local ok, snapshot = pcall(json.decode, card_data)
	if not ok or not is_valid_card_snapshot(snapshot) then
		return nil
	end

	return snapshot
end

function team_card_sync.apply_snapshot_to_card(card, snapshot)
	if not card or not snapshot then return end

	local key = team_card_sync.snapshot_to_base_key(snapshot)
	local front = key and BALATRO.get_card_front(key) or nil
	if front then card:set_base(front) end

	local ed = snapshot.e and { [snapshot.e] = true } or nil
	card:set_edition(ed, APPLY_IMMEDIATELY, APPLY_SILENTLY)
	card:set_seal(snapshot.sl, APPLY_SILENTLY, APPLY_IMMEDIATELY)

	local center = BALATRO.get_center(snapshot.ak or "c_base") or BALATRO.get_center("c_base")
	card:set_ability(center, INITIAL_ASSIGNMENT, DELAY_SPRITES)
	team_card_sync.apply_persistent_ability_snapshot(card, snapshot.p)
	apply_extension_snapshots(card, snapshot)
	team_card_sync.cache_card_snapshot(card, snapshot)

	card:juice_up()
end

get_card_snapshot = function(card)
	if not team_card_sync.is_syncable_playing_card(card) then return nil end
	return {
		fk = get_card_front_key(card),
		r = card.base and card.base.value or nil,
		s = card.base and card.base.suit or nil,
		e = card.edition and card.edition.type or nil,
		sl = card.seal or nil,
		ak = (card.config and card.config.center and card.config.center.key) or "c_base",
		p = team_card_sync.get_persistent_ability_snapshot(card),
		x = capture_extension_snapshots(card),
	}
end
team_card_sync.get_card_snapshot = get_card_snapshot

function team_card_sync.cache_card_snapshot(card, snapshot)
	if not card then
		return nil
	end

	local encoded = team_card_sync.encode_snapshot(snapshot or get_card_snapshot(card))
	if encoded then
		card.mp_last_sync_raw = encoded
	end
	return encoded
end

function team_card_sync.cache_all_playing_card_snapshots()
	local playing_cards = BALATRO.get_playing_cards()
	if not playing_cards then
		return
	end

	for _, card in ipairs(playing_cards) do
		if card and card.mp_card_id and card.mp_synced_as_added then
			team_card_sync.cache_card_snapshot(card)
		end
	end
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
	team_card_sync.cache_all_playing_card_snapshots()
	BALATRO.set_mp_card_next_id(next_card_id)
end

function team_card_sync.assign_initial_team_card_ids()
	local playing_cards = BALATRO.get_playing_cards() or {}
	local prefix = MP.is_teams_mode() and "TEAM" or (BALATRO.get_player_id() or "LOCAL")
	for index, card in ipairs(playing_cards) do
		team_card_sync.mark_card_ready_for_team_sync(card, prefix .. "_" .. (index - 1))
	end
	team_card_sync.finalize_team_card_setup(#playing_cards)
end
