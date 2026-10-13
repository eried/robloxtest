-- Bot playtests for dogs, neighbors and hearts. Run: lune run tests/dogs.spec.luau [rounds] [mode]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Vector3 = roblox.Vector3
local env = { Vector3 = Vector3, Color3 = roblox.Color3 }

local function load(path: string): any
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end

local DogBrain = load("src/shared/DogBrain.luau")
local Sky = load("src/shared/Sky.luau")
local Config = load("src/shared/Config.luau")

local ROUNDS = tonumber(process.args[1]) or 200
local ONLY = process.args[2]
local DT = 1 / 30
local HALF = Config.ForestSize / 2
local HOME = Vector3.new(Config.HomePosition.X, 0, Config.HomePosition.Z)
local SPAWN = Vector3.new(0, 0, 0)

local seed = 84
local function random(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function rand(a: number, b: number): number
	return a + random() * (b - a)
end

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		if failures <= 10 then
			print("FAIL: " .. message)
		end
	end
end

local function isNan(v: Vector3): boolean
	return v.X ~= v.X or v.Z ~= v.Z
end

local function makeWorld()
	local trees, cabins = {}, {}
	while #cabins < Config.NeighborCount do
		local p = Vector3.new(rand(-HALF + 30, HALF - 30), 0, rand(-HALF + 30, HALF - 30))
		local ok = p.Magnitude > 80
		for _, c in cabins do
			if (c - p).Magnitude < 110 then
				ok = false
			end
		end
		if ok then
			table.insert(cabins, p)
		end
	end
	for _ = 1, Config.TreeCount * 5 do
		if #trees >= Config.TreeCount then
			break
		end
		local p = Vector3.new(rand(-HALF + 5, HALF - 5), 0, rand(-HALF + 5, HALF - 5))
		local ok = p.Magnitude > Config.SpawnClearRadius
		for _, t in trees do
			if (t - p).Magnitude < 9 then
				ok = false
				break
			end
		end
		for _, c in cabins do
			if (c - p).Magnitude < 19 then
				ok = false
			end
		end
		if ok then
			table.insert(trees, p)
		end
	end
	local world = { trees = trees, cabins = cabins, half = HALF }
	DogBrain.index(world)
	return world
end

local function isFree(world, p: Vector3, radius: number): boolean
	for _, t in DogBrain.treesNear(world, p, p, radius) do
		if (t - p).Magnitude < radius then
			return false
		end
	end
	for _, c in world.cabins do
		if (c - p).Magnitude < radius + 10 then
			return false
		end
	end
	return true
end

local function randomCatSpot(world, mode: string): Vector3
	for _ = 1, 300 do
		local p = Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
		if (p - HOME).Magnitude >= Config.CatDistance[mode] and isFree(world, p, 5) then
			return p
		end
	end
	return Vector3.new(200, 0, 200)
end

local function fleeSpot(world, cat: Vector3, from: Vector3): Vector3?
	local away = cat - from
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
	for i = 1, 16 do
		local spread = if i <= 6 then 0.8 else math.pi
		local a = rand(-spread, spread)
		local dir = Vector3.new(away.X * math.cos(a) - away.Z * math.sin(a), 0, away.X * math.sin(a) + away.Z * math.cos(a))
		local p = cat + dir * rand(40, 60)
		if math.abs(p.X) < HALF - 15 and math.abs(p.Z) < HALF - 15 and (p - HOME).Magnitude >= Config.MinCatDistance and isFree(world, p, 5) then
			return p
		end
	end
	return nil
end

local function dropSpot(world, from: Vector3): Vector3
	for _ = 1, 30 do
		local a = rand(0, math.pi * 2)
		local p = from + Vector3.new(math.cos(a), 0, math.sin(a)) * rand(40, 60)
		if math.abs(p.X) < HALF - 15 and math.abs(p.Z) < HALF - 15 and (p - HOME).Magnitude > 50 and isFree(world, p, 5) then
			return p
		end
	end
	return from
end

local function kittenSpots(world, center: Vector3): { Vector3 }
	local spots = {}
	for _ = 1, Config.KittenCount do
		local found = nil
		for _ = 1, 200 do
			local a = rand(0, math.pi * 2)
			local p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * rand(40, 160)
			local ok = math.abs(p.X) < HALF - 10 and math.abs(p.Z) < HALF - 10 and (p - HOME).Magnitude >= Config.KittenHomeMin and isFree(world, p, 4)
			for _, other in spots do
				if (other - p).Magnitude < 25 then
					ok = false
				end
			end
			if ok then
				found = p
				break
			end
		end
		table.insert(spots, found or Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15)))
	end
	return spots
end

local function makeMud(count: number, catPos: Vector3)
	local mud = {}
	for _ = 1, count do
		local p = Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
		local r = rand(6, 10)
		if (p - HOME).Magnitude > Config.RatSafeRadius + r and (p - catPos).Magnitude > r + 8 then
			table.insert(mud, { pos = p, radius = r })
		end
	end
	return mud
end

local function makeBirds(world, mode: string, catPos: Vector3, hero: string): { Vector3 }
	local birds = {}
	local count = Config.BirdCount[mode] + (if hero == "Aurelia" then 2 else 0)
	for i = 1, count do
		local along = 0.3 + 0.55 * (i - 0.5) / count
		for _ = 1, 30 do
			local try = HOME:Lerp(catPos, along + rand(-0.04, 0.04)) + Vector3.new(rand(-10, 10), 0, rand(-10, 10))
			if math.abs(try.X) < HALF - 10 and math.abs(try.Z) < HALF - 10 and (try - HOME).Magnitude > Config.RatSafeRadius and isFree(world, try, 3) then
				table.insert(birds, try)
				break
			end
		end
	end
	return birds
end

