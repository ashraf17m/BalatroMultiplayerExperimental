local MAX_ENCODED_TABLE_PAYLOAD_BYTES = 4 * 1024 * 1024
local MAX_UNPACKED_TABLE_SOURCE_BYTES = 16 * 1024 * 1024
local MAX_STR_PACK_PARSE_DEPTH = 256
local MAX_STR_PACK_PARSE_VALUES = 500000

local function trace_serialization_event(event, context, encoded_bytes, compressed_bytes, source_bytes)
	if
		MP.UTILS
		and MP.UTILS.trace_runtime_event
		and MP.UTILS.is_runtime_trace_enabled
		and MP.UTILS.is_runtime_trace_enabled()
	then
		MP.UTILS.trace_runtime_event(event, {
			context = context,
			encoded_bytes = encoded_bytes,
			compressed_bytes = compressed_bytes,
			source_bytes = source_bytes,
		})
	end
end

local function parser_error(parser, message)
	error(string.format("%s at byte %s", message, tostring(parser.index)), 0)
end

local function is_space(byte)
	return byte == 32 or byte == 9 or byte == 10 or byte == 13
end

local function is_digit(byte)
	return byte and byte >= 48 and byte <= 57
end

local function is_identifier_start(byte)
	return byte
		and ((byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) or byte == 95)
end

local function is_identifier_part(byte)
	return is_identifier_start(byte) or is_digit(byte)
end

local function skip_space(parser)
	local source = parser.source
	local index = parser.index
	while index <= parser.length and is_space(source:byte(index)) do
		index = index + 1
	end
	parser.index = index
end

local function expect_char(parser, char)
	if parser.source:sub(parser.index, parser.index) ~= char then
		parser_error(parser, "Expected '" .. char .. "'")
	end
	parser.index = parser.index + 1
end

local function parse_identifier(parser)
	local source = parser.source
	local start = parser.index
	if not is_identifier_start(source:byte(start)) then
		parser_error(parser, "Expected identifier")
	end

	local index = start + 1
	while index <= parser.length and is_identifier_part(source:byte(index)) do
		index = index + 1
	end

	parser.index = index
	return source:sub(start, index - 1)
end

local function parse_number(parser)
	local source = parser.source
	local start = parser.index
	local index = start

	if source:sub(index, index) == "-" then
		index = index + 1
	end

	while index <= parser.length do
		local byte = source:byte(index)
		if is_digit(byte) or byte == 46 or byte == 101 or byte == 69 or byte == 43 or byte == 45 then
			index = index + 1
		else
			break
		end
	end

	local token = source:sub(start, index - 1)
	local value = tonumber(token)
	if value == nil then
		parser_error(parser, "Invalid number literal")
	end

	parser.index = index
	return value
end

local SIMPLE_ESCAPES = {
	a = "\a",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	["\\"] = "\\",
	["\""] = "\"",
	["'"] = "'",
}

