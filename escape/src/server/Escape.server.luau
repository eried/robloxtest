-- Pianka the Escape: the sleeping house, built from the plan, with keys, noise and the way out
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Plan = require(Shared:WaitForChild("Plan"))
local Cat = require(Shared:WaitForChild("Cat"))

local U = Config.Square
local WALL = Config.WallHeight
local DOOR = Config.DoorHeight
local FLOOR2 = Config.Floor2
local rng = Random.new()

local event = Instance.new("RemoteEvent")
event.Name = "Escape"
event.Parent = ReplicatedStorage

local world = Instance.new("Folder")
world.Name = "World"
world.Parent = workspace

type Level = { w: number, h: number, rows: { string }, items: { { t: string, x: number, y: number, r: number } }, labels: { { text: string, x: number, y: number } } }
type Rect = { x: number, y: number, w: number, h: number }

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Class" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or world
	return f
end

-- Plan cells: f floor, w wall, d door, n window, and the yard ones
local function rawCell(lv: Level, x: number, y: number): string
	if x < 0 or y < 0 or x >= lv.w or y >= lv.h then
		return "."
	end
	return string.sub(lv.rows[y + 1], x + 1, x + 1)
end

-- A gap between two walls counts as wall, so the house has no holes
local function cell(lv: Level, x: number, y: number): string
	local c = rawCell(lv, x, y)
	if c == "." and x >= 0 and y >= 0 and x < lv.w and y < lv.h then
		local function solid(i: number, j: number): boolean
			local o = rawCell(lv, i, j)
			return o == "w" or o == "n"
		end
		if (solid(x - 1, y) and solid(x + 1, y)) or (solid(x, y - 1) and solid(x, y + 1)) then
			return "w"
		end
	end
	return c
end

-- Merge matching cells into as few rectangles as possible
local function rects(lv: Level, match: (string, number, number) -> boolean): { Rect }
	local used: { [number]: boolean } = {}
	local out: { Rect } = {}
	local function ok(x: number, y: number): boolean
		return not used[y * lv.w + x] and match(cell(lv, x, y), x, y)
	end
	for y = 0, lv.h - 1 do
		for x = 0, lv.w - 1 do
			if ok(x, y) then
				local w = 1
				while x + w < lv.w and ok(x + w, y) do
					w += 1
				end
				local h = 1
				while y + h < lv.h do
					local all = true
					for i = x, x + w - 1 do
						if not ok(i, y + h) then
							all = false
							break
						end
					end
					if not all then
						break
					end
					h += 1
				end
				for j = y, y + h - 1 do
					for i = x, x + w - 1 do
						used[j * lv.w + i] = true
					end
				end
				table.insert(out, { x = x, y = y, w = w, h = h })
			end
		end
	end
	return out
end

local function block(r: Rect, ox: number, oz: number, y0: number, y1: number, props: { [string]: any }): BasePart
	props.Size = Vector3.new(r.w * U, y1 - y0, r.h * U)
	props.CFrame = CFrame.new(ox + (r.x + r.w / 2) * U, (y0 + y1) / 2, oz + (r.y + r.h / 2) * U)
	return part(props)
end

local function itemSize(it: { t: string, r: number }, w: number, h: number): (number, number)
	if it.r % 2 == 1 then
		return h, w
	end
	return w, h
end

-- Footprints in plan squares, same as the planner
local FOOT: { [string]: { number } } = {
	bedKid = { 2, 4 }, bedGirl = { 2, 4 }, bedMom = { 3, 4 }, bedEmpty = { 2, 4 }, key = { 1, 1 }, squeaky = { 1, 1 }, ballTrack = { 2, 2 },
	catStart = { 1, 1 }, exit = { 1, 1 }, stairsUp = { 2, 5 }, stairsDown = { 2, 5 }, sofa = { 4, 2 }, table = { 3, 2 }, tv = { 2, 1 },
	washer = { 2, 2 }, toilet = { 1, 2 }, bathtub = { 2, 4 }, other = { 2, 2 }, tree = { 2, 2 }, bush = { 2, 2 }, rock = { 1, 1 },
	flowers = { 3, 2 }, shed = { 5, 4 }, trampoline = { 5, 5 }, woodpile = { 3, 1 }, bin = { 1, 1 }, car = { 4, 8 }, houseDoor = { 1, 1 },
	gate = { 2, 1 }, ratSpawn = { 1, 1 }, ratHole = { 1, 1 }, ratGap = { 2, 1 }, jumpSpot = { 1, 1 }, camera = { 1, 1 },
}
local function rectOf(it: { t: string, x: number, y: number, r: number }): Rect
	local f = FOOT[it.t] or { 1, 1 }
	local w, h = itemSize(it, f[1], f[2])
	return { x = it.x, y = it.y, w = w, h = h }
end

local floor1: Level = Plan.floor1
local floor2: Level = Plan.floor2
local yard: Level = Plan.yard
local HOUSE_W, HOUSE_D = floor1.w * U, floor1.h * U

-- Rooms: floor cells joined together, named by the labels in them
local STYLES: { { words: { string }, material: Enum.Material, color: Color3, light: Color3, bright: number } } = {
	{ words = { "bath", "toilet" }, material = Enum.Material.Marble, color = Color3.fromRGB(222, 230, 236), light = Color3.fromRGB(255, 230, 200), bright = 0.6 },
	{ words = { "kitchen", "storage" }, material = Enum.Material.Slate, color = Color3.fromRGB(205, 196, 180), light = Color3.fromRGB(255, 220, 170), bright = 0.7 },
	{ words = { "kid" }, material = Enum.Material.Fabric, color = Color3.fromRGB(120, 150, 205), light = Color3.fromRGB(140, 160, 255), bright = 0.35 },
	{ words = { "girl" }, material = Enum.Material.Fabric, color = Color3.fromRGB(220, 160, 195), light = Color3.fromRGB(200, 150, 255), bright = 0.35 },
	{ words = { "mom" }, material = Enum.Material.Fabric, color = Color3.fromRGB(150, 175, 150), light = Color3.fromRGB(140, 160, 255), bright = 0.35 },
	{ words = { "guest" }, material = Enum.Material.Fabric, color = Color3.fromRGB(196, 178, 150), light = Color3.fromRGB(255, 220, 180), bright = 0.45 },
}
local WOOD = { material = Enum.Material.WoodPlanks, color = Color3.fromRGB(176, 128, 84), light = Color3.fromRGB(255, 214, 165), bright = 0.8 }

