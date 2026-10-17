-- Season smoke test: runs the real scripts in a season, then an admin switches it from the shop.
-- Run: lune run tests/season.spec.luau Halloween
local process = require("@lune/process")
local Engine = require("./engine")

local SEASON = process.args[1] or "Halloween"
local NEXT = if SEASON == "Halloween" then "Christmas" elseif SEASON == "Christmas" then "Birthday:Milenkitka" else "Halloween"
local ADMIN = 4242
Engine.build()
Engine.patch = function(name: string, module: any)
	if name == "Config" then
		module.Season = SEASON
		module.Admins = { ADMIN }
		module.ExtraSfxId = 99
	end
end
Engine.startServer()
local workspace = Engine.workspace
local player, ctx = Engine.addPlayer("Sam", ADMIN)
local function run(seconds: number)
	for _ = 1, 20 * seconds do
		Engine.step(1 / 20)
	end
end
run(40)

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL: " .. message)
	end
end

local function inspect(setting: string)
	local birthday = string.match(setting, "^Birthday:(%w+)$")
	local expected = if birthday then "Birthday" else setting
	check(workspace:GetAttribute("Season") == expected, setting .. ": season attribute is " .. tostring(workspace:GetAttribute("Season")))
	check(workspace:GetAttribute("BirthdayHero") == birthday, setting .. ": birthday hero is " .. tostring(workspace:GetAttribute("BirthdayHero")))
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
	local count: { [string]: number } = {}
	for _, d in workspace:GetDescendants() do
		count[d.Name] = (count[d.Name] or 0) + 1
	end
	local hats = 0
	local template = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("CatTemplate")
	for _, d in (if template then template:GetDescendants() else {}) do
		if d.Name == "Hat" then
			hats += 1
		end
	end
	local balloons = 0
	local decor = workspace:FindFirstChild("SeasonDecor")
	for _, d in (if decor then decor:GetDescendants() else {}) do
		if d.Name == "Balloon" then
			balloons += 1
		end
	end

	if birthday then
		check(balloons > 100, setting .. ": not enough balloons, found " .. balloons)
		check(next(kinds) == nil or kinds.bush ~= nil or kinds.barrel ~= nil or kinds.log ~= nil or kinds.crate ~= nil or kinds.leaves ~= nil or kinds.basket ~= nil, setting .. ": birthday keeps the normal hiding spots")
	elseif setting == "Halloween" then
		check((looks.Pumpkin or 0) > 100, setting .. ": forest bushes should be pumpkins, found " .. tostring(looks.Pumpkin))
		check(next(kinds) == nil or (kinds.pumpkin == true and kinds.bush == nil), setting .. ": Pianka should hide in pumpkins")
		check((count.Bat or 0) > 0, setting .. ": no bats in the sky")
		check((count.Ghost or 0) > 0, setting .. ": no ghosts")
		check((count.Grave or 0) > 20, setting .. ": not enough graves")
		check((count.Cauldron or 0) > 0 and (count.Web or 0) > 0, setting .. ": no cauldron or webs")
		check(bearded == 0, setting .. ": nisser at Halloween")
	else
		check((looks.Snow or 0) > 100, setting .. ": forest bushes should be snow, found " .. tostring(looks.Snow))
		check(next(kinds) == nil or ((kinds.present or kinds.snowpile) and kinds.bush == nil), setting .. ": Pianka should hide in presents or snow")
		check(rats == 0 or bearded == rats, setting .. ": rats should be nisser at Christmas")
		check(workspace:FindFirstChild("Ground").Material.Name == "Snow", setting .. ": ground should be snow")
		check(workspace:FindFirstChild("SnowSky") ~= nil, setting .. ": no falling snow")
	end
	if setting ~= "Halloween" then
		check((count.Ghost or 0) == 0 and (count.Grave or 0) == 0, setting .. ": Halloween leftovers")
		check((looks.Pumpkin or 0) == 0, setting .. ": pumpkins left in the forest")
	end
	if setting ~= "Christmas" then
		check(workspace:FindFirstChild("SnowSky") == nil, setting .. ": snow left falling")
		check(workspace:FindFirstChild("Ground").Material.Name ~= "Snow", setting .. ": snow left on the ground")
	end
	check(hats > 0, setting .. ": Pianka has no season hat")
	check(birthday ~= nil or balloons == 0, setting .. ": balloons without a birthday")
	print(string.format("%s: %d pumpkins, %d snow piles, spots %s, %d rats (%d nisser), %d bats, %d ghosts, %d graves, %d balloons, %d hat parts",
		setting, looks.Pumpkin or 0, looks.Snow or 0, table.concat((function()
			local list = {}
			for k in kinds do
				table.insert(list, k)
			end
			return list
		end)(), "/"), rats, bearded, count.Bat or 0, count.Ghost or 0, count.Grave or 0, balloons, hats))
end

inspect(SEASON)
check(player:GetAttribute("Admin") == true, "admin flag missing")

-- Pressing Play after the clip: a ghostly Happy Halloween, only at Halloween
local function guiText(text: string): boolean
	local pg = player:FindFirstChild("PlayerGui")
	for _, d in (if pg then pg:GetDescendants() else {}) do
		if d.ClassName == "TextLabel" and d.Visible and string.find(d.Text, text, 1, true) then
			return true
		end
	end
	return false
end
do
	local pg = player:FindFirstChild("PlayerGui")
	for _, d in (if pg then pg:GetDescendants() else {}) do
		if d.ClassName == "TextButton" and d.Text == "▶ Play" then
			Engine.fireForClient(ctx, d.Activated)
		end
	end
	run(1.5)
	local greeted = guiText("Happy Halloween")
	check(greeted == (SEASON == "Halloween"), "Happy Halloween greeting " .. (if greeted then "shown outside Halloween" else "missing"))
	run(4)
end

-- The admin switches the season from the shop, a normal player can not
local shopEvent = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("Shop")
local kid, otherCtx = Engine.addPlayer("Kid")
run(2)
Engine.asClient(otherCtx, function()
	shopEvent:FireServer("season", NEXT)
end)
run(2)
check(workspace:GetAttribute("Season") == (if string.match(SEASON, "^Birthday") then "Birthday" else SEASON), "a normal player switched the season")
Engine.asClient(ctx, function()
	shopEvent:FireServer("season", NEXT)
end)
run(10)
inspect(NEXT)

-- The admin replays Pianka's pop: held still and safe while it plays, then free again
local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
Engine.asClient(otherCtx, function()
	shopEvent:FireServer("burst", "preview")
end)
run(1)
check(kid:GetAttribute("Clip") == nil, "a normal player replayed the kitten clip")
Engine.asClient(ctx, function()
	shopEvent:FireServer("burst", "preview")
end)
run(1)
check(player:GetAttribute("Clip") == true and root ~= nil and root.Anchored, "admin kitten replay did not start")
run(11)
check(player:GetAttribute("Clip") == nil and root ~= nil and not root.Anchored, "admin kitten replay did not end")

for _, e in Engine.errors do
	failures += 1
	print(string.format("SCRIPT ERROR x%d: %s", e.count, e.msg))
	print(e.trace)
end
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
