-- Pianka the Escape: the sleeping house and the backyard, built from the plan, with keys, noise, cameras and the way out
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
local Watch = require(Shared:WaitForChild("Watch"))

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
	garageButton = { 1, 1 }, garageButtonIn = { 1, 1 }, ps5 = { 1, 1 }, pouf = { 2, 2 }, wardrobe = { 3, 1 }, vanity = { 2, 1 },
	controller = { 1, 1 }, blocks = { 1, 1 }, lipstick = { 1, 1 }, perfume = { 1, 1 }, basket = { 1, 1 }, boxes = { 1, 1 },
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
	{ words = { "bath", "toilet" }, material = Enum.Material.CeramicTiles, color = Color3.fromRGB(110, 160, 185), light = Color3.fromRGB(255, 230, 200), bright = 0.6 },
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
			local floorPart = block(r, 0, 0, baseY, baseY + 0.12, { Name = "Floor", Material = s.material, Color = s.color, Parent = parent })
			floorPart:SetAttribute("Room", string.lower(room.name))
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
			light.Shadows = false
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
-- Which room each floor cell belongs to, by name
local roomIds: { [number]: { [number]: number } } = {}
local roomLists: { [number]: { { cells: { number }, name: string } } } = {}
roomIds[1], roomLists[1] = buildLevel(floor1, 0, false, f1)
roomIds[2], roomLists[2] = buildLevel(floor2, FLOOR2, true, f2)
local function roomName(floorNo: number, x: number, y: number): string
	local lv = if floorNo == 2 then floor2 else floor1
	local id = roomIds[floorNo][y * lv.w + x]
	return if id then string.lower(roomLists[floorNo][id].name) else ""
end

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

type Sleeper = { name: string, model: Model, head: BasePart, rest: CFrame, floor: number, phase: string, next: number, since: number, facing: Vector3, shut: { BasePart }, open: { BasePart }, face: { { part: BasePart, rel: CFrame } }, side: number }
local sleepers: { Sleeper } = {}
local toys: { { kind: string, model: Model, pos: Vector3, floor: number, ready: number } } = {}
local keySpots: { { floor: number, pos: Vector3, room: string } } = {}
local catBed: Vector3 = Vector3.new(HOUSE_W / 2, 1, HOUSE_D / 2)

local WOOD_DARK = Color3.fromRGB(120, 80, 50)
local WOOD_LIGHT = Color3.fromRGB(190, 145, 95)
local WHITE = Color3.fromRGB(240, 240, 238)

local function buildSleeper(model: Model, cf: CFrame, width: number, depth: number, look: any, kind: string): (BasePart, { BasePart }, { BasePart })
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
	-- Closed eyes while asleep, open eyes when they look around
	local shut, open = {}, {}
	for _, x in { -0.55, 0.55 } do
		table.insert(shut, box(model, "Eye", headCf * CFrame.new(x, headSize / 2 - 0.05, -0.35), Vector3.new(0.5, 0.1, 0.12), Color3.fromRGB(60, 40, 40), Enum.Material.SmoothPlastic, false))
		local white = box(model, "EyeOpen", headCf * CFrame.new(x, headSize / 2 - 0.12, -0.4), Vector3.one * 0.62, Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, false)
		;(white :: Part).Shape = Enum.PartType.Ball
		local pupil = box(model, "EyeOpen", headCf * CFrame.new(x, headSize / 2 + 0.12, -0.45), Vector3.one * 0.3, Color3.fromRGB(30, 25, 25), Enum.Material.SmoothPlastic, false)
		;(pupil :: Part).Shape = Enum.PartType.Ball
		for _, p in { white, pupil } do
			p.Transparency = 1
			table.insert(open, p)
		end
	end
	local bodyLen = math.max(6, depth - 6.5)
	box(model, "Body", cf * CFrame.new(0, 5.6, depth / 2 - 4.6 - bodyLen / 2), Vector3.new(math.min(width - 1.2, if adult then 6 else 4.6), 2.6, bodyLen), look.blanket, Enum.Material.Fabric, false)
	return head, shut, open
end

-- Everything on the head moves with it: hair, bun, eyes
local function headParts(model: Model, head: BasePart): { { part: BasePart, rel: CFrame } }
	local list = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and (p == head or p.Name == "Hair" or p.Name == "Bun" or p.Name == "LongHair" or p.Name == "Eye" or p.Name == "EyeOpen") then
			table.insert(list, { part = p, rel = head.CFrame:ToObjectSpace(p.CFrame) })
		end
	end
	return list
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
	if it.t == "bedMom" then
		-- Her phone by the pillow, it lights up when a camera sees Pianka
		box(model, "Phone", cf * CFrame.new(width / 2 - 1.4, 4.58, depth / 2 - 2.4), Vector3.new(1, 0.16, 1.8), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic, false)
		box(model, "PhoneScreen", cf * CFrame.new(width / 2 - 1.4, 4.68, depth / 2 - 2.4), Vector3.new(0.85, 0.05, 1.6), Color3.fromRGB(12, 14, 20), Enum.Material.Glass, false)
	end
	if look then
		local head, shut, open = buildSleeper(model, cf, width, depth, look, it.t)
		local face = headParts(model, head)
		model:SetAttribute("Sleeper", look.name)
		model:SetAttribute("Snore", look.snore)
		model:SetAttribute("Pitch", look.pitch)
		model:SetAttribute("Room", roomName(floorNo, it.x, it.y))
		model:SetAttribute("Stir", "sleep")
		local first = os.clock() + rng:NextNumber(Config.StirEvery[1], Config.StirEvery[2]) + #sleepers * 3
		table.insert(sleepers, { name = look.name, model = model, head = head, rest = head.CFrame, floor = floorNo, phase = "sleep", next = first, since = 0, facing = Vector3.zero, shut = shut, open = open, face = face, side = 1 })
	end
end

