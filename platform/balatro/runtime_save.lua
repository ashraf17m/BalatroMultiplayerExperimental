MP.PLATFORM = MP.PLATFORM or {}
MP.PLATFORM.BALATRO = MP.PLATFORM.BALATRO or {}

local BALATRO = MP.PLATFORM.BALATRO

function BALATRO.file_exists(path)
	if not (type(path) == "string" and path ~= "") then
		return false
	end

	return not not (love and love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path))
end

function BALATRO.remove_file(path)
	if not (type(path) == "string" and path ~= "") then
		return false
	end
	if not (love and love.filesystem and love.filesystem.remove) then
		return false
	end

	love.filesystem.remove(path)
	return true
end

function BALATRO.get_compressed_save(path)
	if type(path) ~= "string" or path == "" or not get_compressed then
		return nil
	end

	return get_compressed(path)
end

function BALATRO.unpack_compressed_save(compressed)
	if compressed == nil or not STR_UNPACK then
		return nil
	end

	local ok, unpacked = pcall(STR_UNPACK, compressed)
	return ok and unpacked or nil
end

function BALATRO.read_saved_table(path)
	local compressed = BALATRO.get_compressed_save(path)
	if compressed == nil then
		return nil, "Missing saved data."
	end

	local unpacked = BALATRO.unpack_compressed_save(compressed)
	if type(unpacked) ~= "table" then
		return nil, "Saved match data is corrupted."
	end

	return unpacked
end

function BALATRO.write_saved_table(path, data)
	if type(path) ~= "string" or path == "" or not compress_and_save then
		return false
	end

	local ok, result = pcall(compress_and_save, path, data)
	return ok and result ~= false
end

return BALATRO
