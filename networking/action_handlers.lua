local json = require("json")

Client = {}
local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or nil
local is_runtime_trace_enabled = (MP.UTILS and MP.UTILS.is_runtime_trace_enabled) or function() return false end

local function push_ui_to_network(encoded_message)
	if BALATRO and type(BALATRO.push_thread_channel) == "function" then
		return BALATRO.push_thread_channel("uiToNetwork", encoded_message)
	end

	return false
end

local function describe_send_caller()
	if not (debug and debug.getinfo) then
		return "unknown caller"
	end

	local info = debug.getinfo(3, "Sl")
	if not info then
		return "unknown caller"
	end

	return string.format("%s:%s", tostring(info.short_src or info.source or "unknown"), tostring(info.currentline or "?"))
end

local function preview_string(value)
	local text = tostring(value or "")
	if #text > 80 then
		return string.sub(text, 1, 77) .. "..."
	end

	return text
end

local function decode_preencoded_message(encoded_message)
	if type(encoded_message) ~= "string" or type(json.decode) ~= "function" then
		return nil
	end

	local ok, decoded = pcall(json.decode, encoded_message)
	if not ok or type(decoded) ~= "table" then
		return nil
	end

	if decoded.action == nil and decoded.family == nil then
		return nil
	end

	return decoded
end

function Client.queue_send(msg)
	if type(msg) ~= "table" then
		local caller = describe_send_caller()
		if type(msg) == "string" then
			local decoded = decode_preencoded_message(msg)
			if decoded then
				if decoded.action ~= "keepAliveAck" and is_runtime_trace_enabled() and sendTraceMessage then
					sendTraceMessage(string.format("Client queued pre-encoded message: %s", msg), "MULTIPLAYER")
				end
				return push_ui_to_network(msg)
			end

			if sendTraceMessage then
				sendTraceMessage(
					"Skipped non-packet multiplayer string from "
						.. caller
						.. ": "
						.. preview_string(msg),
					"MULTIPLAYER"
				)
			end
		elseif msg == nil then
			if sendTraceMessage then
				sendTraceMessage("Skipped empty multiplayer message from " .. caller, "MULTIPLAYER")
			end
		elseif sendWarnMessage then
			sendWarnMessage(
				"Refused to send malformed multiplayer message from "
					.. caller
					.. " ("
					.. type(msg)
					.. ").",
				"MULTIPLAYER"
			)
		end
		return false
	end

	local encoded_message = json.encode(msg)
	if not encoded_message then
		return false
	end

	if encoded_message ~= '{"action":"keepAliveAck"}' and is_runtime_trace_enabled() and sendTraceMessage then
		sendTraceMessage(string.format("Client queued message: %s", encoded_message), "MULTIPLAYER")
	end

	return push_ui_to_network(encoded_message)
end

-- Returns true only when the packet was queued for the socket thread.
-- It does not mean the server received or accepted the message.
function Client.send(msg)
	return Client.queue_send(msg)
end
