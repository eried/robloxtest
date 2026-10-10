-- Day and night clock, shared by server and client
local Sky = {}

-- Returns clock hour and daylight (0 night, 1 day)
function Sky.at(elapsed: number, dayMinutes: number, nightShare: number): (number, number)
	local start = nightShare + (1 - nightShare) * 7 / 12
	local phase = (elapsed / (dayMinutes * 60) + start) % 1
	local clock = if phase < nightShare
		then (18 + 12 * phase / nightShare) % 24
		else 6 + 12 * (phase - nightShare) / (1 - nightShare)
	local daylight = math.clamp(math.sin((clock - 6) / 12 * math.pi) * 3, 0, 1)
	return clock, daylight
end

return Sky
