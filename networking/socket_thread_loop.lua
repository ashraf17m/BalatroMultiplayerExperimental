return [[
local mainThreadCoroutineFailed = false
local networkCoroutineFailed = false

local function reportCoroutineFailure(name, err)
	local message = string.format("%s coroutine failed: %s", name, tostring(err))
	pushNetworkUiAction("error", message)
end

local function resumeThreadCoroutine(name, coroutineRef, alreadyFailed)
	if alreadyFailed then
		return true
	end

	local ok, err = coroutine.resume(coroutineRef)
	if not ok then
		reportCoroutineFailure(name, err)
		return true
	end

	return false
end

while true do
	mainThreadCoroutineFailed = resumeThreadCoroutine("ui-to-network", mainThreadCoroutine, mainThreadCoroutineFailed)
	networkCoroutineFailed = resumeThreadCoroutine("network-to-ui", networkCoroutine, networkCoroutineFailed)

	if not isSocketClosed then
		flushServerOutgoingBuffer()
	end

	if isReconnecting then
		reconnectTimer = reconnectTimer - 0.05
		if reconnectTimer <= 0 then
			reconnectAttempt = reconnectAttempt + 1
			if reconnectAttempt <= maxReconnectAttempts then
				local delay = reconnectDelays[reconnectAttempt] or reconnectDelays[#reconnectDelays]

				if not Networking.connect() then
					reconnectTimer = delay
				end
			else
				isReconnecting = false
				pushDisconnectedAction()
			end
		end
	end

	if not isSocketClosed and coroutine.status(timerCoroutine) ~= "dead" then
		coroutine.resume(timerCoroutine, keepAliveInitialTimeout)
	elseif not isSocketClosed then
		isRetry = true

		if retryCount > keepAliveRetryCount then
			beginReconnect()
		end

		if isRetry then
			retryCount = retryCount + 1
			sendToServer("{\"action\":\"keepAlive\"}\n")
			timerCoroutine = coroutine.create(timer)
			coroutine.resume(timerCoroutine, keepAliveRetryTimeout)
		end
	end

	socket.sleep(0.05)
end
]]
