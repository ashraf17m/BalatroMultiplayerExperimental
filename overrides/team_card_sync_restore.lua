local build_traceback = MP.UTILS.build_traceback
local team_card_sync = MP.SYNC and MP.SYNC.TEAM_CARD or {}

local game_start_run_ref = Game.start_run

local function run_game_start_run(self, args)
	if args and args.mp_resume and MP.RESUME and MP.RESUME.run_with_start_run_log_filter then
		return MP.RESUME.run_with_start_run_log_filter(function()
			return game_start_run_ref(self, args)
		end)
	end

	return game_start_run_ref(self, args)
end

function Game:start_run(args)
	MP.TEAM_CARD_INITIALIZING = true
	local ok, err = xpcall(function()
		run_game_start_run(self, args)

		if G.GAME then
			G.GAME.mp_card_next_id = 0
		end
		if team_card_sync.setup then
			team_card_sync.setup(args and args.mp_resume)
		end
	end, build_traceback)

	MP.TEAM_CARD_INITIALIZING = false
	if not ok then
		error(err, 0)
	end

	if MP.RESUME and MP.RESUME.on_game_start_run then
		MP.RESUME.on_game_start_run(args)
	end
end
