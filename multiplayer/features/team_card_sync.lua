MP.SYNC = MP.SYNC or {}
local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
MP.TEAM_CARD_SUSPENDED = MP.TEAM_CARD_SUSPENDED or false
MP.TEAM_CARD_INITIALIZING = MP.TEAM_CARD_INITIALIZING or false

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or {}

-- ============================================================================
-- 1. Snapshot Serialization & Deserialization (from team_card_sync_snapshot.lua)
-- ============================================================================
if team_card_sync._snapshot_loaded then
	return
end
team_card_sync._snapshot_loaded = true

local ok_json, json = pcall(require, "json")
if not ok_json then json = rawget(_G, "json") end

local TEAM_CARD_SNAPSHOT_VERSION = 2
local MAX_SAFE_DEPTH = 16
local MAX_SAFE_NODES = 6000
local MAX_SAFE_STRING_LENGTH = 65536
local MAX_ENCODED_SNAPSHOT_LENGTH = 512 * 1024

local CARD_SAVE_FIELDS_NEVER_SYNCED = {
	unique_val = true,
	unique_val__saved_ID = true,
}

-- Local runtime/UI fields are restored after remote Card:load and ignored for compare.
local CARD_RUNTIME_FIELDS_PRESERVED_LOCALLY = {
	"sort_id",
	"params",
	"no_ui",
	"base_cost",
	"extra_cost",
	"cost",
	"sell_cost",
	"facing",
	"sprite_facing",
	"flipping",
	"highlighted",
	"debuff",
	"debuffed_by_blind",
	"rank",
	"added_to_deck",
	"joker_added_to_deck_but_debuffed",
	"playing_card",
	"shop_voucher",
	"pinned",
	"bypass_discovery_center",
	"bypass_discovery_ui",
	"bypass_lock",
	"unique_val",
	"unique_val__saved_ID",
	"ignore_base_shader",
	"ignore_shadow",
}

