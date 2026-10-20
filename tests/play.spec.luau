-- Headless playtest: runs the real server and GPS scripts with bot players.
-- Run: lune run tests/play.spec.luau [minutes per scenario]
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")

local V3, CF = roblox.Vector3, Engine.CFrame
local Enum = roblox.Enum
local MINUTES = tonumber(process.args[1]) or 12
local DT = 1 / 20

Engine.build()
-- Fake pass ids so the Robux shop shows up in the test
Engine.patch = function(name: string, module: any)
	if name == "Config" then
		for i, pass in module.Passes do
			pass.id = 9000 + i
		end
		-- No season here, tests/season.spec.luau covers Halloween and Christmas
		module.Season = "None"
		module.ExtraSfxId = 99
	end
end

local counts: { [string]: number } = {}
local timeline: { string } = {}
Engine.onFire = function(remote: any, player: any, args: any)
	if remote.Name == "PiankaEvent" then
		local kind = args[1]
		counts[kind] = (counts[kind] or 0) + 1
		if kind == "call" and Engine.workspace:GetAttribute("Mode") ~= "Hard" then
			counts.badCall = (counts.badCall or 0) + 1
		end
		if kind ~= "fish" and (process.args[2] == "log" or (kind ~= "spotted" and kind ~= "lunge" and kind ~= "bitten" and kind ~= "hunted")) then
			table.insert(timeline, string.format("%6.1f %s %s", Engine.now, tostring(kind), if player then player.Name else ""))
		end
	end
end

Engine.startServer()
local game = Engine.game
local workspace = Engine.workspace
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local Config = Engine.server.modules[Shared:FindFirstChild("Config")]
local Sky = Engine.server.modules[Shared:FindFirstChild("Sky")]
local HOME = V3.new(Config.HomePosition.X, 0, Config.HomePosition.Z)

-- Watch the real dog brains: who catches whom
local DogBrain = Engine.server.modules[Shared:FindFirstChild("DogBrain")]
local catches: { [string]: number } = {}
local realStep = DogBrain.step
DogBrain.step = function(dog: any, dt: number, now: number, runners: any, world: any, s: any, gap: number)
	local before = dog.state
	local event, id = realStep(dog, dt, now, runners, world, s, gap)
	if event == "caught" then
		local who = if dog.kind == "pack" then "pack" elseif s.chaseFactor == Config.Hunters[workspace:GetAttribute("Mode") or "Practice"].chaseFactor then "neighbor" else "patrol"
		local key = who .. (if workspace:GetAttribute("Escape") then " during escape" else "")
		catches[key] = (catches[key] or 0) + 1
		if process.args[2] == "log" then
			table.insert(timeline, string.format("%6.1f caught by %s (was %s)", Engine.now, key, before))
		end
	end
	return event, id
end

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL: " .. message)
	end
end

-- Obstacles the bots walk around
local trees: { any } = {}
local cabins: { any } = {}
for _, d in workspace:GetDescendants() do
	if d.Name == "Trunk" then
		table.insert(trees, V3.new(d.Position.X, 0, d.Position.Z))
	elseif d.Name == "Walls" then
		table.insert(cabins, V3.new(d.Position.X, 0, d.Position.Z))
	end
end

local function flat(v: any): any
	return V3.new(v.X, 0, v.Z)
end

