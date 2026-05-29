local expected_resume_start_run_logs = {
	["ERROR LOADING GAME: Card area 'shop_jokers' not instantiated before load"] = "shop_jokers",
	["ERROR LOADING GAME: Card area 'shop_booster' not instantiated before load"] = "shop_booster",
	["ERROR LOADING GAME: Card area 'shop_vouchers' not instantiated before load"] = "shop_vouchers",
}

local build_traceback = MP.UTILS.build_traceback

local function run_with_resume_start_run_log_filter(fn)
	local print_ref = print
	if type(print_ref) ~= "function" then
		return fn()
	end

	-- luacheck: push ignore 121
	print = function(...)
		local first = select(1, ...)
		local deferred_shop_area = expected_resume_start_run_logs[tostring(first)]
		if deferred_shop_area then
			if MP.RESUME and MP.RESUME.record_deferred_shop_area then
				MP.RESUME.record_deferred_shop_area(deferred_shop_area)
			end
			if sendTraceMessage then
				sendTraceMessage("Resume deferred vanilla shop card area: " .. deferred_shop_area, "MULTIPLAYER")
			end
			return
		end

		return print_ref(...)
	end

	local ok, result = xpcall(fn, build_traceback)

	print = print_ref
	-- luacheck: pop

	if not ok then
		error(result, 0)
	end

	return result
end

local game_start_run_ref = Game.start_run
function Game:start_run(args)
	MP.TEAM_CARD_INITIALIZING = true
	local ok, err = xpcall(function()
		if args and args.mp_resume then
			run_with_resume_start_run_log_filter(function()
				game_start_run_ref(self, args)
			end)
		else
			game_start_run_ref(self, args)
		end

		if G.GAME then
			G.GAME.mp_card_next_id = 0
		end
		if MP.TEAM_CARD and MP.TEAM_CARD.setup then
			MP.TEAM_CARD.setup(args and args.mp_resume)
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