local function rooms(lv: Level): ({ [number]: number }, { { cells: { number }, name: string } })
	local id: { [number]: number } = {}
	local list = {}
	for y = 0, lv.h - 1 do
		for x = 0, lv.w - 1 do
			if cell(lv, x, y) == "f" and not id[y * lv.w + x] then
				local room = { cells = {}, name = "" }
				table.insert(list, room)
				local stack = { y * lv.w + x }
				id[y * lv.w + x] = #list
				while #stack > 0 do
					local k = table.remove(stack) :: number
					table.insert(room.cells, k)
					local cx, cy = k % lv.w, k // lv.w
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nx, ny = cx + d[1], cy + d[2]
						local nk = ny * lv.w + nx
						if cell(lv, nx, ny) == "f" and not id[nk] then
							id[nk] = #list
							table.insert(stack, nk)
						end
					end
				end
			end
		end
	end
	for _, lb in lv.labels do
		local best, bestD = nil, math.huge
		for dy = -2, 2 do
			for dx = -2, 2 do
				local x, y = math.floor(lb.x) + dx, math.floor(lb.y) + dy
				local r = id[y * lv.w + x]
				if r and x >= 0 and x < lv.w and math.abs(dx) + math.abs(dy) < bestD then
					best, bestD = r, math.abs(dx) + math.abs(dy)
				end
			end
		end
		if best and list[best].name == "" then
			list[best].name = lb.text
		end
	end
	return id, list
end

local function styleOf(name: string): any
	local lower = string.lower(name)
	for _, s in STYLES do
		for _, w in s.words do
			if string.find(lower, w, 1, true) then
				return s
			end
		end
	end
	return WOOD
end

-- Stairs: the hole in floor 2 and the way up
local stairsRect: Rect? = nil
for _, it in floor1.items do
	if it.t == "stairsUp" then
		stairsRect = rectOf(it)
	end
end
local holeCells: { [number]: boolean } = {}
for _, lv in { floor1, floor2 } do
	for _, it in lv.items do
		if it.t == "stairsUp" or it.t == "stairsDown" then
			local r = rectOf(it)
			for j = r.y, r.y + r.h - 1 do
				for i = r.x, r.x + r.w - 1 do
					holeCells[j * floor2.w + i] = true
				end
			end
		end
	end
end

