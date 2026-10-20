-- Backyard cameras: where each one looks right now and what it can see
local Config = require(script.Parent:WaitForChild("Config"))

local Watch = {}

-- Yaw 0 looks up the plan (-Z), turning clockwise seen from above. Each camera sweeps at its own speed
function Watch.look(yaw: number, phase: number, t: number, period: number?): Vector3
	local a = yaw + math.rad(Config.CameraSweep) * math.sin(t * 2 * math.pi / (period or Config.CameraPeriod) + phase)
	return Vector3.new(math.sin(a), 0, -math.cos(a))
end

-- Inside the cone on the ground, walls aside
function Watch.inCone(eye: Vector3, look: Vector3, spot: Vector3): boolean
	local d = Vector3.new(spot.X - eye.X, 0, spot.Z - eye.Z)
	local dist = d.Magnitude
	if dist < 1 then
		return true
	end
	return dist <= Config.CameraRange and d.Unit:Dot(look) >= math.cos(math.rad(Config.CameraHalf))
end

return Watch
