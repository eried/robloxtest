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

local function randomCatSpot(world): Vector3
	for _ = 1, 300 do
		local p = Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
		if (p - HOME).Magnitude >= Config.MinCatDistance and isFree(world, p, 5) then
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

local function makeRats(world, mode: string, catPos: Vector3)
	local rats = {}
	for i = 1, Config.RatCount[mode] do
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

-- Same rules as the rats in the game. Returns true on a bite.
local function ratStep(rat, bot, alive: boolean, world): boolean
	local now = bot.time
	local d = (bot.pos - rat.pos).Magnitude
	local safe = (bot.pos - HOME).Magnitude < Config.RatSafeRadius
	local hunting = alive and d < Config.RatAggro and (bot.pos - rat.nest).Magnitude < Config.RatLeash and not safe and bot.hp > 25
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
				rat.cooldown = now + 2
				if now - bot.lastBite >= 0.5 then
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
	if careful then
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
	local paths = DogBrain.patrolPaths(rand, world, catPos, HOME, s.patrolCount, Config.RatSafeRadius)
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
local function play(mode: string, kind: string, hero: string)
	local careful = kind == "careful"
	local s = Config.Dogs[mode]
	local hs = DogBrain.with(s, Config.Hunters[mode])
	local walk = if hero == "Patrick" then Config.PatrickSpeed else 16
	local calm = if hero == "Milenkitka" then 0.92 else 1
	local world = makeWorld()
	local cat = randomCatSpot(world)
	local dogs, placed = makePatrols(world, cat, s)
	local hunters = makeHunters(world, hs)
	local mud = makeMud(Config.MudCount[mode], cat)
	local rats = makeRats(world, mode, cat)
	local birds = makeBirds(world, mode, cat, hero)
	local bot = {
		pos = SPAWN,
		heading = Vector3.new(1, 0, 0),
		speed = walk,
		walk = walk,
		time = 0,
		slowUntil = 0,
		hp = 100,
		kid = kind == "kid",
		wander = SPAWN,
		wanderUntil = 0,
		lastBite = -10,
		lastCaught = -10,
	}
	local hearts = Config.Hearts[mode]
	local dayOffset = rand(0, Config.DayMinutes * 60)
	local hunting = false
	local phase = "find"
	local flees = if mode == "Easy" then 0 elseif hero == "Aurelia" then 1 else Config.HardFlees
	local kittens: { Vector3 } = {}
	local carryStart, kittenEnd, packStart = 0, 0, 0
	local r = { outcome = "", bites = 0, grabs = 0, ratBites = 0, birds = 0, time = 0, placed = placed, wanted = s.patrolCount, huntShare = 0 }
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
		if phase == "find" then
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
		if hearts < Config.Hearts[mode] and phase ~= "escape" then
			for _, b in birds do
				if (b - bot.pos).Magnitude < 25 and (b - bot.pos).Magnitude < (goal - bot.pos).Magnitude then
					goal = b
				end
			end
		end
		if alive then
			botStep(bot, goal, active, world, mud, careful)
		end
		bot.hp = math.min(100, bot.hp + DT)
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
			runners[1] = {
				id = 1,
				pos = bot.pos,
				heading = bot.heading,
				speed = bot.speed * calm,
				safe = (bot.pos - HOME).Magnitude < Config.RatSafeRadius,
			}
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
				else
					r.bites += 1
				end
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
					bot.hp -= math.min(Config.RatBite, bot.hp - 1)
					bot.slowUntil = bot.time + 1.5
					if phase == "carry" and bot.hp <= 30 then
						phase = "find"
						cat = dropSpot(world, bot.pos)
					end
				end
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
		if alive then
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
						kittenEnd = now + Config.KittenTime
					end
				end
			elseif phase == "carry" then
				if now - carryStart > Config.CarryTime then
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
end

local function pct(n: number, total: number): string
	return string.format("%3d%%", math.floor(n / math.max(total, 1) * 100 + 0.5))
end

print(string.format("Find Pianka bot playtest, %d rounds per row", ROUNDS))
print("Full rounds with patrol dogs, night hunters, rats, mud, hearts and birds")
print("")
print("Mode    Bot      Hero      Won  Hearts  Lost  Time up  Caught  Stall  Bites  Grabs  Rats   Birds  Night  Avg time")
local rows = {
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
}
local totals: { [string]: { failed: number, rounds: number } } = {}
for _, row in rows do
	local mode, bot, hero = row[1], row[2], row[3]
	local careful = bot == "careful"
	if ONLY and ONLY ~= mode then
		continue
	end
	local count: { [string]: number } = {}
	local bites, grabs, ratBites, birdsTaken, time, placed, wanted, night = 0, 0, 0, 0, 0, 0, 0, 0
	for _ = 1, ROUNDS do
		local r = play(mode, bot, hero)
		count[r.outcome] = (count[r.outcome] or 0) + 1
		bites += r.bites
		grabs += r.grabs
		ratBites += r.ratBites
		birdsTaken += r.birds
		time += r.time
		placed += r.placed
		wanted += r.wanted
		night += r.huntShare
	end
	local function n(key: string): number
		return count[key] or 0
	end
	local caught = n("pack") + n("patrol") + n("hunter")
	print(string.format("%-7s %-8s %-8s %s   %s  %s     %s    %s   %s   %4.2f   %4.2f  %5.2f  %5.2f  %s   %5.0f s",
		mode, bot, hero, pct(n("won"), ROUNDS), pct(n("hearts"), ROUNDS), pct(n("lost"), ROUNDS), pct(n("timeUp"), ROUNDS),
		pct(caught, ROUNDS), pct(n("stall"), ROUNDS), bites / ROUNDS, grabs / ROUNDS, ratBites / ROUNDS, birdsTaken / ROUNDS,
		pct(night, ROUNDS), time / ROUNDS))
	local total = totals[mode] or { failed = 0, rounds = 0 }
	total.failed += ROUNDS - n("won") - n("stall")
	total.rounds += ROUNDS
	totals[mode] = total
	check(n("stall") / ROUNDS <= 0.05, mode .. " " .. bot .. " " .. hero .. ": rounds must not stall")
	check(placed / math.max(wanted, 1) >= 0.9, mode .. ": patrol paths must fit")
	if mode == "Easy" and careful then
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
