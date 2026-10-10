local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local rng = Random.new()
local half = Config.ForestSize / 2
local treeSpots: { Vector3 } = {}

local foundEvent = Instance.new("RemoteEvent")
foundEvent.Name = "PiankaFound"
foundEvent.Parent = ReplicatedStorage

local function makePart(class: string, props: { [string]: any }): BasePart
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function isFree(pos: Vector3, radius: number): boolean
	for _, spot in treeSpots do
		if (spot - pos).Magnitude < radius then
			return false
		end
	end
	return true
end

local function randomSpot(margin: number): Vector3
	return Vector3.new(rng:NextNumber(-half + margin, half - margin), 0, rng:NextNumber(-half + margin, half - margin))
end

-- Sky and fog
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 120)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.45
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(190, 215, 190)
atmosphere.Decay = Color3.fromRGB(90, 120, 90)
atmosphere.Haze = 2
atmosphere.Parent = Lighting

-- Ground
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
local terrain = workspace.Terrain
terrain:Clear()
terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(80, 130, 55))
terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(Config.ForestSize + 40, 12, Config.ForestSize + 40), Enum.Material.Grass)

-- Camp
local camp = Instance.new("Folder")
camp.Name = "Camp"
camp.Parent = workspace

local spawnPad = Instance.new("SpawnLocation")
spawnPad.Anchored = true
spawnPad.Size = Vector3.new(10, 1, 10)
spawnPad.Position = Vector3.new(0, 0.5, 0)
spawnPad.Color = Color3.fromRGB(140, 100, 60)
spawnPad.Material = Enum.Material.WoodPlanks
spawnPad.Neutral = true
spawnPad.Duration = 0
spawnPad.Parent = camp

local sign = makePart("Part", {
	Name = "Sign",
	Size = Vector3.new(8, 4, 0.5),
	Position = Vector3.new(0, 5, -8),
	Color = Color3.fromRGB(160, 110, 60),
	Material = Enum.Material.Wood,
	Parent = camp,
})
makePart("Part", {
	Name = "Post",
	Size = Vector3.new(0.6, 3, 0.6),
	Position = Vector3.new(0, 1.5, -8),
	Color = Color3.fromRGB(110, 75, 40),
	Material = Enum.Material.Wood,
	Parent = camp,
})
local signGui = Instance.new("SurfaceGui")
signGui.Face = Enum.NormalId.Back
signGui.Parent = sign
local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(1, 1)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.TextColor3 = Color3.new(1, 1, 1)
signText.Text = "Lost cat: " .. Config.CatName .. "!\nUse your GPS"
signText.Parent = signGui

-- Forest
local forest = Instance.new("Folder")
forest.Name = "Forest"
forest.Parent = workspace

local leafColors = {
	Color3.fromRGB(60, 120, 50),
	Color3.fromRGB(75, 140, 60),
	Color3.fromRGB(50, 105, 45),
}

