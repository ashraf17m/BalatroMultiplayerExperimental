MP.COMPATIBILITY = MP.COMPATIBILITY or {}
MP.COMPATIBILITY.PREVIEW = MP.COMPATIBILITY.PREVIEW or {}

function MP.COMPATIBILITY.PREVIEW.refresh_after_score_calculator_backend_change(backend)
	if tonumber(backend) == 2 then
		return false
	end

	if G.SETTINGS and G.SETTINGS.FN and FN and FN.PRE and FN.PRE.enabled and FN.PRE.enabled() then
		FN.PRE.add_update_event("immediate")
		return true
	end

	return false
end
