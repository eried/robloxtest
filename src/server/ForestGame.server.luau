local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local rng = Random.new()
local half = Config.ForestSize / 2
local treeSpots: { Vector3 } = {}

local catEvent = Instance.new("RemoteEvent")
catEvent.Name = "PiankaEvent"
catEvent.Parent = ReplicatedStorage

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
signText.Text = "Lost cat: " .. Config.CatName .. "!\nFind her and bring her home"
signText.Parent = signGui

-- Cat bed
local home = Config.HomePosition
makePart("Part", {
	Name = "BedRim",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(1.4, 7, 7),
	CFrame = CFrame.new(home + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(120, 60, 140),
	Material = Enum.Material.Fabric,
	Parent = camp,
})
local cushion = makePart("Part", {
	Name = "BedCushion",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(1, 5.6, 5.6),
	CFrame = CFrame.new(home + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	Color = Color3.fromRGB(230, 170, 220),
	Material = Enum.Material.Fabric,
	Parent = camp,
})
local bedTag = Instance.new("BillboardGui")
bedTag.Size = UDim2.fromOffset(200, 40)
bedTag.StudsOffset = Vector3.new(0, 4, 0)
bedTag.MaxDistance = 80
bedTag.Parent = cushion
local bedText = Instance.new("TextLabel")
bedText.Size = UDim2.fromScale(1, 1)
bedText.BackgroundTransparency = 1
bedText.Font = Enum.Font.FredokaOne
bedText.TextScaled = true
bedText.TextColor3 = Color3.fromRGB(255, 200, 240)
bedText.TextStrokeTransparency = 0.3
bedText.Text = Config.CatName .. "'s bed"
bedText.Parent = bedTag

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
type Cat = {
	model: Model,
	body: BasePart,
	tail: BasePart,
	tagText: TextLabel,
	sparkles: Sparkles,
}

local function makeCat(base: CFrame, scale: number): Cat
	local model = Instance.new("Model")
	model.Name = Config.CatName

	local function add(name: string, class: string, size: Vector3, pos: Vector3, color: Color3?, rotation: CFrame?): BasePart
		return makePart(class, {
			Name = name,
			Size = size * scale,
			CFrame = base * CFrame.new(pos * scale) * (rotation or CFrame.identity),
			Color = color or Config.CatColor,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
	end

	local body = add("Body", "Part", Vector3.new(1.6, 1.4, 2.6), Vector3.new(0, 1.4, 0))
	local head = add("Head", "Part", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 2.3, -1.5))
	add("Muzzle", "Part", Vector3.new(0.8, 0.5, 0.2), Vector3.new(0, 2.05, -2.2), Color3.fromRGB(255, 245, 235))
	add("Nose", "Part", Vector3.new(0.25, 0.2, 0.1), Vector3.new(0, 2.25, -2.32), Color3.fromRGB(255, 130, 160))
	for _, x in { -0.38, 0.38 } do
		local eye = add("Eye", "Part", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 2.55, -2.15), Color3.fromRGB(80, 220, 90)) :: Part
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Neon
	end
	add("EarL", "WedgePart", Vector3.new(0.4, 0.6, 0.5), Vector3.new(-0.45, 3.25, -1.5), nil, CFrame.Angles(0, math.rad(90), 0))
	add("EarR", "WedgePart", Vector3.new(0.4, 0.6, 0.5), Vector3.new(0.45, 3.25, -1.5), nil, CFrame.Angles(0, math.rad(-90), 0))
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.9, 0.9 } do
			add("Leg", "Part", Vector3.new(0.4, 0.8, 0.4), Vector3.new(x, 0.4, z))
		end
	end
	local tail = add("Tail", "Part", Vector3.new(0.3, 0.3, 1.8), Vector3.new(0, 2, 1.7), nil, CFrame.Angles(math.rad(-50), 0, 0))
	model.PrimaryPart = body

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffset = Vector3.new(0, 2, 0)
	tag.MaxDistance = 40
	tag.AlwaysOnTop = true
	tag.Parent = head
	local tagText = Instance.new("TextLabel")
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

	return { model = model, body = body, tail = tail, tagText = tagText, sparkles = sparkles }
end

local function spawnWildCat(pos: Vector3): (Cat, ProximityPrompt)
	local cat = makeCat(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), 1)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = Config.CatName
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = cat.body
	cat.model.Parent = workspace

	TweenService:Create(
		cat.tail,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = cat.tail.CFrame * CFrame.Angles(0, math.rad(30), 0) }
	):Play()
	return cat, prompt
