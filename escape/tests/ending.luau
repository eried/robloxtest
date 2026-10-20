-- Dumps the home clip after a win for a render: lune run tests/ending.luau out.json [times]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")

Engine.build()
Engine.startServer()
local ana = Engine.addPlayer("Ana")
local DT = 1 / 30
for _ = 1, 30 * 16 do
	Engine.step(DT)
end
local remote = Engine.game:GetService("ReplicatedStorage"):FindFirstChildOfClass("RemoteEvent")
remote:FireAllClients("free", ana)
remote:FireAllClients("scores", { { id = ana.UserId, time = 201.5 } }, { { name = "Ana", time = 201.5, id = ana.UserId }, { name = "Bo", time = 260, id = 2 } })
local wanted = {}
for v in string.gmatch(process.args[2] or "1,3,4.5,5.4,6.3,7.6,8.6,10", "[^,]+") do
	table.insert(wanted, tonumber(v) :: number)
end
local frames = {}
local start = nil
for _ = 1, 30 * 40 do
	Engine.step(DT)
	local gui = ana.PlayerGui:FindFirstChild("Escape")
	local vf = nil
	for _, d in (if gui then gui:GetDescendants() else {}) do
		if d.ClassName == "ViewportFrame" and d.ZIndex == 22 then
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
				table.insert(parts, { n = p.Name, cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, s = { p.Size.X, p.Size.Y, p.Size.Z }, c = { c.R, c.G, c.B }, ball = p.Shape == roblox.Enum.PartType.Ball, wedge = p.ClassName == "WedgePart", neon = p.Material == roblox.Enum.Material.Neon, a = 1 - p.Transparency })
			end
		end
		local cx, cy, cz, c00, c01, c02, c10, c11, c12, c20, c21, c22 = vf.CurrentCamera.CFrame:GetComponents()
		table.insert(frames, { t = Engine.now - start, parts = parts, cam = { cx, cy, cz, c00, c01, c02, c10, c11, c12, c20, c21, c22 } })
	end
	if #wanted == 0 and ana.PlayerGui.Escape:FindFirstChild("Again", true) then
		break
	end
end
local card = ana.PlayerGui:FindFirstChild("Escape") and ana.PlayerGui.Escape:FindFirstChild("Again", true)
if card then
	local texts = {}
	for _, d in card.Parent:GetDescendants() do
		if d.ClassName == "TextLabel" then
			table.insert(texts, d.Text)
		end
	end
	print(table.concat(texts, " | "))
end
print(#frames, "frames", "card:", card ~= nil)
fs.writeFile(process.args[1] or "ending.json", require("@lune/serde").encode("json", frames))
