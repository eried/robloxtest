-- Headless playtest of Pianka the Escape: real server and client scripts with bot players.
-- Run from the escape folder: lune run tests/escape.spec.luau
local process = require("@lune/process")
local Engine = require("./engine")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3

Engine.build()
-- Fake sound ids so the clips play their sounds in the test
Engine.patch = function(name: string, module: any)
	if name == "Config" then
		module.SfxId = 99
		module.MusicId = 98
	end
end
Engine.startServer()
local workspace = Engine.workspace
local game = Engine.game
local Config = Engine.server.modules[game:GetService("ReplicatedStorage"):FindFirstChild("Shared"):FindFirstChild("Config")]
local DT = 1 / 20
local function run(seconds: number)
	for _ = 1, math.ceil(seconds / DT) do
		Engine.step(DT)
	end
end

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL: " .. message)
	end
end

local ana = Engine.addPlayer("Ana")
local bo = Engine.addPlayer("Bo")
run(4)

local world = workspace:FindFirstChild("World")
local house = world and world:FindFirstChild("House")
local counts: { [string]: number } = {}
for _, d in (if world then world:GetDescendants() else {}) do
	counts[d.Name] = (counts[d.Name] or 0) + 1
end
check(house ~= nil, "no house")
check((counts.Wall or 0) > 20, "too few walls: " .. tostring(counts.Wall))
check((counts.Floor or 0) > 10, "too few floors")
check((counts.Window or 0) > 5, "too few windows")
check((counts.Ramp or 0) == 1, "no stairs ramp")
check((counts.ExitDoor or 0) == 1, "no front door")
check((counts.Ground or 0) == 1 and (counts.Fence or 0) > 0, "no yard")
check((counts.Lamp or 0) > 5, "rooms have no lamps")
local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
check(starter ~= nil and starter:FindFirstChild("HumanoidRootPart") ~= nil and starter:FindFirstChildOfClass("Humanoid") ~= nil, "Pianka is not the player character")

local sleepers = {}
for _, d in world:GetDescendants() do
	if d:GetAttribute("Sleeper") then
		table.insert(sleepers, d)
	end