end

local function carryCat(character: Model): Cat?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local cat = makeCat(head.CFrame * CFrame.new(0, head.Size.Y / 2, 0), 0.6)
	for _, part in cat.model:GetChildren() do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = if part == cat.body then head else cat.body
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.Massless = true
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	cat.model.Parent = character
	return cat
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

local round = 0
local wildCat: Cat? = nil
local carried: Cat? = nil
local homeCat: Cat? = nil
local carrier: Player? = nil

local function removeCat(cat: Cat?)
	if cat then
		cat.model:Destroy()
	end
end

local newRound: () -> ()

local function loseCat()
	local myRound = round
	removeCat(carried)
	carried, carrier = nil, nil
	workspace:SetAttribute("Carrier", nil)
	catEvent:FireAllClients("lost")
	task.wait(2)
	if round == myRound then
		newRound()
	end
end

local function deliver(player: Player)
	local myRound = round
	removeCat(carried)
	carried, carrier = nil, nil
	workspace:SetAttribute("Carrier", nil)

	local stats = player:FindFirstChild("leaderstats")
	local count = stats and stats:FindFirstChild("Rescued") :: IntValue?
	if count then
		count.Value += 1
	end

	homeCat = makeCat(CFrame.new(home + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, math.rad(90), 0), 1)
	local cat = homeCat :: Cat
	cat.tagText.Text = "Home! ❤️"
	cat.sparkles.SparkleColor = Color3.fromRGB(255, 120, 180)
	cat.model.Parent = workspace

	local seconds = workspace:GetServerTimeNow() - (workspace:GetAttribute("RoundStart") :: number)
	catEvent:FireAllClients("home", player, seconds)
	task.wait(6)
	if round == myRound then
		newRound()
	end
end

function newRound()
	removeCat(wildCat)
	removeCat(carried)
	removeCat(homeCat)
	wildCat, carried, homeCat, carrier = nil, nil, nil, nil
	round += 1

	local pos = findCatSpot()
	local cat, prompt = spawnWildCat(pos)
	wildCat = cat
	workspace:SetAttribute("CatPosition", pos)
	workspace:SetAttribute("Carrier", nil)
	workspace:SetAttribute("RoundStart", workspace:GetServerTimeNow())

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if wildCat ~= cat or not character then
			return
		end
		local newCarried = carryCat(character)
		if not newCarried then
			return
		end
		removeCat(cat)
		wildCat = nil
		carried = newCarried
		carrier = player
		workspace:SetAttribute("CatPosition", nil)
		workspace:SetAttribute("Carrier", player.UserId)
		catEvent:FireAllClients("picked", player)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(function()
				if carrier == player then
					loseCat()
				end
			end)
		end
	end)
end

local function addStats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local count = Instance.new("IntValue")
	count.Name = "Rescued"
	count.Parent = stats
	stats.Parent = player
end

Players.PlayerAdded:Connect(addStats)
for _, player in Players:GetPlayers() do
	addStats(player)
end

Players.PlayerRemoving:Connect(function(player)
	if carrier == player then
		loseCat()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local player = carrier
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player and root then
			local offset = root.Position - home
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < Config.HomeRadius then
				deliver(player)
			end
		end
	end
end)

newRound()
