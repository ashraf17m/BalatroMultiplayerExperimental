local function normalize_protocol_payload(payload)
	if type(payload) == "table" then
		return payload
	end

	return {}
end

function MP.PROTOCOL.decode_v2_packet(packet)
	if type(packet) ~= "table" then
		return nil, "Protocol v2 packet must be a table."
	end

	if not MP.PROTOCOL.is_supported_version(packet.version) then
		return nil, "Unsupported protocol version."
	end

	local family = tostring(packet.family or "")
	if not MP.PROTOCOL.is_known_family(family) then
		return nil, "Unknown protocol family."
	end

	local action = tostring(packet.action or "")
	if action == "" then
		return nil, "Protocol action is required."
	end

	local schema_id = tostring(packet.schemaId or packet.schema_id or "")
	if schema_id == "" then
		schema_id = MP.PROTOCOL.get_schema_id(family, action) or ""
	end
	if schema_id == "" then
		return nil, "Protocol schema id is required."
	end

	return {
		version = MP.PROTOCOL.VERSION,
		family = family,
		action = action,
		schema_id = schema_id,
		payload = normalize_protocol_payload(packet.payload),
		flags = MP.PROTOCOL.get_schema_flags(schema_id) or {},
	}
end
