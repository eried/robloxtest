-- Dumps the real part geometry of creatures from the running game for a render
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")
local V3 = roblox.Vector3

Engine.build()
-- Optional season: lune run tests/geometry.luau out.json Halloween
local SEASON = process.args[2] or "None"
Engine.patch = function(name: string, module: any)
	if name == "Config" then
		module.Season = SEASON
	end
end
Engine.startServer()
local workspace = Engine.workspace
local Config = Engine.server.modules[Engine.game:GetService("ReplicatedStorage"):FindFirstChild("Shared"):FindFirstChild("Config")]
local player, ctx = Engine.addPlayer("Ana")
for _ = 1, 20 * 25 do
	Engine.step(1 / 20)
end

local out = {}
local function dump(model: any, kind: string)
	local parts = {}
	local low = math.huge
	local list = model:GetDescendants()
	table.insert(list, model)
	for _, p in list do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local cf = p.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local c = p.Color
			table.insert(parts, {
				name = p.Name,
				cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				size = { p.Size.X, p.Size.Y, p.Size.Z },
				color = { c.R, c.G, c.B },
				ball = p.Shape == roblox.Enum.PartType.Ball,
				cyl = p.Shape == roblox.Enum.PartType.Cylinder,
				neon = p.Material == roblox.Enum.Material.Neon,
				alpha = 1 - p.Transparency,
			})
			if p.Name ~= "Cone" and p.Name ~= "Feather" then
				local corner = math.huge
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = cf * V3.new(sx * p.Size.X / 2, sy * p.Size.Y / 2, sz * p.Size.Z / 2)
							corner = math.min(corner, w.Y)
						end
					end
				end
				low = math.min(low, corner)
			end
		end
	end
	table.insert(out, { kind = kind, low = low, parts = parts, pivot = { model:GetPivot().X, model:GetPivot().Z } })
	print(string.format("%-10s lowest point %.2f studs above ground", kind, low))
end

local function first(folderName: string, kind: string, count: number)
	local folder = workspace:FindFirstChild(folderName)
	local n = 0
	if folder then
		for _, m in folder:GetChildren() do
			if m.ClassName == "Model" and (kind ~= "neighbor" or m.Name == "Neighbor") then
				dump(m, kind)
				n += 1
				if n >= count then
					break
				end
			end
		end
	end
end
first("Dogs", "dog", 3)
first("Rats", "rat", 2)
do
	local n = 0
	for _, bush in workspace:FindFirstChild("Forest"):GetChildren() do
		if bush.Name == "Bush" and (n < 2 or (n < 3 and bush:FindFirstChild("Mouth"))) then
			if n < 2 or bush:FindFirstChild("Mouth") then
				dump(bush, "bush")
				n += 1
			end
		end
	end
end
for _, m in workspace:GetChildren() do
	if m.Name == "Ghost" and m.ClassName == "Model" then
		dump(m, "ghost")
		break
	end
end
do
	local got = {}
	local decor = workspace:FindFirstChild("SeasonDecor")
	for _, d in (if decor then decor:GetChildren() else {}) do
		if (d.Name == "Grave" or d.Name == "Cauldron" or d.Name == "Web" or d.Name == "Balloons") and not got[d.Name] then
			got[d.Name] = true
			dump(d, string.lower(d.Name))
		end
	end
end
first("Birds", "bird", 1)
first("Neighbors", "neighbor", 1)
for _, m in workspace:GetChildren() do
	if m.Name == "Pianka" and m.ClassName == "Model" then
		dump(m, "pianka")
	end
end
first("Bones", "bone", 1)
first("Hedges", "hedge", 1)
first("Camp", "house", 1)

-- Hiding spots: switch modes a few times to see every kind
local seen = {}
local function spots()
	local twist = workspace:FindFirstChild("Twist")
	for _, p in (if twist then twist:GetChildren() else {}) do
		local kind = p:GetAttribute("Kind")
		if p.Name == "HidingSpot" and kind and not seen[kind] then
			seen[kind] = true
			dump(p, "spot:" .. kind)
		end
	end
end
spots()
local setMode = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("SetMode")
for i = 1, 12 do
	Engine.asClient(ctx, function()
		setMode:FireServer(if i % 2 == 0 then "Normal" else "Practice")
	end)
	for _ = 1, 20 * 7 do
		Engine.step(1 / 20)
	end
	spots()
end

-- Map data: hedges, guard lines, cabins, home and Pianka's area
do
	local map = { kind = "map", hedges = {}, dogs = {}, cabins = {}, home = { Config.HomePosition.X, Config.HomePosition.Z }, low = 0, parts = {}, pivot = { 0, 0 } }
	for _, hedge in workspace:FindFirstChild("Hedges"):GetChildren() do
		local core = hedge:FindFirstChild("Core")
		if core then
			local half = core.CFrame.LookVector * core.Size.Z / 2
			table.insert(map.hedges, { core.Position.X - half.X, core.Position.Z - half.Z, core.Position.X + half.X, core.Position.Z + half.Z })
		end
	end
	for _, dog in workspace:FindFirstChild("Dogs"):GetChildren() do
		local a, b = dog:GetAttribute("PathA"), dog:GetAttribute("PathB")
		if a and b then
			local p = dog.PrimaryPart.Position
			table.insert(map.dogs, { a.X, a.Z, b.X, b.Z, p.X, p.Z })
		end
	end
	for _, m in workspace:FindFirstChild("Neighbors"):GetChildren() do
		if m.Name == "Cabin" then
			local p = m:GetPivot().Position
			table.insert(map.cabins, { p.X, p.Z })
		end
	end
	local cat = workspace:GetAttribute("CatPosition")
	map.cat = if cat then { cat.X, cat.Z } else nil
	map.size = Config.ForestSize
	table.insert(out, map)
end

local character = player.Character
if character then
	dump(character, "player")
end

-- Normal: find Pianka, then stack every kitten on the head
local function press(prompt: any)
	if prompt then
		Engine.fireServer(prompt.Triggered, player)
		for _ = 1, 10 do
			Engine.step(1 / 20)
		end
	end
end
for _, part in workspace:FindFirstChild("Twist"):GetChildren() do
	if part:GetAttribute("Pianka") then
		press(part:FindFirstChildOfClass("ProximityPrompt"))
	end
end
for _, m in workspace:GetChildren() do
	if m.Name == Config.CatName and m.ClassName == "Model" then
		press(m:FindFirstChildWhichIsA("ProximityPrompt", true))
	end
end
for _ = 1, 20 * 8 do
	Engine.step(1 / 20)
end
for _, kitten in workspace:FindFirstChild("Kittens"):GetChildren() do
	press(kitten:FindFirstChildWhichIsA("ProximityPrompt", true))
end
character = player.Character
if character then
	print("tower kittens", player:GetAttribute("Kittens"))
	dump(character, "tower")
end

-- Oskar walking hand in hand with Nicola
Engine.asClient(ctx, function()
	setMode:FireServer(nil, "Oskar")
end)
for _ = 1, 20 * 3 do
	Engine.step(1 / 20)
end
character = player.Character
if character then
	print("oskar pair", player:GetAttribute("Pair"), character:FindFirstChild("Nicola") ~= nil)
	dump(character, "oskar")
end
fs.writeFile(process.args[1] or "geometry.json", require("@lune/serde").encode("json", out))
for _, e in Engine.errors do
	print("ERROR", e.msg)
end
