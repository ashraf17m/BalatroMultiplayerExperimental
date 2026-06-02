return [[
local CONFIG_URL, CONFIG_PORT = ...

require("love.filesystem")
local socket = require("socket")

local Networking = {}
local isSocketClosed = true
local networkToUiChannel = love.thread.getChannel("networkToUi")
local uiToNetworkChannel = love.thread.getChannel("uiToNetwork")

local maxReconnectAttempts = 3
local reconnectDelays = { 2, 4, 8 }
local reconnectAttempt = 0
local isReconnecting = false
local reconnectTimer = 0
local sendToServer
local beginReconnect

local keepAliveInitialTimeout = 20
local keepAliveRetryTimeout = 5
local keepAliveRetryCount = 4
local maxOutgoingBufferBytes = 262144

local isRetry = false
local retryCount = 0
local networkBuffer = ""
local outgoingBuffer = ""
local RECONNECTING_ACTION = '{"action":"reconnecting"}'
local DISCONNECTED_ACTION = '{"action":"disconnected"}'

local function pushNetworkUiPayload(payload)
	if payload ~= nil then
		networkToUiChannel:push(payload)
	end
end

local json_string_replacements = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function encodeJsonString(value)
	return '"' .. string.gsub(tostring(value or ""), '[%z\1-\31\\"]', function(char)
		return json_string_replacements[char] or string.format("\\u%04x", string.byte(char))
	end) .. '"'
end

local function pushNetworkUiAction(action, message)
	return pushNetworkUiPayload(
		'{"action":'
			.. encodeJsonString(action)
			.. ',"message":'
			.. encodeJsonString(message)
			.. "}"
	)
end

local function pushReconnectAction()
	return pushNetworkUiPayload(RECONNECTING_ACTION)
end

local function pushDisconnectedAction()
	return pushNetworkUiPayload(DISCONNECTED_ACTION)
end

local function closeNetworkingClient()
	if Networking.Client and Networking.Client.close then
		pcall(function()
			Networking.Client:close()
		end)
	end
	Networking.Client = nil
	isSocketClosed = true
end

local function trimSentOutgoingBytes(sentCount)
	sentCount = tonumber(sentCount) or 0
	if sentCount <= 0 then return end

	if sentCount >= #outgoingBuffer then
		outgoingBuffer = ""
	else
		outgoingBuffer = string.sub(outgoingBuffer, sentCount + 1)
	end
end

local function flushServerOutgoingBuffer()
	if outgoingBuffer == "" then return true end
	if not Networking.Client or isSocketClosed then return false end

	local sent, errorMessage, partial = Networking.Client:send(outgoingBuffer)
	if sent then
		trimSentOutgoingBytes(sent)
		return outgoingBuffer == ""
	end

	trimSentOutgoingBytes(partial)

	if errorMessage == "timeout" then
		return false
	end

	if errorMessage == "closed" then
		beginReconnect()
	end

	return false
end

function Networking.connect()
	if Networking.Client and not isSocketClosed then
		return true
	end

	local client = socket.tcp()
	if not client then
		return false
	end

	Networking.Client = client
	Networking.Client:settimeout(10)
	Networking.Client:setoption("tcp-nodelay", true)

	local connectionResult = Networking.Client:connect(CONFIG_URL, CONFIG_PORT)

	if connectionResult ~= 1 then
		closeNetworkingClient()
		return false
	end

	isSocketClosed = false
	isReconnecting = false
	reconnectAttempt = 0
	Networking.Client:settimeout(0)
	return true
end

local timer = function(time)
	local init = os.time()
	local diff = os.difftime(os.time(), init)
	while diff < time do
		coroutine.yield(diff)
		diff = os.difftime(os.time(), init)
	end
end
local timerCoroutine = coroutine.create(timer)

beginReconnect = function()
	closeNetworkingClient()
	retryCount = 0
	isRetry = false
	timerCoroutine = coroutine.create(timer)
	networkBuffer = ""
	outgoingBuffer = ""

	pushReconnectAction()

	isReconnecting = true
	reconnectAttempt = 0
	reconnectTimer = 0
end

sendToServer = function(message)
	if not Networking.Client or isSocketClosed then return false end
	if message and message ~= "" then
		if (#outgoingBuffer + #message) > maxOutgoingBufferBytes then
			beginReconnect()
			return false
		end

		outgoingBuffer = outgoingBuffer .. message
	end

	return flushServerOutgoingBuffer()
end
]]
