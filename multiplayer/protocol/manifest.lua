local families = {
	"system",
	"lobby",
	"match",
	"team",
	"sync",
	"endgame",
	"feature",
}

MP.PROTOCOL.VERSION = 2
MP.PROTOCOL.FAMILIES = families
MP.PROTOCOL.FAMILY_SET = MP.PROTOCOL.FAMILY_SET or {}

for _, family in ipairs(families) do
	MP.PROTOCOL.FAMILY_SET[family] = true
end

function MP.PROTOCOL.is_supported_version(version)
	return tonumber(version) == MP.PROTOCOL.VERSION
end

function MP.PROTOCOL.is_known_family(family)
	return MP.PROTOCOL.FAMILY_SET[tostring(family or "")] == true
end