local function makeRats(world, mode: string, catPos: Vector3, level: number)
	local rats = {}
	for i = 1, Config.RatCount[mode] + (level - 1) * Config.Level.rats do
		local pos = Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
		for _ = 1, 40 do
			local try = if i % 2 == 0
				then catPos + Vector3.new(rand(-80, 80), 0, rand(-80, 80))
				else Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
			if math.abs(try.X) < HALF - 10 and math.abs(try.Z) < HALF - 10 and (try - HOME).Magnitude > Config.RatSafeRadius + 40
				and (try - catPos).Magnitude > 20 and isFree(world, try, 4) then
				pos = try
				break
			end
		end
		table.insert(rats, { nest = pos, pos = pos, wander = pos, cooldown = 0, windup = 0, speed = Config.RatSpeed[mode] })
	end
	return rats
end

-- Same as the game: Pianka hides in one of several spots around her
local function hideSpots(world, cat: Vector3, level: number, mode: string): { Vector3 }
	local count = math.min(8, Config.HideSpots[mode] + (level - 1) // Config.Level.spotsEvery)
	local spots = { cat }
	for _ = 1, 120 do
		if #spots >= count then
			break
		end
		local a = rand(0, math.pi * 2)
		local try = cat + Vector3.new(math.cos(a), 0, math.sin(a)) * rand(10, 26)
		local ok = math.abs(try.X) < HALF - 10 and math.abs(try.Z) < HALF - 10 and isFree(world, try, 4)
		for _, other in spots do
			if (other - try).Magnitude < 8 then
				ok = false
			end
		end
		if ok then
			table.insert(spots, try)
		end
	end
	return spots
end

local function makeBones(world, mode: string, catPos: Vector3): { Vector3 }
	local bones = {}
	local count = Config.BoneCount[mode]
	for i = 1, count do
		for _ = 1, 30 do
			local try = HOME:Lerp(catPos, (i - 0.5) / count * 0.9) + Vector3.new(rand(-30, 30), 0, rand(-30, 30))
			if math.abs(try.X) < HALF - 10 and math.abs(try.Z) < HALF - 10 and (try - HOME).Magnitude > 20 and isFree(world, try, 3) then
				table.insert(bones, try)
				break
			end
		end
	end
	return bones
end

-- Same as the game: lands toward the closest dog, every guard dog near it goes to eat. The pack ignores bones.
local function throwBone(pos: Vector3, heading: Vector3, dogs, now: number): number
	local land = pos + heading * 14
	local closest = Config.BoneReach
	for _, dog in dogs do
		local d = (dog.pos - pos).Magnitude
		if not dog.hunter and dog.kind ~= "pack" and dog.state ~= "bone" and d < closest and d > 1 then
			closest = d
			land = pos + (dog.pos - pos).Unit * math.min(14, d * 0.6)
		end
	end
	land = Vector3.new(math.clamp(land.X, -HALF + 5, HALF - 5), 0, math.clamp(land.Z, -HALF + 5, HALF - 5))
	local fooled = 0
	for _, dog in dogs do
		if not dog.hunter and dog.kind ~= "pack" and dog.state ~= "bone" and (dog.pos - land).Magnitude < Config.BoneReach then
			DogBrain.distract(dog, land, now, Config.BoneEat)
			fooled += 1
		end
	end
	return fooled
end

-- Same rules as the rats in the game. Returns true on a bite.
local function ratStep(rat, bot, alive: boolean, world): boolean
	local now = bot.time
	local d = (bot.pos - rat.pos).Magnitude
	local safe = (bot.pos - HOME).Magnitude < Config.RatSafeRadius
	local hunting = alive and d < Config.RatAggro and (bot.pos - rat.nest).Magnitude < Config.RatLeash and not safe
	local goal, speed = nil, 0
	local bit = false
	if hunting and now > rat.cooldown then
		speed = math.min(rat.speed, bot.speed * 0.8)
		if d < 2.8 then
			speed = 0
			if rat.windup == 0 then
				rat.windup = now + 0.3
			elseif now >= rat.windup then
				rat.windup = 0
				rat.cooldown = now + 3
				if now - bot.lastBite >= 2.5 then
					bot.lastBite = now
					bit = true
				end
			end
		else
			rat.windup = 0
			goal = bot.pos
		end
	else
		rat.windup = 0
		if (rat.wander - rat.pos).Magnitude < 1 then
			rat.wander = rat.nest + Vector3.new(rand(-15, 15), 0, rand(-15, 15))
		end
		goal, speed = rat.wander, 5
	end
	if goal and speed > 0 then
		local delta = goal - rat.pos
		if delta.Magnitude > 0.05 then
			local nextPos = rat.pos + delta.Unit * math.min(speed * DT, delta.Magnitude)
			for _, t in DogBrain.treesNear(world, nextPos, nextPos, 3) do
				local away = nextPos - t
				if away.Magnitude < 2 and away.Magnitude > 0.01 then
					nextPos = t + away.Unit * 2
				end
			end
			rat.pos = Vector3.new(math.clamp(nextPos.X, -HALF + 3, HALF - 3), 0, math.clamp(nextPos.Z, -HALF + 3, HALF - 3))
		end
	end
	return bit
end

-- Distance between two segments on the ground
local function segmentGap(p1: Vector3, p2: Vector3, a: Vector3, b: Vector3): number
	local function cross(o: Vector3, u: Vector3, v: Vector3): number
		return (u.X - o.X) * (v.Z - o.Z) - (u.Z - o.Z) * (v.X - o.X)
	end
	local d1, d2 = cross(a, b, p1), cross(a, b, p2)
	local d3, d4 = cross(p1, p2, a), cross(p1, p2, b)
	if d1 * d2 < 0 and d3 * d4 < 0 then
		return 0
	end
	local function toSeg(p: Vector3, s0: Vector3, s1: Vector3): number
		local d = s1 - s0
		local t = if d:Dot(d) > 1e-6 then math.clamp((p - s0):Dot(d) / d:Dot(d), 0, 1) else 0
		return (s0 + d * t - p).Magnitude
	end
	return math.min(toSeg(p1, a, b), toSeg(p2, a, b), toSeg(a, p1, p2), toSeg(b, p1, p2))
end

-- Path finding on a coarse grid, used when a hedge is in the way (players see hedges and walk around)
local CELL = 5
local SIDE = math.floor(HALF * 2 / CELL)

local function cellOf(p: Vector3): (number, number)
	return math.clamp(math.floor((p.X + HALF) / CELL), 0, SIDE - 1), math.clamp(math.floor((p.Z + HALF) / CELL), 0, SIDE - 1)
end

local function centerOf(x: number, z: number): Vector3
	return Vector3.new(x * CELL - HALF + CELL / 2, 0, z * CELL - HALF + CELL / 2)
end

local function buildGrid(world)
	local blocked = {}
	local function mark(p: Vector3, radius: number)
		local x0, z0 = cellOf(p - Vector3.new(radius, 0, radius))
		local x1, z1 = cellOf(p + Vector3.new(radius, 0, radius))
		for x = x0, x1 do
			for z = z0, z1 do
				if (centerOf(x, z) - p).Magnitude < radius + CELL * 0.35 then
					blocked[x * SIDE + z] = true
				end
			end
		end
	end
	for _, t in world.trees do
		mark(t, 2.2)
	end
	for _, c in world.cabins do
		mark(c, 9)
	end
	world.blocked = blocked
end

local function astar(world, from: Vector3, goal: Vector3): { Vector3 }?
	local blocked = world.blocked
	local sx, sz = cellOf(from)
	local gx, gz = cellOf(goal)
	-- A goal inside a blocked cell (next to a hedge): aim for the closest open cell to it
	if blocked[gx * SIDE + gz] then
		local best = math.huge
		local bx, bz = gx, gz
		for dx = -3, 3 do
			for dz = -3, 3 do
				local nx, nz = gx + dx, gz + dz
				if nx >= 0 and nz >= 0 and nx < SIDE and nz < SIDE and not blocked[nx * SIDE + nz] then
					local d = (centerOf(nx, nz) - goal).Magnitude
					if d < best then
						best, bx, bz = d, nx, nz
					end
				end
			end
		end
		gx, gz = bx, bz
	end
	local start, target = sx * SIDE + sz, gx * SIDE + gz
	local heap, cost, came = { start }, { [start] = 0 }, {}
	local score = { [start] = 0 }
	local function push(id: number)
		table.insert(heap, id)
		local i = #heap
		while i > 1 do
			local parent = i // 2
			if score[heap[parent]] <= score[heap[i]] then
				break
			end
			heap[parent], heap[i] = heap[i], heap[parent]
			i = parent
		end
	end
	local function pop(): number
		local top = heap[1]
		heap[1] = heap[#heap]
		heap[#heap] = nil
		local i = 1
		while true do
			local l, r, small = i * 2, i * 2 + 1, i
			if l <= #heap and score[heap[l]] < score[heap[small]] then
				small = l
			end
			if r <= #heap and score[heap[r]] < score[heap[small]] then
				small = r
			end
			if small == i then
				break
			end
			heap[small], heap[i] = heap[i], heap[small]
			i = small
		end
		return top
	end
	local steps = 0
	while #heap > 0 and steps < 6000 do
		steps += 1
		local id = pop()
		if id == target then
			local path = {}
			while id do
				table.insert(path, 1, centerOf(id // SIDE, id % SIDE))
				id = came[id]
			end
			path[#path] = goal
			return path
		end
		local x, z = id // SIDE, id % SIDE
		for dx = -1, 1 do
			for dz = -1, 1 do
				local nx, nz = x + dx, z + dz
				if (dx ~= 0 or dz ~= 0) and nx >= 0 and nz >= 0 and nx < SIDE and nz < SIDE then
					local n = nx * SIDE + nz
					local corner = dx ~= 0 and dz ~= 0 and (blocked[nx * SIDE + z] or blocked[x * SIDE + nz])
					if (not blocked[n] or n == target) and not corner then
						local c = cost[id] + (if dx ~= 0 and dz ~= 0 then 1.414 else 1)
						if cost[n] == nil or c < cost[n] then
							cost[n], came[n] = c, id
							score[n] = c + math.sqrt((nx - gx) ^ 2 + (nz - gz) ^ 2)
							push(n)
						end
					end
				end
			end
		end
	end
	return nil
end

local function hedgeInWay(world, from: Vector3, goal: Vector3, margin: number): boolean
	for _, h in world.hedges or {} do
		if segmentGap(from, goal, h.a, h.b) < margin then
			return true
		end
	end
	return false
end

-- Straight to the goal, or along a planned path when a hedge is in the way
local function steer(bot, world, goal: Vector3): Vector3
	-- Keep a path until the way is clearly open, so bots do not flip at hedge ends
	local following = bot.path ~= nil and (bot.pathGoal - goal).Magnitude <= 3
	if not hedgeInWay(world, bot.pos, goal, if following then 6 else 3) then
		bot.path = nil
		return goal
	end
	local path = bot.path
	local node = path and path[bot.pathIndex]
	local off = node and (node - bot.pos).Magnitude or math.huge
	local stuck = node and bot.time - bot.nodeTime > 3
	if not path or (bot.pathGoal - goal).Magnitude > 3 or off > 12 or stuck then
		path = astar(world, bot.pos, goal)
		bot.path, bot.pathGoal, bot.pathIndex = path, goal, 1
		bot.nodeBest, bot.nodeTime = math.huge, bot.time
	end
	if not path then
		return goal
	end
	while bot.pathIndex < #path and (path[bot.pathIndex] - bot.pos).Magnitude < 4 do
		bot.pathIndex += 1
		bot.nodeBest, bot.nodeTime = math.huge, bot.time
	end
	local d = (path[bot.pathIndex] - bot.pos).Magnitude
	if d < bot.nodeBest - 0.5 then
		bot.nodeBest, bot.nodeTime = d, bot.time
	end
	return path[bot.pathIndex]
end

-- A bot player. "naive" walks straight, "careful" steers around cones, "kid" wanders like a searching player.
local function botStep(bot, goal: Vector3, dogs, world, mud, careful: boolean)
	if bot.kid and (goal - bot.pos).Magnitude > 40 then
		if bot.time >= bot.wanderUntil or (bot.wander - bot.pos).Magnitude < 5 then
			local a = rand(-1, 1)
			local u = (goal - bot.pos).Unit
			bot.wander = bot.pos + Vector3.new(u.X * math.cos(a) - u.Z * math.sin(a), 0, u.X * math.sin(a) + u.Z * math.cos(a)) * 60
			bot.wanderUntil = bot.time + 8
		end
		goal = bot.wander
	end
	goal = steer(bot, world, goal)
	local toGoal = goal - bot.pos
	local desire = if toGoal.Magnitude > 0.01 then toGoal.Unit else Vector3.new(1, 0, 0)
	local nearTrees = DogBrain.treesNear(world, bot.pos, bot.pos, 5)
	for _, t in nearTrees do
		local away = bot.pos - t
		local m = away.Magnitude
		if m < 4 and m > 0.01 then
			desire += away / m * (4 - m) * 0.6
		end
	end
	for _, c in world.cabins do
		local away = bot.pos - c
		local m = away.Magnitude
		if m < 13 and m > 0.01 then
			desire += away / m * (13 - m) * 0.3
		end
	end
	if careful and not bot.dash then
		local threat = nil
		for _, dog in dogs do
			if (dog.state == "alert" or dog.state == "chase" or dog.state == "lunge") and (dog.pos - bot.pos).Magnitude < 30 then
				threat = dog
			end
		end
		if threat then
			local away = bot.pos - threat.pos
			if away.Magnitude > 0.01 then
				desire = away.Unit * 3 + desire * 0.5
			end
		else
			local ahead = bot.pos + desire * 10
			for _, dog in dogs do
				local s = dog.settings
				for _, probe in { bot.pos, ahead } do
					local away = probe - dog.pos
					local m = away.Magnitude
					local range = if dog.kind == "pack" then s.packConeRange + 4 else s.coneRange + 6
					if m > 0.01 and m < range and dog.dir:Dot(-away / m) > math.cos(math.rad(s.coneAngle + 20)) then
						local side = Vector3.new(-away.Z, 0, away.X) / m
						if side:Dot(desire) < 0 then
							side = -side
						end
						desire += (away / m + side * 1.5) * (range - m) / range * 3
					end
				end
			end
		end
	end
	local speed = bot.walk
	for _, puddle in mud do
		if (bot.pos - puddle.pos).Magnitude < puddle.radius then
			speed *= 0.55
		end
	end
	if bot.slowUntil > bot.time then
		speed *= 0.6
	end
	local dir = if desire.Magnitude > 0.01 then desire.Unit else Vector3.new(1, 0, 0)
	local nextPos = bot.pos + dir * speed * DT
	for _, t in nearTrees do
		local away = nextPos - t
		local m = away.Magnitude
		if m < 2 and m > 0.01 then
			nextPos = t + away / m * 2
		end
	end
	for _, c in world.cabins do
		local away = nextPos - c
		local m = away.Magnitude
		if m < 8 and m > 0.01 then
			nextPos = c + away / m * 8
		end
	end
	nextPos = Vector3.new(math.clamp(nextPos.X, -HALF + 2, HALF - 2), 0, math.clamp(nextPos.Z, -HALF + 2, HALF - 2))
	local moved = nextPos - bot.pos
	if moved.Magnitude > 0.02 then
		bot.heading = moved.Unit
	end
	bot.pos = nextPos
	bot.speed = speed
end

local function checkDogs(dogs, world)
	for _, dog in dogs do
		check(not isNan(dog.pos) and not isNan(dog.dir), "dog position is NaN")
		check(math.abs(dog.pos.X) <= world.half and math.abs(dog.pos.Z) <= world.half, "dog left the map")
		check(math.abs(dog.dir.Magnitude - 1) < 0.05, "dog direction not unit")
		if dog.kind == "patrol" and dog.state == "patrol" then
			local ab = dog.b - dog.a
			local t = math.clamp((dog.pos - dog.a):Dot(ab) / ab:Dot(ab), 0, 1)
			local off = (dog.a + ab * t - dog.pos).Magnitude
			check(off < 3.5, "patrol wandered off its path by " .. string.format("%.1f", off))
		end
	end
end

local function makePatrols(world, catPos: Vector3, s)
	local dogs = {}
	local paths = DogBrain.patrolPaths(rand, world, catPos, HOME, s.patrolCount, Config.RatSafeRadius, s.lines)
	for _, path in paths do
		local dog = DogBrain.newPatrol(path.a, path.b)
		dog.pos = path.a:Lerp(path.b, rand(0, 1))
		dog.settings = s
		table.insert(dogs, dog)
	end
	return dogs, #paths
end

local function makeHunters(world, hs)
	local hunters = {}
	for _, cabin in world.cabins do
		local path = DogBrain.yardPath(rand, world, cabin, HOME, Config.RatSafeRadius)
		if path then
			check((path.a - cabin).Magnitude > 9 and (path.b - cabin).Magnitude > 9, "yard path hits its cabin")
			local h = DogBrain.newPatrol(path.a, path.b)
			h.pos = path.a:Lerp(path.b, rand(0, 1))
			h.settings = hs
			h.hunter = true
			table.insert(hunters, h)
		end
	end
	return hunters
end

-- One full round. Easy: carry Pianka home. Normal: find 7 kittens in time. Umulig: kittens, then run home.
local function play(mode: string, kind: string, hero: string, level: number?)
	local lv = level or 1
	local careful = kind == "careful"
	local s = DogBrain.forLevel(Config.Dogs[mode], lv, Config.Level)
	local hs = DogBrain.with(s, Config.Hunters[mode])
	local walk = if hero == "Patrick" then Config.PatrickSpeed else 16
	local calm = if hero == "Milenkitka" then 0.92 else 1
	local world = makeWorld()
	local cat = randomCatSpot(world, mode)
	-- Thorn hedges, same rules as the game
	world.hedges = DogBrain.hedges(rand, world, HOME, cat, Config.Hedges[mode], Config.RatSafeRadius)
	for _, h in world.hedges do
		for _, p in DogBrain.hedgePoints(h) do
			table.insert(world.trees, p)
		end
	end
	DogBrain.index(world)
	buildGrid(world)
	local dogs, placed = makePatrols(world, cat, s)
	local hunters = makeHunters(world, hs)
	local mud = makeMud(Config.MudCount[mode], cat)
	local rats = makeRats(world, mode, cat, lv)
	local birds = makeBirds(world, mode, cat, hero)
	local bones = makeBones(world, mode, cat)
	local spots = hideSpots(world, cat, lv, mode)
	local unchecked = table.clone(spots)
	local hidden = true
	local center = Vector3.zero
	for _, spot in spots do
		center += spot
	end
	center = center / #spots + Vector3.new(rand(-5, 5), 0, rand(-5, 5))
	local searching: Vector3? = nil
	local carryTime = math.max(50, Config.CarryTime - (lv - 1) * Config.Level.carryTime)
	local kittenTime = math.max(100, Config.KittenTime - (lv - 1) * Config.Level.kittenTime)
	local bot = {
		pos = SPAWN,
		heading = Vector3.new(1, 0, 0),
		speed = walk,
		walk = walk,
		time = 0,
		slowUntil = 0,
		kid = kind == "kid",
		wander = SPAWN,
		wanderUntil = 0,
		lastBite = -10,
		lastCaught = -10,
		lightOff = false,
		lightUntil = 0,
		bones = 0,
		lastThrow = -10,
	}
	local hearts = Config.Hearts[mode]
	local dayOffset = Sky.offset(Config.DuskClock, Config.DayMinutes, Config.NightShare)
	local hunting = false
	local phase = "find"
	local flees = (if mode == "Easy" then 0 else Config.HardFlees) + (lv - 1) // Config.Level.fleesEvery
	if hero == "Aurelia" then
		flees = math.max(flees - 1, 0)
	end
	local kittens: { Vector3 } = {}
	local carryStart, kittenEnd, packStart = 0, 0, 0
	local r = {
		outcome = "", bites = 0, grabs = 0, ratBites = 0, birds = 0, hiddenTime = 0, time = 0, placed = placed,
		wanted = s.patrolCount, huntShare = 0, searched = 0, thrown = 0, fooled = 0,
	}
	local best, lastProgress, lastGoal = math.huge, 0, Vector3.zero

	local function finish(outcome: string)
		r.outcome = outcome
		r.time = bot.time
		r.huntShare /= math.max(bot.time, 1)
		return r
	end

	while bot.time < 900 do
		bot.time += DT
		local now = bot.time
		local _, daylight = Sky.at(dayOffset + now, Config.DayMinutes, Config.NightShare)
		local hunt = Config.HuntByDay[mode] == true or daylight < 0.5
		if hunt and not hunting then
			for _, h in hunters do
				h.state = "return"
				h.untilTime = now
				h.seeker = false
				h.nextSeek = now + rand(8, 8 + Config.SeekEvery)
			end
			for i = #hunters, 2, -1 do
				local j = math.floor(rand(1, i + 1 - 1e-9))
				hunters[i], hunters[j] = hunters[j], hunters[i]
			end
			for i = 1, math.min(Config.Seekers[mode], #hunters) do
				hunters[i].seeker = true
			end
		end
		hunting = hunt
		if hunt then
			r.huntShare += DT
		end
		local active = table.clone(dogs)
		if hunting then
			for _, h in hunters do
				table.insert(active, h)
			end
		end

		local goal = HOME
		if phase == "find" and hidden then
			-- GPS shows the area. Close by, the spots are visible: search the nearest, kids pick any.
			goal = center
			if (bot.pos - center).Magnitude < 45 then
				if not searching or not table.find(unchecked, searching) then
					searching = unchecked[1]
					for _, spot in unchecked do
						if bot.kid then
							if rand(0, 1) < 0.5 then
								searching = spot
							end
						elseif (spot - bot.pos).Magnitude < (searching - bot.pos).Magnitude then
							searching = spot
						end
					end
				end
				goal = searching
			end
		elseif phase == "find" then
			goal = cat
		elseif phase == "kittens" then
			goal = kittens[1]
			for _, k in kittens do
				if (k - bot.pos).Magnitude < (goal - bot.pos).Magnitude then
					goal = k
				end
			end
		end

		local alive = true
		if bot.bones < 1 and not bot.kid or bot.kid and bot.bones < Config.BoneMax then
			for _, b in bones do
				if (b - bot.pos).Magnitude < (if careful then 22 else 10) and (b - bot.pos).Magnitude < (goal - bot.pos).Magnitude then
					goal = b
				end
			end
		end
		if hearts < Config.Hearts[mode] and phase ~= "escape" then
			for _, b in birds do
				if (b - bot.pos).Magnitude < 25 and (b - bot.pos).Magnitude < (goal - bot.pos).Magnitude then
					goal = b
				end
			end
		end
		-- Stuck behind a guard line: like a player, take the chance and dash through now and then
		local stuck = now - lastProgress
		bot.dash = stuck > 10 and stuck % 8 < 3
		if alive then
			botStep(bot, goal, active, world, mud, careful)
		end
		if hunting and alive and phase ~= "escape" and (bot.pos - HOME).Magnitude >= Config.RatSafeRadius then
			for _, h in hunters do
				if h.seeker and now >= h.nextSeek and (h.state == "patrol" or h.state == "turn") then
					h.nextSeek = now + Config.SeekEvery
					local path = DogBrain.huntPath(rand, world, bot.pos, bot.heading, HOME, Config.RatSafeRadius)
					if path then
						h.a, h.b = path.a, path.b
						h.state = "return"
						h.untilTime = now
						if (h.pos - path.a).Magnitude > 60 then
							h.pos = path.a
							h.graceUntil = now + 1
						end
					end
				end
			end
		end
		local runners = {}
		if alive then
			-- Lantern off at night hides you. Careful bots switch it off near neighbors, kids sometimes.
			local night = daylight < 0.5
			if careful and night then
				local near = false
				for _, h in hunters do
					if (h.pos - bot.pos).Magnitude < 45 then
						near = true
					end
				end
				bot.lightOff = near
			elseif bot.kid and night then
				if now >= bot.lightUntil then
					bot.lightOff = rand(0, 1) < 0.35
					bot.lightUntil = now + rand(8, 20)
				end
			else
				bot.lightOff = false
			end
			if bot.lightOff and night then
				r.hiddenTime += DT
			end
			runners[1] = {
				id = 1,
				pos = bot.pos,
				heading = bot.heading,
				speed = bot.speed * calm,
				safe = (bot.pos - HOME).Magnitude < Config.RatSafeRadius,
				hidden = night and bot.lightOff,
			}
		end
		-- Bones: careful bots throw as soon as a dog is after them, kids only when it is close
		if alive and bot.bones > 0 and now - bot.lastThrow >= 0.8 and kind ~= "naive" then
			for _, dog in active do
				local chasing = dog.target == 1 and (dog.state == "alert" or dog.state == "chase" or dog.state == "lunge")
				local d = (dog.pos - bot.pos).Magnitude
				if not dog.hunter and dog.kind ~= "pack" and chasing and d < (if careful then Config.BoneReach * 0.8 else 10) then
					bot.bones -= 1
					bot.lastThrow = now
					r.thrown += 1
					r.fooled += throwBone(bot.pos, bot.heading, active, now)
					break
				end
			end
		end
		local gap = DogBrain.gap(s, now - packStart)
		for _, dog in active do
			local seen = if now < (dog.graceUntil or 0) then {} else runners
			local event = DogBrain.step(dog, DT, now, seen, world, dog.settings, gap)
			if event == "caught" then
				check((dog.pos - bot.pos).Magnitude < dog.settings.catch + 0.5, "caught from too far")
				if phase == "escape" then
					return finish(if dog.kind == "pack" then "pack" elseif dog.hunter then "hunter" else "patrol")
				end
				if now - bot.lastCaught < 2.5 then
					continue
				end
				bot.lastCaught = now
				if dog.hunter then
					r.grabs += 1
					return finish("grabbed")
				end
				r.bites += 1
				hearts -= 1
				bot.slowUntil = now + 2
				if phase == "carry" then
					phase = "find"
					cat = dropSpot(world, bot.pos)
				end
				if hearts <= 0 then
					return finish("hearts")
				end
				break
			end
		end
		checkDogs(active, world)
		if phase ~= "escape" then
			for _, rat in rats do
				if ratStep(rat, bot, alive, world) then
					r.ratBites += 1
					hearts -= 1
					bot.slowUntil = bot.time + 1.5
					if hearts <= 0 then
						return finish("hearts")
					end
				end
			end
		end

		for i = #bones, 1, -1 do
			if alive and bot.bones < Config.BoneMax and (bones[i] - bot.pos).Magnitude < 4.5 then
				table.remove(bones, i)
				bot.bones += 1
			end
		end
		if alive and hearts < Config.Hearts[mode] then
			for i = #birds, 1, -1 do
				if (birds[i] - bot.pos).Magnitude < 5 and hearts < Config.Hearts[mode] then
					table.remove(birds, i)
					hearts += 1
					r.birds += 1
				end
			end
		end
		if alive and phase == "find" and hidden then
			for i = #unchecked, 1, -1 do
				local spot = unchecked[i]
				if (spot - bot.pos).Magnitude < 6 then
					table.remove(unchecked, i)
					r.searched += 1
					if spot == spots[1] then
						hidden = false
					elseif rand(0, 1) < 0.25 then
						table.insert(rats, { nest = spot, pos = spot, wander = spot, cooldown = now + 1, windup = 0, speed = Config.RatSpeed.Easy })
					end
				end
			end
			check(#unchecked > 0 or not hidden, "real spot must be searchable")
		end
		if alive and not (phase == "find" and hidden) then
			if phase == "find" then
				local d = (bot.pos - cat).Magnitude
				if flees > 0 and d < Config.FleeDistance then
					local spot = fleeSpot(world, cat, bot.pos)
					if spot then
						if #birds < 8 then
							table.insert(birds, cat)
						end
						cat = spot
						flees -= 1
					end
				elseif d < 6 then
					if mode == "Easy" then
						phase = "carry"
						carryStart = now
					else
						phase = "kittens"
						kittens = kittenSpots(world, cat)
						kittenEnd = now + kittenTime
					end
				end
			elseif phase == "carry" then
				if now - carryStart > carryTime then
					return finish("lost")
				elseif (bot.pos - HOME).Magnitude < Config.HomeRadius then
					return finish("won")
				end
			elseif phase == "kittens" then
				for i = #kittens, 1, -1 do
					if (kittens[i] - bot.pos).Magnitude < 6 then
						table.remove(kittens, i)
					end
				end
				if #kittens == 0 then
					if mode ~= "Umulig" then
						return finish("won")
					end
					phase = "escape"
					packStart = now
					for _, other in active do
						if other.state == "alert" or other.state == "chase" then
							other.state = "return"
							other.untilTime = now + 3
						end
					end
					local toHome = HOME - bot.pos
					local heading = if toHome.Magnitude > 1 then toHome.Unit else Vector3.new(0, 0, -1)
					local right = Vector3.new(-heading.Z, 0, heading.X)
					for _, slot in DogBrain.formation(s.packCount) do
						local pos = bot.pos - heading * (s.packGap + 6 + slot.back) + right * slot.side
						pos = Vector3.new(math.clamp(pos.X, -HALF + 5, HALF - 5), 0, math.clamp(pos.Z, -HALF + 5, HALF - 5))
						local dog = DogBrain.newPack(pos, slot.side, slot.back, 1)
						dog.settings = s
						table.insert(dogs, dog)
					end
				elseif now > kittenEnd then
					return finish("timeUp")
				end
			elseif phase == "escape" and (bot.pos - HOME).Magnitude < Config.HomeRadius then
				return finish("won")
			end
		end

		if (goal - lastGoal).Magnitude > 1 then
			best, lastGoal, lastProgress = math.huge, goal, now
		end
		local d = (bot.pos - goal).Magnitude
		if d < best - 1 then
			best, lastProgress = d, now
		elseif now - lastProgress > 45 then
			return finish("stall")
		end
	end
	return finish("stall")
end

-- Unit checks
do
	local world = { trees = {}, cabins = {}, half = HALF }
	local dog = DogBrain.newPatrol(Vector3.new(0, 0, 0), Vector3.new(0, 0, -40))
	check(DogBrain.sees(dog, Vector3.new(0, 0, -10), 18, 30, world), "sees straight ahead")
	check(not DogBrain.sees(dog, Vector3.new(0, 0, 10), 18, 30, world), "does not see behind")
	check(not DogBrain.sees(dog, Vector3.new(15, 0, -5), 18, 30, world), "does not see far to the side")
	check(not DogBrain.sees(dog, Vector3.new(0, 0, -25), 18, 30, world), "does not see past range")
	local blocked = { trees = { Vector3.new(0, 0, -6) }, cabins = {}, half = HALF }
	check(not DogBrain.sees(dog, Vector3.new(0, 0, -12), 18, 30, blocked), "trees block sight")
	check(#DogBrain.formation(6) == 6, "formation size")
	local hs = DogBrain.with(Config.Dogs.Easy, Config.Hunters.Easy)
	check(hs.coneRange == Config.Hunters.Easy.coneRange and hs.packCount == Config.Dogs.Easy.packCount, "settings merge")
	local day = Config.DayMinutes * 60
	local _, afternoon = Sky.at(0, Config.DayMinutes, Config.NightShare)
	local _, midnight = Sky.at(day * (1 - Config.NightShare) * 5 / 12 + day * Config.NightShare / 2, Config.DayMinutes, Config.NightShare)
	check(afternoon > 0.9 and midnight < 0.1, "sky clock")
	local dusk = select(1, Sky.at(Sky.offset(Config.DuskClock, Config.DayMinutes, Config.NightShare), Config.DayMinutes, Config.NightShare))
	check(math.abs(dusk - Config.DuskClock) < 0.01, "rounds start at dusk")

	-- Standing in a dog's path in Easy costs every heart
	local guard = DogBrain.newPatrol(Vector3.new(0, 0, 0), Vector3.new(0, 0, -40))
	local runner = { id = 1, pos = Vector3.new(0, 0, -20), heading = Vector3.new(0, 0, 1), speed = 16, safe = false }
	local hearts, last, t = Config.Hearts.Easy, -10, 0
	while t < 60 and hearts > 0 do
		t += DT
		if DogBrain.step(guard, DT, t, { runner }, world, Config.Dogs.Easy, 0) == "caught" and t - last >= 2.5 then
			last = t
			hearts -= 1
		end
	end
	check(hearts == 0, "Easy: hearts can run out")

	-- Levels add dogs and wider cones, level 1 is the base
	local base = Config.Dogs.Normal
	check(DogBrain.forLevel(base, 1, Config.Level).coneRange == base.coneRange, "level 1 is the base")
	local top = DogBrain.forLevel(base, Config.Level.Max, Config.Level)
	check(top.patrolCount == base.patrolCount + Config.Level.maxDogs and top.coneRange > base.coneRange, "levels get harder")

	-- A chasing dog drops the chase for a bone, eats, then goes back
	local chaser = DogBrain.newPatrol(Vector3.new(0, 0, 0), Vector3.new(0, 0, -40))
	local prey = { id = 1, pos = Vector3.new(0, 0, -12), heading = Vector3.new(0, 0, 1), speed = 0, safe = false }
	t = 0
	while t < 5 and chaser.state ~= "chase" do
		t += DT
		DogBrain.step(chaser, DT, t, { prey }, world, Config.Dogs.Easy, 0)
	end
	check(chaser.state == "chase", "dog chases a runner in front")
	DogBrain.distract(chaser, Vector3.new(20, 0, 0), t, Config.BoneEat)
	local bit, ate = false, false
	local stop = t + Config.BoneEat + 5
	while t < stop and not ate do
		t += DT
		local event = DogBrain.step(chaser, DT, t, { prey }, world, Config.Dogs.Easy, 0)
		bit = bit or event == "caught"
		ate = event == "ate"
	end
	check(not bit and ate and (chaser.pos - Vector3.new(20, 0, 0)).Magnitude < 2, "bone stops the chase")

	-- A dog hears a call, walks to the noise, then goes back to its path
	local ear = DogBrain.newPatrol(Vector3.new(0, 0, 0), Vector3.new(0, 0, -40))
	DogBrain.hear(ear, Vector3.new(30, 0, 0), 0)
	t = 0
	local closest = math.huge
	while t < 8 do
		t += DT
		DogBrain.step(ear, DT, t, {}, world, Config.Dogs.Easy, 0)
		closest = math.min(closest, (ear.pos - Vector3.new(30, 0, 0)).Magnitude)
	end
	check(closest < 4 and ear.state ~= "listen", "dog follows a noise and goes back")
end

local function pct(n: number, total: number): string
	return string.format("%3d%%", math.floor(n / math.max(total, 1) * 100 + 0.5))
end

print(string.format("Find Pianka bot playtest, %d rounds per row", ROUNDS))
print("Full rounds with patrol dogs, night hunters, rats, mud, hearts and birds")
print("")
print("Mode    Lv Bot      Hero      Won  Hearts  Grabbed  Lost  Time up  Caught  Stall  Bites  Rats   Birds  Bones  Search Hidden  Night  Avg time")
local rows: { { any } } = {
	{ "Easy", "careful", "default" },
	{ "Easy", "careful", "Patrick" },
	{ "Easy", "naive", "default" },
	{ "Easy", "kid", "default" },
	{ "Normal", "careful", "default" },
	{ "Normal", "careful", "Aurelia" },
	{ "Normal", "naive", "default" },
	{ "Normal", "kid", "default" },
	{ "Umulig", "careful", "default" },
	{ "Umulig", "careful", "Patrick" },
	{ "Umulig", "naive", "default" },
	{ "Umulig", "kid", "default" },
	{ "Easy", "careful", "default", 5 },
	{ "Easy", "careful", "default", 10 },
	{ "Easy", "kid", "default", 5 },
	{ "Easy", "kid", "default", 10 },
	{ "Normal", "careful", "default", 5 },
	{ "Normal", "careful", "default", 10 },
	{ "Normal", "kid", "default", 3 },
	{ "Normal", "kid", "default", 10 },
}
local totals: { [string]: { failed: number, rounds: number } } = {}
for _, row in rows do
	local mode, bot, hero, lv = row[1], row[2], row[3], row[4] or 1
	local careful = bot == "careful"
	if ONLY and ONLY ~= mode then
		continue
	end
	local count: { [string]: number } = {}
	local bites, grabs, ratBites, birdsTaken, time, placed, wanted, night, hidden = 0, 0, 0, 0, 0, 0, 0, 0, 0
	local fooled, searched = 0, 0
	for _ = 1, ROUNDS do
		local r = play(mode, bot, hero, lv)
		fooled += r.fooled
		searched += r.searched
		count[r.outcome] = (count[r.outcome] or 0) + 1
		bites += r.bites
		grabs += r.grabs
		ratBites += r.ratBites
		birdsTaken += r.birds
		time += r.time
		placed += r.placed
		wanted += r.wanted
		night += r.huntShare
		hidden += r.hiddenTime / math.max(r.time, 1)
	end
	local function n(key: string): number
		return count[key] or 0
	end
	local caught = n("pack") + n("patrol") + n("hunter")
	print(string.format("%-7s %2d %-8s %-8s %s   %s     %s  %s     %s    %s   %s   %4.2f  %5.2f  %5.2f  %5.2f  %5.2f   %s   %s   %5.0f s",
		mode, lv, bot, hero, pct(n("won"), ROUNDS), pct(n("hearts"), ROUNDS), pct(n("grabbed"), ROUNDS), pct(n("lost"), ROUNDS),
		pct(n("timeUp"), ROUNDS), pct(caught, ROUNDS), pct(n("stall"), ROUNDS), bites / ROUNDS, ratBites / ROUNDS,
		birdsTaken / ROUNDS, fooled / ROUNDS, searched / ROUNDS, pct(hidden, ROUNDS), pct(night, ROUNDS), time / ROUNDS))
	local total = totals[mode] or { failed = 0, rounds = 0 }
	total.failed += ROUNDS - n("won") - n("stall")
	total.rounds += ROUNDS
	totals[mode] = total
	check(n("stall") / ROUNDS <= 0.05, mode .. " " .. bot .. " " .. hero .. ": rounds must not stall")
	check(placed / math.max(wanted, 1) >= 0.9, mode .. ": patrol paths must fit")
	check(searched > 0, mode .. ": Pianka must hide")
	if mode == "Easy" and careful and lv >= Config.Level.Max then
		check(n("won") / ROUNDS >= 0.6, "Easy top level must stay doable")
	elseif mode == "Normal" and careful and lv >= Config.Level.Max then
		check(n("won") / ROUNDS >= 0.3, "Normal top level must stay doable")
	elseif mode == "Easy" and careful then
		check(n("won") / ROUNDS >= 0.85, "Easy must be doable for careful players")
	elseif mode == "Normal" and careful then
		check(n("won") / ROUNDS >= 0.5, "Normal must be doable for careful players")
	elseif mode == "Umulig" then
		check(n("won") / ROUNDS <= (if careful then 0.3 else 0.15), "Umulig must stay almost impossible")
	end
end
for mode, total in totals do
	if mode ~= "Easy" or total.rounds >= 600 then
		check(total.failed > 0, mode .. ": there must be a way to fail")
	end
end
print("")
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
