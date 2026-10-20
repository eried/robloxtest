-- Dumps every part of the built world for a render: lune run tests/geometry.luau out.json
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")

Engine.build()
Engine.startServer()
Engine.addPlayer("Ana")
for _ = 1, 40 do
	Engine.step(1 / 20)
end
local out = {}
for _, p in Engine.workspace:GetDescendants() do
	if p:IsA("BasePart") and (p.Transparency < 1 or (process.args[2] == "all" and p.CanCollide)) then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
		local c = p.Color
		table.insert(out, {
			n = p.Name,
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			s = { p.Size.X, p.Size.Y, p.Size.Z },
			c = { c.R, c.G, c.B },
			ball = p.Shape == roblox.Enum.PartType.Ball,
			cyl = p.Shape == roblox.Enum.PartType.Cylinder,
			neon = p.Material == roblox.Enum.Material.Neon,
			wedge = p.ClassName == "WedgePart",
			mesh = p:FindFirstChildOfClass("SpecialMesh") ~= nil,
			a = 1 - p.Transparency,
			col = p.CanCollide,
		})
	end
end
fs.writeFile(process.args[1] or "geometry.json", require("@lune/serde").encode("json", out))
print(#out, "parts")