local function makeTree(pos: Vector3)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	local height = rng:NextNumber(10, 18)
	local width = rng:NextNumber(1.6, 2.6)
	makePart("Part", {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
		Parent = tree,
	})
	if rng:NextNumber() < 0.5 then
		local color = leafColors[rng:NextInteger(1, #leafColors)]
		for _ = 1, 3 do
			local size = rng:NextNumber(7, 11)
			local offset = Vector3.new(rng:NextNumber(-2, 2), height + rng:NextNumber(-1, 2), rng:NextNumber(-2, 2))
			makePart("Part", {
				Name = "Leaves",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				Position = pos + offset,
				Color = color,
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = tree,
			})
		end
	else
		local size = rng:NextNumber(9, 12)
		local y = height * 0.55
		for i = 1, 4 do
			makePart("Part", {
				Name = "Needles",
				Size = Vector3.new(size, 3, size),
				CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(45 * i), 0),
				Color = Color3.fromRGB(35, 85, 45),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = tree,
			})
			size *= 0.72
			y += 2.8
		end
	end
	tree.Parent = forest
end

local placed = 0
for _ = 1, Config.TreeCount * 5 do
	if placed >= Config.TreeCount then
		break
	end
	local pos = randomSpot(5)
	if pos.Magnitude > Config.SpawnClearRadius and isFree(pos, 9) then
		table.insert(treeSpots, pos)
		makeTree(pos)
		placed += 1
	end
end

for _ = 1, Config.BushCount do
	local pos = randomSpot(5)
	if pos.Magnitude > Config.SpawnClearRadius then
		local size = rng:NextNumber(3, 6)
		makePart("Part", {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = pos + Vector3.new(0, size * 0.3, 0),
			Color = leafColors[rng:NextInteger(1, #leafColors)],
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = forest,
		})
	end
end

for _ = 1, Config.RockCount do
	local pos = randomSpot(5)
	if pos.Magnitude > Config.SpawnClearRadius then
		local size = Vector3.new(rng:NextNumber(2, 6), rng:NextNumber(1.5, 4), rng:NextNumber(2, 6))
		makePart("Part", {
			Name = "Rock",
			Size = size,
			CFrame = CFrame.new(pos + Vector3.new(0, size.Y * 0.35, 0))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(115, 115, 110),
			Material = Enum.Material.Slate,
			Parent = forest,
		})
	end
end

-- Invisible walls
for _, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	makePart("Part", {
		Name = "Wall",
		Size = Vector3.new(
			if side.X ~= 0 then 2 else Config.ForestSize,
			60,
			if side.Z ~= 0 then 2 else Config.ForestSize
		),
		Position = side * half + Vector3.new(0, 30, 0),
		Transparency = 1,
		Parent = forest,
	})
end

-- Pianka
local function makeCat(pos: Vector3): (Model, ProximityPrompt, TextLabel, Sparkles)
	local cat = Instance.new("Model")
	cat.Name = Config.CatName
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	local function add(name: string, class: string, size: Vector3, offset: CFrame, color: Color3?, shape: Enum.PartType?): BasePart
		local p = makePart(class, {
			Name = name,
			Size = size,
			CFrame = base * offset,
			Color = color or Config.CatColor,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = cat,
		})
		if shape then
			(p :: Part).Shape = shape
		end
		return p
	end

	local white = Color3.fromRGB(255, 245, 235)
	local body = add("Body", "Part", Vector3.new(1.6, 1.4, 2.6), CFrame.new(0, 1.4, 0))
	local head = add("Head", "Part", Vector3.new(1.5, 1.3, 1.3), CFrame.new(0, 2.3, -1.5))
	add("Muzzle", "Part", Vector3.new(0.8, 0.5, 0.2), CFrame.new(0, 2.05, -2.2), white)
	add("Nose", "Part", Vector3.new(0.25, 0.2, 0.1), CFrame.new(0, 2.25, -2.32), Color3.fromRGB(255, 130, 160))
	add("EyeL", "Part", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.38, 2.55, -2.15), Color3.fromRGB(80, 220, 90), Enum.PartType.Ball).Material =
		Enum.Material.Neon
	add("EyeR", "Part", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.38, 2.55, -2.15), Color3.fromRGB(80, 220, 90), Enum.PartType.Ball).Material =
		Enum.Material.Neon
	add("EarL", "WedgePart", Vector3.new(0.4, 0.6, 0.5), CFrame.new(-0.45, 3.25, -1.5) * CFrame.Angles(0, math.rad(90), 0))
	add("EarR", "WedgePart", Vector3.new(0.4, 0.6, 0.5), CFrame.new(0.45, 3.25, -1.5) * CFrame.Angles(0, math.rad(-90), 0))
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.9, 0.9 } do
			add("Leg", "Part", Vector3.new(0.4, 0.8, 0.4), CFrame.new(x, 0.4, z))
		end
	end
	local tail = add("Tail", "Part", Vector3.new(0.3, 0.3, 1.8), CFrame.new(0, 2, 1.7) * CFrame.Angles(math.rad(-50), 0, 0))
	cat.PrimaryPart = body

	TweenService:Create(
		tail,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = tail.CFrame * CFrame.Angles(0, math.rad(30), 0) }
	):Play()

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffset = Vector3.new(0, 2, 0)
	tag.MaxDistance = 40
	tag.AlwaysOnTop = true
	tag.Parent = head
	local tagText = Instance.new("TextLabel")
	tagText.Name = "Text"
	tagText.Size = UDim2.fromScale(1, 1)
	tagText.BackgroundTransparency = 1
	tagText.Font = Enum.Font.FredokaOne
	tagText.TextScaled = true
	tagText.TextColor3 = Color3.new(1, 1, 1)
	tagText.TextStrokeTransparency = 0.3
	tagText.Text = Config.CatName .. " 🐱"
	tagText.Parent = tag

	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 220, 120)
	sparkles.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = Config.CatName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	cat.Parent = workspace
	return cat, prompt, tagText, sparkles
end

local function farFromPlayers(pos: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - pos).Magnitude < Config.MinCatDistance then
			return false
		end
	end
	return true
end

local function findCatSpot(): Vector3
	for _ = 1, 300 do
		local pos = randomSpot(15)
		if pos.Magnitude >= Config.MinCatDistance and isFree(pos, 5) and farFromPlayers(pos) then
			return pos
		end
	end
	return randomSpot(15)
end

local currentCat: Model? = nil

local function newRound()
	if currentCat then
		currentCat:Destroy()
	end
	local pos = findCatSpot()
	local cat, prompt, tagText, sparkles = makeCat(pos)
	currentCat = cat
	workspace:SetAttribute("CatPosition", pos)
	workspace:SetAttribute("RoundStart", workspace:GetServerTimeNow())

	local done = false
	prompt.Triggered:Connect(function(player)
		if done then
			return
		end
		done = true
		prompt.Enabled = false
		local stats = player:FindFirstChild("leaderstats")
		local count = stats and stats:FindFirstChild("Found") :: IntValue?
		if count then
			count.Value += 1
		end
		local seconds = workspace:GetServerTimeNow() - (workspace:GetAttribute("RoundStart") :: number)
		workspace:SetAttribute("CatPosition", nil)
		foundEvent:FireAllClients(player, seconds)

		tagText.Text = "Meow! ❤️"
		sparkles.SparkleColor = Color3.fromRGB(255, 120, 180)

		task.wait(5)
		newRound()
	end)
end

local function addStats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local count = Instance.new("IntValue")
	count.Name = "Found"
	count.Parent = stats
	stats.Parent = player
end

Players.PlayerAdded:Connect(addStats)
for _, player in Players:GetPlayers() do
	addStats(player)
end

newRound()
