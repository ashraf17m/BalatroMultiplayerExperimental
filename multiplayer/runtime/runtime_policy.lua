MP.RUNTIME_POLICY = {
	client = {
		version = tostring(MP.version or ""),
	},
	lovely = {
		minimum_version = "0.9",
	},
}

local BALATRO = MP.PLATFORM and MP.PLATFORM.BALATRO or nil

-- Player ID is assigned by the server and must be set before any game actions.
-- If nil, it indicates a connection/initialization failure.
if BALATRO and BALATRO.clear_player_id then
	BALATRO.clear_player_id()
end
