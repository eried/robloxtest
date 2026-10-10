-- Dog brains, shared by the game and the tests
local DogBrain = {}

export type Settings = {
	patrolCount: number,
	patrolSpeed: number,
	coneAngle: number,
	coneRange: number,
	alertDelay: number,
	chaseFactor: number,
	chaseTime: number,
	catch: number,
	packCount: number,
	packConeRange: number,
	packSpeedFactor: number,
	packGap: number,
	packGapMin: number,
	packClose: number,
	lungeFactor: number,
	lungeTime: number,
	restTime: number,
}

export type Runner = {
	id: number,
	pos: Vector3,
	heading: Vector3,
	speed: number,
	safe: boolean,
}

export type Dog = {
	kind: string,
	state: string,
	pos: Vector3,
	dir: Vector3,
	untilTime: number,
	a: Vector3,
	b: Vector3,
	toB: boolean,
	turnFrom: Vector3,
	side: number,
	back: number,
	target: number?,
}

export type World = {
	trees: { Vector3 },
	cabins: { Vector3 },
	half: number,
	grid: { [number]: { Vector3 } }?,
}

local CELL = 16

local function cellKey(x: number, z: number): number
	return (x + 512) * 1024 + (z + 512)
end

-- Builds a lookup so only nearby trees are checked
function DogBrain.index(world: World)
	local grid = {}
	for _, t in world.trees do
		local key = cellKey(math.floor(t.X / CELL), math.floor(t.Z / CELL))
		local list = grid[key]
		if not list then
			list = {}
			grid[key] = list
		end
		table.insert(list, t)
	end
	world.grid = grid
end

-- Trees near a box around two points
function DogBrain.treesNear(world: World, a: Vector3, b: Vector3, pad: number): { Vector3 }
	local grid = world.grid
	if not grid then
		return world.trees
	end
	local found = {}
	local x0 = math.floor((math.min(a.X, b.X) - pad) / CELL)
	local x1 = math.floor((math.max(a.X, b.X) + pad) / CELL)
	local z0 = math.floor((math.min(a.Z, b.Z) - pad) / CELL)
	local z1 = math.floor((math.max(a.Z, b.Z) + pad) / CELL)
	for x = x0, x1 do
		for z = z0, z1 do
			local list = grid[cellKey(x, z)]
			if list then
				for _, t in list do
					table.insert(found, t)
				end
			end
		end
	end
	return found
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rotateY(v: Vector3, angle: number): Vector3
	local c, s = math.cos(angle), math.sin(angle)
	return Vector3.new(v.X * c + v.Z * s, 0, -v.X * s + v.Z * c)
end

local function closestOnSegment(a: Vector3, b: Vector3, p: Vector3): Vector3
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return a
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return a + ab * t
end

local function findRunner(runners: { Runner }, id: number?): Runner?
	for _, r in runners do
		if r.id == id then
			return r
		end
	end
	return nil
end

function DogBrain.blocked(world: World, from: Vector3, to: Vector3): boolean
	local d = to - from
	local len = d.Magnitude
	if len < 2 then
		return false
	end
	local u = d / len
	for _, t in DogBrain.treesNear(world, from, to, 2) do
		local rel = t - from
		local along = rel:Dot(u)
		if along > 1.5 and along < len - 1.5 and (rel - u * along).Magnitude < 1.6 then
			return true
		end
	end
	for _, c in world.cabins do
		local rel = c - from
		local along = rel:Dot(u)
		if along > 0 and along < len and (rel - u * along).Magnitude < 6 then
			return true
		end
	end
	return false
end

function DogBrain.sees(dog: Dog, target: Vector3, range: number, halfAngle: number, world: World): boolean
	local to = flat(target) - dog.pos
	local dist = to.Magnitude
	if dist > range then
		return false
	end
	if dist < 2.5 then
		return true
	end
	if dog.dir:Dot(to / dist) < math.cos(math.rad(halfAngle)) then
		return false
	end
	return not DogBrain.blocked(world, dog.pos, flat(target))
end

