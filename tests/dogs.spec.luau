-- Bot playtests for the dog brains. Run: lune run tests/dogs.spec.luau [rounds]
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
local Config = load("src/shared/Config.luau")

local ROUNDS = tonumber(process.args[1]) or 300
local DT = 1 / 30
local HALF = Config.ForestSize / 2
local HOME = Vector3.new(Config.HomePosition.X, 0, Config.HomePosition.Z)

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

local function randomCatSpot(world): Vector3
	for _ = 1, 300 do
		local p = Vector3.new(rand(-HALF + 15, HALF - 15), 0, rand(-HALF + 15, HALF - 15))
		local ok = p.Magnitude >= Config.MinCatDistance
		for _, t in DogBrain.treesNear(world, p, p, 6) do
			if (t - p).Magnitude < 5 then
				ok = false
				break
			end
		end
		if ok then
			return p
		end
	end
	return Vector3.new(200, 0, 200)
end

local function makeMud(world, count: number, catPos: Vector3)
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

-- A bot player. "naive" walks straight, "careful" steers around dog cones.
local function botStep(bot, goal: Vector3, dogs, world, mud, s, careful: boolean)
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

local function checkDogs(dogs, s, world)
	for _, dog in dogs do
		check(not isNan(dog.pos) and not isNan(dog.dir), "dog position is NaN")
		check(math.abs(dog.pos.X) <= world.half and math.abs(dog.pos.Z) <= world.half, "dog left the map")
		check(math.abs(dog.dir.Magnitude - 1) < 0.05, "dog direction not unit")
		if dog.kind == "patrol" and dog.state == "patrol" then
			local ab = dog.b - dog.a
			local t = math.clamp((dog.pos - dog.a):Dot(ab) / ab:Dot(ab), 0, 1)
			local off = (dog.a + ab * t - dog.pos).Magnitude
			check(off < 3.5, "patrol dog wandered off its path by " .. string.format("%.1f", off))
		end
	end
end

local function makePatrols(world, catPos: Vector3, s)
	local dogs = {}
	local paths = DogBrain.patrolPaths(rand, world, catPos, HOME, s.patrolCount, Config.RatSafeRadius)
	for _, path in paths do
		local dog = DogBrain.newPatrol(path.a, path.b)
		dog.pos = path.a:Lerp(path.b, rand(0, 1))
		table.insert(dogs, dog)
	end
	return dogs, #paths
end

-- Easy and Normal: walk to Pianka, carry her home. Being caught makes her run off.
local function playFetch(mode: string, careful: boolean, walk: number)
	local s = Config.Dogs[mode]
	local world = makeWorld()
	local cat = randomCatSpot(world)
	local dogs, placed = makePatrols(world, cat, s)
	local mud = makeMud(world, Config.MudCount[mode], cat)
	local bot = { pos = HOME + Vector3.new(-8, 0, 0), heading = Vector3.new(1, 0, 0), speed = walk, walk = walk, time = 0, slowUntil = 0 }
	local carrying = false
	local stats = { caught = 0, spotted = 0, drops = 0, time = 0, done = false, placed = placed, wanted = s.patrolCount }
	local lastProgress, best = 0, math.huge
	while bot.time < 400 do
		bot.time += DT
		local goal = if carrying then HOME else cat
		botStep(bot, goal, dogs, world, mud, s, careful)
		local runner = { id = 1, pos = bot.pos, heading = bot.heading, speed = bot.walk, safe = (bot.pos - HOME).Magnitude < Config.RatSafeRadius }
		for _, dog in dogs do
			local event = DogBrain.step(dog, DT, bot.time, { runner }, world, s, 0)
			if event == "alert" then
				stats.spotted += 1
			elseif event == "caught" then
				check((dog.pos - bot.pos).Magnitude < s.catch + 0.5, "caught from too far")
				stats.caught += 1
				bot.slowUntil = bot.time + 2
				if carrying then
					carrying = false
					stats.drops += 1
					local angle = rand(0, math.pi * 2)
					cat = bot.pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rand(40, 60)
					cat = Vector3.new(math.clamp(cat.X, -HALF + 15, HALF - 15), 0, math.clamp(cat.Z, -HALF + 15, HALF - 15))
				end
			end
		end
		checkDogs(dogs, s, world)
		if not carrying and (bot.pos - cat).Magnitude < 6 then
			carrying = true
		elseif carrying and (bot.pos - HOME).Magnitude < Config.HomeRadius then
			stats.done = true
			break
		end
		local d = (bot.pos - goal).Magnitude
		if d < best - 1 then
			best, lastProgress = d, bot.time
		elseif bot.time - lastProgress > 40 then
			break
		end
		if (goal - (if carrying then HOME else cat)).Magnitude > 1 then
			best = math.huge
		end
	end
	stats.time = bot.time
	return stats
end