local function makeRng(seed: number): any
	local state = seed
	return {
		NextNumber = function(_, a: number, b: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return a + state / 2147483648 * (b - a)
		end,
	}
end

local function seeds(text: string): number
	local n = 0
	for i = 1, #text do
		n = (n * 31 + string.byte(text, i)) % 1000003
	end
	return n
end

-- UI helpers
local function gui(bot: any): any
	return bot.player:FindFirstChild("PlayerGui")
end

local function findButton(bot: any, match: (any) -> boolean): any
	local root = gui(bot)
	if not root then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextButton" and match(d) then
			return d
		end
	end
	return nil
end

local function click(bot: any, button: any)
	if button then
		Engine.fireForClient(bot.ctx, button.Activated)
	end
end

local function pickHero(bot: any, hero: string)
	click(bot, findButton(bot, function(b)
		for _, c in b:GetChildren() do
			if c.ClassName == "TextLabel" and string.find(c.Text, hero, 1, true) then
				return true
			end
		end
		return false
	end))
end

local function pickMode(bot: any, mode: string)
	local menu = findButton(bot, function(b)
		return b.Name == "Menu"
	end)
	click(bot, menu)
	click(bot, findButton(bot, function(b)
		return b.Text == mode
	end))
	click(bot, findButton(bot, function(b)
		return b.Text == "▶ Play"
	end))
end

-- Bots
local bots: { any } = {}
local stats = { nightSeen = false, daySeen = false, huntOk = true, heartsOk = true, rounds = 0, searching = false, maxLevel = 1, tower = 0, towerPianka = false, practiceMenu = false, clipSince = nil :: number?, nikola = false, nikolaMissing = 0, burstSeen = false }

local function addBot(name: string, kind: string, hero: string): any
	local player, ctx = Engine.addPlayer(name)
	local bot = {
		name = name,
		player = player,
		ctx = ctx,
		kind = kind,
		hero = hero,
		wander = HOME,
		wanderUntil = 0,
		prompted = {},
		lastFlash = 0,
		rng = makeRng(seeds(name)),
	}
	table.insert(bots, bot)
	for _ = 1, 10 do
		Engine.step(DT)
	end
	pickHero(bot, hero)
	click(bot, findButton(bot, function(b)
		return b.Text == "▶ Play"
	end))
	return bot
end

local function removeBot(bot: any)
	Engine.removePlayer(bot.player)
	for i, b in bots do
		if b == bot then
			table.remove(bots, i)
			break
		end
	end
end

local function enemies(): { any }
	local list = {}
	local dogs = workspace:FindFirstChild("Dogs")
	if dogs then
		for _, d in dogs:GetChildren() do
			local body = d.PrimaryPart
			if body then
				table.insert(list, { pos = flat(body.Position), look = flat(body.CFrame.LookVector), range = 22 })
			end
		end
	end
	local neighbors = workspace:FindFirstChild("Neighbors")
	if neighbors then
		for _, n in neighbors:GetChildren() do
			if n:GetAttribute("Hunting") and n.PrimaryPart then
				table.insert(list, { pos = flat(n.PrimaryPart.Position), look = flat(n.PrimaryPart.CFrame.LookVector), range = 26 })
			end
		end
	end
	return list
end

local function nearestChild(folderName: string, from: any): any
	local folder = workspace:FindFirstChild(folderName)
	local best, bestD = nil, math.huge
	if folder then
		for _, c in folder:GetChildren() do
			if c.ClassName == "Model" then
				local p = flat(c:GetPivot().Position)
				local d = (p - from).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
	end
	return best, bestD
end

local function botStep(bot: any, dt: number)
	local player = bot.player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChild("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local pos = flat(root.Position)
	local now = Engine.now
	if player:GetAttribute("Held") then
		return
	end
	local mode = workspace:GetAttribute("Mode") or "Practice"
	local maxHearts = Config.Hearts[mode] or 3
	local hearts = player:GetAttribute("Hearts") or maxHearts

	local goal = HOME
	if player:GetAttribute("Out") then
		goal = HOME + V3.new(-6, 0, 4)
	elseif workspace:GetAttribute("Carrier") == player.UserId then
		goal = HOME
	elseif (player:GetAttribute("Kittens") or 0) > 0 and workspace:GetAttribute("Escape") then
		goal = HOME
	else
		local cat = workspace:GetAttribute("CatPosition")
		if cat and workspace:GetAttribute("CatHidden") then
			-- GPS shows the area, close by the hiding spots are visible
			goal = flat(cat)
			if (goal - pos).Magnitude < 45 then
				local best = math.huge
				for _, part in workspace:FindFirstChild("Twist"):GetChildren() do
					if part.Name == "HidingSpot" then
						local d = (flat(part.Position) - pos).Magnitude
						if d < best then
							best, goal = d, flat(part.Position)
						end
					end
				end
				stats.searching = true
			end
		elseif cat then
			goal = flat(cat)
		else
			local kitten = nearestChild("Kittens", pos)
			if kitten then
				goal = kitten
			end
		end
	end
	if (player:GetAttribute("Bones") or 0) < 1 and bot.kind ~= "naive" then
		local bone, d = nearestChild("Bones", pos)
		if bone and d < 20 and d < (goal - pos).Magnitude then
			goal = bone
		end
	end
	if hearts < maxHearts and not workspace:GetAttribute("Escape") then
		local bird, d = nearestChild("Birds", pos)
		if bird and d < 25 then
			goal = bird
		end
	end
	if bot.kind == "kid" and (goal - pos).Magnitude > 40 then
		if now >= bot.wanderUntil or (bot.wander - pos).Magnitude < 5 then
			local a = bot.rng:NextNumber(-1, 1)
			local u = (goal - pos).Unit
			bot.wander = pos + V3.new(u.X * math.cos(a) - u.Z * math.sin(a), 0, u.X * math.sin(a) + u.Z * math.cos(a)) * 60
			bot.wanderUntil = now + 8
		end
		goal = bot.wander
	end

	local toGoal = goal - pos
	local desire = if toGoal.Magnitude > 0.5 then toGoal.Unit else V3.zero
	for _, t in trees do
		local away = pos - t
		local m = away.Magnitude
		if m < 4 and m > 0.01 then
			desire += away / m * (4 - m) * 0.6
		end
	end
	for _, c in cabins do
		local away = pos - c
		local m = away.Magnitude
		if m < 13 and m > 0.01 then
			desire += away / m * (13 - m) * 0.3
		end
	end
	if bot.kind == "careful" then
		for _, e in enemies() do
			local away = pos - e.pos
			local m = away.Magnitude
			if m > 0.01 and m < e.range and e.look:Dot(-away / m) > math.cos(math.rad(50)) then
				local side = V3.new(-away.Z, 0, away.X) / m
				if side:Dot(desire) < 0 then
					side = -side
				end
				desire += (away / m + side * 1.5) * (e.range - m) / e.range * 3
			end
		end
	end

	local vel = root.AssemblyLinearVelocity
	local push = V3.zero
	if flat(vel).Magnitude > 1 then
		push = flat(vel) * dt
		root.AssemblyLinearVelocity = vel * 0.8
	end
	local move = if desire.Magnitude > 0.01 then desire.Unit * humanoid.WalkSpeed * dt else V3.zero
	local nextPos = pos + move + push
	for _, t in trees do
		local away = nextPos - t
		if away.Magnitude < 2 and away.Magnitude > 0.01 then
			nextPos = t + away.Unit * 2
		end
	end
	local half = Config.ForestSize / 2 - 2
	nextPos = V3.new(math.clamp(nextPos.X, -half, half), 0, math.clamp(nextPos.Z, -half, half))
	local face = if move.Magnitude > 0.01 then move.Unit else flat(root.CFrame.LookVector)
	local y = 3
	if bot.climbUntil and now < bot.climbUntil then
		y = bot.climbY
	end
	local at = V3.new(nextPos.X, y, nextPos.Z)
	root.CFrame = CF.lookAt(at, at + (if face.Magnitude > 0.01 then face else V3.new(0, 0, -1)))
	local head = character:FindFirstChild("Head")
	if head then
		head.CFrame = root.CFrame * CF.new(0, 1.5, 0)
	end

	-- Press E on prompts in reach, climb to ones above
	for prompt in Engine.prompts do
		local part = prompt.Parent
		if prompt.Enabled and part and part.ClassName == "Part" and part:IsDescendantOf(workspace) and not prompt._destroyed then
			local rel = part.Position - root.Position
			local horizontal = flat(rel).Magnitude
			if horizontal < 4 and rel.Y > prompt.MaxActivationDistance - 1 then
				bot.climbY = part.Position.Y - 1
				bot.climbUntil = now + 3
			end
			if rel.Magnitude <= prompt.MaxActivationDistance and now - (bot.prompted[prompt] or -10) > 1 then
				bot.prompted[prompt] = now
				Engine.fireServer(prompt.Triggered, player)
			end
		end
	end

	-- Calling: near her area bots call her to hear where she hides
	local catArea = workspace:GetAttribute("CatPosition")
	if catArea and workspace:GetAttribute("CatHidden") and (flat(catArea) - pos).Magnitude < 120 and now - (bot.lastCall or -100) > 8 then
		bot.lastCall = now
		if bot.kind == "kid" then
			click(bot, findButton(bot, function(b)
				return b.Text == "📣"
			end))
		else
			Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = Enum.KeyCode.C, UserInputType = Enum.UserInputType.Keyboard }, false)
		end
	end

	-- Bones: careful bots press G when a dog comes close, kids tap the button late
	if (player:GetAttribute("Bones") or 0) > 0 and now - (bot.lastBone or -10) > 1 and bot.kind ~= "naive" then
		for _, e in enemies() do
			if e.range == 22 and (e.pos - pos).Magnitude < (if bot.kind == "careful" then 16 else 8) then
				bot.lastBone = now
				if bot.kind == "careful" then
					Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = Enum.KeyCode.G, UserInputType = Enum.UserInputType.Keyboard }, false)
				else
					click(bot, findButton(bot, function(b)
						return string.find(b.Text, "🦴", 1, true) ~= nil
					end))
				end
				break
			end
		end
	end

	-- Lantern: careful bots switch it off near neighbors at night, kids sometimes
	local _, daylight = Sky.at(workspace:GetServerTimeNow() - workspace:GetAttribute("DayStart"), Config.DayMinutes, Config.NightShare)
	local wantOff = false
	if daylight < 0.5 then
		if bot.kind == "careful" then
			for _, e in enemies() do
				if e.range == 26 and (e.pos - pos).Magnitude < 45 then
					wantOff = true
				end
			end
		elseif bot.kind == "kid" then
			if now >= (bot.lightUntil or 0) then
				bot.kidOff = bot.rng:NextNumber(0, 1) < 0.35
				bot.lightUntil = now + bot.rng:NextNumber(8, 20)
			end
			wantOff = bot.kidOff == true
		end
	end
	if (player:GetAttribute("LightOff") == true) ~= wantOff and now - bot.lastFlash > 1 then
		bot.lastFlash = now
		bot.toggles = (bot.toggles or 0) + 1
		Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = Enum.KeyCode.F, UserInputType = Enum.UserInputType.Keyboard }, false)
	end
