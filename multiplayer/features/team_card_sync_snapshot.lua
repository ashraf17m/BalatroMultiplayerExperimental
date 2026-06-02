MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync

if team_card_sync._snapshot_loaded then
	return
end
team_card_sync._snapshot_loaded = true

local ok_json, json = pcall(require, "json")
if not ok_json then json = rawget(_G, "json") end
local BALATRO = MP.PLATFORM.BALATRO

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

local ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY = {
	"discarded",
	"forced_selection",
	"played_this_ante",
	"wheel_flipped",
	"delay_seal",
	"debuff_sources",
	"extra_enhancement",
}

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

local function get_card_center_key(card)
	local key = card and card.config and (
		card.config.center_key
		or (card.config.center and card.config.center.key)
	)
	if type(key) == "string" and key ~= "" and BALATRO.get_center(key) then
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

local function canonical_string(value)
	if json and type(json.encode) == "function" then
		local ok, encoded = pcall(json.encode, value)
		if ok and type(encoded) == "string" then
			return encoded
		end
	end
	return string.format("%q", value)
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
canonical_encode_value = function(value)
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
		keys[#keys + 1] = key
	end
	table.sort(keys, canonical_key_less)

	local parts = {}
	for _, key in ipairs(keys) do
		local encoded_value = canonical_encode_value(value[key])
		if encoded_value ~= nil then
			parts[#parts + 1] = type(key) .. ":" .. canonical_encode_value(key) .. "=" .. encoded_value
		end
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function strip_local_ability_runtime_state(ability)
	if type(ability) ~= "table" then return end

	for _, key in ipairs(ABILITY_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		ability[key] = nil
	end

	for key in pairs(ability) do
		if is_prefixed_local_ability_runtime_field(key) then
			ability[key] = nil
		end
	end
end

local function strip_local_card_save_state(card_save)
	if type(card_save) ~= "table" then return end

	for _, key in ipairs(CARD_RUNTIME_FIELDS_PRESERVED_LOCALLY) do
		card_save[key] = nil
	end
	for key in pairs(card_save) do
		if is_never_synced_card_save_field(key) then
			card_save[key] = nil
		end
	end

	if type(card_save.base) == "table" then
		card_save.base.times_played = nil
	end

	strip_local_ability_runtime_state(card_save.ability)
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
	if not (type(front_key) == "string" and BALATRO.get_card_front(front_key)) then
		front_key = get_card_front_key(card)
	end
	if not (type(front_key) == "string" and BALATRO.get_card_front(front_key)) then
		return nil
	end
	sanitized.save_fields.card = front_key

	local center_key = sanitized.save_fields.center
	if not (type(center_key) == "string" and BALATRO.get_center(center_key)) then
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
		and BALATRO.get_center(center_key)
		and BALATRO.get_card_front(front_key)
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
		if type(front_key) == "string" and BALATRO.get_card_front(front_key) then
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
		if type(center_key) == "string" and BALATRO.get_center(center_key) then
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
	if not snapshot then
		return nil
	end

	local state = { seen = {}, nodes_left = MAX_SAFE_NODES }
	local comparable = safe_clone_value(snapshot, 1, state)
	if type(comparable) ~= "table" then
		return nil
	end

	if comparable.v == TEAM_CARD_SNAPSHOT_VERSION then
		strip_local_card_save_state(comparable.cs)
	end

	local encoded = canonical_encode_value(comparable)
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

	local front = BALATRO.get_card_front(team_card_sync.snapshot_to_base_key(snapshot))
	local center = BALATRO.get_center(team_card_sync.snapshot_to_center_key(snapshot))
		or BALATRO.get_center("c_base")
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
	local playing_cards = BALATRO.get_playing_cards()
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
