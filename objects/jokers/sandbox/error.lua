SMODS.Atlas({
	key = "error_sandbox",
	path = "j_ERROR_sandbox.png",
	px = 71,
	py = 95,
})

local BLUE_SCREEN_ERROR_MESSAGES = {
	"SYSTEM_SERVICE_EXCEPTION",
	"KERNEL_DATA_INPAGE_ERROR",
	"IRQL_NOT_LESS_OR_EQUAL",
	"PAGE_FAULT_IN_NONPAGED_AREA",
	"KMODE_EXCEPTION_NOT_HANDLED",
	"DRIVER_POWER_STATE_FAILURE",
	"CRITICAL_PROCESS_DIED",
	"BAD_POOL_HEADER",
	"MEMORY_MANAGEMENT",
	"SYSTEM_THREAD_EXCEPTION",
	"DPC_WATCHDOG_VIOLATION",
	"CLOCK_WATCHDOG_TIMEOUT",
	"WHEA_UNCORRECTABLE_ERROR",
	"PFN_LIST_CORRUPT",
	"DRIVER_VERIFIER_DETECTED",
	"THREAD_STUCK_IN_DEVICE_DRIVER",
	"VIDEO_TDR_TIMEOUT_DETECTED",
	"APC_INDEX_MISMATCH",
	"DRIVER_IRQL_NOT_LESS_OR_EQUAL",
	"BUGCODE_USB_DRIVER",
	"HYPERVISOR_ERROR",
	"UNEXPECTED_KERNEL_MODE_TRAP",
	"ATTEMPTED_WRITE_TO_READONLY_MEMORY",
	"DRIVER_CORRUPTED_EXPOOL",
	"NTFS_FILE_SYSTEM",
	"FAT_FILE_SYSTEM",
	"KERNEL_SECURITY_CHECK_FAILURE",
	"STOP: 0x0000007E",
	"STOP: 0x000000D1",
	"STOP: 0x0000001E",
	"STOP: 0x00000050",
	"STOP: 0x000000A",
}

local SIMPLE_ERROR_MESSAGES = {
	"$",
	"€",
	"¥",
	"despair",
	"£",
	"₹",
	"₽",
	"₩",
	"¢",
	"₿",
	"◊",
}

local function has_index(index, indexes)
	for _, candidate in ipairs(indexes) do
		if index == candidate then
			return true
		end
	end
	return false
end

local function get_blue_screen_error_colour(index)
	if has_index(index, { 1, 22 }) then return lighten(G.C.BLUE, 0.3) end
	if has_index(index, { 3, 24 }) then return lighten(G.C.BLUE, 0.4) end
	if has_index(index, { 5, 16, 28 }) then return lighten(G.C.BLUE, 0.2) end
	if has_index(index, { 10, 30 }) then return lighten(G.C.BLUE, 0.5) end
	if index == 12 then return lighten(G.C.BLUE, 0.1) end
	if index == 18 then return lighten(G.C.BLUE, 0.6) end
	if has_index(index, { 4, 11, 17, 23, 29 }) then return G.C.CHIPS end
	if has_index(index, { 8, 26 }) then return lighten(G.C.CHIPS, 0.3) end
	if has_index(index, { 14, 32 }) then return lighten(G.C.CHIPS, 0.4) end
	if index == 20 then return lighten(G.C.CHIPS, 0.2) end
	if has_index(index, { 6, 13, 19, 25, 31 }) then return G.C.SECONDARY_SET.Planet end
	if index == 7 then return G.C.RED end
	return G.C.BLUE
end

local function add_error_message(options, message, colour)
	options[#options + 1] = { string = message, colour = colour }
end

local function create_error_message_options()
	local options = {}
	for index, message in ipairs(BLUE_SCREEN_ERROR_MESSAGES) do
		add_error_message(options, message, get_blue_screen_error_colour(index))
	end

	add_error_message(options, "corrupted heap", G.C.BLIND.Boss)
	add_error_message(options, "BSOD", G.C.BLUE)
	add_error_message(options, "malloc(): corrupted top size", G.C.RED)
	add_error_message(options, "use after free", G.C.PERISHABLE)
	add_error_message(options, "stack smashing detected", G.C.ETERNAL)
	add_error_message(options, "double free or corruption", lighten(G.C.RED, 0.2))
	add_error_message(options, "zombie process", lighten(G.C.L_BLACK, 0.5))
	add_error_message(options, "killed by signal 9", G.C.SO_1.Hearts)
	add_error_message(options, "0x" .. string.format("%08X", math.random(0, 0xFFFFFFFF)), G.C.MONEY)

	for _, message in ipairs(SIMPLE_ERROR_MESSAGES) do
		options[#options + 1] = message
	end

	return options
end

for i = 1, 21 do
	SMODS.Joker({
		key = "error_sandbox_" .. i,
		loc_vars = function(self, info_queue, card)
			local r_mults = {}
			for mult_index = 1, 333 do
				r_mults[#r_mults + 1] = tostring(mult_index)
			end
			local loc_mult = "(CURRENTLY " .. math.random(1, 333) .. ")"
			local main_end = {
				{ n = G.UIT.T, config = { text = loc_mult, colour = lighten(G.C.PURPLE, 0.2), scale = 0.4 } },
				{
					n = G.UIT.O,
					config = {
						object = DynaText({
							string = r_mults,
							colours = { G.C.MONEY },
							pop_in_rate = 9999999,
							silent = true,
							random_element = true,
							pop_delay = 1.52,
							scale = 0.32,
							min_cycle_time = 0,
						}),
					},
				},
				{
					n = G.UIT.O,
					config = {
						object = DynaText({
							string = create_error_message_options(),
							colours = { G.C.UI.TEXT_DARK },
							pop_in_rate = 1,
							silent = true,
							random_element = true,
							pop_delay = 0.38,
							scale = 0.32,
							min_cycle_time = 0,
						}),
					},
				},
			}
			return {
				main_end = main_end,
				-- modified localization key trickery to ensure we always use this localization, thanks toneblock
				key = "j_mp_error_sandbox",
			}
		end,

		atlas = "error_sandbox",
		no_collection = MP.sandbox_no_collection,
		unlocked = true,
		discovered = true,
		mp_include = function(self)
			return false
		end,
		mp_credits = { art = { "aura?" } },
	})
end