local TOY_COLORS = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(150, 230, 120) }
local kitchenCount = 0
local function buildFurniture(lv: Level, it: any, floorNo: number, baseY: number, parent: Instance, partner: Vector3?)
	local r = rectOf(it)
	local room = roomName(floorNo, it.x, it.y)
	local t = it.t
	local front = facing(lv, r, false)
	-- A sofa and a TV in the same room face each other
	if partner then
		local c = Vector3.new((r.x + r.w / 2) * U, 0, (r.y + r.h / 2) * U)
		local d = Vector3.new(partner.X - c.X, 0, partner.Z - c.Z)
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
		-- The kid fell asleep playing: his TV still shows the game
		local kids = string.find(room, "kid", 1, true) ~= nil
		box(model, if kids then "GameScreen" else "Screen", cf * CFrame.new(0, 6.6, depth / 2 - 0.5), Vector3.new(width * 0.95, 5.6, 0.35), Color3.fromRGB(18, 20, 26), Enum.Material.Glass)
		surface(floorNo, r, baseY + 3.5)
	elseif t == "ps5" then
		local white = Color3.fromRGB(245, 246, 250)
		local black = Color3.fromRGB(22, 22, 28)
		box(model, "Stand", cf * CFrame.new(0, 0.15, 0), Vector3.new(1.6, 0.3, 1.6), black)
		box(model, "Core", cf * CFrame.new(0, 2.1, 0), Vector3.new(0.7, 3.6, 2.5), black)
		for _, x in { -0.48, 0.48 } do
			box(model, "Shell", cf * CFrame.new(x, 2.25, 0.05), Vector3.new(0.22, 3.9, 2.8), white)
		end
		box(model, "Light", cf * CFrame.new(0, 3.9, -1.2), Vector3.new(0.72, 0.08, 0.12), Color3.fromRGB(80, 150, 255), Enum.Material.Neon, false)
	elseif t == "basket" then
		-- A laundry basket with clothes spilling over the top
		local c = cf.Position
		local wicker = box(model, "Basket", CFrame.new(c + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2.8, 3, 3), Color3.fromRGB(205, 170, 120), Enum.Material.Fabric)
		;(wicker :: Part).Shape = Enum.PartType.Cylinder
		for i, color in { Color3.fromRGB(230, 110, 140), Color3.fromRGB(110, 160, 230), Color3.fromRGB(250, 240, 230) } do
			local cloth = box(model, "Clothes", CFrame.new(c + Vector3.new(-0.5 + i * 0.35, 3, (i % 2) * 0.5 - 0.25)), Vector3.one * 1.2, color, Enum.Material.Fabric, false)
			;(cloth :: Part).Shape = Enum.PartType.Ball
		end
		surface(floorNo, r, baseY + 2.9)
	elseif t == "boxes" then
		-- A stack of moving boxes
		local cardboard = Color3.fromRGB(190, 150, 100)
		box(model, "Box", cf * CFrame.new(0, 1.2, 0), Vector3.new(3.2, 2.4, 3.2), cardboard, Enum.Material.Cardboard)
		box(model, "Box", cf * CFrame.new(0.2, 3.3, -0.1) * CFrame.Angles(0, 0.3, 0), Vector3.new(2.6, 1.8, 2.6), cardboard:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Cardboard)
		box(model, "Tape", cf * CFrame.new(0, 2.42, 0), Vector3.new(0.5, 0.05, 3.2), Color3.fromRGB(220, 200, 150), Enum.Material.SmoothPlastic, false)
		surface(floorNo, r, baseY + 4.2)
	elseif t == "pouf" then
		-- A big soft bean bag
		local c = cf.Position
		local bag = box(model, "Pouf", CFrame.new(c + Vector3.new(0, 1.5, 0)), Vector3.new(width - 1.2, 3, depth - 1.2), Color3.fromRGB(255, 150, 60), Enum.Material.Fabric)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = bag
		local dent = box(model, "Dent", CFrame.new(c + Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 2.6, 2.6), Color3.fromRGB(230, 120, 45), Enum.Material.Fabric, false)
		;(dent :: Part).Shape = Enum.PartType.Cylinder
		surface(floorNo, r, baseY + 3)
	elseif t == "wardrobe" then
		-- Clothes inside, one door left open
		local h = 12.5
		box(model, "Back", cf * CFrame.new(0, h / 2, depth / 2 - 0.3), Vector3.new(width - 0.6, h, 0.4), WOOD_DARK, Enum.Material.Wood)
		for _, x in { -1, 1 } do
			box(model, "Side", cf * CFrame.new(x * (width / 2 - 0.5), h / 2, 0.3), Vector3.new(0.4, h, depth - 1.2), WOOD_DARK, Enum.Material.Wood)
		end
		box(model, "Top", cf * CFrame.new(0, h - 0.2, 0.3), Vector3.new(width - 0.6, 0.4, depth - 1.2), WOOD_DARK, Enum.Material.Wood)
		box(model, "Bottom", cf * CFrame.new(0, 0.5, 0.3), Vector3.new(width - 0.6, 1, depth - 1.2), WOOD_DARK, Enum.Material.Wood)
		box(model, "Inside", cf * CFrame.new(0, h / 2, depth / 2 - 0.55), Vector3.new(width - 1.4, h - 1.2, 0.1), Color3.fromRGB(70, 50, 40), Enum.Material.Wood, false)
		box(model, "Rod", cf * CFrame.new(0, h - 2, 0.4), Vector3.new(width - 1.4, 0.2, 0.2), Color3.fromRGB(190, 190, 195), Enum.Material.Metal, false)
		local clothes = { Color3.fromRGB(220, 90, 120), Color3.fromRGB(90, 140, 220), Color3.fromRGB(250, 220, 120), Color3.fromRGB(120, 200, 160), Color3.fromRGB(180, 120, 220), Color3.fromRGB(240, 240, 240) }
		for i, color in clothes do
			local x = -width / 2 + 1.3 + (i - 1) * (width - 2.6) / (#clothes - 1)
			local long = if i % 2 == 0 then 6.5 else 4.5
			box(model, "Clothes", cf * CFrame.new(x, h - 2.3 - long / 2, 0.4) * CFrame.Angles(0, 0.1 * (i % 3 - 1), 0), Vector3.new(1.4, long, 0.35), color, Enum.Material.Fabric, false)
		end
		local half = (width - 0.6) / 2
		box(model, "Door", cf * CFrame.new(-half / 2, h / 2 + 0.2, -depth / 2 + 0.75), Vector3.new(half - 0.1, h - 0.6, 0.3), WOOD_LIGHT, Enum.Material.Wood)
		box(model, "Handle", cf * CFrame.new(-0.6, h / 2, -depth / 2 + 0.55), Vector3.new(0.2, 1.2, 0.2), Color3.fromRGB(200, 170, 90), Enum.Material.Metal, false)
		local hinge = cf * CFrame.new(half, 0, -depth / 2 + 0.75) * CFrame.Angles(0, math.rad(-55), 0)
		box(model, "Door", hinge * CFrame.new(-half / 2, h / 2 + 0.2, 0), Vector3.new(half - 0.1, h - 0.6, 0.3), WOOD_LIGHT, Enum.Material.Wood, false)
		box(model, "Handle", hinge * CFrame.new(-half + 0.6, h / 2, -0.2), Vector3.new(0.2, 1.2, 0.2), Color3.fromRGB(200, 170, 90), Enum.Material.Metal, false)
	elseif t == "vanity" then
		-- Her make-up table with a mirror and a stool
		box(model, "Top", cf * CFrame.new(0, 5, 0.3), Vector3.new(width - 0.4, 0.4, depth - 0.8), WHITE, Enum.Material.Wood)
		for _, x in { -1, 1 } do
			box(model, "Drawers", cf * CFrame.new(x * (width / 2 - 1.3), 2.4, 0.3), Vector3.new(2.2, 4.8, depth - 1), WHITE, Enum.Material.Wood)
		end
		box(model, "MirrorFrame", cf * CFrame.new(0, 9.5, depth / 2 - 0.25), Vector3.new(5.4, 7, 0.3), Color3.fromRGB(215, 180, 110), Enum.Material.Wood, false)
		local mirror = box(model, "Mirror", cf * CFrame.new(0, 9.5, depth / 2 - 0.45), Vector3.new(4.8, 6.4, 0.1), Color3.fromRGB(190, 215, 235), Enum.Material.Glass, false)
		mirror.Reflectance = 0.4
		for i, color in { Color3.fromRGB(255, 140, 190), Color3.fromRGB(200, 60, 80), Color3.fromRGB(255, 220, 150), Color3.fromRGB(170, 120, 230) } do
			box(model, "Bottle", cf * CFrame.new(-2.4 + i * 1.0, 5.2 + 0.4 + (i % 2) * 0.3, 0.6), Vector3.new(0.5, 0.8 + (i % 2) * 0.6, 0.5), color, Enum.Material.Glass, false)
		end
		local stool = box(model, "Stool", cf * CFrame.new(0, 3, -depth / 2 - 1.6) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.8, 2.8, 2.8), Color3.fromRGB(240, 170, 200), Enum.Material.Fabric)
		;(stool :: Part).Shape = Enum.PartType.Cylinder
		box(model, "StoolLeg", cf * CFrame.new(0, 1.3, -depth / 2 - 1.6), Vector3.new(0.4, 2.6, 0.4), Color3.fromRGB(200, 170, 90), Enum.Material.Metal, false)
		surface(floorNo, r, baseY + 5.2)
	elseif t == "washer" then
		box(model, "Body", cf * CFrame.new(0, 3.5, 0), Vector3.new(width - 0.4, 7, depth - 0.4), WHITE)
		local door = box(model, "Door", cf * CFrame.new(0, 3.6, -depth / 2 + 0.15) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 3.4, 3.4), Color3.fromRGB(90, 110, 130), Enum.Material.Glass, false)
		;(door :: Part).Shape = Enum.PartType.Cylinder
		surface(floorNo, r, baseY + 7)
	elseif t == "toilet" then
		local chrome = Color3.fromRGB(200, 205, 212)
		box(model, "Bowl", cf * CFrame.new(0, 1.6, -0.6), Vector3.new(width * 0.75, 3.2, depth * 0.6), WHITE, Enum.Material.SmoothPlastic)
		box(model, "Seat", cf * CFrame.new(0, 3.3, -0.6), Vector3.new(width * 0.82, 0.2, depth * 0.64), Color3.fromRGB(230, 232, 236), Enum.Material.SmoothPlastic, false)
		box(model, "Lid", cf * CFrame.new(0, 4.7, depth / 2 - 1.85), Vector3.new(width * 0.78, 2.8, 0.2), Color3.fromRGB(230, 232, 236), Enum.Material.SmoothPlastic, false)
		box(model, "Tank", cf * CFrame.new(0, 3, depth / 2 - 0.9), Vector3.new(width * 0.85, 6, 1.6), WHITE, Enum.Material.SmoothPlastic)
		box(model, "Flush", cf * CFrame.new(0, 6.05, depth / 2 - 0.9), Vector3.new(0.6, 0.1, 0.6), chrome, Enum.Material.Metal, false)
		local roll = box(model, "Paper", cf * CFrame.new(width * 0.25, 6.45, depth / 2 - 0.9), Vector3.new(0.9, 0.9, 0.9), Color3.fromRGB(250, 250, 250), Enum.Material.Fabric, false)
		;(roll :: Part).Shape = Enum.PartType.Cylinder
		surface(floorNo, r, baseY + 3.3)
	elseif t == "bathtub" then
		local white = Color3.fromRGB(245, 248, 250)
		local chrome = Color3.fromRGB(200, 205, 212)
		box(model, "Bottom", cf * CFrame.new(0, 0.4, 0), Vector3.new(width, 0.8, depth), white, Enum.Material.SmoothPlastic)
		for _, x in { -1, 1 } do
			box(model, "Side", cf * CFrame.new(x * (width / 2 - 0.35), 2.4, 0), Vector3.new(0.7, 4.8, depth), white, Enum.Material.SmoothPlastic)
		end
		for _, z in { -1, 1 } do
			box(model, "End", cf * CFrame.new(0, 2.4, z * (depth / 2 - 0.35)), Vector3.new(width, 4.8, 0.7), white, Enum.Material.SmoothPlastic)
		end
		local water = box(model, "Water", cf * CFrame.new(0, 3.3, 0), Vector3.new(width - 1.4, 0.2, depth - 1.4), Color3.fromRGB(150, 205, 235), Enum.Material.Glass, false)
		water.Transparency = 0.3
		box(model, "Tap", cf * CFrame.new(width / 2 - 0.35, 5.4, 0), Vector3.new(0.4, 1.2, 0.4), chrome, Enum.Material.Metal, false)
		box(model, "Spout", cf * CFrame.new(width / 2 - 0.85, 5.8, 0), Vector3.new(1.0, 0.3, 0.3), chrome, Enum.Material.Metal, false)
		-- A rubber duck floating in the water
		local duckAt = cf * CFrame.new(width * 0.15, 3.85, -depth * 0.15)
		local duck = box(model, "Duck", duckAt, Vector3.one * 1.1, Color3.fromRGB(255, 215, 50), Enum.Material.SmoothPlastic, false)
		;(duck :: Part).Shape = Enum.PartType.Ball
		local duckHead = box(model, "Duck", duckAt * CFrame.new(0, 0.6, -0.4), Vector3.one * 0.7, Color3.fromRGB(255, 215, 50), Enum.Material.SmoothPlastic, false)
		;(duckHead :: Part).Shape = Enum.PartType.Ball
		box(model, "Beak", duckAt * CFrame.new(0, 0.55, -0.85), Vector3.new(0.35, 0.15, 0.3), Color3.fromRGB(255, 140, 40), Enum.Material.SmoothPlastic, false)
		-- A bath mat in front of the tub
		box(model, "Mat", cf * CFrame.new(0, 0.17, -depth / 2 - 1.5), Vector3.new(math.min(width, depth) * 0.8, 0.1, 2.4), Color3.fromRGB(240, 150, 170), Enum.Material.Fabric, false)
	elseif t == "other" and string.find(room, "kitchen", 1, true) then
		-- The kitchen gets a stove first, then a fridge
		kitchenCount += 1
		local metal = Color3.fromRGB(70, 70, 75)
		if kitchenCount % 2 == 1 then
			box(model, "Stove", cf * CFrame.new(0, 3, 0), Vector3.new(width - 0.4, 6, depth - 0.4), Color3.fromRGB(235, 235, 232), Enum.Material.SmoothPlastic)
			box(model, "Top", cf * CFrame.new(0, 6.15, 0), Vector3.new(width - 0.2, 0.3, depth - 0.2), Color3.fromRGB(45, 45, 50), Enum.Material.Slate)
			for _, x in { -0.22, 0.22 } do
				for _, z in { -0.2, 0.2 } do
					local burner = box(model, "Burner", cf * CFrame.new(x * width, 6.35, z * depth) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 1.8, 1.8), Color3.fromRGB(25, 25, 28), Enum.Material.Metal, false)
					;(burner :: Part).Shape = Enum.PartType.Cylinder
				end
			end
			box(model, "Oven", cf * CFrame.new(0, 2.6, -depth / 2 + 0.15), Vector3.new(width * 0.7, 2.6, 0.2), Color3.fromRGB(30, 30, 36), Enum.Material.Glass, false)
			box(model, "Handle", cf * CFrame.new(0, 4.3, -depth / 2 + 0.05), Vector3.new(width * 0.6, 0.25, 0.25), metal, Enum.Material.Metal, false)
			surface(floorNo, r, baseY + 6.3)
		else
			box(model, "Fridge", cf * CFrame.new(0, 6.5, 0), Vector3.new(width - 0.6, 13, depth - 0.6), Color3.fromRGB(240, 242, 245), Enum.Material.SmoothPlastic)
			box(model, "Line", cf * CFrame.new(0, 8.5, -depth / 2 + 0.25), Vector3.new(width - 0.6, 0.15, 0.1), Color3.fromRGB(190, 195, 200), Enum.Material.SmoothPlastic, false)
			for _, y in { 5, 11 } do
				box(model, "Handle", cf * CFrame.new(width / 2 - 1.2, y, -depth / 2 + 0.2), Vector3.new(0.25, 2, 0.3), metal, Enum.Material.Metal, false)
			end
			for i, c in { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 180, 255), Color3.fromRGB(255, 210, 60) } do
				box(model, "Magnet", cf * CFrame.new(-1 + i * 0.9, 10 + (i % 2) * 0.8, -depth / 2 + 0.22), Vector3.new(0.6, 0.6, 0.1), c, Enum.Material.SmoothPlastic, false)
			end
		end
	elseif t == "other" and string.find(room, "storage", 1, true) then
		-- Shelves with boxes
		for _, x in { -1, 1 } do
			box(model, "Post", cf * CFrame.new(x * (width / 2 - 0.3), 5, depth / 2 - 0.6), Vector3.new(0.4, 10, 0.4), WOOD_DARK, Enum.Material.Wood)
		end
		for i = 0, 2 do
			box(model, "Shelf", cf * CFrame.new(0, 1 + i * 3.6, depth / 2 - 1.4), Vector3.new(width - 0.4, 0.3, 2.2), WOOD_LIGHT, Enum.Material.Wood)
			for j = -1, 1 do
				box(model, "Box", cf * CFrame.new(j * width * 0.28, 1.9 + i * 3.6, depth / 2 - 1.4), Vector3.new(1.8, 1.5, 1.6), TOY_COLORS[(i + j + 3) % 4 + 1]:Lerp(Color3.fromRGB(180, 150, 110), 0.6), Enum.Material.Cardboard, false)
			end
		end
	elseif t == "other" and string.find(room, "guest", 1, true) then
		box(model, "Wardrobe", cf * CFrame.new(0, 5.5, 0.4), Vector3.new(width - 0.4, 11, depth - 1.2), WOOD_DARK, Enum.Material.Wood)
		for _, x in { -0.18, 0.18 } do
			box(model, "Handle", cf * CFrame.new(x * width, 5.5, -depth / 2 + 0.75), Vector3.new(0.2, 1.2, 0.2), Color3.fromRGB(200, 170, 90), Enum.Material.Metal, false)
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