end
check(#sleepers == 3, "expected 3 sleepers, found " .. #sleepers)
local toys = {}
for _, d in world:GetDescendants() do
	if d:GetAttribute("Toy") then
		table.insert(toys, d)
	end
end
check(#toys >= 6, "too few toys")

local function keys(): { any }
	local list = {}
	for _, k in world:FindFirstChild("Keys"):GetChildren() do
		table.insert(list, k)
	end
	return list
end
check(#keys() == 3, "expected 3 keys, found " .. #keys())
check(workspace:GetAttribute("Keys") == 0, "keys should start at 0")

local function root(player: any): any
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local bed = workspace:GetAttribute("CatBed")
local function nearBed(player: any): boolean
	local r = root(player)
	return r ~= nil and bed ~= nil and (r.Position - bed).Magnitude < 6
end
check(nearBed(ana) and nearBed(bo), "players do not start in Pianka's bed")
for _, k in keys() do
	local p = k:GetPivot().Position
	local floor = if p.Y > Config.Floor2 - 3 then 2 else 1
	check(p.Y > (if floor == 2 then Config.Floor2 else 0) + 0.5, "a key is under the floor")
end

local function teleport(player: any, pos: any)
	local r = root(player)
	if r then
		r.CFrame = Engine.CFrame.new(pos)
	end
end

-- One key, then too much noise: someone wakes up and everything resets
local first = keys()[1]
teleport(ana, first:GetPivot().Position)
run(0.5)
check(workspace:GetAttribute("Keys") == 1, "picking up a key did not count")
teleport(ana, bed + Vector3.new(3, 0, 0))
run(0.5)

local mom = nil
for _, s in sleepers do
	if s:GetAttribute("Sleeper") == "Milenkitka" then
		mom = s
	end
end
local woke = false
if mom then
	local head = mom:FindFirstChild("Head")
	local closest, best = nil, math.huge
	for _, t in toys do
		local d = (t.PrimaryPart.Position - head.Position).Magnitude
		if t.PrimaryPart.Position.Y > Config.Floor2 - 3 and d < best then
			closest, best = t, d
		end
	end
	check(closest ~= nil, "no toy upstairs near mom")
	for _ = 1, 40 do
		if not closest then
			break
		end
		teleport(bo, closest.PrimaryPart.Position + Vector3.new(0, 1.4, 0))
		run(0.3)
		teleport(bo, closest.PrimaryPart.Position + Vector3.new(12, 1.4, 0))
		run(1.2)
		if (mom:GetAttribute("Sleep") or 0) == 0 and workspace:GetAttribute("Keys") == 0 then
			woke = true
			break
		end
		if root(bo) and root(bo).Anchored then
			woke = true
			run(Config.CaughtTime + 1)
			break
		end
	end
end
check(woke, "squeaky toys never woke anyone up")
run(1)
check(workspace:GetAttribute("Keys") == 0, "keys were not taken back after a wake up")
check(#keys() == 3, "keys were not put back after a wake up")
check(nearBed(ana) and nearBed(bo), "players were not sent back to bed after a wake up")
check(not root(bo).Anchored, "players stay frozen after a wake up")

-- Running next to a sleeper makes noise, sneaking does not
local kid = nil
for _, s in sleepers do
	if s:GetAttribute("Sleeper") == "Patrick" then
		kid = s
	end
end
if kid then
	local head = kid:FindFirstChild("Head").Position
	local base = Vector3.new(head.X + 8, Config.Floor2 + 1.4, head.Z)
	for i = 1, 30 do
		teleport(ana, base + Vector3.new(if i % 2 == 0 then 1.2 else -1.2, 0, 0))
		Engine.step(DT)
	end
	check((kid:GetAttribute("Sleep") or 0) > 5, "running next to a sleeper made no noise")
	teleport(ana, bed + Vector3.new(3, 0, 0))
	run(Config.CaughtTime + 6)
end

-- All three keys open the front door, then out you go
local Watch = Engine.server.modules[game:GetService("ReplicatedStorage"):FindFirstChild("Shared"):FindFirstChild("Watch")]
local U = Config.Square
local outside = Vector3.new(16 * U, 1.4, 22 * U + 8)
local function escapeHouse(player: any)
	for _, k in keys() do
		if not k:GetAttribute("Gate") then
			teleport(player, k:GetPivot().Position)
			run(0.3)
		end
	end
	run(1.5)
	teleport(player, outside)
	run(0.5)
end
escapeHouse(ana)
check(workspace:GetAttribute("Keys") == 3, "could not collect all keys, got " .. tostring(workspace:GetAttribute("Keys")))
local door = house:FindFirstChild("ExitDoor")
check(door ~= nil and door.CanCollide == false, "front door did not open")
check(ana:GetAttribute("Out") == true, "walking out of the open door did not count as escaping")

-- The backyard: three gate keys, one in the garage, and a locked gate
check(workspace:GetAttribute("Stage") == "yard", "escaping the house did not start the yard")
local gateKeys = {}
for _, k in keys() do
	if k:GetAttribute("Gate") then
		table.insert(gateKeys, k)
	end
end
check(#gateKeys == Config.GateKeyCount, "expected 3 gate keys, found " .. #gateKeys)
local inGarage = false
for _, k in gateKeys do
	local p = k:GetPivot().Position
	if p.X < -16 * U + 14 * U and p.Z < -14 * U + 15 * U then
		inGarage = true
	end
end
check(inGarage, "no gate key in the garage")
local gate = world:FindFirstChild("Yard"):FindFirstChild("Gate")
check(gate ~= nil and gate.CanCollide == true, "the gate is not locked")
local cams = {}
for _, m in world:FindFirstChild("Yard"):FindFirstChild("Cameras"):GetChildren() do
	if m.Name == "Cam" then
		table.insert(cams, m)
	end
end
check(#cams == 5, "expected 5 cameras, found " .. #cams)

-- Right after the door Pianka is safe, the exit clip plays
run(Config.ExitClipTime + 1)
check(workspace:GetAttribute("State") == "play", "caught while standing at the door")

-- Behind a wall the camera can not see her
local cam = cams[1]
local eye = cam:FindFirstChild("Camera").Position
local function inView(distance: number): any
	local look = Watch.look(cam:GetAttribute("Yaw"), cam:GetAttribute("Phase"), workspace:GetServerTimeNow())
	return Vector3.new(eye.X, 1.4, eye.Z) + look * distance
end
local blocker = Engine.new("Part")
blocker.Anchored = true
blocker.Size = Vector3.new(80, 80, 80)
blocker.Parent = workspace
for _ = 1, 30 do
	local spot = inView(30)
	blocker.CFrame = Engine.CFrame.new(eye:Lerp(spot, 0.5) - Vector3.new(0, 30, 0))
	teleport(ana, spot)
	Engine.step(DT)
end
check(workspace:GetAttribute("State") == "play", "a camera saw through a wall")
blocker:Destroy()
teleport(ana, outside)
run(2)

-- In the light: spotted, mom's phone, back to bed, everything starts over
local caught = false
for _ = 1, 40 do
	teleport(ana, inView(30))
	Engine.step(DT)
	if workspace:GetAttribute("State") == "caught" then
		caught = true
		break
	end
end
check(caught, "standing in a camera cone was not spotted")
run(Config.SpottedTime + 1)
check(workspace:GetAttribute("Stage") == "house" and workspace:GetAttribute("Keys") == 0, "being spotted did not restart the round")
check(nearBed(ana) and ana:GetAttribute("Out") == nil, "being spotted did not send Pianka back to bed")
check(gate.CanCollide == true and #keys() == 3, "the yard was not reset after being spotted")

-- All the way out: house keys, gate keys and through the gate
escapeHouse(ana)
for _, k in keys() do
	if k:GetAttribute("Gate") then
		teleport(ana, k:GetPivot().Position)
		run(0.3)
	end
end
check(workspace:GetAttribute("GateKeys") == Config.GateKeyCount, "could not collect the gate keys, got " .. tostring(workspace:GetAttribute("GateKeys")))
run(3)
check(gate.CanCollide == false, "the gate did not open")
local through = gate.Position + Vector3.new(0, 1.4, 12)
teleport(ana, through)
run(0.5)
check(workspace:GetAttribute("State") == "won", "walking through the open gate did not win")
run(Config.WinRestart + 2)
check(workspace:GetAttribute("Keys") == 0 and workspace:GetAttribute("Stage") == "house" and nearBed(ana), "the round did not restart after the escape")

for _, e in Engine.errors do
	failures += 1
	print(string.format("SCRIPT ERROR x%d: %s", e.count, e.msg))
	print(e.trace)
end
print(string.format("Pianka the Escape playtest: %d walls, %d windows, %d sleepers, %d toys, %d keys, %d cameras", counts.Wall or 0, counts.Window or 0, #sleepers, #toys, 3, #cams))
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