local function moveTo(dog: Dog, goal: Vector3, speed: number, dt: number, world: World)
	local delta = goal - dog.pos
	local dist = delta.Magnitude
	if dist < 0.05 or speed <= 0 then
		return
	end
	local dir = delta / dist
	local nextPos = dog.pos + dir * math.min(speed * dt, dist)
	for _, t in DogBrain.treesNear(world, nextPos, nextPos, 3) do
		local away = nextPos - t
		local m = away.Magnitude
		if m < 2.5 and m > 0.01 then
			nextPos = t + away / m * 2.5
		end
	end
	for _, c in world.cabins do
		local away = nextPos - c
		local m = away.Magnitude
		if m < 9 and m > 0.01 then
			nextPos = c + away / m * 9
		end
	end
	local edge = world.half - 3
	dog.pos = Vector3.new(math.clamp(nextPos.X, -edge, edge), 0, math.clamp(nextPos.Z, -edge, edge))
	dog.dir = dir
end

function DogBrain.newPatrol(a: Vector3, b: Vector3): Dog
	return {
		kind = "patrol",
		state = "patrol",
		pos = a,
		dir = (b - a).Unit,
		untilTime = 0,
		a = a,
		b = b,
		toB = true,
		turnFrom = (b - a).Unit,
		side = 0,
		back = 0,
		target = nil,
	}
end

function DogBrain.newPack(pos: Vector3, side: number, back: number, target: number): Dog
	return {
		kind = "pack",
		state = "follow",
		pos = pos,
		dir = Vector3.new(0, 0, -1),
		untilTime = 0,
		a = pos,
		b = pos,
		toB = true,
		turnFrom = Vector3.new(0, 0, -1),
		side = side,
		back = back,
		target = target,
	}
end

-- Slots of a V formation: front dog first, then pairs further back
function DogBrain.formation(count: number): { { side: number, back: number } }
	local slots = {}
	for i = 1, count do
		local row = i // 2
		local sign = if i % 2 == 0 then 1 else -1
		table.insert(slots, { side = if i == 1 then 0 else sign * row * 4, back = row * 4 })
	end
	return slots
end

local function spot(dog: Dog, s: Settings, runners: { Runner }, world: World, now: number): (string?, number?)
	for _, r in runners do
		if not r.safe and DogBrain.sees(dog, r.pos, s.coneRange, s.coneAngle, world) then
			dog.state = "alert"
			dog.untilTime = now + s.alertDelay
			dog.target = r.id
			return "alert", r.id
		end
	end
	return nil, nil
end

local function stepPatrol(dog: Dog, dt: number, now: number, runners: { Runner }, world: World, s: Settings): (string?, number?)
	if dog.state == "patrol" or dog.state == "turn" then
		local event, id = spot(dog, s, runners, world, now)
		if event then
			return event, id
		end
		if dog.state == "turn" then
			local alpha = math.clamp(1 - (dog.untilTime - now) / 1.4, 0, 1)
			dog.dir = rotateY(dog.turnFrom, math.pi * alpha)
			if now >= dog.untilTime then
				dog.state = "patrol"
				dog.toB = not dog.toB
			end
			return nil, nil
		end
		local goal = if dog.toB then dog.b else dog.a
		if (goal - dog.pos).Magnitude < 0.5 then
			dog.state = "turn"
			dog.untilTime = now + 1.4
			dog.turnFrom = dog.dir
		else
			moveTo(dog, goal, s.patrolSpeed, dt, world)
		end
	elseif dog.state == "alert" then
		local r = findRunner(runners, dog.target)
		if not r or r.safe then
			dog.state = "return"
			return "lost", nil
		end
		local to = flat(r.pos) - dog.pos
		if to.Magnitude > 0.1 then
			dog.dir = to.Unit
		end
		if now >= dog.untilTime then
			dog.state = "chase"
			dog.untilTime = now + s.chaseTime
			return "chase", r.id
		end
	elseif dog.state == "chase" then
		local r = findRunner(runners, dog.target)
		if not r or r.safe or now >= dog.untilTime then
			dog.state = "return"
			dog.untilTime = now + 2
			return "lost", nil
		end
		moveTo(dog, flat(r.pos), r.speed * s.chaseFactor, dt, world)
		if (flat(r.pos) - dog.pos).Magnitude < s.catch then
			dog.state = "return"
			dog.untilTime = now + 3
			return "caught", r.id
		end
	elseif dog.state == "return" then
		if now >= dog.untilTime then
			local event, id = spot(dog, s, runners, world, now)
			if event then
				return event, id
			end
		end
		local goal = closestOnSegment(dog.a, dog.b, dog.pos)
		if (goal - dog.pos).Magnitude < 0.5 then
			dog.state = "patrol"
		else
			moveTo(dog, goal, s.patrolSpeed * 1.5, dt, world)
		end
	end
	return nil, nil
end

