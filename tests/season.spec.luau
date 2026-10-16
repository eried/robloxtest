-- Season smoke test: runs the real scripts as Halloween or Christmas. Run: lune run tests/season.spec.luau Halloween
local process = require("@lune/process")
local Engine = require("./engine")

local SEASON = process.args[1] or "Halloween"
Engine.build()
Engine.patch = function(name: string, module: any)
	if name == "Config" then
		module.Season = SEASON
	end
end
Engine.startServer()
local workspace = Engine.workspace
Engine.addPlayer("Sam")
for _ = 1, 20 * 40 do
	Engine.step(1 / 20)
end

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL: " .. message)
	end
end

local birthday = string.match(SEASON, "^Birthday:(%w+)$")
local expected = if birthday then "Birthday" else SEASON
check(workspace:GetAttribute("Season") == expected, "season attribute is " .. tostring(workspace:GetAttribute("Season")))
check(workspace:GetAttribute("BirthdayHero") == birthday, "birthday hero is " .. tostring(workspace:GetAttribute("BirthdayHero")))
local looks: { [string]: number } = {}
for _, child in workspace:FindFirstChild("Forest"):GetChildren() do
	local look = child:GetAttribute("Look")
	if look then
		looks[look] = (looks[look] or 0) + 1
	end
end
local kinds: { [string]: boolean } = {}
for _, part in workspace:FindFirstChild("Twist"):GetChildren() do
	if part.Name == "HidingSpot" then
		kinds[part:GetAttribute("Kind")] = true
	end
end
local rats, bearded = 0, 0
for _, rat in workspace:FindFirstChild("Rats"):GetChildren() do
	rats += 1
	if rat:FindFirstChild("Beard") then
		bearded += 1
	end
end
local bats, hats = 0, 0
for _, d in workspace:GetDescendants() do
	if d.Name == "Bat" then
		bats += 1
	end
end
local template = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("CatTemplate")
for _, d in (if template then template:GetDescendants() else {}) do
	if d.Name == "Hat" then
		hats += 1
	end
end

local balloons = 0
for _, d in workspace:FindFirstChild("Camp"):GetDescendants() do
	if d.Name == "Balloon" then
		balloons += 1
	end
end

if birthday then
	check(balloons > 10, "no balloons at camp")
	check(next(kinds) == nil or kinds.bush ~= nil or kinds.barrel ~= nil or kinds.log ~= nil or kinds.crate ~= nil or kinds.leaves ~= nil or kinds.basket ~= nil, "birthday keeps the normal hiding spots")
elseif SEASON == "Halloween" then
	check((looks.Pumpkin or 0) > 100, "forest bushes should be pumpkins, found " .. tostring(looks.Pumpkin))
	check(next(kinds) == nil or (kinds.pumpkin == true and kinds.bush == nil), "Pianka should hide in pumpkins")
	check(bats > 0, "no bats in the sky")
	check(bearded == 0, "nisser at Halloween")
else
	check((looks.Snow or 0) > 100, "forest bushes should be snow, found " .. tostring(looks.Snow))
	check(next(kinds) == nil or ((kinds.present or kinds.snowpile) and kinds.bush == nil), "Pianka should hide in presents or snow")
	check(rats == 0 or bearded == rats, "rats should be nisser at Christmas")
	check(workspace:FindFirstChild("Ground").Material.Name == "Snow", "ground should be snow")
	check(workspace:FindFirstChild("SnowSky") ~= nil, "no falling snow")
end
check(hats > 0, "Pianka has no season hat")
check(birthday ~= nil or balloons == 0, "balloons without a birthday")

for _, e in Engine.errors do
	failures += 1
	print(string.format("SCRIPT ERROR x%d: %s", e.count, e.msg))
	print(e.trace)
end
print(string.format("%s: %d pumpkins, %d snow piles, spots %s, %d rats (%d nisser), %d bats, %d hat parts",
	SEASON, looks.Pumpkin or 0, looks.Snow or 0, table.concat((function()
		local list = {}
		for k in kinds do
			table.insert(list, k)
		end
		return list
	end)(), "/"), rats, bearded, bats, hats))
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
