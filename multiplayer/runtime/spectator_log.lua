-- Diagnostic log for spectator last-hand / switch bugs. Observation only.
-- Writes %APPDATA%/Balatro/mp_spectator.log (Love save directory).

MP.SPECTATOR_LOG = MP.SPECTATOR_LOG or {}
local LOG = MP.SPECTATOR_LOG
local FILE = "mp_spectator.log"
local MAX_BYTES = 2 * 1024 * 1024
local printed_path = false

local function state_name()
	if not (G and G.STATE and G.STATES) then
		return "?"
	end
	for k, v in pairs(G.STATES) do
		if v == G.STATE then
			return tostring(k)
		end
	end
	return tostring(G.STATE)
end

local function pending_summary()
	local spec = MP.SPECTATOR
	if not spec then
		return "none"
	end
	local kinds = {}
	for _, entry in ipairs(spec.pending_replay_queue or {}) do
		kinds[#kinds + 1] = tostring(entry.type)
	end
	local catch = {}
	for _, entry in ipairs(spec.pending_actions or {}) do
		catch[#catch + 1] = tostring(entry.type)
	end
	return string.format(
		"replay=%d[%s] catchup_buf=%d[%s]",
		#(spec.pending_replay_queue or {}),
		table.concat(kinds, ","),
		#(spec.pending_actions or {}),
		table.concat(catch, ",")
	)
end

function LOG.snapshot_fields()
	local spec = MP.SPECTATOR or {}
	local round = G and G.GAME and G.GAME.current_round
	return {
		state = state_name(),
		hands_left = round and tonumber(round.hands_left),
		hands_played = round and tonumber(round.hands_played),
		play = G and G.play and G.play.cards and #G.play.cards or 0,
		hand = G and G.hand and G.hand.cards and #G.hand.cards or 0,
		step = spec.current_step,
		catchup = not not spec.is_catching_up,
		end_pvp = not not (MP.GAME and MP.GAME.end_pvp),
		stop_use = G and G.GAME and tonumber(G.GAME.STOP_USE) or 0,
		pvp = not not (MP.is_pvp_boss and MP.is_pvp_boss()),
		chips = G and G.GAME and tostring(G.GAME.chips or ""),
		pending = pending_summary(),
		target = spec.target_player_id and tostring(spec.target_player_id):sub(1, 8) or "",
	}
end

function LOG.emit(event, extra)
	local fields = LOG.snapshot_fields()
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			fields[key] = value
		end
	elseif extra ~= nil then
		fields.detail = tostring(extra)
	end

	local parts = { "[spectator]", tostring(event or "event") }
	local keys = {}
	for key, _ in pairs(fields) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		parts[#parts + 1] = tostring(key) .. "=" .. tostring(fields[key])
	end
	local line = table.concat(parts, " ")

	print(line)

	if not (love and love.filesystem and love.filesystem.append) then
		return
	end
	if love.filesystem.getInfo then
		local ok, info = pcall(love.filesystem.getInfo, FILE)
		if ok and info and tonumber(info.size) and tonumber(info.size) > MAX_BYTES then
			pcall(love.filesystem.remove, FILE)
		end
	end
	pcall(love.filesystem.append, FILE, line .. "\n")
	if not printed_path and love.filesystem.getSaveDirectory then
		printed_path = true
		print("[spectator] log file=" .. tostring(love.filesystem.getSaveDirectory()) .. "/" .. FILE)
	end
end