local function stepPack(dog: Dog, dt: number, now: number, runners: { Runner }, world: World, s: Settings, gap: number): (string?, number?)
	local r = findRunner(runners, dog.target)
	if not r then
		return nil, nil
	end
	local rpos = flat(r.pos)
	local function face()
		local to = rpos - dog.pos
		if to.Magnitude > 0.1 then
			dog.dir = to.Unit
		end
	end
	if dog.state == "rest" then
		face()
		if now >= dog.untilTime then
			dog.state = "follow"
		end
		return nil, nil
	elseif dog.state == "lunge" then
		moveTo(dog, rpos, r.speed * s.lungeFactor, dt, world)
		if (rpos - dog.pos).Magnitude < s.catch then
			return "caught", r.id
		end
		if now >= dog.untilTime then
			dog.state = "rest"
			dog.untilTime = now + s.restTime
		end
		return nil, nil
	end
	local heading = r.heading
	local right = Vector3.new(-heading.Z, 0, heading.X)
	local slot = rpos - heading * (gap + dog.back) + right * dog.side
	moveTo(dog, slot, r.speed * s.packSpeedFactor, dt, world)
	face()
	if not r.safe and DogBrain.sees(dog, r.pos, s.packConeRange, s.coneAngle, world) then
		dog.state = "lunge"
		dog.untilTime = now + s.lungeTime
		return "lunge", r.id
	end
	return nil, nil
end

-- Moves one dog. Returns an event ("alert", "chase", "lost", "caught", "lunge") and a runner id.
function DogBrain.step(dog: Dog, dt: number, now: number, runners: { Runner }, world: World, s: Settings, gap: number): (string?, number?)
	if dog.kind == "pack" then
		return stepPack(dog, dt, now, runners, world, s, gap)
	end
	return stepPatrol(dog, dt, now, runners, world, s)
end

-- Pack gap shrinks over time so the pack slowly closes in
function DogBrain.gap(s: Settings, elapsed: number): number
	return math.max(s.packGapMin, s.packGap - s.packClose * elapsed)
end

-- Picks straight patrol paths. Some cross the way from home to Pianka, some guard her.
function DogBrain.patrolPaths(
	rand: (number, number) -> number,
	world: World,
	catPos: Vector3,
	home: Vector3,
	count: number,
	safeRadius: number
): { { a: Vector3, b: Vector3 } }
	local paths: { { a: Vector3, b: Vector3 } } = {}
	local toCat = flat(catPos - home)
	local line = if toCat.Magnitude > 1 then toCat.Unit else Vector3.new(1, 0, 0)
	for i = 1, count do
		for _ = 1, 80 do
			local center: Vector3
			local dir: Vector3
			if i % 3 == 1 then
				center = flat(home):Lerp(flat(catPos), rand(0.35, 0.8)) + Vector3.new(rand(-15, 15), 0, rand(-15, 15))
				dir = rotateY(line, math.pi / 2 + rand(-0.35, 0.35))
			elseif i % 3 == 2 then
				center = flat(catPos) + rotateY(Vector3.new(1, 0, 0), rand(0, math.pi * 2)) * rand(22, 40)
				dir = rotateY(Vector3.new(1, 0, 0), rand(0, math.pi * 2))
			else
				center = Vector3.new(rand(-world.half + 40, world.half - 40), 0, rand(-world.half + 40, world.half - 40))
				dir = rotateY(Vector3.new(1, 0, 0), rand(0, math.pi * 2))
			end
			local len = rand(30, 50)
			local a = center - dir * (len / 2)
			local b = center + dir * (len / 2)
			local edge = world.half - 15
			local ok = math.abs(a.X) < edge and math.abs(a.Z) < edge and math.abs(b.X) < edge and math.abs(b.Z) < edge
			ok = ok and (closestOnSegment(a, b, flat(home)) - flat(home)).Magnitude > safeRadius + 12
			ok = ok and (closestOnSegment(a, b, flat(catPos)) - flat(catPos)).Magnitude > 14
			if ok then
				for _, t in DogBrain.treesNear(world, a, b, 4) do
					if (closestOnSegment(a, b, t) - t).Magnitude < 3 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, c in world.cabins do
					if (closestOnSegment(a, b, c) - c).Magnitude < 12 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, other in paths do
					if ((other.a + other.b) / 2 - center).Magnitude < 28 then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(paths, { a = a, b = b })
				break
			end
		end
	end
	return paths
end

return DogBrain