local WALL_COLOR = Color3.fromRGB(236, 228, 214)
local function buildLevel(lv: Level, baseY: number, top: boolean, parent: Folder)
	local id, list = rooms(lv)
	-- The slab under everything, with the stairs hole upstairs
	for _, r in rects(lv, function(c, x, y)
		return c ~= "." and not (top and holeCells[y * lv.w + x])
	end) do
		block(r, 0, 0, baseY - (if top then 2 else 1), baseY, { Name = "Slab", Color = Color3.fromRGB(150, 135, 120), Parent = parent })
	end
	-- Each room gets its own floor
	for index, room in list do
		local s = styleOf(room.name)
		local set: { [number]: boolean } = {}
		for _, k in room.cells do
			set[k] = true
		end
		for _, r in rects(lv, function(_, x, y)
			return set[y * lv.w + x] == true and not (top and holeCells[y * lv.w + x])
		end) do
			block(r, 0, 0, baseY, baseY + 0.12, { Name = "Floor", Material = s.material, Color = s.color, Parent = parent })
		end
		-- A ceiling lamp in each named room, dim and blue in bedrooms
		if room.name ~= "" then
			local sx, sz = 0, 0
			for _, k in room.cells do
				sx += k % lv.w
				sz += k // lv.w
			end
			local cx, cz = (sx / #room.cells + 0.5) * U, (sz / #room.cells + 0.5) * U
			local lamp = part({ Name = "Lamp", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(cx, baseY + WALL - 0.3, cz), Material = Enum.Material.Neon, Color = s.light, CanCollide = false, Parent = parent })
			local light = Instance.new("PointLight")
			light.Color = s.light
			light.Brightness = s.bright
			light.Range = 34
			light.Shadows = true
			light.Parent = lamp
			lamp:SetAttribute("Room", room.name)
		end
		room.name = room.name ~= "" and room.name or ("Room " .. index)
	end
	for _, r in rects(lv, function(c)
		return c == "w"
	end) do
		block(r, 0, 0, baseY, baseY + WALL, { Name = "Wall", Material = Enum.Material.Plaster, Color = WALL_COLOR, Parent = parent })
	end
	for _, r in rects(lv, function(c)
		return c == "d"
	end) do
		block(r, 0, 0, baseY + DOOR, baseY + WALL, { Name = "DoorTop", Material = Enum.Material.Plaster, Color = WALL_COLOR, Parent = parent })
	end
	for _, r in rects(lv, function(c)
		return c == "n"
	end) do
		block(r, 0, 0, baseY, baseY + 6, { Name = "Sill", Material = Enum.Material.Plaster, Color = WALL_COLOR, Parent = parent })
		block(r, 0, 0, baseY + 6, baseY + 15, { Name = "Window", Material = Enum.Material.Glass, Transparency = 0.55, Color = Color3.fromRGB(150, 185, 230), Parent = parent })
		block(r, 0, 0, baseY + 15, baseY + WALL, { Name = "WallTop", Material = Enum.Material.Plaster, Color = WALL_COLOR, Parent = parent })
	end
	if top then
		for _, r in rects(lv, function(c)
			return c ~= "."
		end) do
			block(r, 0, 0, baseY + WALL, baseY + WALL + 2, { Name = "Roof", Color = Color3.fromRGB(120, 70, 60), Parent = parent })
		end
	end
	return id, list
end

local houseFolder = folder("House")
local f1 = folder("Floor1", houseFolder)
local f2 = folder("Floor2", houseFolder)
buildLevel(floor1, 0, false, f1)
buildLevel(floor2, FLOOR2, true, f2)

-- Which way a piece of furniture faces: away from the closest wall
local function facing(lv: Level, r: Rect, longEnds: boolean): Vector3
	local best, bestD = Vector3.new(0, 0, 1), math.huge
	local sides = {
		{ dir = Vector3.new(0, 0, -1), dx = 0, dy = -1 },
		{ dir = Vector3.new(0, 0, 1), dx = 0, dy = 1 },
		{ dir = Vector3.new(-1, 0, 0), dx = -1, dy = 0 },
		{ dir = Vector3.new(1, 0, 0), dx = 1, dy = 0 },
	}
	for _, s in sides do
		local alongZ = s.dx == 0
		if longEnds and ((r.h >= r.w) ~= alongZ) then
			continue
		end
		for d = 1, 6 do
			local hit = false
			if alongZ then
				local y = if s.dy < 0 then r.y - d else r.y + r.h - 1 + d
				for x = r.x, r.x + r.w - 1 do
					local c = cell(lv, x, y)
					if c == "w" or c == "n" or c == "d" then
						hit = true
					end
				end
			else
				local x = if s.dx < 0 then r.x - d else r.x + r.w - 1 + d
				for y = r.y, r.y + r.h - 1 do
					local c = cell(lv, x, y)
					if c == "w" or c == "n" or c == "d" then
						hit = true
					end
				end
			end
			if hit then
				if d < bestD then
					best, bestD = -s.dir, d
				end
				break
			end
		end
	end
	return best
end

-- A model's frame: centre on the floor, looking out the front
local function frame(r: Rect, baseY: number, front: Vector3, ox: number?, oz: number?): (CFrame, number, number)
	local c = Vector3.new((ox or 0) + (r.x + r.w / 2) * U, baseY, (oz or 0) + (r.y + r.h / 2) * U)
	local width, depth = r.w * U, r.h * U
	if math.abs(front.X) > 0.5 then
		width, depth = depth, width
	end
	return CFrame.lookAt(c, c + front), width, depth
end

local function box(model: Instance, name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	return part({ Name = name, CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = collide ~= false, Parent = model })
end

local surfaces: { { floor: number, rect: Rect, top: number } } = {}
local function surface(floorNo: number, r: Rect, top: number)
	table.insert(surfaces, { floor = floorNo, rect = r, top = top })
end

local sleepers: { { name: string, model: Model, head: BasePart, rest: CFrame, floor: number, sleep: number, sent: number } } = {}
local toys: { { kind: string, model: Model, pos: Vector3, floor: number, ready: number } } = {}
local keySpots: { { floor: number, pos: Vector3 } } = {}
local catBed: Vector3 = Vector3.new(HOUSE_W / 2, 1, HOUSE_D / 2)

local WOOD_DARK = Color3.fromRGB(120, 80, 50)
local WOOD_LIGHT = Color3.fromRGB(190, 145, 95)
local WHITE = Color3.fromRGB(240, 240, 238)

local function buildSleeper(model: Model, cf: CFrame, width: number, depth: number, look: any, kind: string): BasePart
	-- Lying on the back, head on the pillow at the headboard end
	local adult = kind == "bedMom"
	local headSize = if adult then 3.4 else 3.0
	local headCf = cf * CFrame.new(0, 6.3, depth / 2 - 2.6)
	local head = box(model, "Head", headCf, Vector3.one * headSize, look.skin, Enum.Material.SmoothPlastic, false)
	;(head :: Part).Shape = Enum.PartType.Ball
	local hair = box(model, "Hair", headCf * CFrame.new(0, -0.2, 0.45), Vector3.one * (headSize + 0.25), look.hair, Enum.Material.SmoothPlastic, false)
	;(hair :: Part).Shape = Enum.PartType.Ball
	if adult then
		local bun = box(model, "Bun", headCf * CFrame.new(0, -0.4, 2.0), Vector3.one * 1.6, look.hair, Enum.Material.SmoothPlastic, false)
		;(bun :: Part).Shape = Enum.PartType.Ball
	elseif kind == "bedGirl" then
		box(model, "LongHair", headCf * CFrame.new(0, -1.1, 1.6), Vector3.new(headSize + 0.6, 0.4, 2.6), look.hair, Enum.Material.SmoothPlastic, false)
	end
	for _, x in { -0.55, 0.55 } do
		box(model, "Eye", headCf * CFrame.new(x, headSize / 2 - 0.05, -0.35), Vector3.new(0.5, 0.1, 0.12), Color3.fromRGB(60, 40, 40), Enum.Material.SmoothPlastic, false)
	end
	local bodyLen = math.max(6, depth - 6.5)
	box(model, "Body", cf * CFrame.new(0, 5.6, depth / 2 - 4.6 - bodyLen / 2), Vector3.new(math.min(width - 1.2, if adult then 6 else 4.6), 2.6, bodyLen), look.blanket, Enum.Material.Fabric, false)
	return head
end

local function buildBed(lv: Level, it: any, floorNo: number, baseY: number, parent: Instance)
	local r = rectOf(it)
	local front = facing(lv, r, true)
	local cf, width, depth = frame(r, baseY, front)
	local model = Instance.new("Model")
	model.Name = it.t
	model.Parent = parent
	local look = Config.Sleepers[it.t]
	box(model, "Frame", cf * CFrame.new(0, 1.25, 0), Vector3.new(width, 2.5, depth), WOOD_DARK, Enum.Material.Wood)
	box(model, "Mattress", cf * CFrame.new(0, 3.5, 0), Vector3.new(width - 0.4, 2, depth - 0.6), WHITE, Enum.Material.Fabric)
	box(model, "Headboard", cf * CFrame.new(0, 4.5, depth / 2 - 0.4), Vector3.new(width, 9, 0.8), WOOD_DARK, Enum.Material.Wood)
	box(model, "Pillow", cf * CFrame.new(0, 5.0, depth / 2 - 2.4), Vector3.new(width * 0.65, 1.1, 2.6), Color3.fromRGB(250, 250, 255), Enum.Material.Fabric)
	local blanketColor = if look then look.blanket else Color3.fromRGB(200, 185, 160)
	box(model, "Blanket", cf * CFrame.new(0, 4.6, -1.6), Vector3.new(width - 0.2, 0.4, depth - 4.6), blanketColor, Enum.Material.Fabric)
	surface(floorNo, r, baseY + 4.8)
	if look then
		local head = buildSleeper(model, cf, width, depth, look, it.t)
		model:SetAttribute("Sleeper", look.name)
		model:SetAttribute("Snore", look.snore)
		model:SetAttribute("Pitch", look.pitch)
		model:SetAttribute("Sleep", 0)
		table.insert(sleepers, { name = look.name, model = model, head = head, rest = head.CFrame, floor = floorNo, sleep = 0, sent = 0 })
	end
end

local function buildFurniture(lv: Level, it: any, floorNo: number, baseY: number, parent: Instance, tvSpot: Vector3?)
	local r = rectOf(it)
	local t = it.t
	local front = facing(lv, r, false)
	if t == "sofa" and tvSpot then
		local c = Vector3.new((r.x + r.w / 2) * U, 0, (r.y + r.h / 2) * U)
		local d = Vector3.new(tvSpot.X - c.X, 0, tvSpot.Z - c.Z)
		front = if math.abs(d.X) > math.abs(d.Z) then Vector3.new(math.sign(d.X), 0, 0) else Vector3.new(0, 0, math.sign(d.Z))
	end
	local cf, width, depth = frame(r, baseY, front)
	local model = Instance.new("Model")
	model.Name = t
	model.Parent = parent
	if t == "sofa" then
		local fabric = Color3.fromRGB(88, 104, 140)
		box(model, "Seat", cf * CFrame.new(0, 1.75, -0.6), Vector3.new(width, 3.5, depth - 1.2), fabric, Enum.Material.Fabric)
		box(model, "Back", cf * CFrame.new(0, 3.75, depth / 2 - 1), Vector3.new(width, 7.5, 2), fabric, Enum.Material.Fabric)
		for _, x in { -1, 1 } do
			box(model, "Arm", cf * CFrame.new(x * (width / 2 - 0.6), 2.75, -0.3), Vector3.new(1.2, 5.5, depth - 0.6), fabric, Enum.Material.Fabric)
		end
		for i = 0, 2 do
			box(model, "Cushion", cf * CFrame.new((i - 1) * (width - 2.4) / 3, 3.9, -0.8), Vector3.new((width - 2.6) / 3, 0.9, depth - 2.4), Color3.fromRGB(110, 128, 168), Enum.Material.Fabric, false)
		end
		surface(floorNo, r, baseY + 4.3)
	elseif t == "table" then
		box(model, "Top", cf * CFrame.new(0, 6, 0), Vector3.new(width, 0.5, depth), WOOD_LIGHT, Enum.Material.Wood)
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				box(model, "Leg", cf * CFrame.new(x * (width / 2 - 0.5), 2.9, z * (depth / 2 - 0.5)), Vector3.new(0.6, 5.8, 0.6), WOOD_LIGHT, Enum.Material.Wood)
			end
		end
		surface(floorNo, r, baseY + 6.25)
	elseif t == "tv" then
		box(model, "Stand", cf * CFrame.new(0, 1.75, 0), Vector3.new(width, 3.5, depth), WOOD_DARK, Enum.Material.Wood)
		box(model, "Screen", cf * CFrame.new(0, 6.6, depth / 2 - 0.5), Vector3.new(width * 0.95, 5.6, 0.35), Color3.fromRGB(18, 20, 26), Enum.Material.Glass)
		surface(floorNo, r, baseY + 3.5)
	elseif t == "washer" then
		box(model, "Body", cf * CFrame.new(0, 3.5, 0), Vector3.new(width - 0.4, 7, depth - 0.4), WHITE)
		local door = box(model, "Door", cf * CFrame.new(0, 3.6, -depth / 2 + 0.15) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 3.4, 3.4), Color3.fromRGB(90, 110, 130), Enum.Material.Glass, false)
		;(door :: Part).Shape = Enum.PartType.Cylinder
		surface(floorNo, r, baseY + 7)
	elseif t == "toilet" then
		box(model, "Bowl", cf * CFrame.new(0, 1.6, -0.6), Vector3.new(width * 0.75, 3.2, depth * 0.6), WHITE, Enum.Material.Marble)
		box(model, "Tank", cf * CFrame.new(0, 3, depth / 2 - 0.9), Vector3.new(width * 0.85, 6, 1.6), WHITE, Enum.Material.Marble)
		surface(floorNo, r, baseY + 3.3)
	elseif t == "bathtub" then
		local white = Color3.fromRGB(245, 248, 250)
		box(model, "Bottom", cf * CFrame.new(0, 0.4, 0), Vector3.new(width, 0.8, depth), white, Enum.Material.Marble)
		for _, x in { -1, 1 } do
			box(model, "Side", cf * CFrame.new(x * (width / 2 - 0.35), 2.4, 0), Vector3.new(0.7, 4.8, depth), white, Enum.Material.Marble)
		end
		for _, z in { -1, 1 } do
			box(model, "End", cf * CFrame.new(0, 2.4, z * (depth / 2 - 0.35)), Vector3.new(width, 4.8, 0.7), white, Enum.Material.Marble)
		end
	elseif t == "other" then
		box(model, "Cabinet", cf * CFrame.new(0, 3, 0), Vector3.new(width - 0.4, 6, depth - 0.4), WOOD_LIGHT, Enum.Material.Wood)
		for _, x in { -0.25, 0.25 } do
			box(model, "Handle", cf * CFrame.new(x * width, 4.6, -depth / 2 + 0.1), Vector3.new(0.2, 0.9, 0.2), Color3.fromRGB(70, 70, 75), Enum.Material.Metal, false)
		end
		surface(floorNo, r, baseY + 6)
	elseif t == "catStart" then
		local c = cf.Position
		local cushion = box(model, "CatBed", CFrame.new(c + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.8, 4.6, 4.6), Color3.fromRGB(240, 140, 185), Enum.Material.Fabric, false)
		;(cushion :: Part).Shape = Enum.PartType.Cylinder
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			local rim = box(model, "Rim", CFrame.new(c + Vector3.new(math.cos(a) * 2.2, 0.9, math.sin(a) * 2.2)), Vector3.one * 1.1, Color3.fromRGB(225, 110, 165), Enum.Material.Fabric, false)
			;(rim :: Part).Shape = Enum.PartType.Ball
		end
		catBed = c + Vector3.new(0, 1, 0)
	end
	return model
end

local TOY_COLORS = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 230, 120) }
local function buildToy(it: any, floorNo: number, baseY: number, parent: Instance)
	local r = rectOf(it)
	local cf = frame(r, baseY, Vector3.new(0, 0, -1))
	local model = Instance.new("Model")
	model.Name = "Toy"
	model:SetAttribute("Toy", it.t)
	model.Parent = parent
	local c = cf.Position
	if it.t == "squeaky" then
		local color = TOY_COLORS[rng:NextInteger(1, #TOY_COLORS)]
		local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		local body = box(model, "Body", CFrame.new(c + Vector3.new(0, 0.8, 0)) * spin, Vector3.new(1.6, 1.4, 1.9), color, Enum.Material.Plastic, false)
		;(body :: Part).Shape = Enum.PartType.Ball
		local head = box(model, "Head", CFrame.new(c + Vector3.new(0, 1.8, 0)) * spin * CFrame.new(0, 0, -0.6), Vector3.one * 1.0, color, Enum.Material.Plastic, false)
		;(head :: Part).Shape = Enum.PartType.Ball
		box(model, "Beak", CFrame.new(c + Vector3.new(0, 1.7, 0)) * spin * CFrame.new(0, 0, -1.2), Vector3.new(0.5, 0.25, 0.5), Color3.fromRGB(255, 140, 40), Enum.Material.Plastic, false)
		model.PrimaryPart = body
	else
		local base = box(model, "Base", CFrame.new(c + Vector3.new(0, 0.2, 0)), Vector3.new(r.w * U - 0.6, 0.4, r.h * U - 0.6), Color3.fromRGB(240, 240, 245), Enum.Material.Plastic, false)
		local ring = r.w * U / 2 - 0.9
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			box(model, "Track", CFrame.new(c + Vector3.new(math.cos(a) * ring, 0.8, math.sin(a) * ring)) * CFrame.Angles(0, -a, 0), Vector3.new(0.5, 0.8, ring * 0.42), TOY_COLORS[i % 4 + 1], Enum.Material.Plastic, false)
		end
		local ball = box(model, "Ball", CFrame.new(c + Vector3.new(ring, 1.4, 0)), Vector3.one * 1.1, Color3.fromRGB(255, 80, 80), Enum.Material.Plastic, false)
		;(ball :: Part).Shape = Enum.PartType.Ball
		model.PrimaryPart = base
	end
	table.insert(toys, { kind = it.t, model = model, pos = c, floor = floorNo, ready = 0 })
end

local function furnish(lv: Level, floorNo: number, baseY: number, parent: Folder)
	local tvSpot: Vector3? = nil
	for _, it in lv.items do
		if it.t == "tv" then
			local r = rectOf(it)
			tvSpot = Vector3.new((r.x + r.w / 2) * U, baseY, (r.y + r.h / 2) * U)
		end
	end
	for _, it in lv.items do
		local t = it.t
		if t == "bedKid" or t == "bedGirl" or t == "bedMom" or t == "bedEmpty" then
			buildBed(lv, it, floorNo, baseY, parent)
		elseif t == "squeaky" or t == "ballTrack" then
			buildToy(it, floorNo, baseY, parent)
		elseif t == "key" then
			local r = rectOf(it)
			table.insert(keySpots, { floor = floorNo, pos = Vector3.new((r.x + 0.5) * U, baseY, (r.y + 0.5) * U) })
		elseif t ~= "stairsUp" and t ~= "stairsDown" and t ~= "exit" then
			buildFurniture(lv, it, floorNo, baseY, parent, if t == "sofa" then tvSpot else nil)
		end
	end
end

furnish(floor1, 1, 0, f1)
furnish(floor2, 2, FLOOR2, f2)

-- A key on furniture sits on top of it
local function keyHeight(floorNo: number, pos: Vector3): number
	local top = if floorNo == 2 then FLOOR2 else 0
	local sx, sz = math.floor(pos.X / U), math.floor(pos.Z / U)
	for _, s in surfaces do
		local r = s.rect
		if s.floor == floorNo and sx >= r.x and sx < r.x + r.w and sz >= r.y and sz < r.y + r.h then
			top = math.max(top, s.top)
		end
	end
	return top
end

-- Stairs from the hall up to floor 2: steps to look at, a smooth ramp to walk on
if stairsRect then
	local r = stairsRect
	local stairs = folder("Stairs", houseFolder)
	local x0, z0 = r.x * U, r.y * U
	local width, run = r.w * U, r.h * U
	local north = cell(floor2, r.x, r.y - 1) == "f" or cell(floor2, r.x, r.y + r.h) ~= "f"
	local steps = 11
	for i = 1, steps do
		local h = FLOOR2 * i / steps
		local zA = if north then z0 + run - (i - 1) * run / steps else z0 + (i - 1) * run / steps
		local zB = if north then z0 + run - i * run / steps else z0 + i * run / steps
		part({ Name = "Step", Size = Vector3.new(width, h, math.abs(zB - zA)), CFrame = CFrame.new(x0 + width / 2, h / 2, (zA + zB) / 2), Material = Enum.Material.WoodPlanks, Color = WOOD_LIGHT, CanCollide = false, Parent = stairs })
	end
	local bottom = Vector3.new(x0 + width / 2, 0, if north then z0 + run else z0)
	local top = Vector3.new(x0 + width / 2, FLOOR2, if north then z0 else z0 + run)
	local mid = (bottom + top) / 2
	local len = (top - bottom).Magnitude
	part({ Name = "Ramp", Size = Vector3.new(width, 1, len), CFrame = CFrame.lookAt(mid, top) * CFrame.new(0, -0.5, 0), Transparency = 1, Parent = stairs })
	-- A low rail around the hole upstairs, open at the top of the stairs
	local rail = Color3.fromRGB(150, 105, 70)
	local function railPart(a: Vector3, b: Vector3)
		local m = (a + b) / 2
		part({ Name = "Rail", Size = Vector3.new(0.4, 3, (b - a).Magnitude), CFrame = CFrame.lookAt(m, b) + Vector3.new(0, 1.5, 0), Material = Enum.Material.Wood, Color = rail, Parent = stairs })
	end
	local yTop = FLOOR2
	railPart(Vector3.new(x0, yTop, z0), Vector3.new(x0, yTop, z0 + run))
	railPart(Vector3.new(x0 + width, yTop, z0), Vector3.new(x0 + width, yTop, z0 + run))
	if north then
		railPart(Vector3.new(x0, yTop, z0 + run), Vector3.new(x0 + width, yTop, z0 + run))
	else
		railPart(Vector3.new(x0, yTop, z0), Vector3.new(x0 + width, yTop, z0))
	end
end

-- The front door: closed until all the keys are found
local exitDoor: BasePart? = nil
local exitHinge: CFrame? = nil
do
	local spot: { x: number, y: number }? = nil
	for _, it in floor1.items do
		if it.t == "exit" then
			spot = { x = it.x, y = it.y }
		end
	end
	if spot then
		local best: Rect? = nil
		for _, r in rects(floor1, function(c)
			return c == "d"
		end) do
			local edge = r.y == 0 or r.x == 0 or r.y + r.h == floor1.h or r.x + r.w == floor1.w
			local near = math.abs(r.x + r.w / 2 - (spot.x + 0.5)) + math.abs(r.y + r.h / 2 - (spot.y + 0.5))
			if edge and near < 4 and (not best or near < 4) then
				best = r
			end
		end
		if best then
			local across = best.w >= best.h
			local size = if across then Vector3.new(best.w * U, DOOR, 0.8) else Vector3.new(0.8, DOOR, best.h * U)
			local center = Vector3.new((best.x + best.w / 2) * U, DOOR / 2, (best.y + best.h / 2) * U)
			local door = part({ Name = "ExitDoor", Size = size, CFrame = CFrame.new(center), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 60, 40), Parent = houseFolder })
			for i = -1, 1 do
				local offset = if across then Vector3.new(i * 2.2, 1, -0.5) else Vector3.new(-0.5, 1, i * 2.2)
				local lock = part({ Name = "Lock", Size = Vector3.new(1.2, 1.6, 1.2), CFrame = CFrame.new(center + offset), Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 180, 60), CanCollide = false, Anchored = false, Parent = door })
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = door
				weld.Part1 = lock
				weld.Parent = lock
			end
			exitDoor = door
			local hingeOffset = if across then Vector3.new(-size.X / 2, 0, 0) else Vector3.new(0, 0, -size.Z / 2)
			exitHinge = CFrame.new(center + hingeOffset)
		end
	end