-- Umulig: run home with the kittens, the pack follows in formation.
local function playEscape(careful: boolean, walk: number)
	local s = Config.Dogs.Umulig
	local world = makeWorld()
	local start = randomCatSpot(world)
	for _ = 1, 50 do
		if (start - HOME).Magnitude >= Config.KittenHomeMin then
			break
		end
		start = randomCatSpot(world)
	end
	local dogs = makePatrols(world, start, s)
	local mud = makeMud(world, Config.MudCount.Umulig, start)
	local heading = (HOME - start).Unit
	local bot = { pos = start, heading = heading, speed = walk, walk = walk, time = 0, slowUntil = 0 }
	local right = Vector3.new(-heading.Z, 0, heading.X)
	for _, slot in DogBrain.formation(s.packCount) do
		local pos = start - heading * (s.packGap + 6 + slot.back) + right * slot.side
		local dog = DogBrain.newPack(pos, slot.side, slot.back, 1)
		table.insert(dogs, dog)
	end
	local result = { won = false, by = "", time = 0, distance = (start - HOME).Magnitude, lunges = 0 }
	local startTime = 0
	while bot.time < 150 do
		bot.time += DT
		botStep(bot, HOME, dogs, world, mud, s, careful)
		local runner = { id = 1, pos = bot.pos, heading = bot.heading, speed = bot.speed, safe = false }
		local gap = DogBrain.gap(s, bot.time - startTime)
		for _, dog in dogs do
			local event = DogBrain.step(dog, DT, bot.time, { runner }, world, s, gap)
			if event == "lunge" then
				result.lunges += 1
			elseif event == "caught" then
				check((dog.pos - bot.pos).Magnitude < s.catch + 0.5, "caught from too far")
				result.by = dog.kind
				result.time = bot.time
				return result
			end
		end
		checkDogs(dogs, s, world)
		if (bot.pos - HOME).Magnitude < Config.HomeRadius then
			result.won = true
			result.time = bot.time
			return result
		end
	end
	result.by = "timeout"
	result.time = bot.time
	return result
end

-- Unit checks on the cone
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
end

local function pct(n: number, total: number): string
	return string.format("%3d%%", math.floor(n / math.max(total, 1) * 100 + 0.5))
end

print(string.format("Find Pianka dog playtest, %d rounds per row", ROUNDS))
print("")
print("Mode    Bot      Hero     Done  Caught  Rounds caught  Avg time  Paths")
for _, mode in (if process.args[2] == "escape" then {} else { "Easy", "Normal" }) do
	for _, row in { { "careful", true }, { "naive", false } } do
		local done, caughtRounds, caughtTotal, time, placed, wanted = 0, 0, 0, 0, 0, 0
		for _ = 1, ROUNDS do
			local r = playFetch(mode, row[2], 16)
			done += if r.done then 1 else 0
			caughtRounds += if r.caught > 0 then 1 else 0
			caughtTotal += r.caught
			time += r.time
			placed += r.placed
			wanted += r.wanted
		end
		print(string.format("%-7s %-8s %-8s %s  %6.2f  %s           %5.0f s   %s",
			mode, row[1], "-", pct(done, ROUNDS), caughtTotal / ROUNDS, pct(caughtRounds, ROUNDS), time / ROUNDS, pct(placed, wanted)))
		check(done / ROUNDS >= 0.95, mode .. " " .. row[1] .. ": rounds must be finishable")
		if mode == "Easy" and row[2] then
			check(caughtRounds / ROUNDS <= 0.15, "Easy must stay easy for careful players")
		end
		if mode == "Easy" and not row[2] then
			check(caughtRounds / ROUNDS >= 0.05, "Easy dogs must still matter")
		end
	end
end
print("")
print("Umulig escape (run home, pack behind, patrol dogs, mud)")
print("Bot      Hero     Won   Pack  Patrol  Timeout  Avg lunges")
for _, row in { { "careful", true }, { "naive", false } } do
	for _, hero in { { "default", 16 }, { "Patrick", Config.PatrickSpeed } } do
		local won, pack, patrol, timeout, lunges = 0, 0, 0, 0, 0
		for _ = 1, ROUNDS do
			local r = playEscape(row[2], hero[2])
			won += if r.won then 1 else 0
			pack += if r.by == "pack" then 1 else 0
			patrol += if r.by == "patrol" then 1 else 0
			timeout += if r.by == "timeout" then 1 else 0
			lunges += r.lunges
		end
		print(string.format("%-8s %-8s %s  %s  %s    %s     %.2f",
			row[1], hero[1], pct(won, ROUNDS), pct(pack, ROUNDS), pct(patrol, ROUNDS), pct(timeout, ROUNDS), lunges / ROUNDS))
		check(won / ROUNDS <= (if row[2] then 0.3 else 0.15), "Umulig must stay almost impossible")
		check(timeout / ROUNDS <= 0.05, "Umulig escapes must not stall")
	end
end
print("")
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
