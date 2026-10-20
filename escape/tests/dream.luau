-- Dumps the dream bubble scene at a few moments for a render: lune run tests/dream.luau out.json
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")

Engine.build()
Engine.startServer()
local ana = Engine.addPlayer("Ana")
local DT = 1 / 30
local frames = {}
local wanted = { 1.6, 3.4, 5.2, 5.8, 7.5, 9.4, 10.6 }
local start = nil
for _ = 1, 30 * 30 do
	Engine.step(DT)
	local gui = ana:FindFirstChild("PlayerGui") and ana.PlayerGui:FindFirstChild("Escape")
	local vf = nil
	for _, d in (if gui then gui:GetDescendants() else {}) do
		if d.ClassName == "ViewportFrame" then
			vf = d
		end
	end
	if vf and not start then
		start = Engine.now
	end
	if vf and start and #wanted > 0 and Engine.now - start >= wanted[1] then
		table.remove(wanted, 1)
		local parts = {}
		for _, p in vf:GetDescendants() do
			if p:IsA("BasePart") then
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
				local c = p.Color
				table.insert(parts, {
					n = p.Name,
					cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
					s = { p.Size.X, p.Size.Y, p.Size.Z },
					c = { c.R, c.G, c.B },
					ball = p.Shape == roblox.Enum.PartType.Ball,
					wedge = p.ClassName == "WedgePart",
					neon = p.Material == roblox.Enum.Material.Neon,
					a = 1 - p.Transparency,
				})
			end
		end
		local cam = vf.CurrentCamera
		local cx, cy, cz, c00, c01, c02, c10, c11, c12, c20, c21, c22 = cam.CFrame:GetComponents()
		table.insert(frames, { t = Engine.now - start, parts = parts, cam = { cx, cy, cz, c00, c01, c02, c10, c11, c12, c20, c21, c22 } })
	end
	if #wanted == 0 then
		break
	end
end
fs.writeFile(process.args[1] or "dream.json", require("@lune/serde").encode("json", frames))
print(#frames, "frames")