end

-- The backyard around the house, from the yard plan. The house sits at square 16, 14
local YX, YZ = -16 * U, -14 * U
local function inHouse(x: number, y: number): boolean
	return x >= 16 and x < 16 + floor1.w and y >= 14 and y < 14 + floor1.h
end
do
	local yf = folder("Yard")
	part({ Name = "Ground", Size = Vector3.new(yard.w * U + 400, 2, yard.h * U + 400), CFrame = CFrame.new(YX + yard.w * U / 2, -1.06, YZ + yard.h * U / 2), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 120, 60), Parent = yf })
	local function yardRects(kind: string): { Rect }
		return rects(yard, function(c, x, y)
			return c == kind and not inHouse(x, y)
		end)
	end
	for _, r in yardRects("p") do
		block(r, YX, YZ, -0.05, 0.1, { Name = "Path", Material = Enum.Material.Pavement, Color = Color3.fromRGB(170, 160, 145), Parent = yf })
	end
	for _, r in yardRects("s") do
		block(r, YX, YZ, -0.05, 0.25, { Name = "Soil", Material = Enum.Material.Ground, Color = Color3.fromRGB(100, 75, 55), Parent = yf })
	end
	for _, r in yardRects("o") do
		block(r, YX, YZ, -1.2, -0.3, { Name = "Water", Material = Enum.Material.Glass, Transparency = 0.3, Color = Color3.fromRGB(60, 110, 160), Parent = yf })
	end
	for _, r in yardRects("x") do
		block(r, YX, YZ, 0, 10, { Name = "Fence", Material = Enum.Material.WoodPlanks, Color = Color3.fromRGB(140, 105, 70), Parent = yf })
	end
	for _, r in yardRects("h") do
		block(r, YX, YZ, 0, 10, { Name = "Hedge", Material = Enum.Material.Grass, Color = Color3.fromRGB(55, 105, 50), Parent = yf })
	end
	for _, r in yardRects("f") do
		block(r, YX, YZ, -0.05, 0.12, { Name = "GarageFloor", Material = Enum.Material.Concrete, Color = Color3.fromRGB(150, 150, 150), Parent = yf })
	end
	for _, r in yardRects("w") do
		block(r, YX, YZ, 0, WALL, { Name = "Wall", Material = Enum.Material.Brick, Color = Color3.fromRGB(170, 120, 100), Parent = yf })
	end
	for _, r in rects(yard, function(c, x, y)
		return c == "d" and not inHouse(x, y) and x > 0 and y > 0 and x < yard.w - 1 and y < yard.h - 1
	end) do
		block(r, YX, YZ, DOOR, WALL, { Name = "DoorTop", Material = Enum.Material.Brick, Color = Color3.fromRGB(170, 120, 100), Parent = yf })
	end
	-- The gate in the fence stays shut for now
	for _, r in rects(yard, function(c, x, y)
		return c == "d" and (x == 0 or y == 0 or x == yard.w - 1 or y == yard.h - 1)
	end) do
		block(r, YX, YZ, 0, 10, { Name = "Gate", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 65, 70), Parent = yf })
	end
	for _, r in rects(yard, function(c, x, y)
		local edge = x == 0 or y == 0 or x == yard.w - 1 or y == yard.h - 1
		return (c == "f" or c == "w" or c == "d") and not inHouse(x, y) and not edge
	end) do
		block(r, YX, YZ, WALL, WALL + 1.5, { Name = "GarageRoof", Color = Color3.fromRGB(90, 90, 95), Parent = yf })
	end
	-- Garden things
	for _, it in yard.items do
		local r = rectOf(it)
		local cf = frame(r, 0, Vector3.new(0, 0, -1), YX, YZ)
		local c = cf.Position
		local w, d = r.w * U, r.h * U
		if it.t == "tree" then
			part({ Name = "Trunk", Size = Vector3.new(2, 18, 2), CFrame = CFrame.new(c + Vector3.new(0, 9, 0)), Material = Enum.Material.Wood, Color = Color3.fromRGB(95, 70, 50), Parent = yf })
			for i = 0, 3 do
				local leaf = part({ Name = "Leaves", Size = Vector3.one * (14 - i * 2), CFrame = CFrame.new(c + Vector3.new(math.cos(i) * 3, 20 + i * 2, math.sin(i) * 3)), Material = Enum.Material.Grass, Color = Color3.fromRGB(50, 105 + i * 8, 50), CanCollide = false, Parent = yf })
				;(leaf :: Part).Shape = Enum.PartType.Ball
			end
		elseif it.t == "bush" then
			local b = part({ Name = "Bush", Size = Vector3.new(w + 1, 6, d + 1), CFrame = CFrame.new(c + Vector3.new(0, 2.6, 0)), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 120, 55), Parent = yf })
			;(b :: Part).Shape = Enum.PartType.Ball
		elseif it.t == "flowers" then
			part({ Name = "Bed", Size = Vector3.new(w, 1, d), CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0)), Material = Enum.Material.Ground, Color = Color3.fromRGB(95, 70, 50), Parent = yf })
			for _ = 1, 10 do
				local f = part({ Name = "Flower", Size = Vector3.one * 0.9, CFrame = CFrame.new(c + Vector3.new(rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), 1.6, rng:NextNumber(-d / 2 + 0.6, d / 2 - 0.6))), Material = Enum.Material.SmoothPlastic, Color = TOY_COLORS[rng:NextInteger(1, 4)], CanCollide = false, Parent = yf })
				;(f :: Part).Shape = Enum.PartType.Ball
			end
		elseif it.t == "car" then
			local along = if r.h > r.w then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
			local len, wid = math.max(w, d), math.min(w, d)
			local base = CFrame.new(c) * along
			part({ Name = "CarBody", Size = Vector3.new(wid - 1, 4.5, len - 1), CFrame = base * CFrame.new(0, 3.4, 0), Color = Color3.fromRGB(245, 245, 248), Material = Enum.Material.SmoothPlastic, Parent = yf })
			part({ Name = "CarTop", Size = Vector3.new(wid - 2, 3.5, len * 0.5), CFrame = base * CFrame.new(0, 7.3, 1), Color = Color3.fromRGB(245, 245, 248), Parent = yf })
			part({ Name = "CarGlass", Size = Vector3.new(wid - 1.8, 3, len * 0.5 + 0.2), CFrame = base * CFrame.new(0, 7.3, 1), Color = Color3.fromRGB(40, 50, 70), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Parent = yf })
			for _, x in { -1, 1 } do
				for _, z in { -1, 1 } do
					local wheel = part({ Name = "Wheel", Size = Vector3.new(1.2, 3, 3), CFrame = base * CFrame.new(x * (wid / 2 - 0.6), 1.5, z * (len / 2 - 2.5)), Color = Color3.fromRGB(30, 30, 32), Parent = yf })
					;(wheel :: Part).Shape = Enum.PartType.Cylinder
				end
			end
		elseif it.t == "camera" then
			local dir = ({ Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0) })[it.r % 4 + 1]
			local cam = part({ Name = "Camera", Size = Vector3.new(1.2, 1.2, 2.4), CFrame = CFrame.lookAt(c + Vector3.new(0, 14, 0), c + Vector3.new(0, 12, 0) + dir * 10), Color = Color3.fromRGB(235, 235, 240), Parent = yf })
			local led = part({ Name = "Led", Size = Vector3.one * 0.35, CFrame = cam.CFrame * CFrame.new(0.35, 0.35, -1.2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 40, 40), CanCollide = false, Parent = yf })
			led:SetAttribute("Blink", true)
			part({ Name = "Pole", Size = Vector3.new(0.5, 14, 0.5), CFrame = CFrame.new(c + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(80, 80, 85), Parent = yf })
		end
	end
end

-- Night outside, warm lamps inside
Lighting.ClockTime = 0.6
Lighting.Brightness = 1.2
Lighting.Ambient = Color3.fromRGB(78, 80, 104)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 86, 120)
Lighting.FogEnd = 900