end

-- Invariants checked every second
local lastRoundStart = workspace:GetAttribute("RoundStart")
local longestRound = 0
local roundBegan = Engine.now

local function invariants()
	local mode = workspace:GetAttribute("Mode") or "Practice"
	local _, daylight = Sky.at(workspace:GetServerTimeNow() - workspace:GetAttribute("DayStart"), Config.DayMinutes, Config.NightShare)
	local hunting = 0
	for _, n in workspace:FindFirstChild("Neighbors"):GetChildren() do
		if n:GetAttribute("Hunting") then
			hunting += 1
		end
	end
	if daylight < 0.4 then
		stats.nightSeen = true
		if hunting == 0 then
			stats.huntOk = false
			check(false, string.format("no neighbors hunting at night (t=%.0f)", Engine.now))
		end
	elseif daylight > 0.6 then
		stats.daySeen = true
		if hunting > 0 and not Config.HuntByDay[mode] then
			stats.huntOk = false
			check(false, string.format("neighbors still hunting in daylight (t=%.0f)", Engine.now))
		end
	end
	if workspace:GetAttribute("Clip") then
		stats.clipSince = stats.clipSince or Engine.now
		check(Engine.now - stats.clipSince < 12, "escape clip stuck")
	else
		stats.clipSince = nil
		for _, bot in bots do
			local root = bot.player.Character and bot.player.Character:FindFirstChild("HumanoidRootPart")
			if root and root.Anchored and not bot.player:GetAttribute("Held") and not bot.player:GetAttribute("Clip") then
				check(false, bot.name .. " still frozen after a clip")
			end
		end
	end
	-- Watching Pianka pop holds you still for a moment only
	for _, bot in bots do
		if bot.player:GetAttribute("Clip") then
			bot.clipSince = bot.clipSince or Engine.now
			check(Engine.now - bot.clipSince < Config.KittenBurst.total + 2, bot.name .. " stuck watching the kitten burst")
			stats.burstSeen = true
		else
			bot.clipSince = nil
		end
	end
	for _, bot in bots do
		if bot.hero == "Oskar" then
			local character = bot.player.Character
			stats.nikola = stats.nikola or (character ~= nil and character:FindFirstChild("Nikola") ~= nil)
			if bot.player:GetAttribute("Out") and not bot.player:GetAttribute("Sibling") then
				check(false, "Oskar went out before Nikola left")
			end
			if bot.player:GetAttribute("Pair") and character and not character:FindFirstChild("Nikola") and bot.player:GetAttribute("Hearts") then
				stats.nikolaMissing += 1
			end
		end
		if mode == "Practice" and not stats.practiceMenu then
			local play = findButton(bot, function(b)
				return b.Text == "▶ Play"
			end)
			local normal = findButton(bot, function(b)
				return b.Text == "Normal"
			end)
			local stroke = normal and normal:FindFirstChildOfClass("UIStroke")
			stats.practiceMenu = play ~= nil and play.Parent.Parent.Visible and stroke ~= nil and stroke.Enabled
		end
		local character = bot.player.Character
		if character then
			local tower, pianka = 0, false
			for _, child in character:GetChildren() do
				if child.Name == "Kitten" then
					tower += 1
				elseif child.Name == Config.CatName then
					pianka = true
				end
			end
			stats.tower = math.max(stats.tower, tower)
			stats.towerPianka = stats.towerPianka or (pianka and tower > 0 and mode == "Normal")
		end
		local hearts = bot.player:GetAttribute("Hearts")
		local max = bot.player:GetAttribute("MaxHearts") or Config.Hearts[mode] or 3
		if type(hearts) ~= "number" or hearts < 0 or hearts > max then
			stats.heartsOk = false
			check(false, string.format("%s has bad hearts %s (max %d)", bot.name, tostring(hearts), max))
		end
		if bot.player:GetAttribute("Out") and hearts ~= 0 then
			check(false, bot.name .. " is out with hearts left")
		end
	end
	local level = workspace:GetAttribute("Level") or 1
	stats.maxLevel = math.max(stats.maxLevel, level)
	check(level >= 1 and level <= Config.Level.Max, "level out of range: " .. tostring(level))
	local start = workspace:GetAttribute("RoundStart")
	if start ~= lastRoundStart then
		lastRoundStart = start
		stats.rounds += 1
		longestRound = math.max(longestRound, Engine.now - roundBegan)
		roundBegan = Engine.now
	end
