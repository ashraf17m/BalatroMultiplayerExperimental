G.HUD_connection_status = nil

function G.UIDEF.get_connection_status_ui()
	return UIBox({
		definition = {
			n = G.UIT.ROOT,
			config = {
				align = "cm",
				colour = G.C.UI.TRANSPARENT_DARK,
			},
			nodes = {
				MP.UI.UTILS.create_text_node(
					(MP.LOBBY.code and localize("k_in_lobby"))
						or (MP.LOBBY.client.connected and localize("k_connected"))
						or localize("k_warn_service"),
					{
						scale = 0.3,
						colour = G.C.UI.TEXT_LIGHT,
					}
				),
			},
		},
		config = {
			align = "tri",
			bond = "Weak",
			offset = {
				x = 0,
				y = 0.9,
			},
			major = G.ROOM_ATTACH,
		},
	})
end

function G.UIDEF.create_UIBox_view_hash(type)
	local player = type == "host" and MP.get_lobby_owner() or MP.get_primary_opponent_lobby_player()
	local mods = player and player.config and player.config.Mods or {}

	return (
		create_UIBox_generic_options({
			contents = {
				MP.UI.UTILS.create_column(
					{ padding = 0.07, align = "cm" },
					MP.UI.modlist_to_view(mods, G.C.UI.TEXT_LIGHT)
				),
			},
		})
	)
end

function G.UIDEF.create_UIBox_unstuck()
	return (
		create_UIBox_generic_options({
			back_func = "options",
			contents = {
				{
					n = G.UIT.C,
					config = {
						padding = 0.2,
						align = "cm",
					},
					nodes = {
						UIBox_button({ label = { localize("b_unstuck_blind") }, button = "mp_unstuck_blind", minw = 5 }),
					},
				},
			},
		})
	)
end
