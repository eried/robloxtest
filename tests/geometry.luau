-- Dumps the real part geometry of creatures from the running game for a render
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")
local V3 = roblox.Vector3

Engine.build()
Engine.startServer()
local workspace = Engine.workspace
local player = Engine.addPlayer("Ana")
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
first("Birds", "bird", 1)
first("Neighbors", "neighbor", 1)
for _, m in workspace:GetChildren() do
	if m.Name == "Pianka" and m.ClassName == "Model" then
		dump(m, "pianka")
	end
end
local character = player.Character
if character then
	dump(character, "player")
end
fs.writeFile(process.args[1] or "geometry.json", require("@lune/serde").encode("json", out))
for _, e in Engine.errors do
	print("ERROR", e.msg)
end