-- Pianka is the player
StarterPlayer.CharacterWalkSpeed = Config.WalkSpeed
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = Config.JumpHeight
local starter = Cat.character()
starter.Parent = StarterPlayer

-- Round state, shared by everyone in the server
local state: string = "play"
local function setState(s: string)
	state = s
	workspace:SetAttribute("State", s)
end
local keysFound = 0
local tease = 0
local keyFolder = folder("Keys")
local keyModels: { Model } = {}

local function root(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function toBed(player: Player)
	local r = root(player)
	if r then
		local a = rng:NextNumber(0, math.pi * 2)
		local spot = catBed + Vector3.new(math.cos(a) * 1.5, 1.5, math.sin(a) * 1.5)
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.lookAt(spot, spot + Vector3.new(0, 0, -1))
	end
end

local function makeKey(pos: Vector3, index: number): Model
	local gold = Color3.fromRGB(255, 205, 60)
	local model = Instance.new("Model")
	model.Name = "Key"
	local center = part({ Name = "Shaft", Size = Vector3.new(0.5, 0.5, 2.2), CFrame = CFrame.new(pos), Material = Enum.Material.Metal, Color = gold, CanCollide = false, Parent = model })
	local ring = part({ Name = "Ring", Size = Vector3.new(0.4, 1.5, 1.5), CFrame = center.CFrame * CFrame.new(0, 0, 1.4) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = gold, CanCollide = false, Parent = model })
	;(ring :: Part).Shape = Enum.PartType.Cylinder
	part({ Name = "Tooth", Size = Vector3.new(0.4, 0.6, 0.4), CFrame = center.CFrame * CFrame.new(0, -0.45, -0.7), Material = Enum.Material.Metal, Color = gold, CanCollide = false, Parent = model })
	part({ Name = "Tooth", Size = Vector3.new(0.4, 0.45, 0.4), CFrame = center.CFrame * CFrame.new(0, -0.38, -0.2), Material = Enum.Material.Metal, Color = gold, CanCollide = false, Parent = model })
	model.PrimaryPart = center
	model.Parent = keyFolder
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 10
	light.Brightness = 1.4
	light.Parent = center
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = gold
	sparkle.Parent = center
	model:SetAttribute("Index", index)
	return model
end

-- Three keys: mostly upstairs where people sleep, sometimes one downstairs as a bonus
local function placeKeys()
	keyFolder:ClearAllChildren()
	table.clear(keyModels)
	keysFound = 0
	workspace:SetAttribute("Keys", 0)
	local up, down = {}, {}
	for _, s in keySpots do
		table.insert(if s.floor == 2 then up else down, s)
	end
	local picks = {}
	local function take(list: { any })
		if #list > 0 then
			table.insert(picks, table.remove(list, rng:NextInteger(1, #list)))
		end
	end
	if #down > 0 and rng:NextNumber() < Config.DownstairsKeyChance then
		take(down)
	end
	while #picks < Config.KeyCount and (#up > 0 or #down > 0) do
		take(if #up > 0 then up else down)
	end
	for i, s in picks do
		local y = keyHeight(s.floor, s.pos) + 1.6
		table.insert(keyModels, makeKey(Vector3.new(s.pos.X, y, s.pos.Z), i))
	end
end

local doorOpen = false
local doorClosedCf = if exitDoor then exitDoor.CFrame else CFrame.identity
local function openDoor()
	local door, hinge = exitDoor, exitHinge
	if doorOpen then
		return
	end
	doorOpen = true
	if door and hinge then
		door.CanCollide = false
		local goal = hinge * CFrame.Angles(0, math.rad(-100), 0) * hinge:ToObjectSpace(door.CFrame)
		TweenService:Create(door, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { CFrame = goal }):Play()
	end
end

local function resetRound()
	setState("play")
	if exitDoor then
		doorOpen = false
		exitDoor.CFrame = doorClosedCf
		exitDoor.CanCollide = true
	end
	for _, s in sleepers do
		s.sleep = 0
		s.model:SetAttribute("Sleep", 0)
		s.head.CFrame = s.rest
	end
	placeKeys()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Out", nil)
		local r = root(player)
		if r then
			r.Anchored = false
		end
		toBed(player)
	end
	event:FireAllClients("round")
end

-- Someone woke up: Pianka goes back to bed and the keys go back
local function wake(s: { name: string, head: BasePart, rest: CFrame })
	if state ~= "play" then
		return
	end
	setState("caught")
	event:FireAllClients("wake", s.name, s.head.Position)
	TweenService:Create(s.head, TweenInfo.new(0.5, Enum.EasingStyle.Back), { CFrame = s.rest * CFrame.new(0, 3, -1.5) }):Play()
	for _, player in Players:GetPlayers() do
		local r = root(player)
		if r then
			r.Anchored = true
		end
	end
	task.delay(Config.CaughtTime, function()
		if workspace:GetAttribute("State") == "caught" then
			resetRound()
		end
	end)
end

local function noise(pos: Vector3, loud: number, floorNo: number)
	if state ~= "play" then
		return
	end
	if floorNo == 1 then
		tease += 1
		if tease % Config.TeaseEvery == 0 then
			event:FireAllClients("tease")
		end
	end
	for _, s in sleepers do
		if s.floor == floorNo then
			local d = (Vector3.new(s.head.Position.X, 0, s.head.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if d < Config.HearRange then
				s.sleep = math.min(100, s.sleep + loud * (1 - d / Config.HearRange))
			end
		end
	end
end

local function floorOf(y: number): number
	return if y > FLOOR2 - 3 then 2 else 1
end

local last: { [Player]: Vector3 } = {}
RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	if state == "play" then
		for _, player in Players:GetPlayers() do
			local r = root(player)
			if not r then
				continue
			end
			local pos = r.Position
			local prev = last[player]
			last[player] = pos
			local fl = floorOf(pos.Y)
			-- Running near a sleeper wakes them slowly
			if prev and dt > 0 then
				local speed = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z).Magnitude / dt
				if speed > Config.SneakSpeed + 3 and speed < 60 then
					for _, s in sleepers do
						if s.floor == fl then
							local d = (Vector3.new(s.head.Position.X, 0, s.head.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
							if d < Config.SnoreRange then
								s.sleep = math.min(100, s.sleep + Config.RunNoise * dt * (1 - d / Config.SnoreRange))
							end
						end
					end
				end
			end
			-- Toys squeak when you bump them
			for _, toy in toys do
				if toy.floor == fl and now >= toy.ready then
					local d = (toy.pos - Vector3.new(pos.X, toy.pos.Y, pos.Z)).Magnitude
					if d < Config.Toys[toy.kind].radius and math.abs(pos.Y - toy.pos.Y) < 4 then
						toy.ready = now + 1.4
						event:FireAllClients("toy", toy.model, toy.kind)
						noise(toy.pos, Config.Toys[toy.kind].loud, toy.floor)
					end
				end
			end
			-- Keys
			for i = #keyModels, 1, -1 do
				local key = keyModels[i]
				if (key:GetPivot().Position - pos).Magnitude < 3.4 then
					table.remove(keyModels, i)
					key:Destroy()
					keysFound += 1
					workspace:SetAttribute("Keys", keysFound)
					event:FireAllClients("key", player, keysFound)
					if keysFound >= Config.KeyCount then
						openDoor()
						event:FireAllClients("allKeys", player)
					end
				end
			end
			-- Out of the front door
			if doorOpen and not player:GetAttribute("Out") and pos.Y < 10 and (pos.X < -1 or pos.Z < -1 or pos.X > HOUSE_W + 1 or pos.Z > HOUSE_D + 1) then
				player:SetAttribute("Out", true)
				event:FireAllClients("escaped", player)
				if state == "play" then
					setState("won")
					task.delay(Config.WinRestart, function()
						if workspace:GetAttribute("State") == "won" then
							resetRound()
						end
					end)
				end
			end
		end
	end
	-- Too much noise wakes a sleeper, otherwise they calm down over time
	for _, s in sleepers do
		if state == "play" then
			if s.sleep >= 100 then
				wake(s)
			else
				s.sleep = math.max(0, s.sleep - Config.SleepCalm * dt)
			end
		end
		local shown = math.floor(s.sleep)
		if shown ~= s.sent then
			s.sent = shown
			s.model:SetAttribute("Sleep", shown)
		end
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = Config.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.JumpHeight
		task.defer(function()
			toBed(player)
			if state == "caught" then
				local r = root(player)
				if r then
					r.Anchored = true
				end
			end
		end)
	end)
end)
Players.PlayerRemoving:Connect(function(player: Player)
	last[player] = nil
end)

placeKeys()
workspace:SetAttribute("CatBed", catBed)
workspace:SetAttribute("Floor2", FLOOR2)
