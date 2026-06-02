local THE_ORDER = MP.COMPAT.THE_ORDER

local function get_culled_voucher_pool(_pool)
	local culled = {}
	for index = 1, #_pool, 2 do
		local first = _pool[index]
		local second = _pool[index + 1]

		if second == nil then
			culled[#culled + 1] = (first ~= "UNAVAILABLE") and first or "UNAVAILABLE"
		elseif first ~= "UNAVAILABLE" and second ~= "UNAVAILABLE" then
			culled[#culled + 1] = first
			culled[#culled + 1] = second
		elseif first ~= "UNAVAILABLE" then
			culled[#culled + 1] = first
		elseif second ~= "UNAVAILABLE" then
			culled[#culled + 1] = second
		else
			culled[#culled + 1] = "UNAVAILABLE"
		end
	end
	return culled
end

local function is_available_voucher_center(center, spawned)
	return center and center ~= "UNAVAILABLE" and not (spawned and spawned[center])
end

local function collect_available_voucher_centers(culled, spawned)
	local available = {}
	for _, center in ipairs(culled) do
		if is_available_voucher_center(center, spawned) then
			available[#available + 1] = center
		end
	end
	return available
end

local function get_competitive_voucher_center(culled, spawned)
	local available = collect_available_voucher_centers(culled, spawned)
	if #available == 0 then
		return nil
	end

	local max_attempts = math.max(#culled * 2, 1)
	for _ = 1, max_attempts do
		local center = pseudorandom_element(culled, pseudoseed("Voucher0"))
		if is_available_voucher_center(center, spawned) then
			return center
		end
	end

	return pseudorandom_element(available, pseudoseed("Voucher0"))
end

MP.PLATFORM.SMODS.override_known("get_next_vouchers", function(nextvouchers)
	return function(vouchers)
		-- These competitive queues are intentionally deterministic instead of inheriting SMODS weights.
		if THE_ORDER.uses_competitive_voucher_queue() then
			vouchers = vouchers or { spawn = {} }
			local _pool = get_current_pool("Voucher")
			local culled = get_culled_voucher_pool(_pool)
			for index = #vouchers + 1, math.min(
				MP.PLATFORM.SMODS.size_of_pool(_pool),
				G.GAME.starting_params.vouchers_in_shop + (G.GAME.modifiers.extra_vouchers or 0)
			) do
				local center = get_competitive_voucher_center(culled, vouchers.spawn)
				if not center then
					break
				end
				vouchers[#vouchers + 1] = center
				vouchers.spawn[center] = true
			end
			return vouchers
		end
		return nextvouchers(vouchers)
	end
end)

local original_get_next_voucher_key = get_next_voucher_key
function get_next_voucher_key(_from_tag)
	if THE_ORDER.uses_competitive_voucher_queue() then
		local _pool = get_current_pool("Voucher")
		local culled = get_culled_voucher_pool(_pool)
		local center = get_competitive_voucher_center(culled)
		if center then
			return center
		end
	end
	return original_get_next_voucher_key(_from_tag)
end