end

local wantMode: string? = nil
local function run(seconds: number)
	local nextCheck = Engine.now + 1
	local nextAsk = Engine.now + 3
	local stop = Engine.now + seconds
	while Engine.now < stop do
		if wantMode and workspace:GetAttribute("Mode") ~= wantMode and Engine.now >= nextAsk and bots[1] then
			nextAsk = Engine.now + 3
			pickMode(bots[1], wantMode)
		end
		for _, bot in bots do
			botStep(bot, DT)
			local again = findButton(bot, function(b)
				return b.Text == "▶ Play again"
			end)
			if again and again.Parent.Visible and Engine.now >= (bot.againAt or 0) then
				bot.againAt = Engine.now + 3
				stats.again = (stats.again or 0) + 1
				click(bot, again)
			end
		end
		Engine.step(DT)
		if Engine.now >= nextCheck then
			nextCheck += 1
			invariants()
		end
	end
	longestRound = math.max(longestRound, Engine.now - roundBegan)
end

local function snapshot(): { [string]: number }
	return table.clone(counts)
end

local function diff(before: { [string]: number }, key: string): number
	return (counts[key] or 0) - (before[key] or 0)
end

local results = {}
local ONLY = process.args[3]
local function scenario(title: string, mode: string, setup: () -> (), seconds: number)
	if ONLY and not string.find(title, ONLY, 1, true) then
		setup()
		return
	end
	local before = snapshot()
	local roundsBefore = stats.rounds
	longestRound = 0
	roundBegan = Engine.now
	-- Switch while alone, before others join, like a player starting a session
	if bots[1] and #bots == 1 then
		wantMode = mode
		pickMode(bots[1], mode)
	end
	setup()
	wantMode = mode
	if bots[1] then
		pickMode(bots[1], mode)
	end
	run(seconds)
	local wins = diff(before, "home") + diff(before, "allKittens") + diff(before, "escaped")
	local fails = diff(before, "hearts") + diff(before, "lost") + diff(before, "timeUp") + diff(before, "caught")
	table.insert(results, {
		title = title,
		mode = workspace:GetAttribute("Mode"),
		rounds = stats.rounds - roundsBefore,
		wins = wins,
		home = diff(before, "home"),
		kittens = diff(before, "allKittens"),
		escaped = diff(before, "escaped"),
		fails = fails,
		hearts = diff(before, "hearts"),
		bites = diff(before, "dogbite"),
		grabs = diff(before, "grabbed"),
		birds = diff(before, "bird"),
		outs = diff(before, "out"),
		held = diff(before, "held"),
		longest = longestRound,
	})
	check(workspace:GetAttribute("Mode") == mode, title .. ": mode should be " .. mode .. " but is " .. tostring(workspace:GetAttribute("Mode")))
	check(wins + fails > 0 or seconds < 180, title .. ": no round finished in " .. seconds .. " s")
	check(longestRound < 420, string.format("%s: a round lasted %.0f s, maybe stuck", title, longestRound))
