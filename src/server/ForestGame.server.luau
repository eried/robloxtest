local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local rng = Random.new()
local half = Config.ForestSize / 2
local treeSpots: { Vector3 } = {}

local catEvent = Instance.new("RemoteEvent")
catEvent.Name = "PiankaEvent"
catEvent.Parent = ReplicatedStorage

local modeEvent = Instance.new("RemoteEvent")
modeEvent.Name = "SetMode"
modeEvent.Parent = ReplicatedStorage
local sayEvent = Instance.new("RemoteEvent")
sayEvent.Name = "NeighborSay"
sayEvent.Parent = ReplicatedStorage

workspace:SetAttribute("Mode", "Easy")

local function isHardMode(): boolean
	return workspace:GetAttribute("Mode") ~= "Easy"
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

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

local cabinSpots: { Vector3 } = {}

local function isFree(pos: Vector3, radius: number): boolean
	for _, spot in treeSpots do
		if (spot - pos).Magnitude < radius then
			return false
		end
	end
	for _, spot in cabinSpots do
		if (spot - pos).Magnitude < radius + 10 then
			return false
		end
	end
	return true
end

local function randomSpot(margin: number): Vector3
	return Vector3.new(rng:NextNumber(-half + margin, half - margin), 0, rng:NextNumber(-half + margin, half - margin))
end

local home = Config.HomePosition

for _ = 1, 300 do
	if #cabinSpots >= Config.NeighborCount then
		break
	end
	local pos = randomSpot(30)
	local ok = pos.Magnitude > 80
	for _, other in cabinSpots do
		if (other - pos).Magnitude < 110 then
			ok = false
		end
	end
	if ok then
		table.insert(cabinSpots, pos)
	end
end

-- Sky and fog
Lighting.ClockTime = 18
workspace:SetAttribute("DayStart", workspace:GetServerTimeNow())
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(120, 140, 120)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density = 0.45
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(190, 215, 190)
atmosphere.Decay = Color3.fromRGB(90, 120, 90)
atmosphere.Haze = 1.5
atmosphere.Parent = Lighting

local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.7
bloom.Size = 18
bloom.Threshold = 1.3
bloom.Parent = Lighting

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
signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
signGui.Parent = sign
local signText = Instance.new("TextLabel")
signText.Size = UDim2.fromScale(0.92, 0.9)
signText.Position = UDim2.fromScale(0.04, 0.05)
signText.BackgroundTransparency = 1
signText.Font = Enum.Font.FredokaOne
signText.TextScaled = true
signText.TextColor3 = Color3.new(1, 1, 1)
signText.Text = "Lost cat: " .. Config.CatName .. "!\nFind her and bring her home"
signText.Parent = signGui

-- Cat bed
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
	CFrame = CFrame.new(home + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0, math.rad(90)),
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
	if pos.Magnitude > Config.SpawnClearRadius and isFree(pos, 0) then
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
	if pos.Magnitude > Config.SpawnClearRadius and isFree(pos, 0) then
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

-- Neighbors
type Neighbor = {
	root: BasePart,
	head: BasePart,
	bubble: BillboardGui,
	lineNo: TextLabel,
	lineEn: TextLabel,
	spot: Vector3,
	cooldown: number,
	last: number,
	pitch: number,
}
local neighbors: { Neighbor } = {}
local neighborFolder = Instance.new("Folder")
neighborFolder.Name = "Neighbors"
neighborFolder.Parent = workspace

local function makeCabin(pos: Vector3): CFrame
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local cabin = Instance.new("Model")
	cabin.Name = "Cabin"
	makePart("Part", {
		Name = "Walls",
		Size = Vector3.new(12, 8, 10),
		CFrame = base * CFrame.new(0, 4, 0),
		Color = Color3.fromRGB(70, 50, 38),
		Material = Enum.Material.WoodPlanks,
		Parent = cabin,
	})
	makePart("Part", {
		Name = "Roof",
		Size = Vector3.new(8.6, 8.6, 11),
		CFrame = base * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(45)),
		Color = Color3.fromRGB(40, 32, 28),
		Material = Enum.Material.Wood,
		Parent = cabin,
	})
	makePart("Part", {
		Name = "Door",
		Size = Vector3.new(2.6, 5, 0.3),
		CFrame = base * CFrame.new(-2, 2.5, -5.1),
		Color = Color3.fromRGB(30, 22, 18),
		Material = Enum.Material.Wood,
		Parent = cabin,
	})
	local window = makePart("Part", {
		Name = "Window",
		Size = Vector3.new(2.2, 2, 0.3),
		CFrame = base * CFrame.new(3, 4.5, -5.1),
		Color = Color3.fromRGB(255, 160, 70),
		Material = Enum.Material.Neon,
		Parent = cabin,
	})
	local glow = Instance.new("PointLight")
	glow.Range = 24
	glow.Brightness = 2
	glow.Color = Color3.fromRGB(255, 150, 70)
	glow.Parent = window
	cabin.Parent = neighborFolder
	return base * CFrame.new(-2, 0, -8)
end

