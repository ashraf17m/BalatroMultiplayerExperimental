local team_hand_level_sync = MP.SYNC and MP.SYNC.TEAM_HAND_LEVEL or {}

local level_up_hand_ref = level_up_hand
function level_up_hand(card, hand, instant, amount, statustext)
	local previous_level = team_hand_level_sync.get_hand_level and team_hand_level_sync.get_hand_level(hand) or nil
	local previous_level_wire = team_hand_level_sync.serialize_hand_level and team_hand_level_sync.serialize_hand_level(previous_level) or nil
	local result = level_up_hand_ref(card, hand, instant, amount, statustext)

	if not team_hand_level_sync.is_applying_remote_change() and team_hand_level_sync.is_sync_active() then
		local next_level = team_hand_level_sync.get_hand_level and team_hand_level_sync.get_hand_level(hand) or nil
		local next_level_wire = team_hand_level_sync.serialize_hand_level and team_hand_level_sync.serialize_hand_level(next_level) or nil
		if previous_level_wire and next_level_wire and next_level_wire ~= previous_level_wire then
			MP.ACTIONS.team_hand_level_sync(hand, next_level_wire)
		end
	end

	return result
end

local function is_resume_start(args)
	return args and args.mp_resume
end

MP.HOOKS.register_method_hook(Game, "Game", "start_run", "mp.team_hand_level_sync.pending_syncs", {
	before = function(ctx)
		local args = ctx.args and ctx.args[1] or nil
		if not is_resume_start(args) and team_hand_level_sync.clear_pending_syncs then
			team_hand_level_sync.clear_pending_syncs()
		end
	end,
	after = function()
		if team_hand_level_sync.flush_pending_syncs then
			team_hand_level_sync.flush_pending_syncs()
		end
	end,
})