local unpack_values = table.unpack or unpack
local function parse_string(parser)
	local source = parser.source
	local quote = source:sub(parser.index, parser.index)
	local index = parser.index + 1
	local parts = {}

	while index <= parser.length do
		local char = source:sub(index, index)
		if char == quote then
			parser.index = index + 1
			return table.concat(parts)
		end

		if char == "\\" then
			local escaped_index = index + 1
			local escaped_byte = source:byte(escaped_index)
			if not escaped_byte then
				parser.index = index
				parser_error(parser, "Unterminated string escape")
			end

			if is_digit(escaped_byte) then
				local digit_end = escaped_index
				while
					digit_end + 1 <= parser.length
					and digit_end - escaped_index < 2
					and is_digit(source:byte(digit_end + 1))
				do
					digit_end = digit_end + 1
				end
				local value = tonumber(source:sub(escaped_index, digit_end))
				if not value or value > 255 then
					parser.index = index
					parser_error(parser, "Invalid decimal string escape")
				end
				parts[#parts + 1] = string.char(value)
				index = digit_end + 1
			else
				local escaped = source:sub(escaped_index, escaped_index)
				if escaped == "z" then
					index = escaped_index + 1
					while index <= parser.length and is_space(source:byte(index)) do
						index = index + 1
					end
				elseif escaped == "\n" then
					index = escaped_index + 1
				elseif escaped == "\r" then
					index = escaped_index + 1
					if source:sub(index, index) == "\n" then
						index = index + 1
					end
				else
					parts[#parts + 1] = SIMPLE_ESCAPES[escaped] or escaped
					index = escaped_index + 1
				end
			end
		else
			parts[#parts + 1] = char
			index = index + 1
		end
	end

	parser.index = index
	parser_error(parser, "Unterminated string literal")
end

local parse_value

local function parse_argument_list(parser, depth)
	expect_char(parser, "(")
	local args = {}

	skip_space(parser)
	while parser.index <= parser.length and parser.source:sub(parser.index, parser.index) ~= ")" do
		args[#args + 1] = parse_value(parser, depth + 1)
		skip_space(parser)

		local separator = parser.source:sub(parser.index, parser.index)
		if separator == "," then
			parser.index = parser.index + 1
			skip_space(parser)
		elseif separator ~= ")" then
			parser_error(parser, "Expected function argument separator")
		end
	end

	expect_char(parser, ")")
	return args
end

local function apply_whitelisted_constructor(parser, identifier, args)
	if identifier == "to_big" then
		if type(to_big) ~= "function" then
			parser_error(parser, "Constructor 'to_big' is not available")
		end

		local ok, value = pcall(to_big, unpack_values(args, 1, #args))
		if not ok then
			parser_error(parser, "Constructor 'to_big' failed: " .. tostring(value))
		end
		return value
	end

	parser_error(parser, "Unsupported constructor '" .. identifier .. "'")
end

local function note_parsed_value(parser)
	parser.values = parser.values + 1
	if parser.values > MAX_STR_PACK_PARSE_VALUES then
		parser_error(parser, "Decoded payload contains too many values")
	end
end

local function parse_table(parser, depth)
	if depth > MAX_STR_PACK_PARSE_DEPTH then
		parser_error(parser, "Decoded payload is nested too deeply")
	end

	expect_char(parser, "{")
	local result = {}
	local array_index = 1

	skip_space(parser)
	while parser.index <= parser.length and parser.source:sub(parser.index, parser.index) ~= "}" do
		note_parsed_value(parser)
		local key = nil
		local value = nil
		local char = parser.source:sub(parser.index, parser.index)

		if char == "[" then
			parser.index = parser.index + 1
			skip_space(parser)
			key = parse_value(parser, depth + 1)
			skip_space(parser)
			expect_char(parser, "]")
			skip_space(parser)
			expect_char(parser, "=")
			skip_space(parser)
			value = parse_value(parser, depth + 1)
			result[key] = value
		else
			local saved_index = parser.index
			if is_identifier_start(parser.source:byte(parser.index)) then
				local identifier = parse_identifier(parser)
				skip_space(parser)
				if parser.source:sub(parser.index, parser.index) == "=" then
					parser.index = parser.index + 1
					skip_space(parser)
					result[identifier] = parse_value(parser, depth + 1)
				else
					parser.index = saved_index
					value = parse_value(parser, depth + 1)
					result[array_index] = value
					array_index = array_index + 1
				end
			else
				value = parse_value(parser, depth + 1)
				result[array_index] = value
				array_index = array_index + 1
			end
		end

		skip_space(parser)
		local separator = parser.source:sub(parser.index, parser.index)
		if separator == "," or separator == ";" then
			parser.index = parser.index + 1
			skip_space(parser)
		elseif separator ~= "}" then
			parser_error(parser, "Expected table separator")
		end
	end

	expect_char(parser, "}")
	return result
end

parse_value = function(parser, depth)
	skip_space(parser)
	local char = parser.source:sub(parser.index, parser.index)
	if char == "{" then
		return parse_table(parser, depth)
	end
	if char == "\"" or char == "'" then
		return parse_string(parser)
	end
	if char == "-" or char == "." or is_digit(parser.source:byte(parser.index)) then
		return parse_number(parser)
	end
	if is_identifier_start(parser.source:byte(parser.index)) then
		local identifier = parse_identifier(parser)
		skip_space(parser)
		if parser.source:sub(parser.index, parser.index) == "(" then
			local args = parse_argument_list(parser, depth)
			return apply_whitelisted_constructor(parser, identifier, args)
		end
		if identifier == "true" then return true end
		if identifier == "false" then return false end
		if identifier == "nil" then return nil end
		parser_error(parser, "Unexpected identifier '" .. identifier .. "'")
	end

	parser_error(parser, "Expected value")
end

local function STR_UNPACK_CHECKED(str)
	if type(str) ~= "string" then
		error("Decoded payload source must be a string")
	end
	local parser = {
		source = str,
		length = #str,
		index = 1,
		values = 0,
	}

	skip_space(parser)
	if parse_identifier(parser) ~= "return" then
		parser_error(parser, "Expected return statement")
	end
	local str_unpacked = parse_value(parser, 1)
	skip_space(parser)
	if parser.index <= parser.length then
		parser_error(parser, "Unexpected trailing payload data")
	end

	if type(str_unpacked) ~= "table" then
		error("Decoded payload did not return a table")
	end

	return str_unpacked
end

function MP.UTILS.str_pack_and_encode(data, context)
	local str = STR_PACK(data)
	local str_compressed = love.data.compress("string", "gzip", str)
	local str_encoded = love.data.encode("string", "base64", str_compressed)
	trace_serialization_event("serialization.encode", context, #str_encoded, #str_compressed, #str)
	return str_encoded
end

function MP.UTILS.str_decode_and_unpack(str, context)
	local success, str_decoded, str_decompressed, str_unpacked
	if type(str) ~= "string" then
		return nil, "Encoded payload must be a string"
	end
	if #str > MAX_ENCODED_TABLE_PAYLOAD_BYTES then
		return nil, string.format(
			"Encoded payload is too large (%s > %s bytes)",
			tostring(#str),
			tostring(MAX_ENCODED_TABLE_PAYLOAD_BYTES)
		)
	end

	success, str_decoded = pcall(love.data.decode, "string", "base64", str)
	if not success then return nil, str_decoded end
	success, str_decompressed = pcall(love.data.decompress, "string", "gzip", str_decoded)
	if not success then return nil, str_decompressed end
	if type(str_decompressed) ~= "string" then
		return nil, "Decoded payload did not decompress to a string"
	end
	if #str_decompressed > MAX_UNPACKED_TABLE_SOURCE_BYTES then
		return nil, string.format(
			"Decoded payload is too large (%s > %s bytes)",
			tostring(#str_decompressed),
			tostring(MAX_UNPACKED_TABLE_SOURCE_BYTES)
		)
	end

	success, str_unpacked = pcall(STR_UNPACK_CHECKED, str_decompressed)
	if not success then return nil, str_unpacked end
	trace_serialization_event("serialization.decode", context, #str, #str_decoded, #str_decompressed)
	return str_unpacked
end
