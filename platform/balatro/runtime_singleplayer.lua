MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO
local get_root = BALATRO.get_root

function BALATRO.continue_in_singleplayer_run()
	local root = get_root()
	local settings = BALATRO.get_settings and BALATRO.get_settings() or nil
	if not (root and settings and root.delete_run and root.start_run and save_run and get_compressed and STR_UNPACK) then
		return false
	end

	BALATRO.set_no_saving(false)
	BALATRO.set_current_setup("Continue")
	BALATRO.call_ui_function("wipe_on")
	save_run()
	root:delete_run()

	BALATRO.queue_event({
		trigger = "immediate",
		no_delete = true,
		func = function()
			local profile = settings.profile
			local save_path = profile .. "/save.jkr"
			root.SAVED_GAME = get_compressed(save_path)
			if root.SAVED_GAME ~= nil then
				root.SAVED_GAME = STR_UNPACK(root.SAVED_GAME)
			end
			root:start_run({ savetext = root.SAVED_GAME })
			return true
		end,
	})

	BALATRO.call_ui_function("wipe_off")
	return true
end

return BALATRO
