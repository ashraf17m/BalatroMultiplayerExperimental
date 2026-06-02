MP.TESTING = MP.TESTING or {}

function MP.TESTING.show_notice(message)
	if type(attention_text) == "function" and G and G.C then
		attention_text({
			text = tostring(message),
			scale = 0.8,
			hold = 1,
			align = "cm",
			backdrop_colour = G.C.SECONDARY_SET and G.C.SECONDARY_SET.Tarot or G.C.BLUE,
			silent = true,
		})
	elseif sendDebugMessage then
		sendDebugMessage(tostring(message), "MULTIPLAYER")
	end
end

return true
