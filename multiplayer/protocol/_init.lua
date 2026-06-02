MP.PROTOCOL = MP.PROTOCOL or {}

function MP.PROTOCOL.build_route_key(family, action, schema_id)
	return string.format("%s:%s:%s", tostring(family or ""), tostring(action or ""), tostring(schema_id or ""))
end

function MP.PROTOCOL.build_route_key_from_message(message)
	message = message or {}
	return MP.PROTOCOL.build_route_key(message.family, message.action, message.schema_id or message.schemaId)
end

function MP.PROTOCOL.try_finite_number(value)
	local numeric_value = tonumber(value) or tonumber(tostring(value))
	if numeric_value == nil
		or numeric_value ~= numeric_value
		or numeric_value == math.huge
		or numeric_value == -math.huge then
		return nil
	end
	return numeric_value
end

function MP.PROTOCOL.to_finite_number(value, fallback)
	local numeric_value = MP.PROTOCOL.try_finite_number(value)
	if numeric_value == nil then
		return fallback or 0
	end
	return numeric_value
end

function MP.PROTOCOL.try_trunc_number(value)
	local numeric_value = MP.PROTOCOL.try_finite_number(value)
	if numeric_value == nil then
		return nil
	end
	if numeric_value < 0 then
		return math.ceil(numeric_value)
	end
	return math.floor(numeric_value)
end

function MP.PROTOCOL.trunc_number(value)
	return MP.PROTOCOL.try_trunc_number(value) or 0
end

function MP.PROTOCOL.normalize_non_negative_integer(value)
	return math.max(0, math.floor(MP.PROTOCOL.to_finite_number(value, 0)))
end
