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

local function build_connect_payload()
	return {
		action = "connect",
	}
end

local function build_identity_payload()
	return build_system_packet("identity", {
		username = MP.LOBBY.client.username,
		blindCol = normalize_blind_col(MP.LOBBY.client.blind_col),
		modHash = MP.MOD_STRING,
	})
end

function MP.CONNECTION_WIRE.send_connect()
	Client.send(build_connect_payload())
end

function MP.CONNECTION_WIRE.send_identity()
	Client.send(build_identity_payload())
end

function MP.CONNECTION_WIRE.send_rejoin(code, reconnect_token)
	Client.send(build_system_packet("rejoin", {
		code = code,
		reconnectToken = reconnect_token,
	}))
end

function MP.CONNECTION_WIRE.send_keep_alive_ack()
	Client.send({
		action = "keepAliveAck",
	})
end