end

local t0 = os.clock()
local secs = MINUTES * 60

scenario("Practice solo careful", "Practice", function()
	addBot("Ana", "careful", "Patrick")
end, secs)

scenario("Practice solo kid", "Practice", function()
	bots[1].kind = "kid"
end, secs)

scenario("Normal solo careful", "Normal", function()
	bots[1].kind = "careful"
end, secs)

scenario("Hard solo careful", "Hard", function() end, secs)

scenario("Normal team", "Normal", function()
	addBot("Bo", "kid", "Oskar")
	addBot("Cy", "naive", "Milenkitka")
end, secs)

scenario("Hard team", "Hard", function() end, secs)

scenario("Hard, one leaves, one joins", "Hard", function()
	removeBot(bots[3])
	addBot("Di", "careful", "Aurelia")
end, secs)

scenario("Practice after Hard", "Practice", function()
	removeBot(bots[3])
	removeBot(bots[2])
end, secs / 2)
check(workspace:GetAttribute("Level") ~= nil, "level missing")

-- Picking another mode starts again at level 1
do
	wantMode = "Normal"
	run(12)
	check(workspace:GetAttribute("Mode") == "Normal" and workspace:GetAttribute("Level") == 1, "mode change did not reset the level")
	wantMode = "Practice"
	run(12)
