-- Team Card Sync for Teams Mode: load-order guard for split card-sync surfaces.

MP.SYNC = MP.SYNC or {}

local team_card_sync = MP.SYNC.TEAM_CARD or {}
MP.SYNC.TEAM_CARD = team_card_sync
MP.TEAM_CARD = team_card_sync

if team_card_sync._loaded then return end
team_card_sync._loaded = true
MP.TEAM_CARD_LOADED = true

MP.TEAM_CARD_SUSPENDED = MP.TEAM_CARD_SUSPENDED or false

local REQUIRED_TEAM_CARD_APIS = {
	"is_syncable_playing_card",
	"assign_card_id",
	"is_main_team_area",
	"mark_card_ready_for_team_sync",
	"can_relay_changes",
	"sync",
	"sync_card_list",
	"relay_removal",
}

for _, name in ipairs(REQUIRED_TEAM_CARD_APIS) do
	if not team_card_sync[name] then
		error("Team card sync API missing before hook install: " .. tostring(name))
	end
end

-- Team card host hooks now live in `overrides/team_card_sync.lua`.
