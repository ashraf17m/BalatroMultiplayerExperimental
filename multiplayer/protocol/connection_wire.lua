MP.CONNECTION_WIRE = MP.CONNECTION_WIRE or {}

local function build_system_packet(action_name, payload)
	return MP.PROTOCOL.build_v2_packet_for_schema("system", "hello", action_name, payload)
end

local function normalize_blind_col(blind_col)
	if MP.UTILS and MP.UTILS.clamp_blind_col then
		return MP.UTILS.clamp_blind_col(blind_col)
	end
	local numeric_blind_col = tonumber(blind_col) or tonumber(tostring(blind_col)) or 1
	if numeric_blind_col ~= numeric_blind_col
		or numeric_blind_col == math.huge
		or numeric_blind_col == -math.huge then
		numeric_blind_col = 1
	end
	return math.max(1, math.floor(numeric_blind_col))
end

function MP.CONNECTION_WIRE.build_connect_payload()
	return {
		action = "connect",
	}
end

function MP.CONNECTION_WIRE.build_identity_payload(username, blind_col, mod_hash)
	return build_system_packet("identity", {
		username = username,
		blindCol = normalize_blind_col(blind_col),
		modHash = mod_hash,
	})
end

function MP.CONNECTION_WIRE.build_rejoin_payload(code, reconnect_token)
	return build_system_packet("rejoin", {
		code = code,
		reconnectToken = reconnect_token,
	})
end

function MP.CONNECTION_WIRE.build_keep_alive_ack_payload()
	return {
		action = "keepAliveAck",
	}
end