end

-- Shop and lantern from the client
local shopEvent = game:GetService("ReplicatedStorage"):FindFirstChild("Shop")
local stats1 = bots[1].player:FindFirstChild("leaderstats")
local fish = stats1 and stats1:FindFirstChild("Fish")
if fish then
	fish.Value += 30
	Engine.asClient(bots[1].ctx, function()
		shopEvent:FireServer("buy", "LanternPink")
	end)
	run(2)
	local owned = bots[1].player:GetAttribute("Owned") or ""
	check(string.find(owned, "LanternPink", 1, true) ~= nil, "shop: buying a lantern did not work")
	-- Power ups and new looks from the shop
	fish.Value += 200
	for _, id in { "PowerShield", "PowerDouble", "PowerGhost", "PowerFreeze", "HatWitch", "TrailSparkle" } do
		Engine.asClient(bots[1].ctx, function()
			shopEvent:FireServer("buy", id)
		end)
		run(0.5)
	end
	run(1)
	local p1 = bots[1].player
	check(p1:GetAttribute("Shield") == true, "shop: no shield bubble")
	check(type(p1:GetAttribute("DoubleJump")) == "number", "shop: no double jump")
	check(type(p1:GetAttribute("GhostUntil")) == "number", "shop: no ghost mode")
	local character = p1.Character
	check(character ~= nil and character:FindFirstChild("ShopHat", true) ~= nil, "shop: hat not worn")
	Engine.asClient(bots[1].ctx, function()
		shopEvent:FireServer("season", "Halloween")
	end)
	run(2)
	check(workspace:GetAttribute("Season") == nil, "shop: a normal player switched the season")
end

