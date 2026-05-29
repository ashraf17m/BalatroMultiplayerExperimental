local function bxor(a, b)
	local res = 0
	local bitval = 1
	while a > 0 and b > 0 do
		local a_bit = a % 2
		local b_bit = b % 2
		if a_bit ~= b_bit then res = res + bitval end
		bitval = bitval * 2
		a = math.floor(a / 2)
		b = math.floor(b / 2)
	end
	res = res + (a + b) * bitval
	return res
end

local function encrypt_string(str)
	local hash = 2166136261
	for i = 1, #str do
		hash = bxor(hash, str:byte(i))
		hash = (hash * 16777619) % 2 ^ 32
	end
	return string.format("%08x", hash)
end

local DEFAULT_WINDOWS_DRIVE = "C:"
local WINDOWS_ROOT_SEPARATOR = "\\"

local function normalize_windows_root_path(drive)
	if not drive or drive == "" then
		return nil
	end

	drive = drive:gsub("[/\\]+$", "")
	if not drive:match("^[A-Za-z]:$") then
		return nil
	end

	return drive .. "\\"
end

local function append_unique_windows_root(roots, seen, root_path)
	if not root_path then
		return
	end

	local key = root_path:lower()
	if seen[key] then
		return
	end

	seen[key] = true
	roots[#roots + 1] = root_path
end

local function get_windows_root_paths()
	local roots = {}
	local seen = {}

	-- Preserve existing IDs on standard Windows installs; only fall back for non-C system drives.
	append_unique_windows_root(roots, seen, normalize_windows_root_path(DEFAULT_WINDOWS_DRIVE .. WINDOWS_ROOT_SEPARATOR))
	append_unique_windows_root(roots, seen, normalize_windows_root_path(os.getenv("SystemDrive")))

	return roots
end

function MP.UTILS.server_connection_ID()
	local os_name = love.system.getOS()
	local raw_id

	if os_name == "Windows" then
		local ffi = require("ffi")

		ffi.cdef([[
		typedef unsigned long DWORD;
		typedef int BOOL;
		typedef const char* LPCSTR;

		BOOL GetVolumeInformationA(
			LPCSTR lpRootPathName,
			char* lpVolumeNameBuffer,
			DWORD nVolumeNameSize,
			DWORD* lpVolumeSerialNumber,
			DWORD* lpMaximumComponentLength,
			DWORD* lpFileSystemFlags,
			char* lpFileSystemNameBuffer,
			DWORD nFileSystemNameSize
		);
		]])

		local serial_ptr = ffi.new("DWORD[1]")
		for _, root_path in ipairs(get_windows_root_paths()) do
			local ok = ffi.C.GetVolumeInformationA(root_path, nil, 0, serial_ptr, nil, nil, nil, 0)
			if ok ~= 0 then
				raw_id = tostring(serial_ptr[0])
				break
			end
		end
	elseif os_name == "OS X" then
		local cmd =
			[[ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/ { split($0, line, "\""); printf("%s\n", line[4]); }']]
		local handle = io.popen(cmd)
		local result = handle:read("*a")
		if handle then handle:close() end
		raw_id = tostring(result)
	end

	if not raw_id then raw_id = os.getenv("USER") or os.getenv("USERNAME") or os_name end

	return encrypt_string(raw_id)
end