local function makeNeighbor(spot: CFrame)
	local model = Instance.new("Model")
	model.Name = "Neighbor"
	local coat = ({ Color3.fromRGB(40, 40, 48), Color3.fromRGB(55, 40, 35), Color3.fromRGB(35, 45, 40) })[rng:NextInteger(1, 3)]
	local skin = Color3.fromRGB(190, 198, 185)
	local root = makePart("Part", {
		Name = "Torso",
		Size = Vector3.new(2.2, 2.4, 1.1),
		CFrame = spot * CFrame.new(0, 3.6, 0),
		Color = coat,
		Material = Enum.Material.Fabric,
		CanCollide = false,
		Parent = model,
	})
	local function add(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = makePart("Part", {
			Name = name,
			Size = size,
			CFrame = root.CFrame * CFrame.new(offset),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Anchored = false,
			CanCollide = false,
			CanQuery = false,
			Massless = true,
			Parent = model,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	for _, x in { -0.55, 0.55 } do
		add("Leg", Vector3.new(1, 2.4, 1), Vector3.new(x, -2.4, 0), Color3.fromRGB(25, 25, 30))
	end
	for _, x in { -1.65, 1.65 } do
		add("Arm", Vector3.new(1, 2.6, 1), Vector3.new(x, -0.1, 0), coat, Enum.Material.Fabric)
	end
	local head = add("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.9, 0), skin)
	for _, x in { -0.3, 0.3 } do
		add("Eye", Vector3.new(0.25, 0.2, 0.1), Vector3.new(x, 2.0, -0.66), Color3.fromRGB(180, 220, 255), Enum.Material.Neon)
	end
	add("HatBrim", Vector3.new(2, 0.15, 2), Vector3.new(0, 2.6, 0), Color3.fromRGB(20, 20, 22))
	add("HatTop", Vector3.new(1.3, 1.1, 1.3), Vector3.new(0, 3.2, 0), Color3.fromRGB(20, 20, 22))

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(280, 70)
	bubble.StudsOffset = Vector3.new(0, 3.5, 0)
	bubble.MaxDistance = 70
	bubble.AlwaysOnTop = true
	bubble.Enabled = false
	bubble.Parent = head
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	back.BackgroundTransparency = 0.25
	back.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = back
	local lineNo = Instance.new("TextLabel")
	lineNo.Size = UDim2.new(1, -16, 0.6, -4)
	lineNo.Position = UDim2.fromOffset(8, 4)
	lineNo.BackgroundTransparency = 1
	lineNo.Font = Enum.Font.FredokaOne
	lineNo.TextScaled = true
	lineNo.TextColor3 = Color3.fromRGB(200, 225, 255)
	lineNo.Parent = back
	local lineEn = lineNo:Clone()
	lineEn.Size = UDim2.new(1, -16, 0.4, -4)
	lineEn.Position = UDim2.new(0, 8, 0.6, 0)
	lineEn.TextColor3 = Color3.fromRGB(235, 235, 235)
	lineEn.Parent = back

	model.PrimaryPart = root
	model.Parent = neighborFolder
	table.insert(neighbors, {
		root = root,
		head = head,
		bubble = bubble,
		lineNo = lineNo,
		lineEn = lineEn,
		spot = spot.Position + Vector3.new(0, 3.6, 0),
		cooldown = 0,
		last = 0,
		pitch = rng:NextNumber(0.85, 1.05),
	})
end

for _, pos in cabinSpots do
	makeNeighbor(makeCabin(pos))
end

-- Lantern
local lantern = Instance.new("Tool")
lantern.Name = "Lantern"
lantern.CanBeDropped = false
lantern.GripPos = Vector3.new(0, 0.9, 0)
local lanternHandle = makePart("Part", {
	Name = "Handle",
	Size = Vector3.new(0.7, 0.9, 0.7),
	Color = Color3.fromRGB(255, 200, 90),
	Material = Enum.Material.Neon,
	Anchored = false,
	CanCollide = false,
	CastShadow = false,
	Massless = true,
	Parent = lantern,
})
for _, y in { 0.55, -0.55 } do
	local cap = makePart("Part", {
		Name = "Cap",
		Size = Vector3.new(0.9, 0.2, 0.9),
		CFrame = CFrame.new(0, y, 0),
		Color = Color3.fromRGB(40, 35, 30),
		Material = Enum.Material.Metal,
		Anchored = false,
		CanCollide = false,
		Massless = true,
		Parent = lantern,
	})
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lanternHandle
	weld.Part1 = cap
	weld.Parent = cap
end
local lanternLight = Instance.new("PointLight")
lanternLight.Range = 40
lanternLight.Brightness = 3
lanternLight.Color = Color3.fromRGB(255, 190, 110)
lanternLight.Shadows = true
lanternLight.Parent = lanternHandle

local function applyHero(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local hero = player:GetAttribute("Hero")
	local slow = ((player:GetAttribute("SlowUntil") :: number?) or 0) > os.clock()
	humanoid.WalkSpeed = (if hero == "Patrick" then Config.PatrickSpeed else 16) * (if slow then 0.6 else 1)
	humanoid.DisplayName = if type(hero) == "string" then hero else player.DisplayName
	local backpack = player:FindFirstChild("Backpack")
	local tool = character:FindFirstChild("Lantern") or (backpack and backpack:FindFirstChild("Lantern"))
	local handle = tool and tool:FindFirstChild("Handle")
	local light = handle and handle:FindFirstChildOfClass("PointLight")
	if light then
		light.Range = if hero == "Milena" then 60 else 40
		light.Brightness = if hero == "Milena" then 5 else 3
		local color = Color3.fromRGB(255, 190, 110)
		for _, item in Config.Shop do
			if item.id == player:GetAttribute("Lantern") then
				color = item.color
			end
		end
		light.Color = color;
		(handle :: BasePart).Color = color
	end
end

local onLanternFlash: (Player) -> ()
local applyCosmetics: (Player) -> ()

local function giveLantern(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local tool = lantern:Clone()
	tool.Parent = player:WaitForChild("Backpack")
	humanoid:EquipTool(tool)
	tool.Activated:Connect(function()
		onLanternFlash(player)
	end)
	applyHero(player)
	applyCosmetics(player)
end

-- Pianka
type Cat = {
	model: Model,
	body: BasePart,
	tail: BasePart,
	tailRest: CFrame,
	collar: BasePart,
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
	local collar = add("Collar", "Part", Vector3.new(1.55, 0.3, 0.35), Vector3.new(0, 1.85, -1.3), Color3.fromRGB(255, 90, 170))
	collar.Material = Enum.Material.Neon
	add("Muzzle", "Part", Vector3.new(0.8, 0.5, 0.2), Vector3.new(0, 2.05, -2.2))
	add("Nose", "Part", Vector3.new(0.25, 0.2, 0.1), Vector3.new(0, 2.25, -2.32), Color3.fromRGB(55, 55, 60))
	for _, x in { -0.38, 0.38 } do
		local eye = add("Eye", "Part", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 2.55, -2.15), Config.EyeColor) :: Part
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
	tag.MaxDistance = 80
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

	return {
		model = model,
		body = body,
		tail = tail,
		tailRest = body.CFrame:ToObjectSpace(tail.CFrame),
		collar = collar,
		tagText = tagText,
		sparkles = sparkles,
	}
end

local function wagTail(tail: BasePart): Tween
	local tween = TweenService:Create(
		tail,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = tail.CFrame * CFrame.Angles(0, math.rad(30), 0) }
	)
	tween:Play()
	return tween
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
	local glow = Instance.new("PointLight")
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Color = Color3.fromRGB(255, 120, 190)
	glow.Shadows = false
	glow.Parent = cat.body
	cat.model:SetAttribute("Wild", true)
	cat.model.Parent = workspace
	return cat, prompt
end

local function carryCat(character: Model, scale: number, lift: number): Cat?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local cat = makeCat(head.CFrame * CFrame.new(0, head.Size.Y / 2 + lift, 0), scale)
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
local wildPrompt: ProximityPrompt? = nil
local wildTween: Tween? = nil
local homeTween: Tween? = nil
local pendingHero: { [Player]: string } = {}
local fleesLeft = 0
local fleeing = false
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

local kittenFolder = Instance.new("Folder")
kittenFolder.Name = "Kittens"
kittenFolder.Parent = workspace
local kittens: { Cat } = {}
local kittensLeft = 0
local umulig = false
local stacks: { [Player]: { Cat } } = {}

local dogFolder = Instance.new("Folder")
dogFolder.Name = "Dogs"
dogFolder.Parent = workspace
local escapeConn: RBXScriptConnection? = nil

local function clearUmulig()
	if escapeConn then
		escapeConn:Disconnect()
		escapeConn = nil
	end
	dogFolder:ClearAllChildren()
	workspace:SetAttribute("Escape", nil)
	for player, stack in stacks do
		for _, kitten in stack do
			removeCat(kitten)
		end
		player:SetAttribute("Kittens", nil)
	end
	table.clear(stacks)
end

local function failUmulig(player: Player?)
	if not umulig then
		return
	end
	local myRound = round
	umulig = false
	kittensLeft = 0
	clearUmulig()
	kittenFolder:ClearAllChildren()
	workspace:SetAttribute("KittenDeadline", nil)
	catEvent:FireAllClients("caught", player)
	task.delay(5, function()
		if round == myRound then
			newRound()
		end
	end)
end

local function fleeFrom(cat: Cat, prompt: ProximityPrompt, player: Player, from: Vector3)
	local start = cat.model:GetPivot()
	local catPos = Vector3.new(start.X, 0, start.Z)
	local away = Vector3.new(catPos.X - from.X, 0, catPos.Z - from.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)

	local target: Vector3? = nil
	for i = 1, 16 do
		local spread = if i <= 6 then 0.8 else math.pi
		local dir = CFrame.Angles(0, rng:NextNumber(-spread, spread), 0):VectorToWorldSpace(away)
		local pos = catPos + dir * rng:NextNumber(40, 60)
		local farFromHome = (pos - home).Magnitude >= Config.MinCatDistance
		if math.abs(pos.X) < half - 15 and math.abs(pos.Z) < half - 15 and farFromHome and isFree(pos, 5) then
			target = pos
			break
		end
	end
	if not target then
		return
	end

	fleeing = true
	fleesLeft -= 1
	prompt.Enabled = false
	if wildTween then
		wildTween:Cancel()
	end
	cat.tail.CFrame = cat.body.CFrame * cat.tailRest
	catEvent:FireClient(player, "fled")

	local lift = Vector3.new(0, 1.4, 0)
	local dir = (target - catPos).Unit
	local fromCf = CFrame.lookAt(start.Position, start.Position + dir)
	local goalCf = CFrame.lookAt(target + lift, target + lift + dir)
	local t0 = os.clock()
	local alpha = 0
	while alpha < 1 and cat.model.Parent do
		alpha = math.min((os.clock() - t0) / 1.5, 1)
		local hop = math.abs(math.sin(alpha * math.pi * 6)) * 0.8
		local cf = fromCf:Lerp(goalCf, alpha)
		cat.model:PivotTo(cf + Vector3.new(0, hop, 0))
		workspace:SetAttribute("CatPosition", Vector3.new(cf.X, 0, cf.Z))
		RunService.Heartbeat:Wait()
	end

	if wildCat == cat then
		wildTween = wagTail(cat.tail)
		prompt.Enabled = true
	end
	fleeing = false
end

local function loseCat()
	local myRound = round
	removeCat(carried)
	carried, carrier = nil, nil
	workspace:SetAttribute("Carrier", nil)
	workspace:SetAttribute("CarryEnd", nil)
	catEvent:FireAllClients("lost")
	task.wait(2)
	if round == myRound then
		newRound()
	end
end

-- Rats, fish and fun
type Rat = {
	model: Model,
	body: BasePart,
	bubble: BillboardGui,
	nest: Vector3,
	pos: Vector3,
	dir: Vector3,
	wander: Vector3,
	cooldown: number,
	windup: number,
	fleeUntil: number,
	fleeFrom: Vector3,
	deadUntil: number,
	speed: number,
}
local rats: { Rat } = {}
local ratFolder = Instance.new("Folder")
ratFolder.Name = "Rats"
ratFolder.Parent = workspace
local fishFolder = Instance.new("Folder")
fishFolder.Name = "Fish"
fishFolder.Parent = workspace
local twistFolder = Instance.new("Folder")
twistFolder.Name = "Twist"
twistFolder.Parent = workspace
local lastBitten: { [Player]: number } = {}
local lastFlash: { [Player]: number } = {}
local dropCat: (Player) -> ()
local twist: string? = nil
local zoomies = false
local GOLD = Color3.fromRGB(255, 200, 50)

local beam = makePart("Part", {
	Name = "HomeBeam",
	Size = Vector3.new(2, 150, 2),
	Position = home + Vector3.new(0, 76, 0),
	Color = Color3.fromRGB(255, 120, 200),
	Material = Enum.Material.Neon,
	Transparency = 0.6,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
})
beam.Parent = workspace:FindFirstChild("Camp")

local function giveFish(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local fish = stats and stats:FindFirstChild("Fish") :: IntValue?
	if fish then
		fish.Value += amount
		catEvent:FireClient(player, "fish", nil, amount)
	end
end

local function fireworks()
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 220, 110), Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 130, 200) }
	for i = 1, 6 do
		task.delay(i * 0.25, function()
			local start = home + Vector3.new(rng:NextNumber(-6, 6), 2, rng:NextNumber(-6, 6))
			local ball = makePart("Part", {
				Name = "Firework",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 1.2,
				Position = start,
				Color = colors[rng:NextInteger(1, #colors)],
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = workspace,
			})
			local tween = TweenService:Create(ball, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = start + Vector3.new(0, rng:NextNumber(45, 65), 0) })
			tween.Completed:Once(function()
				local boom = Instance.new("Explosion")
				boom.Position = ball.Position
				boom.BlastPressure = 0
				boom.BlastRadius = 6
				boom.DestroyJointRadiusPercent = 0
				boom.ExplosionType = Enum.ExplosionType.NoCraters
				boom.Parent = workspace
				ball:Destroy()
			end)
			tween:Play()
		end)
	end
end

local function makeRat(pos: Vector3): (Model, BasePart, BillboardGui)
	local model = Instance.new("Model")
	model.Name = "Rat"
	local grey = Color3.fromRGB(125, 118, 125)
	local pink = Color3.fromRGB(240, 150, 170)
	local body = makePart("Part", {
		Name = "Body",
		Size = Vector3.new(0.9, 0.6, 1.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)),
		Color = grey,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = model,
	})
	local function add(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
		local part = makePart("Part", {
			Name = name,
			Size = size,
			CFrame = body.CFrame * CFrame.new(offset),
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Anchored = false,
			Massless = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = model,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	add("Head", Vector3.new(0.6, 0.5, 0.6), Vector3.new(0, 0.05, -1), grey)
	add("Nose", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0, 0, -1.35), pink)
	for _, x in { -0.22, 0.22 } do
		add("Ear", Vector3.new(0.25, 0.3, 0.08), Vector3.new(x, 0.4, -0.9), pink)
		add("Eye", Vector3.new(0.12, 0.12, 0.05), Vector3.new(x * 0.8, 0.15, -1.31), Color3.fromRGB(255, 70, 70), Enum.Material.Neon)
	end
	add("Tail", Vector3.new(0.1, 0.1, 1.4), Vector3.new(0, 0.05, 1.45), pink)
	model.PrimaryPart = body

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(110, 32)
	bubble.StudsOffset = Vector3.new(0, 2, 0)
	bubble.MaxDistance = 60
	bubble.AlwaysOnTop = true
	bubble.Enabled = false
	bubble.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 200, 220)
	text.TextStrokeTransparency = 0.2
	text.Text = "Nibble!"
	text.Parent = bubble

	model.Parent = ratFolder
	return model, body, bubble
end

local function clearRats()
	for _, rat in rats do
		rat.model:Destroy()
	end
	table.clear(rats)
	ratFolder:ClearAllChildren()
end

local function spawnRats(catPos: Vector3)
	clearRats()
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	local count = Config.RatCount[mode] or 10
	if twist == "ratparty" then
		count = math.floor(count * 1.5)
	end
	for i = 1, count do
		local pos = randomSpot(15)
		for _ = 1, 40 do
			local try = if i % 2 == 0
				then catPos + Vector3.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(-80, 80))
				else randomSpot(15)
			local okSpot = math.abs(try.X) < half - 10
				and math.abs(try.Z) < half - 10
				and (try - home).Magnitude > Config.RatSafeRadius + 40
				and (try - catPos).Magnitude > 20
				and isFree(try, 4)
			if okSpot then
				pos = try
				break
			end
		end
		local model, body, bubble = makeRat(pos)
		table.insert(rats, {
			model = model,
			body = body,
			bubble = bubble,
			nest = pos,
			pos = pos,
			dir = Vector3.new(0, 0, -1),
			wander = pos,
			cooldown = 0,
			windup = 0,
			fleeUntil = 0,
			fleeFrom = pos,
			deadUntil = 0,
			speed = Config.RatSpeed[mode] or 11,
		})
	end
end

local function biteBy(rat: Rat, player: Player, humanoid: Humanoid)
	local now = os.clock()
	rat.cooldown = now + 2
	if now - (lastBitten[player] or 0) < 0.5 then
		return
	end
	lastBitten[player] = now
	humanoid:TakeDamage(math.max(0, math.min(Config.RatBite, humanoid.Health - 1)))
	player:SetAttribute("SlowUntil", now + 1.5)
	applyHero(player)
	task.delay(1.6, applyHero, player)
	rat.bubble.Enabled = true
	task.delay(0.6, function()
		rat.bubble.Enabled = false
	end)
	catEvent:FireClient(player, "bitten")
	if carrier == player and humanoid.Health <= 30 then
		dropCat(player)
	end
end

local function squash(rat: Rat, player: Player)
	rat.deadUntil = os.clock() + 20
	rat.windup = 0
	local poof = Instance.new("Explosion")
	poof.Position = rat.pos + Vector3.new(0, 0.5, 0)
	poof.BlastPressure = 0
	poof.BlastRadius = 1
	poof.DestroyJointRadiusPercent = 0
	poof.ExplosionType = Enum.ExplosionType.NoCraters
	poof.Parent = workspace
	rat.model.Parent = nil
	giveFish(player, Config.Reward.Rat)
	catEvent:FireClient(player, "squash")
end

onLanternFlash = function(player: Player)
	local now = os.clock()
	local root = getRoot(player)
	if not root or now - (lastFlash[player] or 0) < 4 then
		return
	end
	lastFlash[player] = now
	local character = player.Character
	local tool = character and character:FindFirstChild("Lantern")
	local handle = tool and tool:FindFirstChild("Handle")
	local light = handle and handle:FindFirstChildOfClass("PointLight")
	if light then
		light.Range = 60
		light.Brightness = 10
		task.delay(0.3, applyHero, player)
	end
	local radius = if player:GetAttribute("Hero") == "Milena" then 30 else 20
	local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
	for _, rat in rats do
		if (rat.pos - pos).Magnitude < radius then
			rat.fleeUntil = now + 3
			rat.fleeFrom = pos
			rat.windup = 0
		end
	end
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function spawnFish()
	fishFolder:ClearAllChildren()
	local myRound = round
	for _ = 1, Config.FishCount do
		local pos = randomSpot(10)
		for _ = 1, 20 do
			if (pos - home).Magnitude > 25 and isFree(pos, 3) then
				break
			end
			pos = randomSpot(10)
		end
		local fish = makePart("Part", {
			Name = "Fish",
			Size = Vector3.new(1.4, 0.7, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)),
			Color = Color3.fromRGB(255, 170, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = fishFolder,
		})
		local light = Instance.new("PointLight")
		light.Range = 8
		light.Brightness = 1
		light.Color = Color3.fromRGB(255, 170, 60)
		light.Shadows = false
		light.Parent = fish
		local taken = false
		fish.Touched:Connect(function(hit)
			local player = if taken then nil else playerFromHit(hit)
			if not player then
				return
			end
			taken = true
			fish.Transparency = 1
			light.Enabled = false
			giveFish(player, 1)
			task.delay(Config.FishRespawn, function()
				if fish.Parent and round == myRound then
					taken = false
					fish.Transparency = 0
					light.Enabled = true
				end
			end)
		end)
	end
end

local function buildTree(pos: Vector3): number
	local wood = Color3.fromRGB(120, 85, 50)
	local steps = { Vector3.new(4, 2.6, 0), Vector3.new(0, 5.2, 4), Vector3.new(-4, 7.8, 0) }
	for _, offset in steps do
		makePart("Part", {
			Name = "Step",
			Size = Vector3.new(3, 0.6, 3),
			Position = pos + offset - Vector3.new(0, 0.3, 0),
			Color = wood,
			Material = Enum.Material.WoodPlanks,
			Parent = twistFolder,
		})
	end
	makePart("Part", {
		Name = "Platform",
		Size = Vector3.new(5, 0.6, 5),
		Position = pos + Vector3.new(0, 10.1, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = twistFolder,
	})
	makePart("Part", {
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 1.2, 1.2),
		CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
		Parent = twistFolder,
	})
	return 10.4
end

local function deliver(player: Player)
	local myRound = round
	removeCat(carried)
	carried, carrier = nil, nil
	workspace:SetAttribute("Carrier", nil)
	workspace:SetAttribute("CarryEnd", nil)

	local stats = player:FindFirstChild("leaderstats")
	local count = stats and stats:FindFirstChild("Rescued") :: IntValue?
	if count then
		count.Value += if twist == "golden" then 2 else 1
	end
	giveFish(player, Config.Reward.Deliver * (if twist == "golden" then 2 else 1))
	fireworks()

	homeCat = makeCat(CFrame.new(home + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, math.rad(90), 0), 1)
	local cat = homeCat :: Cat
	cat.tagText.Text = "Home! ❤️"
	cat.sparkles.SparkleColor = Color3.fromRGB(255, 120, 180)
	cat.model.Parent = workspace
	homeTween = wagTail(cat.tail)

	local seconds = workspace:GetServerTimeNow() - (workspace:GetAttribute("RoundStart") :: number)
	catEvent:FireAllClients("home", player, seconds)
	task.wait(6)
	if round == myRound then
		newRound()
	end
end

local function kittenSpot(center: Vector3, taken: { Vector3 }): Vector3
	for _ = 1, 200 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(40, 160)
		local ok = math.abs(pos.X) < half - 10
			and math.abs(pos.Z) < half - 10
			and (pos - home).Magnitude >= Config.KittenHomeMin
			and isFree(pos, 4)
		for _, other in taken do
			if (other - pos).Magnitude < 25 then
				ok = false
			end
		end
		if ok then
			return pos
		end
	end
	return randomSpot(15)
end

local function makeKitten(cf: CFrame): Cat
	local kitten = makeCat(cf, 0.45)
	kitten.model.Name = "Kitten"
	kitten.tagText.Text = "Kitten"
	local tag = kitten.tagText.Parent :: BillboardGui
	tag.MaxDistance = 50
	kitten.sparkles:Destroy()
	local glow = Instance.new("PointLight")
	glow.Range = 7
	glow.Brightness = 1
	glow.Color = Color3.fromRGB(255, 120, 190)
	glow.Shadows = false
	glow.Parent = kitten.body
	table.insert(kittens, kitten)
	return kitten
end

local function kittenAtHome(index: number)
	local angle = index / Config.KittenCount * math.pi * 2
	local spot = home + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5
	makeKitten(CFrame.lookAt(spot, Vector3.new(home.X, 0, home.Z))).model.Parent = workspace
end

local function stackKitten(player: Player): boolean
	local character = player.Character
	if not character or not getRoot(player) then
		return false
	end
	local stack = stacks[player]
	if not stack then
		local fresh: { Cat } = {}
		stack = fresh
		stacks[player] = fresh
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(function()
				if stacks[player] == fresh and #fresh > 0 then
					failUmulig(player)
				end
			end)
		end
	end
	local kitten = carryCat(character, 0.45, #stack * 1.4)
	if not kitten then
		return false
	end
	kitten.model.Name = "Kitten"
	local tag = kitten.tagText.Parent :: BillboardGui
	tag:Destroy()
	kitten.sparkles:Destroy()
	table.insert(stack, kitten)
	player:SetAttribute("Kittens", #stack)
	return true
end

local function makeDog(pos: Vector3): (Model, TextLabel)
	local dog = Instance.new("Model")
	dog.Name = "Dog"
	local fur = ({ Color3.fromRGB(120, 80, 45), Color3.fromRGB(90, 60, 40), Color3.fromRGB(160, 120, 80), Color3.fromRGB(60, 55, 50) })[rng:NextInteger(1, 4)]
	local base = CFrame.new(pos)
	local function add(name: string, size: Vector3, offset: Vector3, color: Color3?): BasePart
		return makePart("Part", {
			Name = name,
			Size = size,
			CFrame = base * CFrame.new(offset),
			Color = color or fur,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = dog,
		})
	end
	local body = add("Body", Vector3.new(1.8, 1.5, 3.4), Vector3.new(0, 1.9, 0))
	add("Head", Vector3.new(1.5, 1.4, 1.5), Vector3.new(0, 2.9, -2.1))
	add("Snout", Vector3.new(0.9, 0.7, 0.9), Vector3.new(0, 2.6, -3.1))
	add("Nose", Vector3.new(0.4, 0.3, 0.2), Vector3.new(0, 2.85, -3.6), Color3.fromRGB(20, 20, 20))
	add("Tongue", Vector3.new(0.4, 0.1, 0.5), Vector3.new(0, 2.2, -3.4), Color3.fromRGB(230, 90, 110))
	for _, x in { -0.4, 0.4 } do
		add("Eye", Vector3.new(0.25, 0.25, 0.1), Vector3.new(x, 3.15, -2.88), Color3.fromRGB(255, 90, 40)).Material = Enum.Material.Neon
		add("Ear", Vector3.new(0.3, 0.9, 0.6), Vector3.new(x * 2, 3.0, -1.9))
	end
	for _, x in { -0.6, 0.6 } do
		for _, z in { -1.2, 1.2 } do
			add("Leg", Vector3.new(0.5, 1.3, 0.5), Vector3.new(x, 0.65, z))
		end
	end
	add("Tail", Vector3.new(0.3, 0.3, 1.4), Vector3.new(0, 2.6, 2.1))
	dog.PrimaryPart = body
	for _, part in dog:GetChildren() do
		if part:IsA("BasePart") and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.Massless = true
		end
	end

	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(120, 40)
	bubble.StudsOffset = Vector3.new(0, 4.5, 0)
	bubble.MaxDistance = 120
	bubble.AlwaysOnTop = true
	bubble.Parent = body
	local bark = Instance.new("TextLabel")
	bark.Size = UDim2.fromScale(1, 1)
	bark.BackgroundTransparency = 1
	bark.Font = Enum.Font.FredokaOne
	bark.TextScaled = true
	bark.TextColor3 = Color3.fromRGB(255, 80, 60)
	bark.TextStrokeTransparency = 0.2
	bark.Text = "WOOF!"
	bark.Visible = false
	bark.Parent = bubble

	dog.Parent = dogFolder
	return dog, bark
end

local function startEscape()
	local myRound = round
	clearRats()
	workspace:SetAttribute("KittenDeadline", nil)
	workspace:SetAttribute("Escape", true)
	catEvent:FireAllClients("dogs")

	local runners: { Player } = {}
	for player, stack in stacks do
		if #stack > 0 then
			table.insert(runners, player)
		end
	end
	if #runners == 0 then
		failUmulig(nil)
		return
	end

	type Dog = { model: Model, bark: TextLabel, pos: Vector3, dir: Vector3, speed: number, restUntil: number, nextRest: number, barkUntil: number }
	local dogs: { Dog } = {}
	local now = os.clock()
	for i = 1, Config.DogCount do
		local runner = runners[(i - 1) % #runners + 1]
		local root = getRoot(runner)
		local center = if root then Vector3.new(root.Position.X, 0, root.Position.Z) else Vector3.zero
		local angle = i / Config.DogCount * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local pos = center
		for _ = 1, 12 do
			pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(Config.DogSpawnMin, Config.DogSpawnMax)
			pos = Vector3.new(math.clamp(pos.X, -half + 5, half - 5), 0, math.clamp(pos.Z, -half + 5, half - 5))
			if (pos - center).Magnitude >= 40 then
				break
			end
			angle = rng:NextNumber(0, math.pi * 2)
		end
		local model, bark = makeDog(pos)
		table.insert(dogs, {
			model = model,
			bark = bark,
			pos = pos,
			dir = (center - pos).Unit,
			speed = Config.DogSpeedFactor * rng:NextNumber(0.95, 1.05),
			restUntil = now + rng:NextNumber(2.5, 3),
			nextRest = now + rng:NextNumber(5, 8),
			barkUntil = 0,
		})
	end

	local delivered = 0
	local finished = false
	escapeConn = RunService.Heartbeat:Connect(function(dt)
		if finished or round ~= myRound then
			return
		end
		local t = os.clock()
		local targets: { [Player]: Vector3 } = {}
		for player, stack in stacks do
			if #stack > 0 then
				local root = getRoot(player)
				if not root or not player.Parent then
					finished = true
					failUmulig(player)
					return
				end
				local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
				if (pos - Vector3.new(home.X, 0, home.Z)).Magnitude < Config.HomeRadius then
					for _, kitten in stack do
						removeCat(kitten)
						delivered += 1
						kittenAtHome(delivered)
					end
					table.clear(stack)
					player:SetAttribute("Kittens", 0)
					if delivered >= Config.KittenCount then
						finished = true
						umulig = false
						local seconds = workspace:GetServerTimeNow() - (workspace:GetAttribute("RoundStart") :: number)
						if escapeConn then
							escapeConn:Disconnect()
							escapeConn = nil
						end
						dogFolder:ClearAllChildren()
						workspace:SetAttribute("Escape", nil)
						catEvent:FireAllClients("escaped", player, seconds)
						giveFish(player, Config.Reward.Umulig)
						fireworks()
						task.delay(8, function()
							if round == myRound then
								newRound()
							end
						end)
						return
					end
				else
					targets[player] = pos
				end
			end
		end

		for _, dog in dogs do
			local best: Vector3? = nil
			local bestPlayer: Player? = nil
			local bestDistance = math.huge
			for player, pos in targets do
				local distance = (pos - dog.pos).Magnitude
				if distance < bestDistance then
					best, bestPlayer, bestDistance = pos, player, distance
				end
			end
			if best and bestDistance < Config.DogCatch then
				finished = true
				failUmulig(bestPlayer)
				return
			end

			local targetHumanoid = bestPlayer and bestPlayer.Character and bestPlayer.Character:FindFirstChildOfClass("Humanoid")
			local calm = bestPlayer ~= nil and bestPlayer:GetAttribute("Hero") == "Milena"
			if t >= dog.nextRest and bestDistance < 30 then
				dog.restUntil = t + rng:NextNumber(1.2, 2) * (if calm then 2 else 1)
				dog.nextRest = dog.restUntil + rng:NextNumber(5, 8)
			end
			local running = best ~= nil and t >= dog.restUntil
			if best and running then
				local dir = (best - dog.pos).Unit
				local walkSpeed = if targetHumanoid then targetHumanoid.WalkSpeed else 16
				local nextPos = dog.pos + dir * walkSpeed * dog.speed * dt
				for _, tree in treeSpots do
					local away = nextPos - tree
					if away.Magnitude < 3 and away.Magnitude > 0.01 then
						nextPos = tree + away.Unit * 3
					end
				end
				for _, cabin in cabinSpots do
					local away = nextPos - cabin
					if away.Magnitude < 9 and away.Magnitude > 0.01 then
						nextPos = cabin + away.Unit * 9
					end
				end
				for _, other in dogs do
					local away = nextPos - other.pos
					if other ~= dog and away.Magnitude < 3 and away.Magnitude > 0.01 then
						nextPos += away.Unit * (3 - away.Magnitude) * 0.5
					end
				end
				dog.dir = dir
				dog.pos = Vector3.new(math.clamp(nextPos.X, -half + 3, half - 3), 0, math.clamp(nextPos.Z, -half + 3, half - 3))
			end

			if t > dog.barkUntil and rng:NextNumber() < dt * 0.3 then
				dog.barkUntil = t + 0.6
			end
			dog.bark.Visible = t < dog.barkUntil
			local hop = if running then math.abs(math.sin(t * 14)) * 0.5 else 0
			local at = dog.pos + Vector3.new(0, 1.9 + hop, 0)
			local body = dog.model.PrimaryPart :: BasePart
			body.CFrame = CFrame.lookAt(at, at + dog.dir)
		end
	end)
end

local function collectKitten(kitten: Cat, player: Player)
	if kitten.model.Parent ~= kittenFolder or kittensLeft <= 0 then
		return
	end
	if umulig and not stackKitten(player) then
		return
	end
	local myRound = round
	removeCat(kitten)
	kittensLeft -= 1
	if not umulig then
		kittenAtHome(Config.KittenCount - kittensLeft)
	end

	local stats = player:FindFirstChild("leaderstats")
	local count = stats and stats:FindFirstChild("Rescued") :: IntValue?
	if count then
		count.Value += 1
	end
	giveFish(player, Config.Reward.Kitten)
	workspace:SetAttribute("KittensLeft", kittensLeft)
	catEvent:FireAllClients("kitten", player, kittensLeft)

	if kittensLeft == 0 and umulig then
		startEscape()
	elseif kittensLeft == 0 then
		workspace:SetAttribute("KittenDeadline", nil)
		local seconds = workspace:GetServerTimeNow() - (workspace:GetAttribute("RoundStart") :: number)
		catEvent:FireAllClients("allKittens", player, seconds)
		fireworks()
		task.wait(8)
		if round == myRound then
			newRound()
		end
	end
end

local function startKittens(cat: Cat, ultra: boolean)
	local myRound = round
	umulig = ultra
	local center = cat.model:GetPivot().Position
	removeCat(cat)
	wildCat = nil
	workspace:SetAttribute("CatPosition", nil)

	local boom = Instance.new("Explosion")
	boom.Position = center
	boom.BlastPressure = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Parent = workspace

	homeCat = makeCat(CFrame.new(home + Vector3.new(0, 1.45, 0)) * CFrame.Angles(0, math.rad(90), 0), 1)
	local mom = homeCat :: Cat
	mom.tagText.Text = "Mama " .. Config.CatName
	mom.model.Parent = workspace
	homeTween = wagTail(mom.tail)

	local taken: { Vector3 } = {}
	for _ = 1, Config.KittenCount do
		local pos = kittenSpot(Vector3.new(center.X, 0, center.Z), taken)
		table.insert(taken, pos)
		local kitten = makeKitten(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up"
		prompt.ObjectText = "Kitten"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = kitten.body
		prompt.Triggered:Connect(function(player)
			collectKitten(kitten, player)
		end)
		kitten.model.Parent = kittenFolder
	end
	kittensLeft = Config.KittenCount
	workspace:SetAttribute("KittensLeft", kittensLeft)
	workspace:SetAttribute("KittenDeadline", workspace:GetServerTimeNow() + Config.KittenTime)
	catEvent:FireAllClients("kittens")

	task.wait(Config.KittenTime)
	if round == myRound and kittensLeft > 0 then
		kittensLeft = 0
		umulig = false
		clearUmulig()
		kittenFolder:ClearAllChildren()
		workspace:SetAttribute("KittenDeadline", nil)
		catEvent:FireAllClients("timeUp")
		task.wait(4)
		if round == myRound then
			newRound()
		end
	end
end

local placeWildCat: (Vector3, number) -> ()

placeWildCat = function(pos: Vector3, height: number)
	local cat, prompt = spawnWildCat(pos)
	if height > 0 then
		cat.model:PivotTo(cat.model:GetPivot() + Vector3.new(0, height, 0))
		prompt.MaxActivationDistance = 6
	end
	if twist == "golden" then
		cat.collar.Color = GOLD
		cat.sparkles.SparkleColor = GOLD
		cat.tagText.Text = "Golden " .. Config.CatName .. " ✨"
	end
	wildCat = cat
	wildPrompt = prompt
	wildTween = wagTail(cat.tail)
	fleeing = false
	workspace:SetAttribute("CatPosition", pos)
	workspace:SetAttribute("Carrier", nil)
	workspace:SetAttribute("CarryEnd", nil)

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if wildCat ~= cat or fleeing or not character or not getRoot(player) then
			return
		end
		if isHardMode() then
			if wildTween then
				wildTween:Cancel()
			end
			startKittens(cat, workspace:GetAttribute("Mode") == "Umulig")
			return
		end
		local newCarried = carryCat(character, 0.6, 0)
		if not newCarried then
			return
		end
		if twist == "golden" then
			newCarried.collar.Color = GOLD
		end
		removeCat(cat)
		wildCat = nil
		carried = newCarried
		carrier = player
		workspace:SetAttribute("CatPosition", nil)
		workspace:SetAttribute("Carrier", player.UserId)
		workspace:SetAttribute("CarryEnd", workspace:GetServerTimeNow() + Config.CarryTime)
		catEvent:FireAllClients("picked", player)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Died:Once(function()
				if carrier == player then
					loseCat()
				end
			end)
		end
		player.CharacterRemoving:Once(function()
			if carrier == player then
				loseCat()
			end
		end)
		task.delay(Config.CarryTime, function()
			if carried == newCarried then
				loseCat()
			end
		end)
	end)
end

function newRound()
	if wildTween then
		wildTween:Cancel()
	end
	if homeTween then
		homeTween:Cancel()
	end
	wildTween, homeTween = nil, nil
	for player, hero in pendingHero do
		player:SetAttribute("Hero", hero)
		applyHero(player)
	end
	table.clear(pendingHero)
	removeCat(wildCat)
	removeCat(carried)
	removeCat(homeCat)
	for _, kitten in kittens do
		removeCat(kitten)
	end
	table.clear(kittens)
	kittensLeft = 0
	umulig = false
	clearUmulig()
	workspace:SetAttribute("KittensLeft", nil)
	workspace:SetAttribute("KittenDeadline", nil)
	wildCat, carried, homeCat, carrier = nil, nil, nil, nil
	round += 1

	twistFolder:ClearAllChildren()
	local roll = rng:NextNumber()
	twist = if roll < 0.35
		then nil
		elseif roll < 0.53 then "tree"
		elseif roll < 0.7 then "zoomies"
		elseif roll < 0.84 then "ratparty"
		elseif roll < 0.92 then "fullmoon"
		else "golden"
	zoomies = twist == "zoomies"
	workspace:SetAttribute("Twist", twist)

	local pos = findCatSpot()
	fleesLeft = Config.HardFlees
	workspace:SetAttribute("RoundStart", workspace:GetServerTimeNow())
	placeWildCat(pos, if twist == "tree" then buildTree(pos) else 0)
	spawnRats(pos)
	spawnFish()
	if twist then
		catEvent:FireAllClients("twist", nil, twist)
	end
end

dropCat = function(player: Player)
	local root = getRoot(player)
	local from = if root then Vector3.new(root.Position.X, 0, root.Position.Z) else home
	removeCat(carried)
	carried, carrier = nil, nil
	local spot = from
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local try = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(40, 60)
		if math.abs(try.X) < half - 15 and math.abs(try.Z) < half - 15 and (try - home).Magnitude > 50 and isFree(try, 5) then
			spot = try
			break
		end
	end
	placeWildCat(spot, 0)
	catEvent:FireAllClients("dropped", player)
end

local DataStoreService = game:GetService("DataStoreService")
local okStore, saves = pcall(function()
	return DataStoreService:GetDataStore("FindPianka1")
end)
local okBoard, ranking = pcall(function()
	return DataStoreService:GetOrderedDataStore("Rescued1")
end)
local loaded: { [Player]: boolean } = {}

local function ownedList(player: Player): { string }
	local list = {}
	for _, id in string.split((player:GetAttribute("Owned") :: string?) or "", ",") do
		if id ~= "" then
			table.insert(list, id)
		end
	end
	return list
end

local function savePlayer(player: Player)
	local stats = player:FindFirstChild("leaderstats")
	local count = stats and stats:FindFirstChild("Rescued") :: IntValue?
	local fish = stats and stats:FindFirstChild("Fish") :: IntValue?
	if not count or not fish or not loaded[player] then
		return
	end
	local key = tostring(player.UserId)
	if okStore then
		local data = {
			rescued = count.Value,
			fish = fish.Value,
			owned = ownedList(player),
			lantern = player:GetAttribute("Lantern"),
			crown = player:GetAttribute("Crown") == true,
			pet = player:GetAttribute("Pet") == true,
		}
		pcall(function()
			saves:SetAsync(key, data)
		end)
	end
	if okBoard and count.Value > 0 then
		pcall(function()
			ranking:SetAsync(key, count.Value)
		end)
	end
end

-- Shop and cosmetics
local shopEvent = Instance.new("RemoteEvent")
shopEvent.Name = "Shop"
shopEvent.Parent = ReplicatedStorage
type Pet = { cat: Cat, pos: Vector3 }
local pets: { [Player]: Pet } = {}
local lastShop: { [Player]: number } = {}

local function weldTo(root: BasePart, model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

applyCosmetics = function(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local oldCrown = character and character:FindFirstChild("Crown")
	if oldCrown then
		oldCrown:Destroy()
	end
	if character and head and player:GetAttribute("Crown") then
		local crown = Instance.new("Model")
		crown.Name = "Crown"
		local base = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.2, 0)
		local ring = makePart("Part", {
			Name = "Ring",
			Size = Vector3.new(1.3, 0.35, 1.3),
			CFrame = base,
			Color = GOLD,
			Material = Enum.Material.Metal,
			Parent = crown,
		})
		for _, offset in { Vector3.new(0.5, 0.4, 0.5), Vector3.new(-0.5, 0.4, 0.5), Vector3.new(0.5, 0.4, -0.5), Vector3.new(-0.5, 0.4, -0.5) } do
			makePart("Part", { Name = "Spike", Size = Vector3.new(0.25, 0.5, 0.25), CFrame = base * CFrame.new(offset), Color = GOLD, Material = Enum.Material.Metal, Parent = crown })
		end
		makePart("Part", { Name = "Gem", Size = Vector3.new(0.3, 0.3, 0.1), CFrame = base * CFrame.new(0, 0, -0.66), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.Neon, Parent = crown })
		weldTo(ring, crown)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = ring
		weld.Parent = ring
		ring.Anchored = false
		ring.Massless = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		crown.Parent = character
	end

	local pet = pets[player]
	if pet then
		pet.cat.model:Destroy()
		pets[player] = nil
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and player:GetAttribute("Pet") then
		local start = Vector3.new(root.Position.X + 3, 0, root.Position.Z + 3)
		local cat = makeCat(CFrame.new(start), 0.4)
		cat.model.Name = "Pet"
		cat.tagText.Text = player.DisplayName .. "'s kitten"
		local tag = cat.tagText.Parent :: BillboardGui
		tag.MaxDistance = 30
		cat.sparkles:Destroy()
		weldTo(cat.body, cat.model)
		cat.model.Parent = workspace
		pets[player] = { cat = cat, pos = start }
	end
end

shopEvent.OnServerEvent:Connect(function(player, action, id)
	local now = os.clock()
	if type(id) ~= "string" or now - (lastShop[player] or 0) < 0.3 then
		return
	end
	lastShop[player] = now
	local item = nil
	for _, entry in Config.Shop do
		if entry.id == id then
			item = entry
		end
	end
	if not item then
		return
	end
	local owned = ownedList(player)
	local has = table.find(owned, id) ~= nil
	if action == "buy" and not has then
		local stats = player:FindFirstChild("leaderstats")
		local fish = stats and stats:FindFirstChild("Fish") :: IntValue?
		if not fish or fish.Value < item.price then
			catEvent:FireClient(player, "poor")
			return
		end
		fish.Value -= item.price
		table.insert(owned, id)
		player:SetAttribute("Owned", table.concat(owned, ","))
		has = true
		action = "equip"
		catEvent:FireClient(player, "bought", nil, item.name)
	end
	if action == "equip" and has then
		if item.kind == "lantern" then
			player:SetAttribute("Lantern", if player:GetAttribute("Lantern") == id then nil else id)
		elseif item.kind == "crown" then
			player:SetAttribute("Crown", not player:GetAttribute("Crown"))
		elseif item.kind == "pet" then
			player:SetAttribute("Pet", not player:GetAttribute("Pet"))
		end
		applyHero(player)
		applyCosmetics(player)
	end
end)

local function addPlayer(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local count = Instance.new("IntValue")
	count.Name = "Rescued"
	count.Parent = stats
	local fish = Instance.new("IntValue")
	fish.Name = "Fish"
	fish.Parent = stats
	stats.Parent = player

	task.spawn(function()
		if okStore then
			local ok, data = pcall(function()
				return saves:GetAsync(tostring(player.UserId))
			end)
			if ok and type(data) == "table" then
				if type(data.rescued) == "number" then
					count.Value += data.rescued
				end
				if type(data.fish) == "number" then
					fish.Value += data.fish
				end
				if type(data.owned) == "table" then
					player:SetAttribute("Owned", table.concat(data.owned, ","))
				end
				if type(data.lantern) == "string" then
					player:SetAttribute("Lantern", data.lantern)
				end
				player:SetAttribute("Crown", data.crown == true)
				player:SetAttribute("Pet", data.pet == true)
				applyHero(player)
				applyCosmetics(player)
			end
			loaded[player] = ok
		end
	end)

	player.CharacterAdded:Connect(function(character)
		giveLantern(player, character)
	end)
	if player.Character then
		task.spawn(giveLantern, player, player.Character)
	end
end

Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

local lastCall: { [Player]: number } = {}
local lastChangeBy: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player)
	local pet = pets[player]
	if pet then
		pet.cat.model:Destroy()
		pets[player] = nil
	end
	lastBitten[player] = nil
	lastFlash[player] = nil
	lastShop[player] = nil
	task.spawn(function()
		savePlayer(player)
		loaded[player] = nil
	end)
	lastCall[player] = nil
	lastChangeBy[player] = nil
	pendingHero[player] = nil
	if carrier == player then
		loseCat()
	end
	local stack = stacks[player]
	if stack and #stack > 0 then
		failUmulig(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local cat, prompt = wildCat, wildPrompt
		if cat and prompt and not fleeing and (zoomies or (fleesLeft > 0 and isHardMode())) then
			local catPos = cat.model:GetPivot().Position
			for _, p in Players:GetPlayers() do
				local r = getRoot(p)
				local limit = if p:GetAttribute("Hero") == "Aurelia" then Config.HardFlees - 1 else 0
				if r and (zoomies or fleesLeft > limit) and (r.Position - catPos).Magnitude < Config.FleeDistance then
					zoomies = false
					task.spawn(fleeFrom, cat, prompt, p, r.Position)
					break
				end
			end
		end

		local player = carrier
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if player and root then
			local offset = root.Position - home
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < Config.HomeRadius then
				task.spawn(deliver, player)
			end
		end
	end
end)

local lastModeChange = 0
modeEvent.OnServerEvent:Connect(function(player, mode, hero)
	local now = os.clock()
	if now - (lastCall[player] or 0) < 1 then
		return
	end
	lastCall[player] = now
	local busy = carrier ~= nil or kittensLeft > 0 or homeCat ~= nil or workspace:GetAttribute("Escape") ~= nil
	if type(hero) == "string" and Config.Heroes[hero] and player:GetAttribute("Hero") ~= hero then
		if busy and player:GetAttribute("Hero") ~= nil then
			pendingHero[player] = hero
			catEvent:FireClient(player, "heroLater", nil, hero)
		else
			player:SetAttribute("Hero", hero)
			applyHero(player)
		end
	end
	if (mode == "Easy" or mode == "Normal" or mode == "Umulig") and mode ~= workspace:GetAttribute("Mode") then
		local alone = #Players:GetPlayers() <= 1
		local tooSoon = not alone and now - (lastChangeBy[player] or -math.huge) < 60
		if (busy and not alone) or tooSoon or now - lastModeChange < 5 then
			catEvent:FireClient(player, "modeLocked")
			return
		end
		lastModeChange = now
		lastChangeBy[player] = now
		workspace:SetAttribute("Mode", mode)
		catEvent:FireAllClients("mode", player, mode)
		newRound()
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		savePlayer(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do
			savePlayer(player)
		end
	end
end)

-- Leaderboard sign at camp
local board = makePart("Part", {
	Name = "Leaderboard",
	Size = Vector3.new(7, 9, 0.5),
	CFrame = CFrame.lookAt(Vector3.new(-11, 5, -3), Vector3.new(0, 5, 0)),
	Color = Color3.fromRGB(70, 50, 35),
	Material = Enum.Material.Wood,
	Parent = workspace:FindFirstChild("Camp"),
})
local boardGui = Instance.new("SurfaceGui")
boardGui.Face = Enum.NormalId.Front
boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
boardGui.Parent = board
local boardText = Instance.new("TextLabel")
boardText.Size = UDim2.fromScale(0.9, 0.92)
boardText.Position = UDim2.fromScale(0.05, 0.04)
boardText.BackgroundTransparency = 1
boardText.Font = Enum.Font.FredokaOne
boardText.TextScaled = true
boardText.TextColor3 = Color3.fromRGB(255, 220, 150)
boardText.TextYAlignment = Enum.TextYAlignment.Top
boardText.Text = "Top rescuers\n..."
boardText.Parent = boardGui

local names: { [number]: string } = {}
task.spawn(function()
	while okBoard do
		local ok, pages = pcall(function()
			return ranking:GetSortedAsync(false, 10)
		end)
		if ok then
			local lines = { "Top rescuers 🐱" }
			for i, entry in pages:GetCurrentPage() do
				local id = tonumber(entry.key) or 0
				if not names[id] then
					local got, name = pcall(function()
						return Players:GetNameFromUserIdAsync(id)
					end)
					names[id] = if got then name else "?"
				end
				table.insert(lines, i .. ". " .. names[id] .. "  " .. entry.value)
			end
			boardText.Text = table.concat(lines, "\n")
		end
		task.wait(60)
	end
end)

local function speak(n: Neighbor)
	local index = rng:NextInteger(1, #Config.Lines)
	if index == n.last then
		index = index % #Config.Lines + 1
	end
	local line = Config.Lines[index]
	n.last = index
	n.cooldown = os.clock() + line[2] + rng:NextNumber(8, 14)
	n.lineNo.Text = line[3]
	n.lineEn.Text = line[4]
	n.bubble.Enabled = true
	sayEvent:FireAllClients(n.head, index, n.pitch)
	task.delay(math.max(line[2] / n.pitch + 0.5, line[2] + 1), function()
		n.bubble.Enabled = false
	end)
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, n in neighbors do
		local pos = n.root.Position
		local target: Vector3? = nil
		local nearest = 40
		for _, player in Players:GetPlayers() do
			local root = getRoot(player)
			if root then
				local distance = (Vector3.new(root.Position.X, pos.Y, root.Position.Z) - pos).Magnitude
				if distance < nearest then
					target, nearest = Vector3.new(root.Position.X, pos.Y, root.Position.Z), distance
				end
			end
		end
		local nextPos = pos
		local face: Vector3? = nil
		if target then
			face = target
			if nearest > 7 then
				local step = pos + (target - pos).Unit * Config.NeighborSpeed * dt
				local clear = true
				for _, cabin in cabinSpots do
					if (Vector3.new(step.X, 0, step.Z) - cabin).Magnitude < 8 then
						clear = false
					end
				end
				if clear and (step - n.spot).Magnitude < 20 then
					nextPos = step
				end
			end
			if nearest < 28 and now > n.cooldown then
				speak(n)
			end
		elseif (n.spot - pos).Magnitude > 0.5 then
			nextPos = pos + (n.spot - pos).Unit * math.min((n.spot - pos).Magnitude, 4 * dt)
			face = n.spot + (n.spot - pos)
		end
		if face and (Vector3.new(face.X, pos.Y, face.Z) - nextPos).Magnitude > 0.1 then
			n.root.CFrame = CFrame.lookAt(nextPos, Vector3.new(face.X, nextPos.Y, face.Z)) * CFrame.Angles(0, 0, math.sin(now * 3) * 0.04)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if #rats == 0 then
		return
	end
	type Target = { player: Player, root: BasePart, humanoid: Humanoid, pos: Vector3 }
	local targets: { Target } = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local humanoid = root and (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			table.insert(targets, { player = player, root = root, humanoid = humanoid, pos = Vector3.new(root.Position.X, 0, root.Position.Z) })
		end
	end
	local homeFlat = Vector3.new(home.X, 0, home.Z)
	for _, rat in rats do
		if rat.deadUntil > 0 then
			if now < rat.deadUntil then
				continue
			end
			rat.deadUntil = 0
			rat.pos = rat.nest
			rat.model.Parent = ratFolder
		end
		local nearest = math.huge
		local target: Target? = nil
		local targetDistance = Config.RatAggro
		local squashed = false
		for _, t in targets do
			local distance = (t.pos - rat.pos).Magnitude
			nearest = math.min(nearest, distance)
			if distance < 2.4 and t.root.AssemblyLinearVelocity.Y < -2 and t.root.Position.Y > 3.3 then
				squash(rat, t.player)
				squashed = true
				break
			end
			local safe = (t.pos - homeFlat).Magnitude < Config.RatSafeRadius
			local inLeash = (t.pos - rat.nest).Magnitude < Config.RatLeash
			if distance < targetDistance and inLeash and not safe and t.humanoid.Health > 25 then
				target, targetDistance = t, distance
			end
		end
		if squashed or nearest > 120 then
			continue
		end

		local goal: Vector3? = nil
		local speed = 0
		if now < rat.fleeUntil then
			local away = rat.pos - rat.fleeFrom
			goal = rat.pos + (if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)) * 5
			speed = 14
		elseif target and now > rat.cooldown then
			speed = math.min(rat.speed, target.humanoid.WalkSpeed * 0.8)
			if targetDistance < 2.8 then
				speed = 0
				if rat.windup == 0 then
					rat.windup = now + 0.3
				elseif now >= rat.windup then
					rat.windup = 0
					biteBy(rat, target.player, target.humanoid)
				end
			else
				rat.windup = 0
				goal = target.pos
			end
		else
			rat.windup = 0
			if (rat.wander - rat.pos).Magnitude < 1 then
				rat.wander = rat.nest + Vector3.new(rng:NextNumber(-15, 15), 0, rng:NextNumber(-15, 15))
			end
			goal = rat.wander
			speed = 5
		end

		if goal and speed > 0 then
			local delta = goal - rat.pos
			if delta.Magnitude > 0.05 then
				local dir = delta.Unit
				local nextPos = rat.pos + dir * math.min(speed * dt, delta.Magnitude)
				for _, tree in treeSpots do
					local away = nextPos - tree
					if away.Magnitude < 2 and away.Magnitude > 0.01 then
						nextPos = tree + away.Unit * 2
					end
				end
				for _, cabin in cabinSpots do
					local away = nextPos - cabin
					if away.Magnitude < 9 and away.Magnitude > 0.01 then
						nextPos = cabin + away.Unit * 9
					end
				end
				rat.dir = dir
				rat.pos = Vector3.new(math.clamp(nextPos.X, -half + 3, half - 3), 0, math.clamp(nextPos.Z, -half + 3, half - 3))
			end
		end
		local hop = if speed > 6 then math.abs(math.sin(now * 18)) * 0.15 else 0
		local at = rat.pos + Vector3.new(0, 0.45 + hop, 0)
		rat.body.CFrame = CFrame.lookAt(at, at + rat.dir)
	end
end)

local lastRainbow = 0
RunService.Heartbeat:Connect(function(dt)
	for player, pet in pets do
		local root = getRoot(player)
		if root and pet.cat.model.Parent then
			local goal = root.CFrame * CFrame.new(2.5, 0, 3)
			local goalPos = Vector3.new(goal.X, 0, goal.Z)
			local delta = goalPos - pet.pos
			if delta.Magnitude > 60 then
				pet.pos = goalPos
			elseif delta.Magnitude > 0.3 then
				pet.pos += delta * math.min(1, dt * 5)
			end
			local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			local face = if delta.Magnitude > 0.5 then delta.Unit elseif look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
			local at = pet.pos + Vector3.new(0, 1.4 * 0.4, 0)
			pet.cat.body.CFrame = CFrame.lookAt(at, at + face)
		end
	end

	local now = os.clock()
	if now - lastRainbow < 0.1 then
		return
	end
	lastRainbow = now
	local color = Color3.fromHSV((now * 0.2) % 1, 0.6, 1)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Lantern") == "LanternRainbow" and player.Character then
			local tool = player.Character:FindFirstChild("Lantern")
			local handle = tool and tool:FindFirstChild("Handle") :: BasePart?
			local light = handle and handle:FindFirstChildOfClass("PointLight")
			if handle and light then
				handle.Color = color
				light.Color = color
			end
		end
	end
end)

newRound()