-- Game passes: owned on join, and bought from the shop
do
	local probe, probeCtx = Engine.addPlayer("Pat")
	for _ = 1, 10 do
		Engine.step(DT)
	end
	local id = probe.UserId
	Engine.passes[id] = { [9002] = true }
	Engine.removePlayer(probe)
	local returning = Engine.addPlayer("Pat", id)
	for _ = 1, 40 do
		Engine.step(DT)
	end
	check(returning:GetAttribute("Pet") == true and string.find(returning:GetAttribute("Owned") or "", "Pet", 1, true) ~= nil,
		"pass: owned kitten pet not given on join")
	Engine.removePlayer(returning)

	local buyer = bots[1]
	local before = buyer.player:GetAttribute("MaxHearts")
	local heartButton = findButton(buyer, function(b)
		local row = b.Parent
		for _, c in (row and row:GetChildren() or {}) do
			if c.ClassName == "TextLabel" and string.find(c.Text, "Extra heart", 1, true) then
				return true
			end
		end
		return false
	end)
	check(heartButton ~= nil, "pass: Extra heart button missing in shop")
	click(buyer, heartButton)
	run(1)
	check(buyer.player:GetAttribute("ExtraHeart") == true and buyer.player:GetAttribute("MaxHearts") == (before or 0) + 1,
		"pass: buying Extra heart did not add a heart")
	check(heartButton and heartButton.Text == "Owned ✓", "pass: shop does not show Extra heart as owned")
end

-- Map opens with M and shows hedges, guard lines and home
do
	local bot = bots[1]
	Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = Enum.KeyCode.M, UserInputType = Enum.UserInputType.Keyboard }, false)
	run(1)
	local shown, items = false, 0
	for _, d in gui(bot):GetDescendants() do
		if d.ClassName == "TextLabel" and string.find(d.Text, "Map", 1, true) and d.Parent.Visible then
			shown = true
			local area = d.Parent:FindFirstChildOfClass("Frame")
			items = if area then #area:GetChildren() else 0
		end
	end
	check(shown and items > 5, "map did not open or is empty (" .. items .. " items)")
	Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = Enum.KeyCode.M, UserInputType = Enum.UserInputType.Keyboard }, false)
	run(1)
	-- Tapping the GPS opens it too
	local function mapOpen(): boolean
		for _, d in gui(bot):GetDescendants() do
			if d.ClassName == "TextLabel" and string.find(d.Text, "Map", 1, true) and d.Parent.Visible then
				return true
			end
		end
		return false
	end
	check(not mapOpen(), "map did not close with M")
	click(bot, findButton(bot, function(b)
		return b.Name == "MapTap"
	end))
	run(1)
	check(mapOpen(), "tapping the GPS did not open the map")
	click(bot, findButton(bot, function(b)
		return b.Name == "MapTap"
	end))
	run(1)
end

-- Controller: hints show, Y toggles the lantern, the menu opens with Play selected and B closes it
do
	local bot = bots[1]
	local selection = game:GetService("GuiService")
	local function press(key: any)
		Engine.fireForClient(bot.ctx, UIS.InputBegan, { KeyCode = key, UserInputType = Enum.UserInputType.Gamepad1 }, false)
		run(0.5)
	end
	Engine.fireForClient(bot.ctx, UIS.LastInputTypeChanged, Enum.UserInputType.Gamepad1)
	run(0.5)
	local hint = false
	for _, d in gui(bot):GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text == "Y" and d.Visible then
			hint = true
		end
	end
	check(hint, "gamepad: the lantern does not show the Y hint")
	local before = bot.player:GetAttribute("LightOff") == true
	press(Enum.KeyCode.ButtonY)
	check((bot.player:GetAttribute("LightOff") == true) ~= before, "gamepad: Y did not toggle the lantern")
	press(Enum.KeyCode.ButtonY)
	press(Enum.KeyCode.DPadLeft)
	local selected = selection.SelectedObject
	check(selected ~= nil and selected.Text == "▶ Play", "gamepad: the menu did not select Play")
	press(Enum.KeyCode.ButtonB)
	check(selection.SelectedObject == nil, "gamepad: B did not close the menu")
	press(Enum.KeyCode.DPadRight)
	local item = selection.SelectedObject
	check(item ~= nil and item.ClassName == "TextButton" and item.Text ~= "▶ Play", "gamepad: the shop did not select its first item")
	press(Enum.KeyCode.ButtonB)
	check(selection.SelectedObject == nil, "gamepad: B did not close the shop")
	Engine.fireForClient(bot.ctx, UIS.LastInputTypeChanged, Enum.UserInputType.Keyboard)
	run(0.5)
	local shown = false
	for _, d in gui(bot):GetDescendants() do
		if d.ClassName == "TextLabel" and (d.Text == "◀" or d.Text == "Y") and d.Visible then
			shown = true
		end
	end
	check(not shown, "gamepad: hints stay after switching to the keyboard")
