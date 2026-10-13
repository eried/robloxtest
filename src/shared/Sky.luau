-- Day and night clock, shared by server and client
local Sky = {}

-- Daylight for a clock hour (0 night, 1 day)
function Sky.light(clock: number): number
	return math.clamp(math.sin((clock - 6) / 12 * math.pi) * 3, 0, 1)
end

-- Returns clock hour and daylight
function Sky.at(elapsed: number, dayMinutes: number, nightShare: number): (number, number)
	local start = nightShare + (1 - nightShare) * 7 / 12
	local phase = (elapsed / (dayMinutes * 60) + start) % 1
	local clock = if phase < nightShare
		then (18 + 12 * phase / nightShare) % 24
		else 6 + 12 * (phase - nightShare) / (1 - nightShare)
	return clock, Sky.light(clock)
end

-- Seconds after DayStart when the clock shows a daytime hour (6 to 18)
function Sky.offset(clock: number, dayMinutes: number, nightShare: number): number
	local start = nightShare + (1 - nightShare) * 7 / 12
	local phase = nightShare + (clock - 6) / 12 * (1 - nightShare)
	return ((phase - start) % 1) * dayMinutes * 60
end

return Sky
