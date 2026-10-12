-- Headless playtest: runs the real server and GPS scripts with bot players.
-- Run: lune run tests/play.spec.luau [minutes per scenario]
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Engine = require("./engine")

local V3, CF = roblox.Vector3, roblox.CFrame
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
	end
end

local counts: { [string]: number } = {}
local timeline: { string } = {}
Engine.onFire = function(remote: any, player: any, args: any)
	if remote.Name == "PiankaEvent" then
		local kind = args[1]
		counts[kind] = (counts[kind] or 0) + 1
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
		local who = if dog.kind == "pack" then "pack" elseif s.chaseFactor == Config.Hunters[workspace:GetAttribute("Mode") or "Easy"].chaseFactor then "neighbor" else "patrol"
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
	local pg = bot.player:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild("GPS")
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
		return b.Text == "Menu"
	end)
	click(bot, menu)
	click(bot, findButton(bot, function(b)
		return b.Text == mode
	end))
end

-- Bots
local bots: { any } = {}

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
	local mode = workspace:GetAttribute("Mode") or "Easy"
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
		if cat then
			goal = flat(cat)
		else
			local kitten = nearestChild("Kittens", pos)
			if kitten then
				goal = kitten
			end
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
local stats = { nightSeen = false, daySeen = false, huntOk = true, heartsOk = true, rounds = 0 }
local lastRoundStart = workspace:GetAttribute("RoundStart")
local longestRound = 0
local roundBegan = Engine.now

local function invariants()
	local mode = workspace:GetAttribute("Mode") or "Easy"
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
	for _, bot in bots do
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

scenario("Easy solo careful", "Easy", function()
	addBot("Ana", "careful", "Patrick")
end, secs)

scenario("Easy solo kid", "Easy", function()
	bots[1].kind = "kid"
end, secs)

scenario("Normal solo careful", "Normal", function()
	bots[1].kind = "careful"
end, secs)

scenario("Umulig solo careful", "Umulig", function() end, secs)

scenario("Normal team", "Normal", function()
	addBot("Bo", "kid", "Aurelia")
	addBot("Cy", "naive", "Milenkitka")
end, secs)

scenario("Umulig team", "Umulig", function() end, secs)

scenario("Umulig, one leaves, one joins", "Umulig", function()
	removeBot(bots[3])
	addBot("Di", "careful", "Aurelia")
end, secs)

scenario("Easy after Umulig", "Easy", function()
	removeBot(bots[3])
	removeBot(bots[2])
end, secs / 2)

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

-- GPS screen agrees with the game
do
	local root = gui(bots[1])
	local hearts = bots[1].player:GetAttribute("Hearts")
	local found = false
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextLabel" and d.Text ~= "" and (string.find(d.Text, "❤️", 1, true) or string.find(d.Text, "😵", 1, true)) and d.TextSize == 22 then
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