end

-- GPS screen agrees with the game
do
	local root = gui(bots[1])
	local hearts = bots[1].player:GetAttribute("Hearts")
	local found = false
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text ~= "" and (string.find(d.Text, "❤️", 1, true) or string.find(d.Text, "👻", 1, true)) and d.TextSize == 22 then
			found = true
			local shown = select(2, string.gsub(d.Text, "❤️", ""))
			check(bots[1].player:GetAttribute("Out") or shown == hearts, string.format("GPS shows %d hearts but player has %s", shown, tostring(hearts)))
		end
	end
	check(found, "GPS hearts label not found")
end

print(string.format("Find Pianka headless playtest, %d min per scenario, %.0f s real time", MINUTES, os.clock() - t0))
print("")
print("Scenario                         Mode    Rounds  Home  Kittens  Escaped  Fails  Game over  Held  Bites  Birds  Longest")
for _, r in results do
	print(string.format("%-32s %-7s %6d %5d %8d %8d %6d %10d %5d %6d %6d %6.0f s",
		r.title, r.mode, r.rounds, r.home, r.kittens, r.escaped, r.fails, r.hearts, r.held, r.bites, r.birds, r.longest))
end
print("")
check(stats.nightSeen and stats.daySeen, "should see both day and night")
check((counts.hunt or 0) > 0, "neighbors never started hunting")
check(stats.huntOk, "neighbors hunted at the wrong time")
check(stats.searching and (counts.bush or 0) > 0, "bots never searched a hiding spot")
check((counts.call or 0) > 0 and (counts.meowBack or 0) > 0, "calling Pianka never got a meow back")
check((counts.gotBone or 0) > 0 and (counts.bone or 0) > 0, "bones never picked up or thrown")
check(stats.maxLevel > 1 or MINUTES < 1, "level never went up")
check(stats.tower >= 2, "tower: kittens never stacked on a head")
check((counts.badCall or 0) == 0, "call worked outside Hard")
check(stats.nikola, "Oskar never walked with Nikola")
check(stats.nikolaMissing < 5, "Nikola missing while the pair is together")
check((counts.escaped or 0) == 0 or (counts.escapeClip or 0) > 0, "escape won without the clip")
check(stats.practiceMenu, "practice: menu with Normal did not open after the round")
check(stats.towerPianka, "tower: Pianka not under the kittens in Normal")
check(stats.burstSeen, "nobody watched Pianka pop into kittens")
print(string.format("Levels: top %d, hiding spots searched %d, bones picked %d, thrown %d, play again %d, calls %d, meows back %d, heard %d",
	stats.maxLevel, counts.bush or 0, counts.gotBone or 0, counts.bone or 0, stats.again or 0, counts.call or 0, counts.meowBack or 0, counts.heard or 0))
print(string.format("Events: hunt %d, dawn %d, dropped %d, gift %d, twist %d, out %d",
	counts.hunt or 0, counts.dawn or 0, counts.dropped or 0, counts.gift or 0, counts.twist or 0, counts.out or 0))
local catchList = {}
for k, v in catches do
	table.insert(catchList, k .. " " .. v)
end
table.sort(catchList)
print("Catches: " .. table.concat(catchList, ", "))
if Engine.warnings then
	print("Script warnings: " .. Engine.warnings)
end
for _, e in Engine.errors do
	failures += 1
	print(string.format("SCRIPT ERROR x%d: %s", e.count, e.msg))
	print(e.trace)
end
if process.args[2] == "log" then
	for _, line in timeline do
		print(line)
	end
end
if failures > 0 then
	print(string.format("%d checks FAILED", failures))
	process.exit(1)
end
print("All checks passed")
