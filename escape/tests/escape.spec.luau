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
		module.TenseId = 97
		module.DreamId = 96
		-- The bots escape fast
		module.MinRunTime = 30
		-- Test the peeking rule too
		module.LookWakes = true
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
-- One key in each bedroom upstairs
local floorParts = {}
for _, d in world:GetDescendants() do
	if d.Name == "Floor" then
		table.insert(floorParts, d)
	end
end
local keyRooms: { [string]: boolean } = {}
for _, k in keys() do
	local hit = Engine.raycast(k:GetPivot().Position, Vector3.new(0, -10, 0), { FilterType = roblox.Enum.RaycastFilterType.Include, FilterDescendantsInstances = floorParts })
	local room = hit and hit.Instance:GetAttribute("Room")
	if type(room) == "string" then
		keyRooms[room] = true
	end
end
check(keyRooms.kid == true and keyRooms.girl == true and keyRooms.mom == true, "the keys are not one in each bedroom")

local function teleport(player: any, pos: any)
	local r = root(player)
	if r then
		r.CFrame = Engine.CFrame.new(pos)
	end
end

-- The garage: the button outside opens the door, it closes slowly, the button inside opens it again
local yardFolder = world:FindFirstChild("Yard")
local garageDoor = yardFolder:FindFirstChild("GarageDoor")
local outsideButton, insideButton = nil, nil
for _, p in yardFolder:GetChildren() do
	if p.Name == "GarageButton" then
		if p.CanCollide then
			outsideButton = p
		else
			insideButton = p
		end
	end
end
check(garageDoor ~= nil and garageDoor.CanCollide == true, "the garage door is not closed")
check(outsideButton ~= nil and insideButton ~= nil, "garage buttons missing")
if garageDoor and outsideButton and insideButton then
	local closedHeight = garageDoor.Size.Y
	teleport(bo, outsideButton.Position - Vector3.new(0, 3.4, 0))
	run(0.2)
	check(workspace:GetAttribute("Garage") == "opening", "the outside button did not open the garage")
	teleport(bo, bed + Vector3.new(3, 0, 0))
	run(Config.GarageOpenTime + 0.2)
	check(garageDoor.CanCollide == false and garageDoor.Size.Y < closedHeight / 2, "the garage door did not roll up")
	run(Config.GarageHold + Config.GarageCloseTime * 0.5)
	check(workspace:GetAttribute("Garage") == "closing", "the garage door does not close slowly")
	run(Config.GarageCloseTime * 0.5 + 0.5)
	check(workspace:GetAttribute("Garage") == "closed" and garageDoor.CanCollide == true, "the garage door did not close")
	teleport(bo, insideButton.Position - Vector3.new(0, 2.6, 0))
	run(0.2)
	check(workspace:GetAttribute("Garage") == "opening", "the inside button did not open the garage")
	teleport(bo, bed + Vector3.new(3, 0, 0))
	run(Config.GarageOpenTime + Config.GarageHold + Config.GarageCloseTime + 1)
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
-- One squeak upstairs is enough: the closest sleeper wakes up at once
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
	check(closest ~= nil, "no toy upstairs")
	if closest then
		local at = closest.PrimaryPart.Position
		teleport(bo, Vector3.new(at.X, Config.Floor2 + 1.4, at.Z))
		run(0.3)
		woke = workspace:GetAttribute("State") == "caught" and root(bo).Anchored
		run(Config.CaughtTime + 1)
	end