local function buildToy(it: any, floorNo: number, baseY: number, parent: Instance)
	local r = rectOf(it)
	local cf = frame(r, baseY, Vector3.new(0, 0, -1))
	local model = Instance.new("Model")
	model.Name = "Toy"
	model:SetAttribute("Toy", it.t)
	model.Parent = parent
	local c = cf.Position
	local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local base = CFrame.new(c) * spin
	if it.t == "controller" then
		-- A game controller left on the floor
		local white = Color3.fromRGB(245, 246, 250)
		local body = box(model, "Body", base * CFrame.new(0, 0.3, 0), Vector3.new(1.9, 0.45, 1.0), white, Enum.Material.SmoothPlastic, false)
		for _, x in { -0.75, 0.75 } do
			local grip = box(model, "Grip", base * CFrame.new(x, 0.32, 0.45), Vector3.one * 0.75, white, Enum.Material.SmoothPlastic, false)
			;(grip :: Part).Shape = Enum.PartType.Ball
			local stick = box(model, "Stick", base * CFrame.new(x * 0.45, 0.6, 0.15) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.2, 0.3, 0.3), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic, false)
			;(stick :: Part).Shape = Enum.PartType.Cylinder
		end
		box(model, "Pad", base * CFrame.new(0, 0.54, -0.15), Vector3.new(0.75, 0.05, 0.45), Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic, false)
		box(model, "Light", base * CFrame.new(0, 0.54, -0.42), Vector3.new(0.6, 0.06, 0.08), Color3.fromRGB(80, 150, 255), Enum.Material.Neon, false)
		model.PrimaryPart = body
	elseif it.t == "blocks" then
		-- Toy bricks spilled on the floor
		local first: BasePart? = nil
		for i, off in { Vector3.new(-0.5, 0.3, 0.2), Vector3.new(0.6, 0.3, -0.3), Vector3.new(0.1, 0.9, 0.1) } do
			local color = TOY_COLORS[(i + it.x) % #TOY_COLORS + 1]
			local brick = box(model, "Brick", base * CFrame.new(off) * CFrame.Angles(0, i * 0.7, 0), Vector3.new(1.2, 0.6, 0.6), color, Enum.Material.SmoothPlastic, false)
			for _, sx in { -0.3, 0.3 } do
				local knob = box(model, "Knob", brick.CFrame * CFrame.new(sx, 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.16, 0.3, 0.3), color, Enum.Material.SmoothPlastic, false)
				;(knob :: Part).Shape = Enum.PartType.Cylinder
			end
			first = first or brick
		end
		model.PrimaryPart = first
	elseif it.t == "lipstick" then
		-- A few lipsticks rolled off the make-up table
		local first: BasePart? = nil
		local tips = { Color3.fromRGB(210, 30, 70), Color3.fromRGB(255, 110, 150), Color3.fromRGB(170, 40, 120) }
		for i, off in { Vector3.new(-0.5, 0.2, 0), Vector3.new(0.45, 0.2, 0.55), Vector3.new(0.3, 0.2, -0.6) } do
			local roll = base * CFrame.new(off) * CFrame.Angles(0, i * 1.1, 0)
			local tube = box(model, "Tube", roll * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.0, 0.36, 0.36), Color3.fromRGB(230, 190, 90), Enum.Material.Metal, false)
			;(tube :: Part).Shape = Enum.PartType.Cylinder
			local tip = box(model, "Tip", roll * CFrame.new(0, 0, -0.62) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.3, 0.3, 0.3), tips[i], Enum.Material.SmoothPlastic, false)
			;(tip :: Part).Shape = Enum.PartType.Cylinder
			first = first or tube
		end
		model.PrimaryPart = first
	elseif it.t == "perfume" then
		-- A glass perfume bottle
		local bottle = box(model, "Bottle", base * CFrame.new(0, 0.6, 0), Vector3.new(0.9, 1.2, 0.55), Color3.fromRGB(255, 160, 210), Enum.Material.Glass, false)
		bottle.Transparency = 0.25
		box(model, "Neck", base * CFrame.new(0, 1.3, 0), Vector3.new(0.3, 0.25, 0.3), Color3.fromRGB(230, 190, 90), Enum.Material.Metal, false)
		local cap = box(model, "Cap", base * CFrame.new(0, 1.6, 0), Vector3.one * 0.45, Color3.fromRGB(230, 190, 90), Enum.Material.Metal, false)
		;(cap :: Part).Shape = Enum.PartType.Ball
		model.PrimaryPart = bottle
	elseif it.t == "squeaky" then
		local color = TOY_COLORS[rng:NextInteger(1, #TOY_COLORS)]
		local body = box(model, "Body", CFrame.new(c + Vector3.new(0, 1.15, 0)) * spin, Vector3.new(2.4, 2.1, 2.8), color, Enum.Material.Plastic, false)
		;(body :: Part).Shape = Enum.PartType.Ball
		local head = box(model, "Head", CFrame.new(c + Vector3.new(0, 2.6, 0)) * spin * CFrame.new(0, 0, -0.9), Vector3.one * 1.5, color, Enum.Material.Plastic, false)
		;(head :: Part).Shape = Enum.PartType.Ball
		box(model, "Beak", CFrame.new(c + Vector3.new(0, 2.45, 0)) * spin * CFrame.new(0, 0, -1.75), Vector3.new(0.75, 0.35, 0.75), Color3.fromRGB(255, 140, 40), Enum.Material.Plastic, false)
		for _, x in { -0.35, 0.35 } do
			local eye = box(model, "Eye", CFrame.new(c + Vector3.new(0, 2.85, 0)) * spin * CFrame.new(x, 0, -1.55), Vector3.one * 0.25, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, false)
			;(eye :: Part).Shape = Enum.PartType.Ball
		end
		model.PrimaryPart = body
	else
		local plate = box(model, "Base", CFrame.new(c + Vector3.new(0, 0.2, 0)), Vector3.new(r.w * U - 0.6, 0.4, r.h * U - 0.6), Color3.fromRGB(240, 240, 245), Enum.Material.Plastic, false)
		local ring = r.w * U / 2 - 0.9
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			box(model, "Track", CFrame.new(c + Vector3.new(math.cos(a) * ring, 0.8, math.sin(a) * ring)) * CFrame.Angles(0, -a, 0), Vector3.new(0.5, 0.8, ring * 0.42), TOY_COLORS[i % 4 + 1], Enum.Material.Plastic, false)
		end
		local ball = box(model, "Ball", CFrame.new(c + Vector3.new(ring, 1.4, 0)), Vector3.one * 1.1, Color3.fromRGB(255, 80, 80), Enum.Material.Plastic, false)
		;(ball :: Part).Shape = Enum.PartType.Ball
		model.PrimaryPart = plate
	end
	table.insert(toys, { kind = it.t, model = model, pos = c, floor = floorNo, ready = 0 })
end

local function furnish(lv: Level, floorNo: number, baseY: number, parent: Folder)
	-- Each room's TV and sofa, so they can face each other
	local spots: { [string]: Vector3 } = {}
	for _, it in lv.items do
		if it.t == "tv" or it.t == "sofa" then
			local r = rectOf(it)
			spots[it.t .. roomName(floorNo, it.x, it.y)] = Vector3.new((r.x + r.w / 2) * U, baseY, (r.y + r.h / 2) * U)
		end
	end
	for _, it in lv.items do
		local t = it.t
		if t == "bedKid" or t == "bedGirl" or t == "bedMom" or t == "bedEmpty" then
			buildBed(lv, it, floorNo, baseY, parent)
		elseif Config.Toys[t] then
			buildToy(it, floorNo, baseY, parent)
		elseif t == "key" then
			local r = rectOf(it)
			table.insert(keySpots, { floor = floorNo, pos = Vector3.new((r.x + 0.5) * U, baseY, (r.y + 0.5) * U), room = roomName(floorNo, it.x, it.y) })
		elseif t ~= "stairsUp" and t ~= "stairsDown" and t ~= "exit" then
			local room = roomName(floorNo, it.x, it.y)
			buildFurniture(lv, it, floorNo, baseY, parent, if t == "sofa" then spots["tv" .. room] elseif t == "tv" then spots["sofa" .. room] else nil)
		end
	end
end

furnish(floor1, 1, 0, f1)
furnish(floor2, 2, FLOOR2, f2)

-- Make it a home: rugs, pictures, curtains, plants, a wall clock, chairs, nightstands, a doormat
local function decorate(lv: Level, floorNo: number, baseY: number, parent: Folder)
	local deco = folder("Decor", parent)
	local taken: { [number]: boolean } = {}
	-- Wall spots already used by something hanging, by cell and side
	local hung: { [number]: boolean } = {}
	local rugged: { [number]: boolean } = {}
	for _, it in lv.items do
		if it.t ~= "key" and it.t ~= "exit" then
			local r = rectOf(it)
			for j = r.y - (if it.t == "squeaky" or it.t == "ballTrack" then 0 else 0), r.y + r.h - 1 do
				for i = r.x, r.x + r.w - 1 do
					taken[j * lv.w + i] = true
				end
			end
		end
	end
	-- The vanity's stool stands in front of it
	for _, it in lv.items do
		if it.t == "vanity" then
			local r = rectOf(it)
			local front = facing(lv, r, false)
			for i = r.x, r.x + r.w - 1 do
				for j = r.y, r.y + r.h - 1 do
					taken[(j + math.round(front.Z)) * lv.w + i + math.round(front.X)] = true
				end
			end
		end
	end
	local function free(x: number, y: number): boolean
		return cell(lv, x, y) == "f" and not taken[y * lv.w + x] and not (floorNo == 2 and holeCells[y * lv.w + x])
	end
	local function nearDoor(x: number, y: number): boolean
		for dy = -2, 2 do
			for dx = -2, 2 do
				if cell(lv, x + dx, y + dy) == "d" then
					return true
				end
			end
		end
		return false
	end
	local function at(x: number, y: number, h: number): Vector3
		return Vector3.new((x + 0.5) * U, baseY + h, (y + 0.5) * U)
	end
	local PALETTE = { Color3.fromRGB(196, 92, 84), Color3.fromRGB(84, 120, 186), Color3.fromRGB(214, 170, 72), Color3.fromRGB(96, 160, 110), Color3.fromRGB(160, 100, 170) }
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local clockDone = false
	for index, room in roomLists[floorNo] do
		local name = string.lower(room.name)
		local wet = string.find(name, "bath", 1, true) or string.find(name, "toilet", 1, true)
		local plain = wet or string.find(name, "kitchen", 1, true) or string.find(name, "storage", 1, true)
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for _, k in room.cells do
			local x, y = k % lv.w, k // lv.w
			minX, minY, maxX, maxY = math.min(minX, x), math.min(minY, y), math.max(maxX, x), math.max(maxY, y)
		end
		if #room.cells < 6 then
			continue
		end
		local tint = PALETTE[(index + floorNo) % #PALETTE + 1]
		-- A rug in the middle of the room, or by the sofa when the middle is the stairs
		if not plain then
			local w, h = math.max(2, math.floor((maxX - minX + 1) * 0.5)), math.max(2, math.floor((maxY - minY + 1) * 0.45))
			local rx, ry = math.floor((minX + maxX + 1) / 2 - w / 2), math.floor((minY + maxY + 1) / 2 - h / 2)
			local ok = true
			for j = ry, ry + h - 1 do
				for i = rx, rx + w - 1 do
					if cell(lv, i, j) ~= "f" or (floorNo == 2 and holeCells[j * lv.w + i]) then
						ok = false
					end
				end
			end
			if ok then
				rugged[index] = true
				part({ Name = "Rug", Size = Vector3.new(w * U - 1, 0.1, h * U - 1), CFrame = CFrame.new((rx + w / 2) * U, baseY + 0.17, (ry + h / 2) * U), Material = Enum.Material.Fabric, Color = tint, CanCollide = false, CastShadow = false, Parent = deco })
				part({ Name = "Rug", Size = Vector3.new(w * U - 2.4, 0.11, h * U - 2.4), CFrame = CFrame.new((rx + w / 2) * U, baseY + 0.18, (ry + h / 2) * U), Material = Enum.Material.Fabric, Color = tint:Lerp(Color3.new(1, 1, 1), 0.35), CanCollide = false, CastShadow = false, Parent = deco })
			end
		end
		-- Pictures on plain stretches of wall, and the clock in the living room downstairs
		local placed: { { number } } = {}
		for _, k in room.cells do
			local x, y = k % lv.w, k // lv.w
			for di, d in DIRS do
				local wx, wy = x + d[1], y + d[2]
				local sx, sy = d[2], d[1]
				if cell(lv, wx, wy) == "w" and cell(lv, wx + sx, wy + sy) == "w" and cell(lv, wx - sx, wy - sy) == "w" and #placed < (if plain then 1 else 2) then
					local far = true
					for _, p in placed do
						if math.abs(p[1] - x) + math.abs(p[2] - y) < 4 then
							far = false
						end
					end
					if far and (x + y * 3 + index) % 3 == 0 then
						table.insert(placed, { x, y })
						hung[k * 4 + di] = true
						local face = at(x, y, 11) + Vector3.new(d[1], 0, d[2]) * (U / 2 - 0.2)
						local cf = CFrame.lookAt(face, face - Vector3.new(d[1], 0, d[2]))
						if not clockDone and floorNo == 1 and string.find(name, "living", 1, true) then
							clockDone = true
							local clock = part({ Name = "WallClock", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.2, 3.2), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(250, 248, 240), Parent = deco })
							part({ Name = "ClockRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 3.6, 3.6), CFrame = cf * CFrame.new(0, 0, 0.08) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD_DARK, Parent = deco })
							part({ Name = "Hand", Size = Vector3.new(0.15, 1.2, 0.08), CFrame = cf * CFrame.new(0, 0.5, -0.2), Color = Color3.fromRGB(30, 30, 30), CanCollide = false, Parent = deco })
							part({ Name = "Hand", Size = Vector3.new(0.9, 0.12, 0.08), CFrame = cf * CFrame.new(0.4, 0, -0.2), Color = Color3.fromRGB(30, 30, 30), CanCollide = false, Parent = deco })
							clock:SetAttribute("Ticks", true)
						else
							part({ Name = "Frame", Size = Vector3.new(4.4, 3.4, 0.25), CFrame = cf, Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false, Parent = deco })
							part({ Name = "Picture", Size = Vector3.new(3.8, 2.8, 0.1), CFrame = cf * CFrame.new(0, 0, -0.15), Color = Color3.fromRGB(150, 200, 240), CanCollide = false, Parent = deco })
							part({ Name = "Picture", Size = Vector3.new(3.8, 1.1, 0.1), CFrame = cf * CFrame.new(0, -0.85, -0.17), Color = tint:Lerp(Color3.fromRGB(90, 160, 90), 0.6), CanCollide = false, Parent = deco })
							local sun = part({ Name = "Picture", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.9, 0.9), CFrame = cf * CFrame.new(1, 0.6, -0.19) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 220, 90), CanCollide = false, Parent = deco })
							sun.Material = Enum.Material.SmoothPlastic
						end
					end
				end
			end
		end
		-- Potted plants in free corners, away from doors, a few in big rooms
		if not wet then
			local plants: { { number } } = {}
			for _, k in room.cells do
				local x, y = k % lv.w, k // lv.w
				local wallX = cell(lv, x - 1, y) == "w" or cell(lv, x + 1, y) == "w"
				local wallY = cell(lv, x, y - 1) == "w" or cell(lv, x, y + 1) == "w"
				local apart = true
				for _, p in plants do
					if math.abs(p[1] - x) + math.abs(p[2] - y) < 6 then
						apart = false
					end
				end
				if wallX and wallY and apart and free(x, y) and not nearDoor(x, y) then
					table.insert(plants, { x, y })
					local base = at(x, y, 0)
					local pot = part({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 2, 2), CFrame = CFrame.new(base + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 110, 70), Parent = deco })
					pot.Material = Enum.Material.Slate
					for i = 0, 2 do
						local leaf = part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * (2.6 - i * 0.4), CFrame = CFrame.new(base + Vector3.new(math.cos(i * 2.1) * 0.5, 3 + i * 0.9, math.sin(i * 2.1) * 0.5)), Color = Color3.fromRGB(60, 140 + i * 15, 70), Material = Enum.Material.Grass, CanCollide = false, Parent = deco })
						leaf.CastShadow = true
					end
					taken[y * lv.w + x] = true
					if #plants >= (if #room.cells > 120 then 3 else 1) then
						break
					end
				end
			end
		end
	end
	-- Living rooms get a coffee table by the sofa and a bookshelf, kids' rooms a toy chest
	local sofas, tvs = {}, {}
	for _, it in lv.items do
		if it.t == "sofa" then
			table.insert(sofas, rectOf(it))
		elseif it.t == "tv" and sofas[1] == nil then
			table.insert(tvs, rectOf(it))
		end
	end
	-- The TV that shares a room with the first sofa
	for _, it in lv.items do
		if it.t == "tv" and sofas[1] and roomName(floorNo, it.x, it.y) == roomName(floorNo, sofas[1].x, sofas[1].y) then
			table.insert(tvs, 1, rectOf(it))
		end
	end
	local function rectCenter(r: Rect): Vector3
		return Vector3.new((r.x + r.w / 2) * U, baseY, (r.y + r.h / 2) * U)
	end
	local sofaPair = sofas[1] and (tvs[1] or sofas[2])
	if sofas[1] and sofaPair then
		local a, b = rectCenter(sofas[1]), rectCenter(sofaPair)
		local m = (a + b) / 2
		local cx, cy = math.floor(m.X / U), math.floor(m.Z / U)
		if free(cx, cy) then
			local cf = CFrame.lookAt(m, m + (b - a).Unit)
			part({ Name = "CoffeeTable", Size = Vector3.new(6, 0.5, 3.6), CFrame = cf * CFrame.new(0, 2.6, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = deco })
			for _, lx in { -2.6, 2.6 } do
				for _, lz in { -1.4, 1.4 } do
					part({ Name = "TableLeg", Size = Vector3.new(0.4, 2.4, 0.4), CFrame = cf * CFrame.new(lx, 1.2, lz), Color = WOOD_DARK, CanCollide = false, Parent = deco })
				end
			end
			part({ Name = "Mug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.6, 0.6), CFrame = cf * CFrame.new(1.4, 3.25, 0.4) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 120, 110), CanCollide = false, Parent = deco })
			taken[cy * lv.w + cx] = true
			local rid = roomIds[floorNo][cy * lv.w + cx]
			if rid and not rugged[rid] then
				local len = math.max(6, (b - a).Magnitude - 5)
				part({ Name = "Rug", Size = Vector3.new(14, 0.1, len), CFrame = cf * CFrame.new(0, 0.17, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(150, 90, 80), CanCollide = false, CastShadow = false, Parent = deco })
				part({ Name = "Rug", Size = Vector3.new(12, 0.11, len - 2), CFrame = cf * CFrame.new(0, 0.18, 0), Material = Enum.Material.Fabric, Color = Color3.fromRGB(215, 180, 140), CanCollide = false, CastShadow = false, Parent = deco })
			end
		end
	end
	for _, room in roomLists[floorNo] do
		local name = string.lower(room.name)
		local living = string.find(name, "living", 1, true) ~= nil or string.find(name, "dining", 1, true) ~= nil
		local kids = string.find(name, "kid", 1, true) or string.find(name, "girl", 1, true)
		if living then
			-- Three free cells in a row along a solid wall
			local done = false
			for _, k in room.cells do
				if done then
					break
				end
				local x, y = k % lv.w, k // lv.w
				for _, d in DIRS do
					local sx, sy = d[2], d[1]
					local ok = true
					for i = -1, 1 do
						local cx, cy = x + sx * i, y + sy * i
						if not free(cx, cy) or nearDoor(cx, cy) or cell(lv, cx + d[1], cy + d[2]) ~= "w" then
							ok = false
						end
					end
					if ok then
						done = true
						local face = at(x, y, 0) + Vector3.new(d[1], 0, d[2]) * (U / 2 - 1.3)
						local cf = CFrame.lookAt(face, face - Vector3.new(d[1], 0, d[2]))
						part({ Name = "Bookshelf", Size = Vector3.new(U * 3 - 0.6, 10, 2.4), CFrame = cf * CFrame.new(0, 5, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = deco })
						for shelf = 0, 2 do
							for book = 0, 9 do
								local h = 1.8 + (book % 3) * 0.3
								part({ Name = "Book", Size = Vector3.new(0.8, h, 1.8), CFrame = cf * CFrame.new(-4.6 + book * 1.02, 1.2 + shelf * 3.2 + h / 2, -0.4), Color = PALETTE[(book + shelf) % #PALETTE + 1], CanCollide = false, Parent = deco })
							end
						end
						for i = -1, 1 do
							taken[(y + sy * i) * lv.w + (x + sx * i)] = true
						end
						break
					end
				end
			end
		elseif kids then
			for _, k in room.cells do
				local x, y = k % lv.w, k // lv.w
				local wallX = cell(lv, x - 1, y) == "w" or cell(lv, x + 1, y) == "w"
				local wallY = cell(lv, x, y - 1) == "w" or cell(lv, x, y + 1) == "w"
				if wallX and wallY and free(x, y) and not nearDoor(x, y) then
					local base = at(x, y, 0)
					local chest = Color3.fromRGB(240, 170, 60)
					part({ Name = "ToyChest", Size = Vector3.new(3.4, 2.6, 2.6), CFrame = CFrame.new(base + Vector3.new(0, 1.3, 0)), Color = chest, Material = Enum.Material.Wood, Parent = deco })
					part({ Name = "Lid", Size = Vector3.new(3.6, 0.4, 2.8), CFrame = CFrame.new(base + Vector3.new(0, 2.8, 0)), Color = chest:Lerp(Color3.new(1, 0.4, 0.4), 0.4), Material = Enum.Material.Wood, Parent = deco })
					taken[y * lv.w + x] = true
					break
				end
			end
		end
	end
	-- Curtains on both sides of every window, on the room side
	for _, r in rects(lv, function(c)
		return c == "n"
	end) do
		local across = r.w >= r.h
		local inward = Vector3.zero
		if across then
			inward = if cell(lv, r.x, r.y + 1) == "f" then Vector3.new(0, 0, 1) else Vector3.new(0, 0, -1)
		else
			inward = if cell(lv, r.x + 1, r.y) == "f" then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0)
		end
		local center = Vector3.new((r.x + r.w / 2) * U, baseY + 10.5, (r.y + r.h / 2) * U) + inward * (U / 2 + 0.25)
		local along = if across then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		local half = (if across then r.w else r.h) * U / 2
		local color = PALETTE[(r.x + r.y) % #PALETTE + 1]:Lerp(Color3.new(1, 1, 1), 0.25)
		for _, side in { -1, 1 } do
			local pos = center + along * side * (half - 0.9)
			part({ Name = "Curtain", Size = if across then Vector3.new(1.8, 10, 0.3) else Vector3.new(0.3, 10, 1.8), CFrame = CFrame.new(pos), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = deco })
		end
		part({ Name = "Rod", Size = if across then Vector3.new(r.w * U + 1, 0.25, 0.25) else Vector3.new(0.25, 0.25, r.h * U + 1), CFrame = CFrame.new(center + Vector3.new(0, 5.2, 0)), Color = WOOD_DARK, CanCollide = false, Parent = deco })
	end
	-- Chairs around tables, nightstands by beds, a doormat at the front door
	for _, it in lv.items do
		local r = rectOf(it)
		if it.t == "table" then
			local long = r.w >= r.h
			for _, side in { -1, 1 } do
				for _, off in { -0.25, 0.25 } do
					local c = Vector3.new((r.x + r.w / 2) * U, baseY, (r.y + r.h / 2) * U)
					local pos = if long then c + Vector3.new(off * r.w * U, 0, side * (r.h * U / 2 + 1.4)) else c + Vector3.new(side * (r.w * U / 2 + 1.4), 0, off * r.h * U)
					local face = (Vector3.new(c.X, 0, c.Z) - Vector3.new(pos.X, 0, pos.Z)).Unit
					local cf = CFrame.lookAt(pos, pos + face)
					part({ Name = "Chair", Size = Vector3.new(2.4, 0.4, 2.4), CFrame = cf * CFrame.new(0, 3.2, 0), Color = WOOD_LIGHT, Material = Enum.Material.Wood, Parent = deco })
					part({ Name = "ChairBack", Size = Vector3.new(2.4, 3.2, 0.35), CFrame = cf * CFrame.new(0, 4.9, 1.05), Color = WOOD_LIGHT, Material = Enum.Material.Wood, Parent = deco })
					for _, lx in { -0.95, 0.95 } do
						for _, lz in { -0.95, 0.95 } do
							part({ Name = "ChairLeg", Size = Vector3.new(0.3, 3, 0.3), CFrame = cf * CFrame.new(lx, 1.5, lz), Color = WOOD_DARK, Material = Enum.Material.Wood, CanCollide = false, Parent = deco })
						end
					end
				end
			end
		elseif it.t == "bedKid" or it.t == "bedGirl" or it.t == "bedMom" or it.t == "bedEmpty" then
			-- Next to the headboard, on whichever side has room
			local front = facing(lv, r, true)
			local cf = frame(r, baseY, front)
			local width = if math.abs(front.X) > 0.5 then r.h * U else r.w * U
			local depth = if math.abs(front.X) > 0.5 then r.w * U else r.h * U
			for _, side in { 1, -1 } do
				local spot = (cf * CFrame.new(side * (width / 2 + 1.6), 0, depth / 2 - 1.8)).Position
				local cx, cy = math.floor(spot.X / U), math.floor(spot.Z / U)
				if free(cx, cy) and not nearDoor(cx, cy) then
					local ncf = CFrame.lookAt(spot, spot + front)
					part({ Name = "Nightstand", Size = Vector3.new(2.6, 3.4, 2.6), CFrame = ncf * CFrame.new(0, 1.7, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = deco })
					part({ Name = "LampBase", Size = Vector3.new(0.5, 1.2, 0.5), CFrame = ncf * CFrame.new(0, 4, 0), Color = Color3.fromRGB(200, 190, 170), Parent = deco })
					local shade = part({ Name = "LampShade", Size = Vector3.new(1.4, 1, 1.4), CFrame = ncf * CFrame.new(0, 4.9, 0), Color = Color3.fromRGB(255, 225, 170), Material = Enum.Material.Neon, CanCollide = false, Parent = deco })
					local glow = Instance.new("PointLight")
					glow.Color = Color3.fromRGB(255, 200, 140)
					glow.Brightness = 0.25
					glow.Range = 12
					glow.Parent = shade
					taken[cy * lv.w + cx] = true
					break
				end
			end
		elseif it.t == "exit" then
			part({ Name = "Doormat", Size = Vector3.new(7, 0.12, 4), CFrame = CFrame.new((r.x + 1) * U, baseY + 0.18, (r.y + 0.3) * U), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Fabric, CanCollide = false, Parent = deco })
		end
	end

	-- A run of free cells along a solid wall, away from doors. The frame sits on the floor at
	-- the wall, looking into the room, X along the wall
	local function wallRun(cells: { number }, need: number): CFrame?
		for _, k in cells do
			local x, y = k % lv.w, k // lv.w
			for _, d in DIRS do
				local sx, sy = d[2], d[1]
				local ok = true
				for i = 0, need - 1 do
					local cx, cy = x + sx * i, y + sy * i
					if not free(cx, cy) or nearDoor(cx, cy) or cell(lv, cx + d[1], cy + d[2]) ~= "w" then
						ok = false
						break
					end
				end
				if ok then
					for i = 0, need - 1 do
						taken[(y + sy * i) * lv.w + x + sx * i] = true
					end
					local wallAt = at(x, y, 0) + Vector3.new(sx, 0, sy) * ((need - 1) * U / 2) + Vector3.new(d[1], 0, d[2]) * (U / 2)
					return CFrame.lookAt(wallAt, wallAt - Vector3.new(d[1], 0, d[2]))
				end
			end
		end
		return nil
	end
	-- A free spot high on a solid wall for things that hang there
	local function wallSpot(cells: { number }, from: number): CFrame?
		for n = 0, #cells - 1 do
			local k = cells[(from + n) % #cells + 1]
			local x, y = k % lv.w, k // lv.w
			for di, d in DIRS do
				if cell(lv, x + d[1], y + d[2]) == "w" and not hung[k * 4 + di] and free(x, y) and not nearDoor(x, y) then
					hung[k * 4 + di] = true
					local wallAt = at(x, y, 0) + Vector3.new(d[1], 0, d[2]) * (U / 2)
					return CFrame.lookAt(wallAt, wallAt - Vector3.new(d[1], 0, d[2]))
				end
			end
		end
		return nil
	end
	local function piece(name: string, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
		return part({ Name = name, CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = collide == true, Parent = deco })
	end
	local function round(p: BasePart, shape: Enum.PartType): BasePart
		(p :: Part).Shape = shape
		return p
	end
	local CHROME = Color3.fromRGB(200, 205, 212)
	-- A shelf on the wall with books and a little plant
	local function shelf(cf: CFrame, h: number, tint: Color3)
		piece("Shelf", cf * CFrame.new(0, h, -0.6), Vector3.new(3.6, 0.25, 1.2), WOOD_DARK, Enum.Material.Wood)
		for b = 0, 3 do
			local bh = 1.2 + (b % 2) * 0.35
			piece("Book", cf * CFrame.new(-1.4 + b * 0.5, h + 0.12 + bh / 2, -0.6), Vector3.new(0.4, bh, 0.9), PALETTE[(b + h) % #PALETTE + 1])
		end
		round(piece("Pot", cf * CFrame.new(1.1, h + 0.5, -0.6) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.8, 0.8, 0.8), tint, Enum.Material.Slate), Enum.PartType.Cylinder)
		round(piece("Leaves", cf * CFrame.new(1.1, h + 1.3, -0.6), Vector3.one * 1.1, Color3.fromRGB(70, 150, 80), Enum.Material.Grass), Enum.PartType.Ball)
	end
	-- A poster or a drawing on the wall
	local function poster(cf: CFrame, h: number, colors: { Color3 })
		piece("Poster", cf * CFrame.new(0, h, -0.1), Vector3.new(2.8, 3.6, 0.08), colors[1])
		piece("Poster", cf * CFrame.new(0, h + 0.4, -0.15), Vector3.new(1.6, 1.6, 0.06), colors[2])
		piece("Poster", cf * CFrame.new(0, h - 1.1, -0.15), Vector3.new(2.2, 0.5, 0.06), colors[3])
	end
	for index, room in roomLists[floorNo] do
		local name = string.lower(room.name)
		local function has(word: string): boolean
			return string.find(name, word, 1, true) ~= nil
		end
		if #room.cells < 6 then
			continue
		end
		if has("bath") or has("toilet") then
			-- A sink with a mirror, a shelf with bottles and a towel
			local cf = wallRun(room.cells, 1)
			if cf then
				piece("SinkStand", cf * CFrame.new(0, 2.2, -1.3), Vector3.new(1, 4.4, 1), WHITE, nil, true)
				piece("Sink", cf * CFrame.new(0, 4.9, -1.3), Vector3.new(3.2, 1, 2.4), WHITE, nil, true)
				piece("Basin", cf * CFrame.new(0, 5.42, -1.4), Vector3.new(2.4, 0.1, 1.6), Color3.fromRGB(190, 215, 230))
				piece("Tap", cf * CFrame.new(0, 5.8, -0.35), Vector3.new(0.3, 0.9, 0.3), CHROME, Enum.Material.Metal)
				piece("Spout", cf * CFrame.new(0, 6.15, -0.65), Vector3.new(0.25, 0.25, 0.7), CHROME, Enum.Material.Metal)
				piece("MirrorFrame", cf * CFrame.new(0, 10.2, -0.1), Vector3.new(3.8, 4.6, 0.2), CHROME, Enum.Material.Metal)
				piece("Mirror", cf * CFrame.new(0, 10.2, -0.22), Vector3.new(3.4, 4.2, 0.1), Color3.fromRGB(200, 225, 240), Enum.Material.Glass).Reflectance = 0.5
				piece("Shelf", cf * CFrame.new(0, 7.5, -0.45), Vector3.new(3.4, 0.2, 0.9), WHITE)
				for i, c in { Color3.fromRGB(120, 200, 230), Color3.fromRGB(255, 160, 190), Color3.fromRGB(250, 240, 200) } do
					local bh = 0.8 + (i % 2) * 0.4
					piece("Bottle", cf * CFrame.new(-1.6 + i * 0.8, 7.6 + bh / 2, -0.45), Vector3.new(0.5, bh, 0.5), c)
				end
			end
			local towel = wallSpot(room.cells, index * 3)
			if towel then
				piece("TowelBar", towel * CFrame.new(0, 8, -0.4), Vector3.new(3, 0.2, 0.2), CHROME, Enum.Material.Metal)
				piece("Towel", towel * CFrame.new(0, 6.1, -0.5), Vector3.new(2.4, 4, 0.25), PALETTE[index % #PALETTE + 1]:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Fabric)
			end
		elseif has("kitchen") then
			-- Counters with a sink and a kettle, cupboards above
			for run = 1, 2 do
				local cf = wallRun(room.cells, 2)
				if not cf then
					break
				end
				local len = 2 * U
				local white = Color3.fromRGB(235, 232, 225)
				piece("Counter", cf * CFrame.new(0, 2.9, -1.8), Vector3.new(len - 0.2, 5.8, 3.2), white, nil, true)
				piece("CounterTop", cf * CFrame.new(0, 6, -1.9), Vector3.new(len, 0.4, 3.6), Color3.fromRGB(60, 60, 66), Enum.Material.Slate, true)
				piece("Cupboard", cf * CFrame.new(0, 13, -1.0), Vector3.new(len - 0.2, 4, 2), white, nil, true)
				for _, x in { -len / 4, len / 4 } do
					piece("Handle", cf * CFrame.new(x, 5, -3.45), Vector3.new(0.8, 0.15, 0.15), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
					piece("Handle", cf * CFrame.new(x, 11.4, -2.05), Vector3.new(0.8, 0.15, 0.15), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
				end
				if run == 1 then
					piece("Basin", cf * CFrame.new(len / 4, 6.22, -2), Vector3.new(2.6, 0.1, 2), Color3.fromRGB(170, 175, 182), Enum.Material.Metal)
					piece("Tap", cf * CFrame.new(len / 4, 6.9, -0.6), Vector3.new(0.3, 1.2, 0.3), CHROME, Enum.Material.Metal)
					piece("Spout", cf * CFrame.new(len / 4, 7.45, -1.0), Vector3.new(0.25, 0.25, 0.9), CHROME, Enum.Material.Metal)
					round(piece("Kettle", cf * CFrame.new(-len / 4, 7, -1.9) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(1.6, 1.4, 1.4), Color3.fromRGB(220, 70, 60)), Enum.PartType.Cylinder)
				else
					round(piece("Bowl", cf * CFrame.new(0, 6.5, -1.9) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.6, 2.2, 2.2), Color3.fromRGB(240, 240, 235)), Enum.PartType.Cylinder)
					for i, c in { Color3.fromRGB(230, 60, 50), Color3.fromRGB(255, 200, 40), Color3.fromRGB(120, 200, 70) } do
						round(piece("Fruit", cf * CFrame.new(-0.5 + i * 0.35, 7.1, -1.9 + (i % 2) * 0.4), Vector3.one * 0.7, c), Enum.PartType.Ball)
					end
				end
			end
		elseif has("living") or has("dining") then
			-- A reading corner: an armchair and a floor lamp
			local chair = wallRun(room.cells, 1)
			if chair then
				local fabric = PALETTE[(index + 2) % #PALETTE + 1]
				piece("Armchair", chair * CFrame.new(0, 1.4, -2.2), Vector3.new(3.6, 2.8, 3.2), fabric, Enum.Material.Fabric, true)
				piece("ArmchairBack", chair * CFrame.new(0, 3.2, -0.9), Vector3.new(3.6, 6.4, 0.9), fabric, Enum.Material.Fabric, true)
				for _, x in { -1.6, 1.6 } do
					piece("ArmchairArm", chair * CFrame.new(x, 2.4, -2.1), Vector3.new(0.6, 2, 3.2), fabric, Enum.Material.Fabric, true)
				end
				piece("Cushion", chair * CFrame.new(0, 3, -2.3), Vector3.new(2.4, 0.5, 2.4), fabric:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Fabric)
			end
			local lamp = wallRun(room.cells, 1)
			if lamp then
				round(piece("LampFoot", lamp * CFrame.new(0, 0.15, -1.4) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.3, 1.6, 1.6), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, true), Enum.PartType.Cylinder)
				piece("LampPole", lamp * CFrame.new(0, 4.5, -1.4), Vector3.new(0.25, 9, 0.25), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, true)
				local shade = piece("LampShade", lamp * CFrame.new(0, 9.6, -1.4), Vector3.new(2.2, 1.8, 2.2), Color3.fromRGB(255, 225, 170), Enum.Material.Neon)
				local glow = Instance.new("PointLight")
				glow.Color = Color3.fromRGB(255, 200, 140)
				glow.Brightness = 0.4
				glow.Range = 18
				glow.Parent = shade
			end
			if #room.cells > 150 and floorNo == 2 then
				-- A piano with its bench
				local piano = wallRun(room.cells, 3)
				if piano then
					local black = Color3.fromRGB(25, 25, 30)
					piece("Piano", piano * CFrame.new(0, 3.8, -1.3), Vector3.new(3 * U - 0.8, 7.6, 2.4), black, nil, true).Reflectance = 0.15
					piece("Keys", piano * CFrame.new(0, 4.6, -2.9), Vector3.new(3 * U - 2, 0.4, 1.2), Color3.fromRGB(245, 245, 240), nil, true)
					for i = 0, 13 do
						if i % 7 ~= 2 and i % 7 ~= 6 then
							piece("BlackKey", piano * CFrame.new(-4.6 + i * 0.7, 4.9, -2.65), Vector3.new(0.3, 0.25, 0.7), black)
						end
					end
					piece("Music", piano * CFrame.new(0, 6.6, -2.4) * CFrame.Angles(math.rad(-15), 0, 0), Vector3.new(2.6, 1.8, 0.08), Color3.fromRGB(250, 248, 235))
					piece("Bench", piano * CFrame.new(0, 2.6, -5), Vector3.new(4.4, 0.6, 1.8), black, nil, true)
					for _, x in { -1.8, 1.8 } do
						piece("BenchLeg", piano * CFrame.new(x, 1.15, -5), Vector3.new(0.4, 2.3, 1.4), black)
					end
				end
			end
			-- A sideboard with a vase of flowers
			local side = wallRun(room.cells, 2)
			if side then
				piece("Sideboard", side * CFrame.new(0, 2.6, -1.4), Vector3.new(7.4, 5.2, 2.4), WOOD_DARK, Enum.Material.Wood, true)
				round(piece("Vase", side * CFrame.new(-1.8, 6.2, -1.4) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2, 1, 1), Color3.fromRGB(90, 140, 200), Enum.Material.Glass), Enum.PartType.Cylinder)
				for i, c in { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(250, 250, 250) } do
					round(piece("Flower", side * CFrame.new(-1.8 + (i - 2) * 0.45, 7.8 + (i % 2) * 0.3, -1.4), Vector3.one * 0.6, c), Enum.PartType.Ball)
				end
				for i = 0, 2 do
					round(piece("Plate", side * CFrame.new(1 + i * 0.3, 5.9 + i * 0.12, -1.4) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.12, 1.6, 1.6), WHITE), Enum.PartType.Cylinder)
				end
			end
			-- Pianka's scratching tree near her bed downstairs
			local tree = if floorNo == 1 then wallRun(room.cells, 1) else nil
			if tree then
				local sisal = Color3.fromRGB(200, 170, 120)
				piece("TreeBase", tree * CFrame.new(0, 0.3, -2), Vector3.new(3.2, 0.6, 3.2), Color3.fromRGB(240, 140, 185), Enum.Material.Fabric, true)
				round(piece("TreePost", tree * CFrame.new(0, 3.3, -2) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(5.4, 1.1, 1.1), sisal, Enum.Material.Fabric, true), Enum.PartType.Cylinder)
				piece("TreeTop", tree * CFrame.new(0, 6.2, -2), Vector3.new(3, 0.5, 3), Color3.fromRGB(240, 140, 185), Enum.Material.Fabric, true)
				round(piece("TreeBall", tree * CFrame.new(1.2, 5, -3.2), Vector3.one * 0.7, Color3.fromRGB(120, 200, 255)), Enum.PartType.Ball)
				piece("TreeString", tree * CFrame.new(1.2, 5.6, -3.2), Vector3.new(0.05, 1.2, 0.05), WHITE)
			end
		elseif has("hall") then
			-- Coats, a hat and shoes by the front door
			local rack = wallRun(room.cells, 1)
			if rack then
				piece("CoatRack", rack * CFrame.new(0, 5.5, -1.2), Vector3.new(0.35, 11, 0.35), WOOD_DARK, Enum.Material.Wood, true)
				piece("CoatFoot", rack * CFrame.new(0, 0.2, -1.2), Vector3.new(2, 0.4, 2), WOOD_DARK, Enum.Material.Wood, true)
				for i, c in { Color3.fromRGB(180, 60, 60), Color3.fromRGB(70, 90, 150), Color3.fromRGB(230, 200, 90) } do
					local a = i * 2.1
					piece("Coat", rack * CFrame.new(math.cos(a) * 0.7, 8, -1.2 + math.sin(a) * 0.7) * CFrame.Angles(0, a, 0), Vector3.new(1.6, 4.5, 0.5), c, Enum.Material.Fabric)
				end
				round(piece("Hat", rack * CFrame.new(0, 11.2, -1.2) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(0.8, 1.8, 1.8), Color3.fromRGB(90, 60, 40), Enum.Material.Fabric), Enum.PartType.Cylinder)
				for i, c in { Color3.fromRGB(40, 40, 46), Color3.fromRGB(240, 90, 120), Color3.fromRGB(240, 90, 120), Color3.fromRGB(40, 40, 46) } do
					piece("Shoe", rack * CFrame.new(-1.5 + (i - 1) * 0.6 + (if i > 2 then 1.4 else 0), 0.3, -2.6), Vector3.new(0.5, 0.5, 1.3), c)
				end
			end
		elseif has("kid") then
			-- Glow stars on the ceiling, a shelf with a rocket and a superhero poster
			for i = 1, 16 do
				local k = room.cells[(i * 37) % #room.cells + 1]
				local x, y = k % lv.w, k // lv.w
				local star = piece("Star", CFrame.new(at(x, y, WALL - 0.06) + Vector3.new(((i * 13) % 5 - 2) * 0.6, 0, ((i * 7) % 5 - 2) * 0.6)) * CFrame.Angles(0, i, 0), Vector3.new(0.7, 0.06, 0.7), Color3.fromRGB(210, 255, 170), Enum.Material.Neon)
				star.CastShadow = false
			end
			local spot = wallSpot(room.cells, 5)
			if spot then
				shelf(spot, 9, Color3.fromRGB(120, 150, 205))
			end
			local p = wallSpot(room.cells, 17)
			if p then
				poster(p, 13, { Color3.fromRGB(40, 60, 120), Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 210, 60) })
			end
		elseif has("girl") then
			-- Fairy lights along a wall, a shelf and a poster
			local lights = wallSpot(room.cells, 3)
			if lights then
				local colors = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 230, 140), Color3.fromRGB(170, 210, 255) }
				for i = 0, 8 do
					local x = -3.6 + i * 0.9
					local bulb = round(piece("FairyLight", lights * CFrame.new(x, 15 - math.sin(i / 8 * math.pi) * 0.8, -0.25), Vector3.one * 0.35, colors[i % 3 + 1], Enum.Material.Neon), Enum.PartType.Ball)
					bulb.CastShadow = false
				end
			end
			local spot = wallSpot(room.cells, 11)
			if spot then
				shelf(spot, 9, Color3.fromRGB(230, 170, 200))
			end
			local p = wallSpot(room.cells, 23)
			if p then
				poster(p, 12.5, { Color3.fromRGB(250, 200, 225), Color3.fromRGB(240, 80, 140), Color3.fromRGB(150, 110, 220) })
			end
		elseif has("mom") then
			-- Books, a plant and family drawings from the kids
			local spot = wallSpot(room.cells, 7)
			if spot then
				shelf(spot, 9, Color3.fromRGB(190, 110, 70))
			end
			local p = wallSpot(room.cells, 19)
			if p then
				poster(p, 12.5, { Color3.fromRGB(250, 248, 240), Color3.fromRGB(255, 120, 150), Color3.fromRGB(90, 160, 220) })
			end
		elseif has("guest") then
			-- A desk with a chair and a lamp
			local desk = wallRun(room.cells, 2)
			if desk then
				piece("Desk", desk * CFrame.new(0, 5.2, -1.6), Vector3.new(7, 0.4, 3), WOOD_LIGHT, Enum.Material.Wood, true)
				for _, x in { -3.2, 3.2 } do
					piece("DeskLeg", desk * CFrame.new(x, 2.5, -1.6), Vector3.new(0.4, 5, 2.6), WOOD_LIGHT, Enum.Material.Wood, true)
				end
				piece("Chair", desk * CFrame.new(0, 3.2, -4.2), Vector3.new(2.4, 0.4, 2.4), WOOD_DARK, Enum.Material.Wood, true)
				piece("ChairBack", desk * CFrame.new(0, 4.9, -5.3), Vector3.new(2.4, 3.2, 0.35), WOOD_DARK, Enum.Material.Wood, true)
				piece("Laptop", desk * CFrame.new(-1.2, 5.5, -1.8), Vector3.new(2, 0.15, 1.4), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
				piece("Mug", desk * CFrame.new(1.8, 5.8, -1.4), Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(90, 160, 220))
			end
		end
	end
end
decorate(floor1, 1, 0, f1)
decorate(floor2, 2, FLOOR2, f2)

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
	local steps = 22
	for i = 1, steps do
		local h = FLOOR2 * i / steps
		local zA = if north then z0 + run - (i - 1) * run / steps else z0 + (i - 1) * run / steps
		local zB = if north then z0 + run - i * run / steps else z0 + i * run / steps
		part({ Name = "Step", Size = Vector3.new(width, h, math.abs(zB - zA)), CFrame = CFrame.new(x0 + width / 2, h / 2, (zA + zB) / 2), Material = Enum.Material.WoodPlanks, Color = WOOD_LIGHT, CanCollide = false, Parent = stairs })
		-- Invisible sides so nobody walks into the stairs from the side
		for _, sx in { x0 - 0.25, x0 + width + 0.25 } do
			part({ Name = "StairSide", Size = Vector3.new(0.5, h, math.abs(zB - zA)), CFrame = CFrame.new(sx, h / 2, (zA + zB) / 2), Transparency = 1, Parent = stairs })
		end
	end
	-- And the tall end under the top of the stairs
	local zEnd = if north then z0 - 0.25 else z0 + run + 0.25
	part({ Name = "StairEnd", Size = Vector3.new(width + 1, FLOOR2, 0.5), CFrame = CFrame.new(x0 + width / 2, FLOOR2 / 2, zEnd), Transparency = 1, Parent = stairs })
	local bottom = Vector3.new(x0 + width / 2, 0, if north then z0 + run else z0)
	local top = Vector3.new(x0 + width / 2, FLOOR2, if north then z0 else z0 + run)
	local mid = (bottom + top) / 2
	local len = (top - bottom).Magnitude
	part({ Name = "Ramp", Size = Vector3.new(width, 1, len), CFrame = CFrame.lookAt(mid, top), Transparency = 1, Parent = stairs })
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
local cameras: { { eye: Vector3, yaw: number, phase: number, period: number } } = {}
local yardKeySpots: { { pos: Vector3, garage: boolean } } = {}
local gate: BasePart? = nil
local gateCap: BasePart? = nil
local gateClosedCf = CFrame.identity
local gateSlide = Vector3.zero
local gateLine = math.huge
local camFolder: Folder
local garageDoor: BasePart? = nil
local garageClosed = CFrame.identity
local garageSize = Vector3.zero
local garageButtons: { { part: BasePart, inside: boolean } } = {}
do
	local yf = folder("Yard")
	camFolder = folder("Cameras", yf)
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
		-- No jumping over the fence from anything: an invisible wall above it
		block(r, YX, YZ, 10, 90, { Name = "Boundary", Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false, Parent = yf })
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
		-- The big door out of the garage rolls up, inner doors stay open
		local outer = false
		for _, n in { { r.x, r.y - 1 }, { r.x, r.y + r.h }, { r.x - 1, r.y }, { r.x + r.w, r.y } } do
			local c = rawCell(yard, n[1], n[2])
			if c ~= "f" and c ~= "w" and c ~= "d" then
				outer = true
			end
		end
		if outer then
			local across = r.w >= r.h
			local size = if across then Vector3.new(r.w * U, DOOR, 1) else Vector3.new(1, DOOR, r.h * U)
			local door = part({ Name = "GarageDoor", Size = size, CFrame = CFrame.new(YX + (r.x + r.w / 2) * U, DOOR / 2, YZ + (r.y + r.h / 2) * U), Material = Enum.Material.DiamondPlate, Color = Color3.fromRGB(205, 205, 210), Parent = yf })
			garageDoor = door
			garageClosed = door.CFrame
			garageSize = size
		end
	end
	-- A dim lamp in the garage
	do
		local sx, sz, n = 0, 0, 0
		for y = 0, yard.h - 1 do
			for x = 0, yard.w - 1 do
				if rawCell(yard, x, y) == "f" and not inHouse(x, y) then
					sx += x
					sz += y
					n += 1
				end
			end
		end
		if n > 0 then
			local lamp = part({ Name = "Lamp", Size = Vector3.new(3, 0.4, 3), CFrame = CFrame.new(YX + (sx / n + 0.5) * U, WALL - 0.3, YZ + (sz / n + 0.5) * U), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 225, 170), CanCollide = false, Parent = yf })
			local light = Instance.new("PointLight")
			light.Color = lamp.Color
			light.Brightness = 0.5
			light.Range = 40
			light.Parent = lamp
		end
	end
	-- The gate in the fence, locked three times
	for _, r in rects(yard, function(c, x, y)
		return c == "d" and (x == 0 or y == 0 or x == yard.w - 1 or y == yard.h - 1)
	end) do
		local g = block(r, YX, YZ, 0, 10, { Name = "Gate", Material = Enum.Material.Metal, Color = Color3.fromRGB(60, 65, 70), Parent = yf })
		local across = r.w >= r.h
		for i = -1, 1 do
			local offset = if across then Vector3.new(i * 2.4, 1.5, -0.9 - r.h * U / 2 + 0.5) else Vector3.new(-0.9 - r.w * U / 2 + 0.5, 1.5, i * 2.4)
			local lock = part({ Name = "Lock", Size = Vector3.new(1.3, 1.7, 1.3), CFrame = CFrame.new(g.Position + offset), Material = Enum.Material.Metal, Color = Color3.fromRGB(220, 180, 60), CanCollide = false, Anchored = false, Parent = g })
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = g
			weld.Part1 = lock
			weld.Parent = lock
		end
		gate = g
		gateClosedCf = g.CFrame
		gateCap = block(r, YX, YZ, 10, 90, { Name = "Boundary", Transparency = 1, CanQuery = false, CanTouch = false, CastShadow = false, Parent = yf })
		-- A road outside the gate, with a dashed line
		local roadZ = YZ + (r.y + r.h) * U + 26
		part({ Name = "Road", Size = Vector3.new(yard.w * U + 200, 0.2, 16), CFrame = CFrame.new(YX + yard.w * U / 2, 0.05, roadZ), Material = Enum.Material.Asphalt, Color = Color3.fromRGB(55, 55, 60), Parent = yf })
		for i = 0, 18 do
			part({ Name = "RoadLine", Size = Vector3.new(6, 0.22, 0.6), CFrame = CFrame.new(YX - 90 + i * 24, 0.06, roadZ), Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 230, 200), CanCollide = false, Parent = yf })
		end
		gateSlide = Vector3.new(0, -9.9, 0)
		gateLine = YZ + (r.y + r.h) * U
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
			-- A camera on a pole, sweeping left and right. The client turns it and draws its cone
			local yaw = (it.r % 4) * math.pi / 2
			local phase = #cameras * 1.9
			local period = Config.CameraPeriod * (1 + 0.17 * ((#cameras % 3) - 1))
			local eye = c + Vector3.new(0, 14, 0)
			local look = Watch.look(yaw, phase, 0, period)
			local cam = Instance.new("Model")
			cam.Name = "Cam"
			cam:SetAttribute("Yaw", yaw)
			cam:SetAttribute("Phase", phase)
			cam:SetAttribute("Period", period)
			cam.Parent = camFolder
			local head = part({ Name = "Camera", Size = Vector3.new(1.2, 1.2, 2.4), CFrame = CFrame.lookAt(eye, eye + look * 10 - Vector3.new(0, 4, 0)), Color = Color3.fromRGB(235, 235, 240), CanCollide = false, Parent = cam })
			local led = part({ Name = "Led", Size = Vector3.one * 0.35, CFrame = head.CFrame * CFrame.new(0.35, 0.35, -1.2), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 40, 40), CanCollide = false, Parent = cam })
			led:SetAttribute("Blink", true)
			cam.PrimaryPart = head
			part({ Name = "Pole", Size = Vector3.new(0.5, 14, 0.5), CFrame = CFrame.new(c + Vector3.new(0, 6.6, 0)), Color = Color3.fromRGB(80, 80, 85), Parent = camFolder })
			table.insert(cameras, { eye = eye, yaw = yaw, phase = phase, period = period })
		elseif it.t == "key" then
			table.insert(yardKeySpots, { pos = Vector3.new(c.X, 0, c.Z), garage = rawCell(yard, it.x, it.y) == "f" })
		elseif it.t == "garageButton" then
			-- A post with a big button, out in the yard
			part({ Name = "ButtonPost", Size = Vector3.new(1, 4.5, 1), CFrame = CFrame.new(c + Vector3.new(0, 2.25, 0)), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal, Parent = yf })
			local b = part({ Name = "GarageButton", Size = Vector3.new(1.8, 0.6, 1.8), CFrame = CFrame.new(c + Vector3.new(0, 4.8, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 230, 100), Parent = yf })
			table.insert(garageButtons, { part = b, inside = false })
		elseif it.t == "garageButtonIn" then
			-- On the wall next to it inside the garage
			local offset = Vector3.zero
			for _, n in { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } } do
				if rawCell(yard, it.x + n[1], it.y + n[2]) == "w" then
					offset = Vector3.new(n[1], 0, n[2]) * (U / 2 - 0.35)
					break
				end
			end
			local size = if offset.X ~= 0 then Vector3.new(0.6, 1.6, 1.6) else Vector3.new(1.6, 1.6, 0.6)
			local b = part({ Name = "GarageButton", Size = size, CFrame = CFrame.new(c + offset + Vector3.new(0, 4, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(80, 230, 100), CanCollide = false, Parent = yf })
			table.insert(garageButtons, { part = b, inside = true })
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
-- The player's own avatar must not be dressed onto the cat
StarterPlayer.LoadCharacterAppearance = false
StarterPlayer.CharacterWalkSpeed = Config.WalkSpeed
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = Config.JumpHeight
local starter = Cat.character()
starter.Parent = StarterPlayer

-- Round state, shared by everyone in the server
local state: string = "play"
-- When each player's run started, when they joined, and if they saw the night from the start
local Runs = { start = {} :: { [Player]: number }, joined = {} :: { [Player]: number }, fresh = {} :: { [Player]: boolean } }
local function setState(s: string)
	state = s
	workspace:SetAttribute("State", s)
end
local keysFound = 0
local tease = 0
local keyFolder = folder("Keys")
local keyModels: { Model } = {}
-- After the house comes the yard: gate keys, cameras and the gate
local stage: string = "house"
local gateFound = 0
local gateOpen = false
local seen: { [Player]: number } = {}
local safeUntil: { [Player]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function setStage(s: string)
	stage = s
	workspace:SetAttribute("Stage", s)
end

-- Sleepers: asleep, a snort to warn, then they look around with open eyes
local function moveHead(s: Sleeper, goal: CFrame, seconds: number)
	for _, f in s.face do
		if seconds <= 0 then
			f.part.CFrame = goal * f.rel
		else
			TweenService:Create(f.part, TweenInfo.new(seconds, Enum.EasingStyle.Back), { CFrame = goal * f.rel }):Play()
		end
	end
end

local function setStir(s: Sleeper, phase: string, nextTime: number)
	s.phase = phase
	s.next = nextTime
	s.since = os.clock()
	if phase == "look" then
		-- Lift the head and look toward the room, to one side. The view is where the head ends up
		s.side = -s.side
		local goal = s.rest * CFrame.new(0, 1, 0) * CFrame.Angles(-0.45, 0, s.side * 0.45)
		local up = goal.UpVector
		s.facing = Vector3.new(up.X, 0, up.Z).Unit
		s.model:SetAttribute("Facing", s.facing)
		moveHead(s, goal, 0.5)
	elseif phase == "awake" then
		moveHead(s, s.rest * CFrame.new(0, 3, -1.5) * CFrame.Angles(-0.9, 0, 0), 0.5)
	elseif phase == "sleep" then
		moveHead(s, s.rest, 0.8)
	end
	s.model:SetAttribute("Stir", phase)
	local looking = phase == "look" or phase == "awake"
	for _, p in s.open do
		p.Transparency = if looking then 0 else 1
	end
	for _, p in s.shut do
		p.Transparency = if looking then 1 else 0
	end
end

-- The garage door: closed, opening, hold, closing
local garage = { open = 0, phase = "closed", hold = 0 }
local GREEN, AMBER = Color3.fromRGB(80, 230, 100), Color3.fromRGB(255, 180, 60)
local function setGarage(phase: string)
	garage.phase = phase
	workspace:SetAttribute("Garage", phase)
	for _, b in garageButtons do
		b.part.Color = if phase == "closed" or phase == "closing" then GREEN else AMBER
	end
end
local function showGarage()
	local door = garageDoor
	if door then
		local gap = garage.open * (DOOR - 1)
		door.Size = Vector3.new(garageSize.X, DOOR - gap, garageSize.Z)
		door.CFrame = garageClosed + Vector3.new(0, gap / 2, 0)
		door.CanCollide = gap < 3.6
	end
end
local function stepGarage(dt: number)
	if garage.phase == "opening" then
		garage.open = math.min(1, garage.open + dt / Config.GarageOpenTime)
		if garage.open >= 1 then
			garage.hold = Config.GarageHold
			setGarage("hold")
		end
		showGarage()
	elseif garage.phase == "hold" then
		garage.hold -= dt
		if garage.hold <= 0 then
			setGarage("closing")
		end
	elseif garage.phase == "closing" then
		garage.open = math.max(0, garage.open - dt / Config.GarageCloseTime)
		if garage.open <= 0 then
			setGarage("closed")
		end
		showGarage()
	end
end

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

local KEY_BRONZE = Color3.fromRGB(214, 150, 62)
local KEY_GLOW = Color3.fromRGB(255, 215, 110)
local function makeKey(pos: Vector3, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Key"
	-- Bronze like the key on the screen, with a glow around it so it shows in a dark room
	local center = part({ Name = "Shaft", Size = Vector3.new(0.7, 0.7, 3), CFrame = CFrame.new(pos), Material = Enum.Material.Metal, Color = KEY_BRONZE, Reflectance = 0.15, CanCollide = false, Parent = model })
	local ring = part({ Name = "Ring", Size = Vector3.new(0.55, 2.1, 2.1), CFrame = center.CFrame * CFrame.new(0, 0, 1.95) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Metal, Color = KEY_BRONZE, Reflectance = 0.15, CanCollide = false, Parent = model })
	;(ring :: Part).Shape = Enum.PartType.Cylinder
	part({ Name = "Tooth", Size = Vector3.new(0.55, 0.85, 0.55), CFrame = center.CFrame * CFrame.new(0, -0.6, -1), Material = Enum.Material.Metal, Color = KEY_BRONZE, CanCollide = false, Parent = model })
	part({ Name = "Tooth", Size = Vector3.new(0.55, 0.6, 0.55), CFrame = center.CFrame * CFrame.new(0, -0.5, -0.3), Material = Enum.Material.Metal, Color = KEY_BRONZE, CanCollide = false, Parent = model })
	model.PrimaryPart = center
	-- The light sits just above the key so it lights the key itself and the floor around it
	local lamp = part({ Name = "Glow", Size = Vector3.one * 0.2, CFrame = center.CFrame * CFrame.new(0, 2.2, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = model })
	local light = Instance.new("PointLight")
	light.Color = KEY_GLOW
	light.Range = 14
	light.Brightness = 2
	light.Parent = lamp
	local halo = Instance.new("Highlight")
	halo.FillColor = KEY_GLOW
	halo.FillTransparency = 0.75
	halo.OutlineColor = KEY_GLOW
	halo.OutlineTransparency = 0.1
	halo.DepthMode = Enum.HighlightDepthMode.Occluded
	halo.Parent = model
	model.Parent = keyFolder
	model:SetAttribute("Index", index)
	return model
end

local function take(picks: { any }, list: { any })
	if #list > 0 then
		table.insert(picks, table.remove(list, rng:NextInteger(1, #list)))
	end
end

-- Three keys upstairs, one in each bedroom, deep inside behind the toys
-- Keys go back to the same spots after a fail, new spots only after a win
local housePicks: { any }? = nil
local gatePicks: { any }? = nil
local function placeKeys(reroll: boolean?)
	keyFolder:ClearAllChildren()
	table.clear(keyModels)
	keysFound = 0
	workspace:SetAttribute("Keys", 0)
	if reroll or not housePicks then
		local byRoom: { [string]: { any } } = {}
		local rooms = {}
		for _, s in keySpots do
			if s.floor == 2 then
				if not byRoom[s.room] then
					byRoom[s.room] = {}
					table.insert(rooms, s.room)
				end
				table.insert(byRoom[s.room], s)
			end
		end
		local fresh = {}
		while #fresh < Config.KeyCount and #rooms > 0 do
			local room = table.remove(rooms, rng:NextInteger(1, #rooms)) :: string
			take(fresh, byRoom[room])
		end
		housePicks = fresh
	end
	for i, s in housePicks :: { any } do
		local y = keyHeight(s.floor, s.pos) + 1.6
		table.insert(keyModels, makeKey(Vector3.new(s.pos.X, y, s.pos.Z), i))
	end
end

-- Gate keys in the yard, one always hides in the garage
local function placeGateKeys()
	gateFound = 0
	workspace:SetAttribute("GateKeys", 0)
	if not gatePicks then
		local garage, other = {}, {}
		for _, s in yardKeySpots do
			table.insert(if s.garage then garage else other, s)
		end
		local fresh = {}
		take(fresh, garage)
		while #fresh < Config.GateKeyCount and (#other > 0 or #garage > 0) do
			take(fresh, if #other > 0 then other else garage)
		end
		gatePicks = fresh
	end
	for i, s in gatePicks :: { any } do
		local key = makeKey(s.pos + Vector3.new(0, 1.6, 0), i)
		key:SetAttribute("Gate", true)
		table.insert(keyModels, key)
	end
end

local function openGate()
	local g = gate
	if gateOpen or not g then
		return
	end
	gateOpen = true
	g.CanCollide = false
	if gateCap then
		gateCap.CanCollide = false
	end
	TweenService:Create(g, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { CFrame = gateClosedCf + gateSlide }):Play()
end

-- While a clip shows the door or the gate, sleepers settle and nobody can be caught
local function calmSleepers(seconds: number)
	local now = os.clock()
	for _, s in sleepers do
		if s.phase == "sleep" then
			s.next = math.max(s.next, now + seconds)
		elseif s.phase == "warn" or s.phase == "look" then
			setStir(s, "sleep", now + seconds + rng:NextNumber(1, 3))
		end
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

local function resetRound(reroll: boolean?)
	if reroll then
		gatePicks = nil
	end
	if reroll and state == "won" then
		for _, p in Players:GetPlayers() do
			Runs.start[p] = os.clock()
		end
	end
	-- After any reset everyone starts from nothing
	for _, p in Players:GetPlayers() do
		Runs.fresh[p] = true
	end
	setState("play")
	setStage("house")
	garage.open = 0
	setGarage("closed")
	showGarage()
	table.clear(seen)
	table.clear(safeUntil)
	gateFound = 0
	workspace:SetAttribute("GateKeys", 0)
	if gate then
		gateOpen = false
		gate.CFrame = gateClosedCf
		gate.CanCollide = true
	end
	if gateCap then
		gateCap.CanCollide = true
	end
	if exitDoor then
		doorOpen = false
		exitDoor.CFrame = doorClosedCf
		exitDoor.CanCollide = true
	end
	for i, s in sleepers do
		setStir(s, "sleep", os.clock() + rng:NextNumber(Config.StirEvery[1], Config.StirEvery[2]) + i * 3)
		moveHead(s, s.rest, 0)
	end
	placeKeys(reroll)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Out", nil)
		player:SetAttribute("Seen", nil)
		toBed(player)
		local r = root(player)
		if r then
			r.Anchored = false
		end
	end
	event:FireAllClients("round")
end

local function freezeAll()
	for _, player in Players:GetPlayers() do
		local r = root(player)
		if r then
			r.Anchored = true
		end
	end
end


-- Someone woke up: Pianka goes back to bed and the keys go back
local function wake(s: Sleeper, cause: string, culprit: Player?)
	if state ~= "play" then
		return
	end
	setState("caught")
	event:FireAllClients("wake", s.name, s.head.Position, cause, culprit)
	setStir(s, "awake", math.huge)
	freezeAll()
	task.delay(Config.CaughtTime, function()
		if workspace:GetAttribute("State") == "caught" then
			resetRound()
		end
	end)
end

-- A camera saw Pianka: mom's phone buzzes, she wakes up and everything starts over
local mom = nil
for _, s in sleepers do
	if s.model.Name == "bedMom" then
		mom = s
	end
end
local function spotted(eye: Vector3, player: Player)
	if state ~= "play" then
		return
	end
	setState("caught")
	event:FireAllClients("spotted", player, eye)
	freezeAll()
	task.delay(Config.SpottedTime * 0.55, function()
		if workspace:GetAttribute("State") == "caught" and mom then
			setStir(mom, "awake", math.huge)
		end
	end)
	task.delay(Config.SpottedTime, function()
		if workspace:GetAttribute("State") == "caught" then
			resetRound()
		end
	end)
end

-- The first camera that can see this spot right now, walls and bushes block the view
local function watcher(pos: Vector3, t: number): Vector3?
	for _, cam in cameras do
		if Watch.inCone(cam.eye, Watch.look(cam.yaw, cam.phase, t, cam.period), pos) then
			local filter: { Instance } = { camFolder, keyFolder }
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(filter, p.Character)
				end
			end
			rayParams.FilterDescendantsInstances = filter
			-- Along the ground, just like the red light on the grass: walls and bushes cast a shadow
			local from = Vector3.new(cam.eye.X, 1.5, cam.eye.Z)
			local to = Vector3.new(pos.X, 1.5, pos.Z)
			if not workspace:Raycast(from, to - from, rayParams) then
				return cam.eye
			end
		end
	end
	return nil
end

-- One squeak upstairs wakes the closest sleeper. Downstairs only gets a grumble, and every few a call
local function noise(pos: Vector3, floorNo: number, culprit: Player?)
	if state ~= "play" then
		return
	end
	if floorNo == 2 then
		local best: Sleeper? = nil
		local bestD = math.huge
		for _, s in sleepers do
			local d = (Vector3.new(s.head.Position.X, 0, s.head.Position.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if s.floor == 2 and d < bestD then
				best, bestD = s, d
			end
		end
		if best then
			wake(best, "toy", culprit)
		end
	else
		tease += 1
		event:FireAllClients(if tease % Config.TeaseEvery == 0 then "tease" else "grumble")
	end
end

local function floorOf(y: number): number
	return if y > FLOOR2 - 3 then 2 else 1
end

-- Speed: each run starts when the dream ends, wake ups and alarms cost time.
-- Best times live in an ordered data store and show in the player list
local Best = { store = nil :: any, names = {} :: { [number]: string }, top = {} :: { { name: string, time: number, id: number } } }
pcall(function()
	Best.store = game:GetService("DataStoreService"):GetOrderedDataStore("EscapeBestTimes")
end)
function Best.nameOf(id: number): string
	if not Best.names[id] then
		local ok, n = pcall(function()
			return Players:GetNameFromUserIdAsync(id)
		end)
		Best.names[id] = if ok and type(n) == "string" then n else "?"
	end
	return Best.names[id]
end
function Best.show(player: Player, tenths: number?)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		local f = Instance.new("Folder")
		f.Name = "leaderstats"
		f.Parent = player
		stats = f
	end
	local best = (stats :: Instance):FindFirstChild("⏱️") :: StringValue?
	if not best then
		local v = Instance.new("StringValue")
		v.Name = "⏱️"
		v.Value = "-"
		v.Parent = stats
		best = v
	end
	if tenths and best then
		local sec = math.floor(tenths / 10 + 0.5)
		best.Value = string.format("%d:%02d", sec // 60, sec % 60)
	end
end
function Best.load()
	local store = Best.store
	if not store then
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(true, 10)
	end)
	if not ok or not pages then
		return
	end
	local list = {}
	for _, entry in (pages :: any):GetCurrentPage() do
		local id = tonumber(entry.key) or 0
		table.insert(list, { name = Best.nameOf(id), time = entry.value / 10, id = id })
	end
	Best.top = list
end
-- Only the best time is kept, and nothing silly short
function Best.save(player: Player, seconds: number)
	local store = Best.store
	if not store or player.UserId <= 0 or seconds < Config.MinRunTime then
		return
	end
	local tenths = math.floor(seconds * 10 + 0.5)
	local ok, saved = pcall(function()
		return store:UpdateAsync(tostring(player.UserId), function(old: number?): number?
			if old and old <= tenths then
				return nil
			end
			return tenths
		end)
	end)
	if ok and type(saved) == "number" then
		Best.show(player, saved)
	end
end

-- After a win the end card can start the next night once the ending has played
local wonAt = 0
event.OnServerEvent:Connect(function(player: Player, kind: any)
	if kind == "again" and state == "won" and os.clock() - wonAt > Config.EndingTime then
		resetRound(true)
	elseif kind == "exitDone" and (safeUntil[player] or 0) > os.clock() + 0.5 then
		safeUntil[player] = os.clock() + 0.5
	elseif kind == "start" and Runs.joined[player] and os.clock() - Runs.joined[player] < 30 then
		-- The dream is over: the clock starts now
		Runs.start[player] = math.max(Runs.start[player] or 0, os.clock())
	end
end)

local last: { [Player]: Vector3 } = {}
local sampleAt: { [Player]: number } = {}
local speeds: { [Player]: number } = {}
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local function seesMoving(s: Sleeper): Player?
	if os.clock() - s.since < 0.3 then
		return nil
	end
	local facing = s.facing
	local floorY = if s.floor == 2 then FLOOR2 else 0
	local from = Vector3.new(s.head.Position.X, floorY + 1.5, s.head.Position.Z)
	for _, player in Players:GetPlayers() do
		local r = root(player)
		if r and floorOf(r.Position.Y) == s.floor and (speeds[player] or 0) > Config.MoveTolerance then
			local to = Vector3.new(r.Position.X, floorY + 1.5, r.Position.Z)
			local d = to - from
			local inFront = d.Magnitude < 0.1 or d.Unit:Dot(facing) >= math.cos(math.rad(Config.SightHalf))
			if d.Magnitude < Config.StirRange and inFront then
				local filter: { Instance } = { s.model, keyFolder }
				for _, p in Players:GetPlayers() do
					if p.Character then
						table.insert(filter, p.Character)
					end
				end
				sightParams.FilterDescendantsInstances = filter
				if not workspace:Raycast(from, d, sightParams) then
					return player
				end
			end
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	if state == "play" then
		for _, player in Players:GetPlayers() do
			local r = root(player)
			if not r then
				continue
			end
			local pos = r.Position
			local fl = floorOf(pos.Y)
			-- How fast Pianka moves, judged over 0.3 s so network bursts do not count
			local prev = last[player]
			if not prev or now - (sampleAt[player] or 0) >= 0.3 then
				if prev then
					speeds[player] = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z).Magnitude / math.max(now - (sampleAt[player] or now), 1 / 60)
				end
				last[player] = pos
				sampleAt[player] = now
			end
			-- Toys squeak when you bump them
			for _, toy in toys do
				if toy.floor == fl and now >= toy.ready then
					local d = (toy.pos - Vector3.new(pos.X, toy.pos.Y, pos.Z)).Magnitude
					local info = Config.Toys[toy.kind]
					if d < info.radius and pos.Y - toy.pos.Y > -2 and pos.Y - toy.pos.Y < (if info.small then Config.StepHeight else 4) then
						toy.ready = now + 1.4
						event:FireAllClients("toy", toy.model, toy.kind)
						noise(toy.pos, toy.floor, player)
					end
				end
			end
			-- Keys
			for i = #keyModels, 1, -1 do
				local key = keyModels[i]
				if (key:GetPivot().Position - pos).Magnitude < 3.4 then
					table.remove(keyModels, i)
					local forGate = key:GetAttribute("Gate") == true
					key:Destroy()
					if forGate then
						gateFound += 1
						workspace:SetAttribute("GateKeys", gateFound)
						event:FireAllClients("gateKey", player, gateFound)
						if gateFound >= Config.GateKeyCount then
							for _, p in Players:GetPlayers() do
								if p:GetAttribute("Out") then
									safeUntil[p] = math.max(safeUntil[p] or 0, now + 2.6)
								end
							end
							openGate()
							event:FireAllClients("gateOpen", player)
						end
					else
						keysFound += 1
						workspace:SetAttribute("Keys", keysFound)
						event:FireAllClients("key", player, keysFound)
						if keysFound >= Config.KeyCount then
							openDoor()
							calmSleepers(3.5)
							event:FireAllClients("allKeys", player)
						end
					end
				end
			end
			-- Garage buttons open the door, the one outside shows it opening
			if garage.phase == "closed" or garage.phase == "closing" then
				for _, b in garageButtons do
					local bp = b.part.Position
					if Vector3.new(bp.X - pos.X, 0, bp.Z - pos.Z).Magnitude < 3.4 and math.abs(bp.Y - pos.Y) < 5 then
						local wasShut = garage.phase == "closed"
						if not b.inside and wasShut then
							safeUntil[player] = math.max(safeUntil[player] or 0, now + Config.GarageClipTime)
						end
						setGarage("opening")
						event:FireAllClients("garage", player, if b.inside then "inside" elseif wasShut then "outside" else "again")
						break
					end
				end
			end
			-- Out of the front door and into the yard
			if doorOpen and not player:GetAttribute("Out") and pos.Y < 10 and (pos.X < -1 or pos.Z < -1 or pos.X > HOUSE_W + 1 or pos.Z > HOUSE_D + 1) then
				player:SetAttribute("Out", true)
				safeUntil[player] = now + Config.ExitClipTime
				if stage == "house" then
					setStage("yard")
					placeGateKeys()
				end
				event:FireAllClients("escaped", player)
			end
			-- Cameras watch the yard. A moment in their light and mom's phone buzzes
			if player:GetAttribute("Out") then
				local eye = if now >= (safeUntil[player] or 0) then watcher(pos, workspace:GetServerTimeNow()) else nil
				local s = seen[player] or 0
				s = if eye then s + dt / Config.SpotTime else math.max(0, s - dt / Config.SpotTime)
				seen[player] = s
				local shown = math.floor(math.min(s, 1) * 10) / 10
				if player:GetAttribute("Seen") ~= shown then
					player:SetAttribute("Seen", shown)
				end
				if eye and s >= 1 then
					spotted(eye, player)
					break
				end
			end
			-- Through the open gate: free
			if gateOpen and player:GetAttribute("Out") and pos.Z > gateLine + 2 then
				setState("won")
				wonAt = now
				event:FireAllClients("free", player)
				-- Times for the cats that played the whole night and are out, saved and ranked
				local times = {}
				for _, p in Players:GetPlayers() do
					if Runs.fresh[p] and p:GetAttribute("Out") then
						table.insert(times, { id = p.UserId, time = now - (Runs.start[p] or now) })
					end
				end
				task.spawn(function()
					for _, entry in times do
						local p = Players:GetPlayerByUserId(entry.id)
						if p then
							Best.save(p, entry.time)
						end
					end
					Best.load()
					event:FireAllClients("scores", times, Best.top)
				end)
				task.delay(Config.WinRestart, function()
					if workspace:GetAttribute("State") == "won" then
						resetRound(true)
					end
				end)
				break
			end
		end
	end
	if state == "play" then
		stepGarage(dt)
	end
	-- Sleepers stir now and then. While they look around, moving where they can see wakes them
	for _, s in sleepers do
		if state ~= "play" then
			break
		end
		if s.phase == "sleep" and now >= s.next then
			setStir(s, "warn", now + Config.StirWarn)
		elseif s.phase == "warn" and now >= s.next then
			setStir(s, "look", now + Config.StirTime)
		elseif s.phase == "look" then
			local mover = if Config.LookWakes then seesMoving(s) else nil
			if mover then
				wake(s, "look", mover)
				break
			end
			if now >= s.next then
				setStir(s, "sleep", now + rng:NextNumber(Config.StirEvery[1], Config.StirEvery[2]))
			end
		end
	end
end)

local function joined(player: Player)
	Runs.joined[player] = os.clock()
	Runs.start[player] = os.clock()
	Runs.fresh[player] = ((workspace:GetAttribute("Keys") :: number?) or 0) == 0 and stage == "house"
	Best.show(player, nil)
	task.spawn(function()
		local store = Best.store
		if store and player.UserId > 0 then
			local ok, best = pcall(function()
				return store:GetAsync(tostring(player.UserId))
			end)
			if ok and type(best) == "number" then
				Best.show(player, best)
			end
		end
	end)
	local function spawned(character: Model)
		seen[player] = nil
		safeUntil[player] = nil
		for _, p in character:GetDescendants() do
			if p:IsA("BasePart") then
				p.CollisionGroup = "Cats"
			end
		end
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.WalkSpeed = Config.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.JumpHeight
		player:SetAttribute("Out", nil)
		task.defer(function()
			toBed(player)
			if state == "caught" then
				local r = root(player)
				if r then
					r.Anchored = true
				end
			end
		end)
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then
		task.spawn(spawned, player.Character)
	end
end
pcall(function()
	local physics = game:GetService("PhysicsService")
	physics:RegisterCollisionGroup("Cats")
	physics:CollisionGroupSetCollidable("Cats", "Cats", false)
end)
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do
	task.spawn(joined, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	Runs.start[player] = nil
	Runs.joined[player] = nil
	Runs.fresh[player] = nil
	sampleAt[player] = nil
	last[player] = nil
	speeds[player] = nil
	seen[player] = nil
	safeUntil[player] = nil
end)

placeKeys()
setState("play")
setStage("house")
setGarage("closed")
workspace:SetAttribute("CatBed", catBed)
workspace:SetAttribute("Floor2", FLOOR2)
