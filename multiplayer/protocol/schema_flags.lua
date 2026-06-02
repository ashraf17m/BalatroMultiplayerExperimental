local SCHEMA_DEFINITIONS = {
	system = {
		hello = {
			id = "system.hello.v2",
			flags = { replay = "never", persistence = "none" },
		},
		hello_ack = {
			id = "system.helloAck.v2",
			flags = { replay = "never", persistence = "session" },
		},
	},
	lobby = {
		intent = {
			id = "lobby.intent.v2",
			flags = { replay = "never", persistence = "none" },
		},
		snapshot = {
			id = "lobby.snapshot.v2",
			flags = { replay = "snapshot", persistence = "session" },
		},
	},
	match = {
		intent = {
			id = "match.intent.v2",
			flags = { replay = "never", persistence = "none" },
		},
		state = {
			id = "match.state.v2",
			flags = { replay = "state", persistence = "resume" },
		},
	},
	team = {
		state = {
			id = "team.state.v2",
			flags = { replay = "state", persistence = "resume" },
		},
	},
	sync = {
		state = {
			id = "sync.state.v2",
			flags = { replay = "state", persistence = "resume" },
		},
	},
	endgame = {
		state = {
			id = "endgame.state.v2",
			flags = { replay = "snapshot", persistence = "endgame" },
		},
	},
	feature = {
		event = {
			id = "feature.event.v2",
			flags = { replay = "event", persistence = "none" },
		},
	},
}

local message_schemas = {}
local schema_flags = {}

for family, actions in pairs(SCHEMA_DEFINITIONS) do
	local family_schemas = {}
	for action, definition in pairs(actions) do
		family_schemas[action] = definition.id
		schema_flags[definition.id] = definition.flags
	end

	message_schemas[family] = family_schemas
end

function MP.PROTOCOL.get_schema_id(family, action)
	local family_key = tostring(family or "")
	local action_key = tostring(action or "")
	local family_schemas = message_schemas[family_key]
	return family_schemas and family_schemas[action_key] or nil
end

function MP.PROTOCOL.get_schema_flags(schema_id)
	return schema_flags[tostring(schema_id or "")]
end
