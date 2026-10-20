-- Dumps the house with Pianka posed for the icon and thumbnails: lune run tests/art.luau out.json
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")
local CFrame = Engine.CFrame

Engine.build()
Engine.startServer()
for _ = 1, 20 do
	Engine.step(1 / 20)
end
local shared = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local Cat = Engine.server.modules[shared:FindFirstChild("Cat")]
local Config = Engine.server.modules[shared:FindFirstChild("Config")]
local workspace = Engine.workspace

-- Pianka sneaking across the upstairs living room, and one looking at the camera for the icon
local f2 = Config.Floor2
local sneak = Cat.build(CFrame.lookAt(roblox.Vector3.new(63, f2 - 0.15, 64), roblox.Vector3.new(50, f2, 50)), 1)
sneak.model.Name = "Sneak"
sneak.model.Parent = workspace
local icon = Cat.build(CFrame.lookAt(roblox.Vector3.new(300, 0, 300), roblox.Vector3.new(300, 0, 310)), 1)
icon.model.Name = "Icon"
icon.model.Parent = workspace

local out = {}
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
		local c = p.Color
		local owner = p:FindFirstAncestorWhichIsA("Model")
		table.insert(out, {
			n = p.Name,
			m = if owner then owner.Name else "",
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			s = { p.Size.X, p.Size.Y, p.Size.Z },
			c = { c.R, c.G, c.B },
			ball = p.Shape == roblox.Enum.PartType.Ball,
			cyl = p.Shape == roblox.Enum.PartType.Cylinder,
			wedge = p.ClassName == "WedgePart",
			neon = p.Material == roblox.Enum.Material.Neon,
			a = 1 - p.Transparency,
		})
	end
end
fs.writeFile(process.args[1] or "art.json", require("@lune/serde").encode("json", out))
print(#out, "parts")
