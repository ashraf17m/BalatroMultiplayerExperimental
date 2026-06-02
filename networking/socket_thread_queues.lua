return [[
local mainThreadMessageQueue = function()
	local requestsPerCycle = 25
	while true do
		for _ = 1, requestsPerCycle do
			local msg = uiToNetworkChannel:pop()
			if msg then
				if msg == "{\"action\":\"connect\"}" then
					Networking.connect()
				else
					sendToServer(msg .. "\n")
				end
			else
				coroutine.yield()
			end
		end

		coroutine.yield()
	end
end
local mainThreadCoroutine = coroutine.create(mainThreadMessageQueue)

local networkPacketQueue = function()
	local packetsPerCycle = 25
	while true do
		if Networking.Client and not isSocketClosed then
			for _ = 1, packetsPerCycle do
				local data, error, partial = Networking.Client:receive("*a")

				if (data or partial) and (data ~= "" or partial ~= "") then
					local chunk = data or partial
					networkBuffer = networkBuffer .. chunk

					while true do
						local newlinePos = string.find(networkBuffer, "\n")
						if not newlinePos then break end

						local line = string.sub(networkBuffer, 1, newlinePos - 1)
						networkBuffer = string.sub(networkBuffer, newlinePos + 1)

						if line ~= "" then
							isRetry = false
							retryCount = 0
							timerCoroutine = coroutine.create(timer)

							if string.find(line, '"keepAlive"') and not string.find(line, 'Ack') then
								sendToServer('{"action":"keepAliveAck"}\n')
							end

							networkToUiChannel:push(line)
						end
					end
				elseif error == "closed" then
					beginReconnect()
					break
				else
					coroutine.yield()
				end
			end

			coroutine.yield()
		end

		coroutine.yield()
	end
end
local networkCoroutine = coroutine.create(networkPacketQueue)
]]
