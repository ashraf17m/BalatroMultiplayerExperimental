-- Calculator V2 state signatures.
--
-- Full signatures are for exact cache reuse. Guard signatures are for deciding
-- whether an async result still belongs to the current selected hand.

MP = MP or {}
MP.CALCULATOR_V2 = MP.CALCULATOR_V2 or {}

local CALC = MP.CALCULATOR_V2

local function stable_value(value, depth, seen)
	local value_type = type(value)
	if value_type == "number" or value_type == "boolean" or value_type == "string" or value == nil then
		return tostring(value)
	end
	if value_type ~= "table" then return value_type end
	if depth <= 0 then return "{...}" end

	seen = seen or {}
	if seen[value] then return "{cycle}" end
	seen[value] = true

	local keys = {}
	for key in pairs(value) do
		local key_type = type(key)
		if key_type == "string" or key_type == "number" or key_type == "boolean" then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

	local pieces = {}
	local max_items = 32
	for i, key in ipairs(keys) do
		if i > max_items then
			pieces[#pieces + 1] = "..."
			break
		end
		pieces[#pieces + 1] = tostring(key) .. "=" .. stable_value(value[key], depth - 1, seen)
	end

	seen[value] = nil
	return "{" .. table.concat(pieces, ",") .. "}"
end

local function score_signature_value(value)
	local value_type = type(value)
	if value == nil or value_type == "number" or value_type == "boolean" or value_type == "string" then
		return tostring(value)
	end
	if value_type ~= "table" then return value_type end

	if type(value.array) == "table" then
		local pieces = { "sign=" .. tostring(value.sign) }
		local array_keys = {}
		for key in pairs(value.array) do array_keys[#array_keys + 1] = key end
		table.sort(array_keys, function(a, b)
			local left = tonumber(a)
			local right = tonumber(b)
			if left and right then return left < right end
			return tostring(a) < tostring(b)
		end)
		for _, key in ipairs(array_keys) do
			pieces[#pieces + 1] = tostring(key) .. ":" .. tostring(value.array[key])
		end
		return "omega(" .. table.concat(pieces, ",") .. ")"
	end

	if value.m ~= nil or value.e ~= nil then
		return "big(m=" .. tostring(value.m) .. ",e=" .. tostring(value.e) .. ")"
	end

	if type(number_format) == "function" then
		local ok, formatted = pcall(number_format, value)
		if ok then return tostring(formatted) end
	end
	return stable_value(value, 1)
end

local function area_cards(area)
	return area and area.cards or nil
end

local function card_identity(card)
	if not card then return "nil" end
	return tostring(card.sort_id or card.unique_val or card.ID or card)
end

local function card_identity_list_signature(label, cards)
	local pieces = { label, tostring(cards and #cards or 0) }
	if cards then
		for i, card in ipairs(cards) do
			pieces[#pieces + 1] = tostring(i) .. ":" .. card_identity(card)
		end
	end
	return table.concat(pieces, ";")
end

local function card_signature(card)
	if not card then return "nil" end

	local center = card.config and card.config.center
	local base = card.base or {}
	return table.concat({
		tostring(card.sort_id or ""),
		tostring(center and center.key or ""),
		tostring(base.id or ""),
		tostring(base.suit or ""),
		tostring(card.facing or ""),
		tostring(card.debuff or false),
		tostring(card.seal or ""),
		stable_value(card.edition, 1),
		stable_value(card.ability, 2),
	}, "|")
end

local function card_list_signature(label, cards)
	local pieces = { label, tostring(cards and #cards or 0) }
	if cards then
		for i, card in ipairs(cards) do
			pieces[#pieces + 1] = tostring(i) .. ":" .. card_signature(card)
		end
	end
	return table.concat(pieces, ";")
end

function CALC.current_request_guard_signature()
	local hand = G and G.hand or nil
	return table.concat({
		"rev=" .. tostring(CALC.cache_revision or 0),
		"state=" .. tostring(G and G.STATE or ""),
		card_identity_list_signature("highlighted", hand and hand.highlighted),
		card_identity_list_signature("hand", area_cards(hand)),
		card_identity_list_signature("jokers", area_cards(G and G.jokers)),
		card_identity_list_signature("consumeables", area_cards(G and G.consumeables)),
	}, "\n")
end

function CALC.current_signature()
	local game = G and G.GAME or {}
	local blind = game.blind or {}
	local blind_config = blind.config and blind.config.blind or {}
	local hand = G and G.hand or nil
	local parts = {
		"rev=" .. tostring(CALC.cache_revision or 0),
		"state=" .. tostring(G and G.STATE or ""),
		"dollars=" .. stable_value(game.dollars, 1),
		"probability=" .. score_signature_value(game.probabilities and game.probabilities.normal),
		"blind=key=" .. tostring(blind_config.key or blind.name or "")
			.. ";chips=" .. score_signature_value(blind.chips)
			.. ";disabled=" .. tostring(blind.disabled),
		"hands=" .. stable_value(game.hands, 2),
		card_list_signature("highlighted", hand and hand.highlighted),
		card_list_signature("hand", area_cards(hand)),
		card_list_signature("jokers", area_cards(G and G.jokers)),
		card_list_signature("consumeables", area_cards(G and G.consumeables)),
	}
	return table.concat(parts, "\n")
end
