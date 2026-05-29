local SCHEMA_ID_DEFAULTS = {
	system = {
		hello = "system.hello.v2",
		hello_ack = "system.helloAck.v2",
	},
	lobby = {
		intent = "lobby.intent.v2",
		snapshot = "lobby.snapshot.v2",
	},
	match = {
		intent = "match.intent.v2",
		state = "match.state.v2",
	},
	team = {
		state = "team.state.v2",
	},
	sync = {
		state = "sync.state.v2",
	},
	endgame = {
		state = "endgame.state.v2",
	},
	feature = {
		event = "feature.event.v2",
	},
}

local function encode_v2_packet(packet)
	local decoded, err = MP.PROTOCOL.decode_v2_packet(packet)
	if not decoded then
		return nil, err
	end

	return {
		version = decoded.version,
		family = decoded.family,
		action = decoded.action,
		schemaId = decoded.schema_id,
		payload = decoded.payload,
	}
end

local function build_v2_packet_with_schema(family, action, schema_id, payload)
	return encode_v2_packet({
		version = MP.PROTOCOL.VERSION,
		family = family,
		action = action,
		schemaId = schema_id,
		payload = payload or {},
	})
end

local function get_schema_id_or_default(family, schema_action)
	local schema_id = MP.PROTOCOL.get_schema_id and MP.PROTOCOL.get_schema_id(family, schema_action) or nil
	if schema_id ~= nil then
		return schema_id
	end

	local family_defaults = SCHEMA_ID_DEFAULTS[family]
	if family_defaults == nil then
		return nil
	end

	return family_defaults[schema_action]
end

function MP.PROTOCOL.build_v2_packet_for_schema(family, schema_action, action, payload)
	return build_v2_packet_with_schema(
		family,
		action,
		get_schema_id_or_default(family, schema_action),
		payload
	)
end