local CARD_RUNTIME_SET = {}
for _, key in ipairs(CARD_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
	CARD_RUNTIME_SET[key] = true
end

local ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY = {
	"discarded",
	"forced_selection",
	"played_this_ante",
	"wheel_flipped",
	"delay_seal",
	"debuff_sources",
	"extra_enhancement",
}

local ABILITY_RUNTIME_SET = {}
for _, key in ipairs(ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
	ABILITY_RUNTIME_SET[key] = true
end

local get_card_snapshot
team_card_sync.SNAPSHOT_VERSION = TEAM_CARD_SNAPSHOT_VERSION

function team_card_sync.require_snapshot_api(name)
	local value = team_card_sync[name]
	if not value then
		error("Team card sync snapshot API missing: " .. tostring(name))
	end
	return value
end

local function is_safe_number(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function get_card_front_key(card)
	local key = card and card.config and card.config.card_key
	if type(key) == "string" and key ~= "" and (G and G.P_CARDS and G.P_CARDS[key] or nil) then
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

local function get_card_center_key(card)
	local key = card and card.config and (
		card.config.center_key
		or (card.config.center and card.config.center.key)
	)
	if type(key) == "string" and key ~= "" and (G and G.P_CENTERS and G.P_CENTERS[key] or nil) then
		return key
	end
	return "c_base"
end

local function safe_clone_key(key)
	local key_type = type(key)
	if key_type == "string" then
		if #key > 256 then
			return nil
		end
		return key
	end
	if is_safe_number(key) then
		return key
	end
	return nil
end

local function safe_clone_value(value, depth, state)
	local value_type = type(value)
	if value_type == "nil" or value_type == "boolean" then
		return value
	end
	if value_type == "number" then
		return is_safe_number(value) and value or nil
	end
	if value_type == "string" then
		return #value <= MAX_SAFE_STRING_LENGTH and value or nil
	end
	if value_type ~= "table" or depth >= MAX_SAFE_DEPTH or state.nodes_left <= 0 then
		return nil
	end
	if state.seen[value] then
		return nil
	end

	state.seen[value] = true
	state.nodes_left = state.nodes_left - 1

	local copy = {}
	for key, child_value in pairs(value) do
		if state.nodes_left <= 0 then
			break
		end

		local safe_key = safe_clone_key(key)
		if safe_key ~= nil then
			local safe_value = safe_clone_value(child_value, depth + 1, state)
			if safe_value ~= nil then
				copy[safe_key] = safe_value
			end
		end
	end

	state.seen[value] = nil
	return copy
end

local function is_never_synced_card_save_field(key)
	if CARD_SAVE_FIELDS_NEVER_SYNCED[key] then
		return true
	end
	return type(key) == "string" and string.sub(key, 1, 3) == "mp_"
end

local function is_prefixed_local_ability_runtime_field(key)
	return type(key) == "string" and string.sub(key, 1, 6) == "SMODS_"
end

local function canonical_number(value)
	local encoded = string.format("%.17g", value)
	return encoded == "-0" and "0" or encoded
end

local json_string_escapes = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function canonical_string(value)
	if string.find(value, "^[%w_]+$") then
		return '"' .. value .. '"'
	end
	return '"' .. string.gsub(value, '[%z\1-\31\\"]', function(char)
		return json_string_escapes[char] or string.format("\\u%04x", string.byte(char))
	end) .. '"'
end

local CANONICAL_KEY_TYPE_ORDER = { boolean = 1, number = 2, string = 3 }

local function canonical_key_less(a, b)
	local a_type, b_type = type(a), type(b)
	local a_order = CANONICAL_KEY_TYPE_ORDER[a_type] or 99
	local b_order = CANONICAL_KEY_TYPE_ORDER[b_type] or 99
	if a_order ~= b_order then
		return a_order < b_order
	end
	if a_type == "number" then
		return a < b
	end
	return tostring(a) < tostring(b)
end

local canonical_encode_value
canonical_encode_value = function(value, mode)
	local value_type = type(value)
	if value_type == "nil" then
		return "nil"
	end
	if value_type == "boolean" then
		return value and "true" or "false"
	end
	if value_type == "number" then
		return canonical_number(value)
	end
	if value_type == "string" then
		return canonical_string(value)
	end
	if value_type ~= "table" then
		return nil
	end

	local keys = {}
	for key in pairs(value) do
		local skip = false
		if mode == "cs" then
			skip = CARD_RUNTIME_SET[key] or is_never_synced_card_save_field(key)
		elseif mode == "cs_base" then
			skip = (key == "times_played")
		elseif mode == "cs_ability" then
			skip = ABILITY_RUNTIME_SET[key] or is_prefixed_local_ability_runtime_field(key)
		end
		if not skip then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, canonical_key_less)

	local parts = {}
	for _, key in ipairs(keys) do
		local child_mode = nil
		if mode == "root" and key == "cs" and value.v == TEAM_CARD_SNAPSHOT_VERSION then
			child_mode = "cs"
		elseif mode == "cs" then
			if key == "base" then
				child_mode = "cs_base"
			elseif key == "ability" then
				child_mode = "cs_ability"
			end
		end
		local encoded_value = canonical_encode_value(value[key], child_mode)
		if encoded_value ~= nil then
			parts[#parts + 1] = type(key) .. ":" .. canonical_encode_value(key) .. "=" .. encoded_value
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function strip_local_ability_runtime_state(ability)
	if type(ability) ~= "table" then return end

	for key in pairs(ability) do
		if ABILITY_RUNTIME_SET[key] or is_prefixed_local_ability_runtime_field(key) then
			ability[key] = nil
		end
	end
end

local function ensure_card_save_load_state(card, card_save)
	if type(card_save) ~= "table" or type(card_save.base) ~= "table" then
		return
	end

	if card_save.base.times_played == nil then
		local local_times_played = card and card.base and card.base.times_played
		card_save.base.times_played = type(local_times_played) == "number" and local_times_played or 0
	end
end

function team_card_sync.ensure_card_base_runtime(card)
	if type(card and card.base) == "table" and card.base.times_played == nil then
		card.base.times_played = 0
	end
end

function team_card_sync.sanitize_card_save(card, card_save)
	if type(card_save) ~= "table" then
		return nil
	end

	local state = { seen = {}, nodes_left = MAX_SAFE_NODES }
	local sanitized = {}
	for key, value in pairs(card_save) do
		if not is_never_synced_card_save_field(key) then
			local safe_key = safe_clone_key(key)
			if safe_key ~= nil then
				local safe_value = safe_clone_value(value, 1, state)
				if safe_value ~= nil then
					sanitized[safe_key] = safe_value
				end
			end
		end
	end

	sanitized.save_fields = type(sanitized.save_fields) == "table" and sanitized.save_fields or {}
	sanitized.params = type(sanitized.params) == "table" and sanitized.params or {}
	sanitized.facing = type(sanitized.facing) == "string" and sanitized.facing or "front"
	sanitized.sprite_facing = type(sanitized.sprite_facing) == "string" and sanitized.sprite_facing or "front"

	local front_key = sanitized.save_fields.card
	if not (type(front_key) == "string" and (G and G.P_CARDS and G.P_CARDS[front_key] or nil)) then
		front_key = get_card_front_key(card)
	end
	if not (type(front_key) == "string" and (G and G.P_CARDS and G.P_CARDS[front_key] or nil)) then
		return nil
	end
	sanitized.save_fields.card = front_key

	local center_key = sanitized.save_fields.center
	if not (type(center_key) == "string" and (G and G.P_CENTERS and G.P_CENTERS[center_key] or nil)) then
		center_key = get_card_center_key(card)
	end
	sanitized.save_fields.center = center_key

	return sanitized
end

function team_card_sync.get_sanitized_card_save(card)
	if not (card and type(card.save) == "function") then
		return nil
	end

	local ok, card_save = pcall(function()
		return card:save()
	end)
	if not ok then
		return nil
	end

	return team_card_sync.sanitize_card_save(card, card_save)
end

local function is_valid_card_save_snapshot(card_save)
	if type(card_save) ~= "table" or type(card_save.save_fields) ~= "table" then
		return false
	end

	local center_key = card_save.save_fields.center
	local front_key = card_save.save_fields.card
	return type(center_key) == "string"
		and type(front_key) == "string"
		and (G and G.P_CENTERS and G.P_CENTERS[center_key] or nil)
		and (G and G.P_CARDS and G.P_CARDS[front_key] or nil)
end

local function is_valid_card_snapshot(snapshot)
	if type(snapshot) ~= "table" then
		return false
	end

	return snapshot.v == TEAM_CARD_SNAPSHOT_VERSION
		and is_valid_card_save_snapshot(snapshot.cs)
end

function team_card_sync.snapshot_to_base_key(snapshot)
	if type(snapshot) ~= "table" then return nil end

	if snapshot.v == TEAM_CARD_SNAPSHOT_VERSION
		and type(snapshot.cs) == "table"
		and type(snapshot.cs.save_fields) == "table"
	then
		local front_key = snapshot.cs.save_fields.card
		if type(front_key) == "string" and (G and G.P_CARDS and G.P_CARDS[front_key] or nil) then
			return front_key
		end
	end

	return nil
end

function team_card_sync.snapshot_to_center_key(snapshot)
	if type(snapshot) ~= "table" then
		return "c_base"
	end

	if snapshot.v == TEAM_CARD_SNAPSHOT_VERSION
		and type(snapshot.cs) == "table"
		and type(snapshot.cs.save_fields) == "table"
	then
		local center_key = snapshot.cs.save_fields.center
		if type(center_key) == "string" and (G and G.P_CENTERS and G.P_CENTERS[center_key] or nil) then
			return center_key
		end
	end

	return "c_base"
end

function team_card_sync.encode_snapshot(snapshot)
	if not snapshot or not json or type(json.encode) ~= "function" then
		return nil
	end

	local ok, encoded = pcall(json.encode, snapshot)
	if not ok or type(encoded) ~= "string" or #encoded > MAX_ENCODED_SNAPSHOT_LENGTH then
		return nil
	end
	return encoded
end

function team_card_sync.encode_snapshot_for_compare(snapshot)
	if type(snapshot) ~= "table" then
		return nil
	end

	local encoded = canonical_encode_value(snapshot, "root")
	if type(encoded) ~= "string" or #encoded > MAX_ENCODED_SNAPSHOT_LENGTH then
		return nil
	end
	return encoded
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

function team_card_sync.capture_local_card_runtime(card)
	local runtime = {
		fields = {},
		ability_fields = {},
		ability_prefixed_fields = {},
		base_times_played = card and card.base and card.base.times_played or nil,
		mp_card_id = card and card.mp_card_id or nil,
		mp_synced_as_added = card and card.mp_synced_as_added or nil,
		mp_last_sync_raw = card and card.mp_last_sync_raw or nil,
	}

	for _, key in ipairs(CARD_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		runtime.fields[key] = card and card[key] or nil
	end

	local ability = card and card.ability or nil
	for _, key in ipairs(ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		local value = nil
		if ability then
			value = ability[key]
		end
		runtime.ability_fields[key] = {
			present = ability ~= nil and value ~= nil,
			value = value,
		}
	end
	if type(ability) == "table" then
		for key, value in pairs(ability) do
			if is_prefixed_local_ability_runtime_field(key) then
				runtime.ability_prefixed_fields[key] = {
					present = true,
					value = value,
				}
			end
		end
	end

	return runtime
end

local function restore_runtime_value(target, key, saved)
	if saved and saved.present then
		target[key] = saved.value
	else
		target[key] = nil
	end
end

local function restore_local_ability_runtime(card, runtime)
	if not (card and runtime) then return end

	card.ability = card.ability or {}
	strip_local_ability_runtime_state(card.ability)

	for _, key in ipairs(ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		restore_runtime_value(card.ability, key, runtime.ability_fields[key])
	end
	for key, saved in pairs(runtime.ability_prefixed_fields or {}) do
		restore_runtime_value(card.ability, key, saved)
	end
end

function team_card_sync.restore_local_card_runtime(card, runtime)
	if not (card and runtime) then
		return
	end

	for _, key in ipairs(CARD_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		card[key] = runtime.fields[key]
	end

	if type(card.base) == "table" then
		card.base.times_played = type(runtime.base_times_played) == "number" and runtime.base_times_played or 0
	end
	restore_local_ability_runtime(card, runtime)

	card.mp_card_id = runtime.mp_card_id
	card.mp_synced_as_added = runtime.mp_synced_as_added
	card.mp_last_sync_raw = runtime.mp_last_sync_raw
end

local function ensure_card_draw_children(card, snapshot)
	if not card then
		return
	end

	card.children = card.children or {}
	card.params = type(card.params) == "table" and card.params or {}
	card.facing = type(card.facing) == "string" and card.facing or "front"
	card.sprite_facing = type(card.sprite_facing) == "string" and card.sprite_facing or "front"

	if not (type(card.set_sprites) == "function" and (not card.children.center or not card.children.back)) then
		return
	end

	local front = (G and G.P_CARDS and G.P_CARDS[team_card_sync.snapshot_to_base_key(snapshot)] or nil)
	local center = (G and G.P_CENTERS and G.P_CENTERS[team_card_sync.snapshot_to_center_key(snapshot)])
		or (G and G.P_CENTERS and G.P_CENTERS["c_base"] or nil)
	if front and center then
		pcall(function()
			card:set_sprites(center, front)
		end)
	end
end

local function apply_card_save_snapshot(card, snapshot)
	if not (card and type(card.load) == "function" and type(snapshot.cs) == "table") then
		return false
	end

	local runtime = team_card_sync.capture_local_card_runtime(card)
	ensure_card_save_load_state(card, snapshot.cs)
	local ok = pcall(function()
		card:load(snapshot.cs)
	end)
	team_card_sync.restore_local_card_runtime(card, runtime)

	return ok
end

function team_card_sync.apply_snapshot_to_card(card, snapshot)
	if not card or not snapshot then return end

	local applied = snapshot.v == TEAM_CARD_SNAPSHOT_VERSION
		and apply_card_save_snapshot(card, snapshot)
	if not applied then return end

	ensure_card_draw_children(card, snapshot)
	team_card_sync.cache_card_snapshot(card, snapshot)
	if card.juice_up then
		card:juice_up()
	end
end

get_card_snapshot = function(card)
	if not team_card_sync.is_syncable_playing_card(card) then return nil end

	local card_save = team_card_sync.get_sanitized_card_save(card)
	if not card_save then return nil end

	return {
		v = TEAM_CARD_SNAPSHOT_VERSION,
		cs = card_save,
	}
end
team_card_sync.get_card_snapshot = get_card_snapshot

function team_card_sync.cache_card_snapshot(card, snapshot)
	if not card then
		return nil
	end

	local encoded = team_card_sync.encode_snapshot_for_compare(snapshot or get_card_snapshot(card))
	if encoded then
		card.mp_last_sync_raw = encoded
	end
	return encoded
end

function team_card_sync.cache_all_playing_card_snapshots()
	local playing_cards = (G and G.playing_cards or nil)
	if not playing_cards then
		return
	end

	for _, card in ipairs(playing_cards) do
		team_card_sync.ensure_card_base_runtime(card)
		if card and card.mp_card_id and card.mp_synced_as_added then
			team_card_sync.cache_card_snapshot(card)
		end
	end
end

-- ============================================================================
-- 2. Card Identity & Tagging (from team_card_sync_identity.lua)
-- ============================================================================
if team_card_sync._identity_loaded then
	return
end
team_card_sync._identity_loaded = true


local function get_card_front_key(...) return team_card_sync.get_card_front_key(...) end
local function cache_all_playing_card_snapshots(...) return team_card_sync.cache_all_playing_card_snapshots(...) end

local card_by_id_cache = setmetatable({}, { __mode = "v" })

function team_card_sync.is_syncable_playing_card(card)
	if not card then return false end
	if card.ability and (card.ability.set == "Joker" or card.ability.consumeable) then
		return false
	end
	return not not ((card.base and card.base.suit and card.base.value) or get_card_front_key(card))
end

function team_card_sync.assign_card_id(card)
	if not card or card.mp_card_id then return end
	local game = (G and G.GAME or nil)
	if not game then return end
	local next_id = game.mp_card_next_id or 0
	local prefix = (G and G.MP_ID or nil) or "LOCAL"
	card.mp_card_id = prefix .. "_" .. next_id
	card_by_id_cache[tostring(card.mp_card_id)] = card
	game.mp_card_next_id = next_id + 1
end

function team_card_sync.is_main_team_area(area)
	if not area or not area.config or area.config.mp_preview_only then return false end
	return area == (G and G.deck or nil) or area == (G and G.hand or nil)
end

function team_card_sync.get_card_by_id(id)
	if id == nil then
		return nil
	end
	local want = tostring(id)
	local cached = card_by_id_cache[want]
	if cached and cached.mp_card_id and tostring(cached.mp_card_id) == want and not (cached.removed or cached.REMOVED) then
		return cached
	end

	local playing_cards = (G and G.playing_cards or nil)
	if playing_cards then
		for _, card in ipairs(playing_cards) do
			if card and card.mp_card_id and tostring(card.mp_card_id) == want then
				card_by_id_cache[want] = card
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
						card_by_id_cache[want] = card
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
	if card.mp_card_id then
		card_by_id_cache[tostring(card.mp_card_id)] = card
	end
end

function team_card_sync.finalize_team_card_setup(next_card_id)
	cache_all_playing_card_snapshots()
	if G and G.GAME then
		G.GAME.mp_card_next_id = next_card_id
	end
end

function team_card_sync.assign_initial_team_card_ids()
	local playing_cards = (G and G.playing_cards or nil) or {}
	-- Index-based TEAM ids are deterministic across clients in the same
	-- lobby regardless of the shared-deck option; spectator boards rely on
	-- that to resolve sync deltas against the watched player's deck.
	local prefix = (MP.LOBBY and MP.LOBBY.code) and "TEAM"
		or ((G and G.MP_ID or nil) or "LOCAL")
	for index, card in ipairs(playing_cards) do
		team_card_sync.mark_card_ready_for_team_sync(card, prefix .. "_" .. (index - 1))
	end
	team_card_sync.finalize_team_card_setup(#playing_cards)
end

-- ============================================================================
-- 3. Network Application & Relaying (from team_card_sync_apply.lua)
-- ============================================================================
if team_card_sync._apply_loaded then
	return
end
team_card_sync._apply_loaded = true


local is_applying_remote_change = false
local removed_card_ids = {}

local function get_card_by_id(...) return team_card_sync.get_card_by_id(...) end
local function encode_snapshot(...) return team_card_sync.encode_snapshot(...) end
local function encode_snapshot_for_compare(...) return team_card_sync.encode_snapshot_for_compare(...) end
local function decode_snapshot_data(...) return team_card_sync.decode_snapshot_data(...) end
local function apply_snapshot_to_card(...) return team_card_sync.apply_snapshot_to_card(...) end
local function get_card_snapshot(...) return team_card_sync.get_card_snapshot(...) end
local function snapshot_to_center_key(...) return team_card_sync.snapshot_to_center_key(...) end
local function snapshot_to_base_key(...) return team_card_sync.snapshot_to_base_key(...) end
local function assign_card_id(...) return team_card_sync.assign_card_id(...) end
local function mark_card_ready_for_team_sync(...) return team_card_sync.mark_card_ready_for_team_sync(...) end
local function ensure_card_base_runtime(...) return team_card_sync.ensure_card_base_runtime(...) end

local SHARED_INITIAL_CARD_ID_PATTERN = "^TEAM_%d+$"

local function is_team_card_sync_active()
	-- NOTE: deliberately NOT gated on MP.is_shared_card_sync_enabled().
	-- That option only decides whether teammates share deck state (the
	-- server owns that routing decision). Card relays must keep flowing so
	-- spectators of this player can apply deck mutations to their boards.
	return (G and G.STAGES and G.STAGE == G.STAGES.RUN or false)
		and MP.LOBBY
		and MP.LOBBY.code
		and not MP.TEAM_CARD_INITIALIZING
		and not MP.TEAM_CARD_SUSPENDED
		and not (G and (G.STATE == G.STATES.GAME_OVER or G.STATE == G.STATES.GAME_WIN) or false)
		and not (MP.GAME and MP.GAME.won)
end

local function trace_team_card_sync() end
local function trace_team_card() end

local function apply_remote_change(fn)
	is_applying_remote_change = true
	local ok, err = pcall(fn)
	is_applying_remote_change = false
	if not ok and sendWarnMessage then
		sendWarnMessage("Team card sync error: " .. tostring(err), "MULTIPLAYER")
	end
	return ok
end

function team_card_sync.is_sync_active()
	return is_team_card_sync_active()
end

function team_card_sync.can_relay_changes()
	return not is_applying_remote_change and is_team_card_sync_active()
end

function team_card_sync.is_applying_remote_change()
	return is_applying_remote_change
end

local function spec_team_log() end

local function is_spectating_board()
	return not not (MP.SPECTATOR and MP.SPECTATOR.is_spectating)
end

local function relay_teammate_sync_into_action_stream(data)
	-- Spectators of this player only see recorded actions. A teammate's
	-- Strength never becomes a local USE_CARD, so it must be streamed here
	-- or the spectator board never changes. Server fan-out to spectators is
	-- a separate path and has not been reaching this client.
	if is_spectating_board() then
		return
	end
	if not (MP.RECORDER and MP.RECORDER.record_action) then
		return
	end
	local source = data and (data.playerId or data.sourcePlayerId)
	if source == nil or tostring(source) == "SERVER" then
		return
	end
	local self_id = (G and G.MP_ID or nil)
	if self_id and tostring(source) == tostring(self_id) then
		return
	end
	MP.RECORDER.record_action("TEAM_CARD_SYNC", {
		cardKey = data.cardKey,
		actionType = data.actionType,
		cardData = data.cardData,
		sourcePlayerId = tostring(source),
	})
end

local function spectator_should_ignore_source(data)
	local spec = MP.SPECTATOR
	if not (spec and spec.is_spectating and spec.target_player_id) then
		return false
	end
	local source = data and (data.playerId or data.sourcePlayerId)
	return source ~= nil and tostring(source) == tostring(spec.target_player_id)
end

local function is_card_in_play_area(card)
	local play_area = (G and G.play or nil)
	if not (card and play_area) then
		return false
	end
	if card.area == play_area then
		return true
	end
	if type(play_area.cards) ~= "table" then
		return false
	end

	for _, play_card in ipairs(play_area.cards) do
		if play_card == card then
			return true
		end
	end

	return false
end

team_card_sync.is_card_in_play_area = is_card_in_play_area

local function is_playing_card_in_deck_list(card)
	local playing_cards = (G and G.playing_cards) or nil
	if not playing_cards then
		return false
	end

	for _, playing_card in ipairs(playing_cards) do
		if playing_card == card then
			return true
		end
	end

	return false
end

local function is_card_removed_or_destroyed(card)
	return card and (card.removed or card.REMOVED or card.destroyed or card.shattered)
end

local function is_live_playing_card_in_deck(card)
	if not card or is_card_removed_or_destroyed(card) then
		return false
	end
	return is_playing_card_in_deck_list(card)
end

local function has_synced_team_card_id(card)
	return card and card.mp_card_id and card.mp_synced_as_added
end

local function is_relayable_synced_team_card(card)
	return has_synced_team_card_id(card) and is_live_playing_card_in_deck(card)
end

local function is_new_unsynced_team_card(card)
	return card and not card.mp_synced_as_added and is_live_playing_card_in_deck(card)
end

local function is_relayable_new_team_card(card)
	return card and card.mp_card_id and is_new_unsynced_team_card(card)
end

local function clear_shared_initial_id_from_new_card(card)
	if card
		and not card.mp_synced_as_added
		and type(card.mp_card_id) == "string"
		and string.match(card.mp_card_id, SHARED_INITIAL_CARD_ID_PATTERN)
	then
		card.mp_card_id = nil
	end
end

local function is_relayable_removed_team_card(card)
	return has_synced_team_card_id(card)
		and not card.removed
		and is_playing_card_in_deck_list(card)
end

local function mark_removed_card_id(card_id)
	if card_id ~= nil then
		removed_card_ids[tostring(card_id)] = true
	end
end

local function is_removed_card_id(card_id)
	return card_id ~= nil and removed_card_ids[tostring(card_id)] == true
end

function team_card_sync.clear_removed_card_ids()
	removed_card_ids = {}
	if team_card_sync.clear_pending_remote_changes then
		team_card_sync.clear_pending_remote_changes()
	end
end

local function build_team_card_payload(card, action_type, card_data)
	local is_relayable = action_type == "removed" and is_relayable_removed_team_card(card)
		or action_type == "sync" and is_relayable_synced_team_card(card)
	if not team_card_sync.can_relay_changes() or not is_relayable then
		return nil
	end

	return {
		card_id = tostring(card.mp_card_id),
		action_type = action_type,
		card_data = card_data,
	}
end

function team_card_sync.relay_payload(payload)
	if not (payload and payload.card_id and MP.ACTIONS and MP.ACTIONS.team_card_sync) then
		return false
	end

	return not not MP.ACTIONS.team_card_sync(payload.card_id, payload.action_type, payload.card_data)
end

local function build_snapshot_data(card, force_send)
	local snapshot = get_card_snapshot(card)
	if not snapshot then
		return nil, nil, "snapshot_missing"
	end

	local compare_encoded = encode_snapshot_for_compare(snapshot)
	if not compare_encoded then
		return nil, nil, "compare_encode_failed"
	end

	if not force_send and card.mp_last_sync_raw == compare_encoded then
		return nil, nil, "unchanged"
	end

	local encoded = encode_snapshot(snapshot)
	if not encoded then
		return nil, nil, "encode_failed"
	end

	return encoded, compare_encoded
end

function team_card_sync.build_snapshot_payload(card)
	if not is_relayable_synced_team_card(card) then
		return nil
	end

	local encoded, compare_encoded = build_snapshot_data(card, false)
	if not encoded then
		return nil
	end

	local payload = build_team_card_payload(card, "sync", encoded)
	if payload then
		payload.compare_data = compare_encoded
	end
	return payload
end

function team_card_sync.sync(card)
	local payload = team_card_sync.build_snapshot_payload(card)
	if not payload then
		return false
	end

	if not team_card_sync.relay_payload(payload) then
		return false
	end

	card.mp_last_sync_raw = payload.compare_data
	return true
end

function team_card_sync.sync_new_card(card)
	trace_team_card(card, "sync_new_start")
	if not team_card_sync.can_relay_changes() then
		trace_team_card_sync("sync_new_blocked", {
			reason = "cannot_relay",
			active = is_team_card_sync_active(),
			applying_remote = is_applying_remote_change,
			suspended = not not MP.TEAM_CARD_SUSPENDED,
			initializing = not not MP.TEAM_CARD_INITIALIZING,
		})
		return false
	end
	if not is_new_unsynced_team_card(card) then
		trace_team_card(card, "sync_new_blocked", { reason = "not_unsynced_real_card" })
		return false
	end

	ensure_card_base_runtime(card)
	clear_shared_initial_id_from_new_card(card)
	assign_card_id(card)
	if not is_relayable_new_team_card(card) then
		trace_team_card(card, "sync_new_blocked", { reason = "not_relayable_after_id" })
		return false
	end

	local encoded, compare_encoded, snapshot_reason = build_snapshot_data(card, true)
	if not encoded then
		trace_team_card(card, "sync_new_blocked", { reason = snapshot_reason or "snapshot_failed" })
		return false
	end

	local payload = {
		card_id = tostring(card.mp_card_id),
		action_type = "sync",
		card_data = encoded,
	}
	if not team_card_sync.relay_payload(payload) then
		trace_team_card(card, "sync_new_blocked", {
			reason = "relay_payload_failed",
			encoded_bytes = #encoded,
		})
		return false
	end

	mark_card_ready_for_team_sync(card)
	card.mp_last_sync_raw = compare_encoded
	trace_team_card_sync("sync_new_sent", {
		card_id = tostring(card.mp_card_id),
		playing_card = card.playing_card or "nil",
		encoded_bytes = #encoded,
	})
	return true
end

function team_card_sync.build_removal_payload(card)
	return build_team_card_payload(card, "removed", nil)
end

function team_card_sync.relay_removal(card)
	if card and card.mp_team_card_suppress_next_removal_relay then
		card.mp_team_card_suppress_next_removal_relay = nil
		return false
	end

	local payload = team_card_sync.build_removal_payload(card)
	return team_card_sync.relay_payload(payload)
end

local function create_remote_team_card_target(card_id, snapshot)
	local key = team_card_sync.snapshot_to_base_key(snapshot)
	if not key then
		trace_team_card_sync("remote_create_blocked", {
			card_id = tostring(card_id or "nil"),
			reason = "missing_base_key",
		})
		return nil
	end

	trace_team_card_sync("remote_create_start", {
		card_id = tostring(card_id or "nil"),
		base_key = tostring(key),
		center_key = tostring(snapshot_to_center_key(snapshot)),
	})
	local target = BALATRO.create_playing_card({
		front = (G and G.P_CARDS and G.P_CARDS[key] or nil),
		center = (G and G.P_CENTERS and G.P_CENTERS[snapshot_to_center_key(snapshot)] or nil) or (G and G.P_CENTERS and G.P_CENTERS["c_base"] or nil),
	}, (G and G.deck or nil))
	mark_card_ready_for_team_sync(target, card_id)
	trace_team_card(target, "remote_create_complete")
	return target
end

local function card_already_matches_snapshot(card, snapshot)
	local incoming_compare = encode_snapshot_for_compare(snapshot)
	if not incoming_compare then
		return false, nil
	end

	if card and card.mp_last_sync_raw and card.mp_last_sync_raw == incoming_compare then
		return true, incoming_compare
	end

	local current_compare = encode_snapshot_for_compare(get_card_snapshot(card))
	return current_compare ~= nil and current_compare == incoming_compare, incoming_compare
end

local function apply_remote_team_card_removal_now(card_id, options)
	local card = get_card_by_id(card_id)
	if not card then
		return false
	end

	if options and options.from_play_flush and is_card_in_play_area(card) and type(card.start_dissolve) == "function" then
		card.mp_team_card_suppress_next_removal_relay = true
		card.destroyed = true
		card:start_dissolve(nil, true)
		return true
	end

	card:remove()
	return true
end

local function apply_remote_team_card_snapshot_now(card_id, snapshot)
	trace_team_card_sync("remote_snapshot_apply_start", {
		card_id = tostring(card_id or "nil"),
		target_exists = not not get_card_by_id(card_id),
	})
	local target = get_card_by_id(card_id)
	local existed = target ~= nil
	if not target then
		target = create_remote_team_card_target(card_id, snapshot)
	end
	if target and target.area and target.base then
		local already_matches, compare_data = card_already_matches_snapshot(target, snapshot)
		if already_matches then
			target.mp_last_sync_raw = compare_data
			spec_team_log("SAME", tostring(card_id))
			trace_team_card_sync("remote_snapshot_apply_skipped", {
				card_id = tostring(card_id or "nil"),
				reason = "already_matches",
			})
			return true
		end

		apply_snapshot_to_card(target, snapshot)
		spec_team_log(existed and "APPLY" or "CREATE", tostring(card_id))
		trace_team_card(target, "remote_snapshot_applied")
		return true
	end

	spec_team_log("FAIL", tostring(card_id))

	trace_team_card_sync("remote_snapshot_apply_blocked", {
		card_id = tostring(card_id or "nil"),
		reason = "missing_target_or_runtime",
		target_exists = not not target,
	})
	return false
end

local apply_remote_team_card_change_now

local function apply_remote_team_card_changes_now(changes, options)
	local applied_count = 0
	apply_remote_change(function()
		for _, change in ipairs(changes) do
			if apply_remote_team_card_change_now(change, options) then
				applied_count = applied_count + 1
			end
		end
	end)
	return applied_count
end

team_card_sync.apply_remote_changes_now = apply_remote_team_card_changes_now

apply_remote_team_card_change_now = function(change, options)
	if change.action_type == "removed" then
		return apply_remote_team_card_removal_now(change.card_id, options)
	end

	if change.snapshot then
		return apply_remote_team_card_snapshot_now(change.card_id, change.snapshot)
	end

	return false
end

local function enqueue_remote_team_card_change(change)
	if not (change and change.card_id and change.action_type) then
		return false
	end

	if is_spectating_board() then
		if MP.SPECTATOR.applying_snapshot then
			if team_card_sync.defer_remote_change_until_active then
				return team_card_sync.defer_remote_change_until_active(change)
			end
			return false
		end
		apply_remote_change(function()
			apply_remote_team_card_change_now(change)
		end)
		return true
	end

	if not is_team_card_sync_active() then
		if team_card_sync.defer_remote_change_until_active then
			return team_card_sync.defer_remote_change_until_active(change)
		end
		return false
	end

	if team_card_sync.defer_remote_change and team_card_sync.defer_remote_change(change) then
		return true
	end

	local function apply_or_defer()
		if not is_team_card_sync_active() then
			return true
		end

		if team_card_sync.defer_remote_change and team_card_sync.defer_remote_change(change) then
			return true
		end

		apply_remote_change(function()
			apply_remote_team_card_change_now(change)
		end)
		return true
	end

	if not BALATRO.queue_event then
		apply_remote_change(function()
			apply_remote_team_card_change_now(change)
		end)
		return true
	end

	return BALATRO.queue_event({
		trigger = "after",
		delay = 0,
		func = apply_or_defer,
	})
end

function team_card_sync.sync_card_list(cards)
	if is_applying_remote_change or not is_team_card_sync_active() or type(cards) ~= "table" then
		return
	end

	local seen = {}
	for _, card in ipairs(cards) do
		if is_relayable_synced_team_card(card) then
			local id = tostring(card.mp_card_id)
			if not seen[id] then
				seen[id] = true
				team_card_sync.sync(card)
			end
		end
	end
end

function team_card_sync.sync_full_deck()
	if is_applying_remote_change or not is_team_card_sync_active() then
		return 0
	end

	local playing_cards = (G and G.playing_cards) or {}
	local sent_count = 0
	for _, card in ipairs(playing_cards) do
		if is_relayable_synced_team_card(card) then
			local encoded, compare_encoded = build_snapshot_data(card, true)
			if encoded then
				local payload = {
					card_id = tostring(card.mp_card_id),
					action_type = "sync",
					card_data = encoded,
				}
				if team_card_sync.relay_payload(payload) then
					card.mp_last_sync_raw = compare_encoded
					sent_count = sent_count + 1
				end
			end
		end
	end

	return sent_count
end

function team_card_sync.handle_sync(data)
	if spectator_should_ignore_source(data) then
		spec_team_log("SKIP_A", string.format("%s %s", tostring(data and data.actionType), tostring(data and data.cardKey)))
		trace_team_card_sync("remote_sync_ignored", {
			card_id = data and tostring(data.cardKey or "nil") or "nil",
			reason = "spectated_target_uses_action_stream",
		})
		return
	end

	relay_teammate_sync_into_action_stream(data)

	trace_team_card_sync("remote_sync_received", {
		card_id = data and tostring(data.cardKey or "nil") or "nil",
		action_type = data and tostring(data.actionType or "nil") or "nil",
		active = is_team_card_sync_active(),
		card_data_bytes = data and type(data.cardData) == "string" and #data.cardData or 0,
	})
	if not (data and data.cardKey) then return end
	local id = data.cardKey

	if data.actionType == "removed" then
		mark_removed_card_id(id)
		return enqueue_remote_team_card_change({
			card_id = id,
			action_type = "removed",
		})
	end
	if is_removed_card_id(id) then
		trace_team_card_sync("remote_sync_ignored", {
			card_id = tostring(id),
			reason = "removed_card_id",
		})
		return
	end

	local snapshot = decode_snapshot_data(data.cardData)
	if not snapshot then
		trace_team_card_sync("remote_sync_ignored", {
			card_id = tostring(id),
			reason = "decode_failed",
			card_data_bytes = type(data.cardData) == "string" and #data.cardData or 0,
		})
		return
	end

	return enqueue_remote_team_card_change({
		card_id = id,
		action_type = "sync",
		snapshot = snapshot,
	})
end

-- ============================================================================
-- 4. Pending Remote Changes Queue (from team_card_sync_pending.lua)
-- ============================================================================
if team_card_sync._pending_loaded then
	return
end
team_card_sync._pending_loaded = true


local TEAM_CARD_REMOTE_APPLY_RETRY_DELAY = 0.1

local function create_change_queue()
	local queue = {
		by_id = {},
		order = {},
		flush_scheduled = false,
	}

	function queue.remember(change)
		if not (change and change.card_id and change.action_type) then
			return false
		end

		local card_id = tostring(change.card_id)
		if not queue.by_id[card_id] then
			queue.order[#queue.order + 1] = card_id
		end
		queue.by_id[card_id] = change
		return true
	end

	function queue.has_changes()
		return #queue.order > 0
	end

	function queue.take_all()
		local changes = {}
		for _, card_id in ipairs(queue.order) do
			local change = queue.by_id[card_id]
			if change then
				changes[#changes + 1] = change
				queue.by_id[card_id] = nil
			end
		end

		queue.order = {}
		queue.flush_scheduled = false
		return changes
	end

	function queue.clear()
		queue.by_id = {}
		queue.order = {}
		queue.flush_scheduled = false
	end

	return queue
end

local pending_queue = create_change_queue()
local startup_queue = create_change_queue()

local function is_team_card_sync_active()
	return team_card_sync.is_sync_active and team_card_sync.is_sync_active()
end

local function is_multiplayer_match_active()
	return MP.is_lobby_match_in_progress and MP.is_lobby_match_in_progress()
end

local function apply_remote_team_card_changes_now(changes, options)
	if team_card_sync.apply_remote_changes_now then
		return team_card_sync.apply_remote_changes_now(changes, options)
	end

	return 0
end

local function is_local_hand_resolution_active()
	local play_area = (G and G.play or nil)
	if play_area and type(play_area.cards) == "table" and #play_area.cards > 0 then
		return true
	end

	local states = (G and G.STATES) or nil
	local state = (G and G.STATE) or nil
	local hand_area = (G and G.hand or nil)
	local highlighted = hand_area and hand_area.highlighted or nil
	return states and state == states.HAND_PLAYED and type(highlighted) == "table" and #highlighted > 0
end

local function schedule_pending_remote_flush()
	if pending_queue.flush_scheduled or not BALATRO.queue_event then
		return false
	end

	pending_queue.flush_scheduled = true
	return BALATRO.queue_event({
		trigger = "after",
		delay = TEAM_CARD_REMOTE_APPLY_RETRY_DELAY,
		func = function()
			pending_queue.flush_scheduled = false
			team_card_sync.flush_pending_remote_changes()
			return true
		end,
	})
end

local function schedule_startup_remote_flush()
	if startup_queue.flush_scheduled or not BALATRO.queue_event then
		return false
	end

	startup_queue.flush_scheduled = true
	return BALATRO.queue_event({
		trigger = "after",
		delay = TEAM_CARD_REMOTE_APPLY_RETRY_DELAY,
		func = function()
			startup_queue.flush_scheduled = false
			team_card_sync.flush_startup_remote_changes()
			return true
		end,
	})
end

local function queue_played_hand_remote_change_animation(changes, on_complete)
	if team_card_sync.queue_played_hand_remote_change_animation then
		return team_card_sync.queue_played_hand_remote_change_animation(changes, on_complete)
	end

	return false
end

function team_card_sync.has_pending_remote_changes()
	return pending_queue.has_changes()
end

function team_card_sync.has_startup_remote_changes()
	return startup_queue.has_changes()
end

function team_card_sync.clear_pending_remote_changes()
	pending_queue.clear()
	startup_queue.clear()
end

function team_card_sync.defer_remote_change_until_active(change)
	if not startup_queue.remember(change) then
		return false
	end

	schedule_startup_remote_flush()
	return true
end

function team_card_sync.defer_remote_change(change)
	if not is_local_hand_resolution_active() then
		return false
	end

	pending_queue.remember(change)
	schedule_pending_remote_flush()
	return true
end

function team_card_sync.flush_startup_remote_changes()
	if not startup_queue.has_changes() then
		return false
	end
	if not is_team_card_sync_active() then
		if not is_multiplayer_match_active() then
			startup_queue.take_all()
			return false
		end
		schedule_startup_remote_flush()
		return false
	end

	local changes = startup_queue.take_all()
	local applied_count = apply_remote_team_card_changes_now(changes, { force = true })
	return applied_count > 0
end

function team_card_sync.flush_pending_remote_changes(options)
	if not pending_queue.has_changes() then
		return false
	end
	if not is_team_card_sync_active() then
		pending_queue.take_all()
		return false
	end
	if not (options and options.force) and is_local_hand_resolution_active() then
		schedule_pending_remote_flush()
		return false
	end

	local changes = pending_queue.take_all()
	local applied_count = apply_remote_team_card_changes_now(changes, options)
	return applied_count > 0
end

function team_card_sync.animate_pending_remote_changes_for_played_hand(on_complete)
	if not pending_queue.has_changes() then
		return false
	end
	if not is_team_card_sync_active() then
		pending_queue.take_all()
		return false
	end
	if not BALATRO.queue_event then
		team_card_sync.flush_pending_remote_changes({
			force = true,
			from_play_flush = true,
		})
		return false
	end

	local changes = pending_queue.take_all()
	if not queue_played_hand_remote_change_animation(changes, on_complete) then
		apply_remote_team_card_changes_now(changes, {
			force = true,
			from_play_flush = true,
		})
		return false
	end

	return true
end

-- ============================================================================
-- 5. Card Sync Animations (from team_card_sync_animation.lua)
-- ============================================================================
if team_card_sync._animation_loaded then
	return
end
team_card_sync._animation_loaded = true


local function get_card_by_id(...) return team_card_sync.get_card_by_id(...) end

local function apply_remote_team_card_changes_now(changes, options)
	if team_card_sync.apply_remote_changes_now then
		return team_card_sync.apply_remote_changes_now(changes, options)
	end

	return 0
end

local function is_card_in_play_area(card)
	return team_card_sync.is_card_in_play_area and team_card_sync.is_card_in_play_area(card)
end

local function is_live_card(card)
	return card and not (card.removed or card.destroyed or card.shattered or card.dissolve)
end

local function refresh_card_sprites_after_remote_animation(card)
	if not card then
		return
	end
	if card.config and card.config.center and type(card.set_sprites) == "function" then
		card:set_sprites(card.config.center)
	end
	if card.ability and type(card.should_hide_front) == "function" then
		card.front_hidden = card:should_hide_front()
	end
end

local function queue_card_flip_event(card, delay_seconds, sound_key, sound_percent, sound_volume)
	return BALATRO.queue_event({
		trigger = "after",
		delay = delay_seconds,
		func = function()
			if is_live_card(card) and type(card.flip) == "function" then
				card:flip()
				BALATRO.play_sound(sound_key, sound_percent, sound_volume)
				if card.juice_up then
					card:juice_up(0.3, 0.3)
				end
				if sound_key == "tarot2" then
					refresh_card_sprites_after_remote_animation(card)
				end
			end
			return true
		end,
	})
end

local function collect_played_hand_animation_cards(changes)
	local cards = {}
	local seen = {}
	local has_played_card_change = false

	for _, change in ipairs(changes) do
		local card = get_card_by_id(change.card_id)
		if is_card_in_play_area(card) then
			has_played_card_change = true
			if change.action_type ~= "removed" and not seen[card] then
				seen[card] = true
				cards[#cards + 1] = card
			end
		end
	end

	return cards, has_played_card_change
end

local function queue_remote_play_flush_apply(changes)
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.1,
		func = function()
			apply_remote_team_card_changes_now(changes, {
				force = true,
				from_play_flush = true,
			})
			return true
		end,
	})
end

local function queue_unhighlight_after_remote_animation()
	BALATRO.queue_event({
		trigger = "after",
		delay = 0.2,
		func = function()
			BALATRO.unhighlight_hand()
			return true
		end,
	})
end

local function queue_animation_complete(on_complete)
	BALATRO.queue_event({
		trigger = "after",
		delay = 0,
		func = function()
			if type(on_complete) == "function" then
				on_complete()
			end
			return true
		end,
	})
end

function team_card_sync.queue_played_hand_remote_change_animation(changes, on_complete)
	if not BALATRO.queue_event then
		return false
	end

	local cards_to_flip, has_played_card_change = collect_played_hand_animation_cards(changes)
	if not has_played_card_change then
		return false
	end

	for i = 1, #cards_to_flip do
		local percent = 1.15 - (i - 0.999) / (#cards_to_flip - 0.998) * 0.3
		queue_card_flip_event(cards_to_flip[i], 0.15, "card1", percent)
	end

	if #cards_to_flip > 0 then
		BALATRO.delay(0.2)
	end

	queue_remote_play_flush_apply(changes)

	for i = 1, #cards_to_flip do
		local percent = 0.85 + (i - 0.999) / (#cards_to_flip - 0.998) * 0.3
		queue_card_flip_event(cards_to_flip[i], 0.15, "tarot2", percent, 0.6)
	end

	queue_unhighlight_after_remote_animation()
	BALATRO.delay(0.5)
	queue_animation_complete(on_complete)
	return true
end

-- ============================================================================
-- 6. Team Card Restore & Run Setup (from team_card_sync_restore.lua)
-- ============================================================================
if team_card_sync._restore_loaded then
	return
end
team_card_sync._restore_loaded = true


local function get_card_id_suffix(...) return team_card_sync.get_card_id_suffix(...) end
local function mark_card_ready_for_team_sync(...) return team_card_sync.mark_card_ready_for_team_sync(...) end
local function finalize_team_card_setup(...) return team_card_sync.finalize_team_card_setup(...) end
local function assign_initial_team_card_ids(...) return team_card_sync.assign_initial_team_card_ids(...) end

local function get_playing_cards()
	return (G and G.playing_cards) or nil
end

local function get_playing_cards_or_empty()
	return get_playing_cards() or {}
end

local function get_local_card_id_prefix()
	return (G and G.MP_ID or nil) or "LOCAL"
end

local function is_valid_card_id(card_id)
	return type(card_id) == "string" and card_id ~= ""
end

local function normalize_card_id(card_id)
	return is_valid_card_id(card_id) and card_id or nil
end

local function advance_next_card_id_from_card(card, next_card_id)
	local suffix = get_card_id_suffix(card and card.mp_card_id)
	if suffix and suffix >= next_card_id then
		return suffix + 1
	end

	return next_card_id
end

local function get_saved_card_id(pending_restore, card_ids_by_playing_card, card, index)
	if card_ids_by_playing_card and card.playing_card ~= nil then
		local saved_id = card_ids_by_playing_card[tostring(card.playing_card)]
		if saved_id ~= nil then
			return saved_id
		end
	end

	return pending_restore.card_ids[index]
end

local function assign_missing_card_ids(cards, prefix, next_card_id)
	for _, card in ipairs(cards) do
		if not is_valid_card_id(card.mp_card_id) then
			mark_card_ready_for_team_sync(card, prefix .. "_" .. next_card_id)
			next_card_id = next_card_id + 1
		end
	end

	return next_card_id
end

local function scan_existing_card_ids(cards)
	local has_existing_ids = false
	local next_card_id = 0

	for _, card in ipairs(cards) do
		if is_valid_card_id(card.mp_card_id) then
			has_existing_ids = true
			next_card_id = advance_next_card_id_from_card(card, next_card_id)
		end
	end

	return has_existing_ids, next_card_id
end

function team_card_sync.get_pending_team_card_restore_state()
	return MP.RESUME
		and MP.RESUME.get_pending_team_card_restore
		and MP.RESUME.get_pending_team_card_restore()
		or nil
end

function team_card_sync.restore_team_card_ids_from_pending_state(pending_restore)
	if not (type(pending_restore) == "table" and type(pending_restore.card_ids) == "table") then
		return false
	end

	local cards = get_playing_cards_or_empty()
	local next_card_id = tonumber(pending_restore.next_card_id) or 0
	local card_ids_by_playing_card = type(pending_restore.card_ids_by_playing_card) == "table"
		and pending_restore.card_ids_by_playing_card
		or nil

	for index, card in ipairs(cards) do
		local saved_id = get_saved_card_id(pending_restore, card_ids_by_playing_card, card, index)
		mark_card_ready_for_team_sync(card, normalize_card_id(saved_id))
		next_card_id = advance_next_card_id_from_card(card, next_card_id)
	end

	next_card_id = assign_missing_card_ids(cards, get_local_card_id_prefix(), next_card_id)

	finalize_team_card_setup(next_card_id)
	return true
end

function team_card_sync.ensure_team_card_ids_for_existing_run()
	local cards = get_playing_cards_or_empty()
	local has_existing_ids, next_card_id = scan_existing_card_ids(cards)

	-- Same rule as assign_initial_team_card_ids: any lobby run uses the
	-- deterministic TEAM prefix so spectator boards can match card ids.
	local in_lobby = not not (MP.LOBBY and MP.LOBBY.code)
	local prefix = (in_lobby and not has_existing_ids) and "TEAM"
		or get_local_card_id_prefix()

	for index, card in ipairs(cards) do
		local resolved_id = card.mp_card_id
		if not is_valid_card_id(resolved_id) then
			if in_lobby and not has_existing_ids then
				resolved_id = "TEAM_" .. (index - 1)
				if index > next_card_id then
					next_card_id = index
				end
			else
				resolved_id = prefix .. "_" .. next_card_id
				next_card_id = next_card_id + 1
			end
		end

		mark_card_ready_for_team_sync(card, resolved_id)
	end

	finalize_team_card_setup(next_card_id)
end

function team_card_sync.setup(preserve_existing_ids)
	if not get_playing_cards() then
		return
	end

	if MP.MATCH_LIFECYCLE and MP.MATCH_LIFECYCLE.resume_team_card_sync then
		MP.MATCH_LIFECYCLE.resume_team_card_sync()
	end
	if team_card_sync.clear_removed_card_ids then
		team_card_sync.clear_removed_card_ids()
	end

	if not preserve_existing_ids then
		assign_initial_team_card_ids()
		return
	end

	local pending_restore = team_card_sync.get_pending_team_card_restore_state()
	if team_card_sync.restore_team_card_ids_from_pending_state(pending_restore) then
		return
	end

	team_card_sync.ensure_team_card_ids_for_existing_run()
end

return team_card_sync