end
check(woke, "one squeak upstairs did not wake anyone")
run(1)
check(workspace:GetAttribute("Keys") == 0, "keys were not taken back after a wake up")
check(#keys() == 3, "keys were not put back after a wake up")
check(nearBed(ana) and nearBed(bo), "players were not sent back to bed after a wake up")
check(not root(bo).Anchored, "players stay frozen after a wake up")

-- Downstairs a squeak only gets a grumble from upstairs
local downToy = nil
for _, t in toys do
	if t.PrimaryPart.Position.Y < Config.Floor2 - 3 then
		downToy = t
	end
end
if downToy then
	teleport(bo, downToy.PrimaryPart.Position + Vector3.new(0, 1.4, 0))
	run(0.3)
	check(workspace:GetAttribute("State") == "play", "a squeak downstairs woke someone")
	teleport(bo, bed + Vector3.new(3, 0, 0))
	run(0.5)
end

-- Sleepers stir: a snort, then they look around. Standing still is safe, moving wakes them
local kid = nil
for _, s in sleepers do
	if s:GetAttribute("Sleeper") == "Patrick" then
		kid = s
	end
end
if kid then
	local head = kid:FindFirstChild("Head").Position
	local spot = Vector3.new(head.X - 10, Config.Floor2 + 1.4, head.Z)
	local phases: { [string]: boolean } = {}
	teleport(ana, spot)
	for _ = 1, math.ceil((Config.StirEvery[2] + 12) / DT) do
		Engine.step(DT)
		phases[kid:GetAttribute("Stir")] = true
		if kid:GetAttribute("Stir") == "look" then
			break
		end
	end
	check(phases.warn == true and phases.look == true, "the kid never snorted and looked around")
	local eyes = 0
	for _, p in kid:GetDescendants() do
		if p.Name == "EyeOpen" and p.Transparency == 0 then
			eyes += 1
		end
	end
	check(eyes > 0, "the kid looks around with closed eyes")
	run(Config.StirTime * 0.5)
	check(workspace:GetAttribute("State") == "play", "standing still while the kid looked woke him")
	-- Next time he looks, move a moment and stop: it builds up, drains, and he sleeps on
	-- The next time he looks into the room, not at the wall by his bed
	local function nextLook(): Vector3
		local facing = Vector3.zero
		for _ = 1, 4 do
			for _ = 1, math.ceil((Config.StirEvery[2] + 12) / DT) do
				Engine.step(DT)
				if kid:GetAttribute("Stir") == "look" then
					break
				end
			end
			run(0.4)
			facing = kid:GetAttribute("Facing")
			if facing.X > 0 then
				break
			end
			run(Config.StirTime)
		end
		return facing
	end
	local facing = nextLook()
	spot = Vector3.new(head.X, Config.Floor2 + 1.4, head.Z) + facing * 9
	for i = 1, 14 do
		teleport(ana, spot - facing * i * 0.2)
		Engine.step(DT)
	end
	check(((ana:GetAttribute("Tension") :: number?) or 0) > 0, "moving while the kid looked did not build up")
	run(Config.StirTime)
	check(workspace:GetAttribute("State") == "play", "a short move while the kid looked woke him")
	check(((ana:GetAttribute("Tension") :: number?) or 0) == 0, "standing still did not calm it down")
	-- Next time keep moving: after a moment he wakes up
	facing = nextLook()
	spot = Vector3.new(head.X, Config.Floor2 + 1.4, head.Z) + facing * 9
	for i = 1, 60 do
		teleport(ana, spot - facing * i * 0.15)
		Engine.step(DT)
		if workspace:GetAttribute("State") == "caught" then
			break
		end
	end
	check(workspace:GetAttribute("State") == "caught", "moving while the kid looked did not wake him")
	run(Config.CaughtTime + 1.5)
	check(workspace:GetAttribute("State") == "play" and kid:GetAttribute("Stir") == "sleep", "the round did not reset after the kid woke")
end

-- Small things on the floor: jumping over them is quiet, stepping on one wakes someone
local small = {}
for _, t in toys do
	if Config.Toys[t:GetAttribute("Toy")].small then
		small[t:GetAttribute("Toy")] = t
	end
end
check(small.controller ~= nil and small.blocks ~= nil, "no controllers or toy blocks in the kid's room")
check(small.lipstick ~= nil and small.perfume ~= nil, "no lipsticks or perfume in mom's room")
if small.controller then
	local c = small.controller.PrimaryPart.Position
	teleport(ana, Vector3.new(c.X, Config.Floor2 + 5, c.Z))
	run(0.2)
	check(workspace:GetAttribute("State") == "play", "jumping over the controller made noise")
	teleport(ana, Vector3.new(c.X, Config.Floor2 + 1.4, c.Z))
	run(0.3)
	check(workspace:GetAttribute("State") == "caught", "stepping on the controller woke nobody")
	run(Config.CaughtTime + 1.5)
end

-- The kid's TV still plays the game
local screen = nil
for _, d in world:GetDescendants() do
	if d.Name == "GameScreen" then
		screen = d
	end
end
check(screen ~= nil and screen:FindFirstChildOfClass("SurfaceGui") ~= nil, "the kid's TV shows no game")

-- The stairs are solid from the side
check((counts.StairSide or 0) > 10 and (counts.StairEnd or 0) == 1, "the stairs can be walked into from the side")

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
local inBackRoom = false
for _, k in gateKeys do
	local p = k:GetPivot().Position
	if p.X > -16 * U + 10 * U and p.X < -16 * U + 13 * U and p.Z > -14 * U + 3 * U and p.Z < -14 * U + 7 * U then
		inBackRoom = true
	end
end
check(inBackRoom, "no gate key in the garage back room")
local gate = world:FindFirstChild("Yard"):FindFirstChild("Gate")
check(gate ~= nil and gate.CanCollide == true, "the gate is not locked")
-- Nothing gets over the fence or the gate: invisible walls go up high above them
local caps = {}
for _, d in world:FindFirstChild("Yard"):GetChildren() do
	if d.Name == "Boundary" then
		table.insert(caps, d)
	end
end
local function capOverGate(): any
	for _, c in caps do
		if math.abs(c.Position.X - gate.Position.X) < 1 and math.abs(c.Position.Z - gate.Position.Z) < 1 then
			return c
		end
	end
	return nil
end
check(#caps >= 4 and capOverGate() ~= nil and capOverGate().CanCollide and capOverGate().Size.Y > 60, "the fence or gate can be jumped over")
local cams = {}
for _, m in world:FindFirstChild("Yard"):FindFirstChild("Cameras"):GetChildren() do
	if m.Name == "Cam" then
		table.insert(cams, m)
	end
end
check(#cams == 9, "expected 9 cameras, found " .. #cams)

-- Right after the door Pianka is safe, the exit clip plays
run(Config.ExitClipTime + 1)
check(workspace:GetAttribute("State") == "play", "caught while standing at the door")

-- Behind a wall the camera can not see her
local cam = cams[1]
local eye = cam:FindFirstChild("Camera").Position
local function inView(distance: number): any
	local look = Watch.look(cam:GetAttribute("Yaw"), cam:GetAttribute("Phase"), workspace:GetServerTimeNow(), cam:GetAttribute("Period"))
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
check(gate.CanCollide == false and not capOverGate().CanCollide, "the gate did not open")
local through = gate.Position + Vector3.new(0, 1.4, 12)
teleport(ana, through)
run(0.5)
check(workspace:GetAttribute("State") == "won", "walking through the open gate did not win")
-- The run is timed: best times are saved, shown in the player list and on the end card
run(Config.EndingTime + 3)
local best = Engine.stores["ordered:EscapeBestTimes"] or {}
check(best[tostring(ana.UserId)] ~= nil, "the escape time was not saved")
local stats = ana:FindFirstChild("leaderstats")
check(stats ~= nil and stats:FindFirstChild("⏱️") ~= nil and stats["⏱️"].Value ~= "-", "the best time is not in the player list")
check(ana.PlayerGui.Escape:FindFirstChild("Again", true) ~= nil, "no end card with a play again button")
run(Config.WinRestart - Config.EndingTime)
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
