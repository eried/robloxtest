local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local DogBrain = require(ReplicatedStorage.Shared.DogBrain)
local Sky = require(ReplicatedStorage.Shared.Sky)

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
atmosphere.Offset = 0.18
atmosphere.Color = Color3.fromRGB(190, 215, 190)
atmosphere.Decay = Color3.fromRGB(90, 120, 90)
atmosphere.Haze = 1.75
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
workspace.Terrain:Clear()
-- A flat ground part with its top exactly at 0, so nothing sinks into terrain or grass
makePart("Part", {
	Name = "Ground",
	Size = Vector3.new(Config.ForestSize + 40, 4, Config.ForestSize + 40),
	Position = Vector3.new(0, -2, 0),
	Color = Color3.fromRGB(80, 130, 55),
	Material = Enum.Material.Grass,
	TopSurface = Enum.SurfaceType.Smooth,
	Parent = workspace,
})

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

-- Vision cones
local CONE_CALM = Color3.fromRGB(255, 220, 90)
local CONE_PACK = Color3.fromRGB(255, 150, 60)
local CONE_ANGRY = Color3.fromRGB(255, 60, 50)
local CONE_HUNT = Color3.fromRGB(255, 200, 130)

local function makeCone(model: Model, root: BasePart, nose: Vector3, range: number, angle: number, color: Color3): ({ BasePart }, SpotLight)
	local cone: { BasePart } = {}
	local spread = math.rad(angle)
	local function edge(from: Vector3, to: Vector3)
		local part = makePart("Part", {
			Name = "Cone",
			Size = Vector3.new(0.18, 0.06, (to - from).Magnitude),
			CFrame = root.CFrame * CFrame.lookAt((from + to) / 2, to),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Anchored = false,
			Massless = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = model,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		table.insert(cone, part)
	end
	local left = nose + Vector3.new(-math.sin(spread), 0, -math.cos(spread)) * range
	local right = nose + Vector3.new(math.sin(spread), 0, -math.cos(spread)) * range
	edge(nose, left)
	edge(nose, right)
	edge(left, right)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = angle * 2
	light.Range = range
	light.Brightness = 2
	light.Color = color
	light.Shadows = false
	light.Parent = root
	return cone, light
end

-- Neighbors
type Neighbor = {
	model: Model,
	root: BasePart,
	head: BasePart,
	bubble: BillboardGui,
	lineNo: TextLabel,
	lineEn: TextLabel,
	spot: Vector3,
	cabin: Vector3,
	cooldown: number,
	last: number,
	pitch: number,
	pointUntil: number,
	pointAt: Vector3,
	lamp: PointLight,
	brain: DogBrain.Dog?,
	seeker: boolean,
	nextSeek: number,
	cone: { BasePart },
	light: SpotLight?,
	angry: boolean,
	sayUntil: number,
	graceUntil: number,
	holding: Player?,
	holdUntil: number,
	holdRound: number,
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

local function makeNeighbor(spot: CFrame, cabin: Vector3)
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
	local lantern = add("Lantern", Vector3.new(0.6, 0.8, 0.6), Vector3.new(1.65, -1.7, -0.4), Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
	local lamp = Instance.new("PointLight")
	lamp.Range = 14
	lamp.Brightness = 2
	lamp.Color = Color3.fromRGB(255, 190, 110)
	lamp.Enabled = false
	lamp.Parent = lantern

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
		model = model,
		root = root,
		head = head,
		bubble = bubble,
		lineNo = lineNo,
		lineEn = lineEn,
		spot = spot.Position + Vector3.new(0, 3.6, 0),
		cabin = Vector3.new(cabin.X, 0, cabin.Z),
		cooldown = 0,
		last = 0,
		pitch = rng:NextNumber(0.85, 1.05),
		pointUntil = 0,
		pointAt = Vector3.zero,
		lamp = lamp,
		brain = nil,
		seeker = false,
		nextSeek = 0,
		cone = {},
		light = nil,
		angry = false,
		sayUntil = 0,
		graceUntil = 0,
		holding = nil,
		holdUntil = 0,
		holdRound = 0,
	})
end

for _, pos in cabinSpots do
	makeNeighbor(makeCabin(pos), pos)
end

-- Lantern
local lantern = Instance.new("Tool")
lantern.Name = "Lantern"
lantern.CanBeDropped = false
lantern.GripPos = Vector3.new(0, 1, 0)
local lanternHandle = makePart("Part", {
	Name = "Handle",
	Size = Vector3.new(0.6, 0.8, 0.6),
	Color = Color3.fromRGB(255, 200, 90),
	Material = Enum.Material.Neon,
	Transparency = 0.15,
	Anchored = false,
	CanCollide = false,
	CastShadow = false,
	Massless = true,
	Parent = lantern,
})
local function lanternPart(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
	local part = makePart("Part", {
		Name = name,
		Size = size,
		CFrame = CFrame.new(offset),
		Color = color,
		Material = material,
		Anchored = false,
		CanCollide = false,
		CastShadow = false,
		Massless = true,
		Parent = lantern,
	})
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = lanternHandle
	weld.Part1 = part
	weld.Parent = part
end
local METAL = Color3.fromRGB(45, 40, 35)
lanternPart("Flame", Vector3.new(0.2, 0.3, 0.2), Vector3.new(0, -0.1, 0), Color3.fromRGB(255, 250, 210), Enum.Material.Neon)
lanternPart("Base", Vector3.new(0.85, 0.15, 0.85), Vector3.new(0, -0.47, 0), METAL, Enum.Material.Metal)
lanternPart("Cap", Vector3.new(0.85, 0.15, 0.85), Vector3.new(0, 0.47, 0), METAL, Enum.Material.Metal)
lanternPart("Roof", Vector3.new(0.5, 0.18, 0.5), Vector3.new(0, 0.62, 0), METAL, Enum.Material.Metal)
for _, x in { -0.32, 0.32 } do
	for _, z in { -0.32, 0.32 } do
		lanternPart("Post", Vector3.new(0.08, 0.8, 0.08), Vector3.new(x, 0, z), METAL, Enum.Material.Metal)
	end
	lanternPart("Loop", Vector3.new(0.07, 0.35, 0.07), Vector3.new(x * 0.6, 0.86, 0), METAL, Enum.Material.Metal)
end
lanternPart("Loop", Vector3.new(0.45, 0.07, 0.07), Vector3.new(0, 1.04, 0), METAL, Enum.Material.Metal)
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
	local now = os.clock()
	local slow = ((player:GetAttribute("SlowUntil") :: number?) or 0) > now
	local boost = ((player:GetAttribute("BoostUntil") :: number?) or 0) > now
	local muddy = player:GetAttribute("Muddy") == true
	humanoid.WalkSpeed = (if hero == "Patrick" then Config.PatrickSpeed else 16)
		* (if slow then 0.6 else 1)
		* (if muddy then 0.55 else 1)
		* (if boost then 1.5 else 1)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if ((player:GetAttribute("JumpUntil") :: number?) or 0) > now then 20 else 7.2
	local stats = player:FindFirstChild("leaderstats")
	local rescued = stats and stats:FindFirstChild("Rescued") :: IntValue?
	local saved = if rescued then rescued.Value else 0
	local title = if saved >= 100 then " 👑" elseif saved >= 25 then " 🏅" elseif saved >= 5 then " ⭐" else ""
	humanoid.DisplayName = (if type(hero) == "string" then hero else player.DisplayName) .. title
	local backpack = player:FindFirstChild("Backpack")
	local tool = character:FindFirstChild("Lantern") or (backpack and backpack:FindFirstChild("Lantern"))
	local handle = tool and tool:FindFirstChild("Handle")
	local light = handle and handle:FindFirstChildOfClass("PointLight")
	if light then
		local bright = ((player:GetAttribute("GlowUntil") :: number?) or 0) > now
		light.Range = if hero == "Milenkitka" or bright then 60 else 40
		light.Brightness = if bright then 7 elseif hero == "Milenkitka" then 5 else 3
		local color = Color3.fromRGB(255, 190, 110)
		for _, item in Config.Shop do
			if item.id == player:GetAttribute("Lantern") then
				color = item.color
			end
		end
		local off = player:GetAttribute("LightOff") == true
		light.Color = color
		light.Enabled = not off
		local glass = handle :: BasePart
		glass.Color = if off then Color3.fromRGB(60, 55, 45) else color
		glass.Material = if off then Enum.Material.Glass else Enum.Material.Neon
		for _, part in (tool :: Instance):GetChildren() do
			if part.Name == "Flame" and part:IsA("BasePart") then
				part.Transparency = if off then 1 else 0
			end
		end
	end
end

local onLanternFlash: (Player) -> ()
local applyCosmetics: (Player) -> ()

-- Each hero has a look: colors plus a cap, cat ears or a hair bun with scarf
type Look = { skin: Color3, shirt: Color3, pants: Color3 }
local LOOKS: { [string]: Look } = {
	Patrick = { skin = Color3.fromRGB(255, 205, 160), shirt = Color3.fromRGB(205, 45, 45), pants = Color3.fromRGB(45, 75, 150) },
	Aurelia = { skin = Color3.fromRGB(245, 210, 180), shirt = Color3.fromRGB(240, 120, 185), pants = Color3.fromRGB(125, 65, 150) },
	Milenkitka = { skin = Color3.fromRGB(235, 195, 165), shirt = Color3.fromRGB(40, 95, 75), pants = Color3.fromRGB(55, 50, 65) },
}

local function dressHero(player: Player)
	local character = player.Character
	local hero = player:GetAttribute("Hero")
	local look = if type(hero) == "string" then LOOKS[hero] else nil
	if not character or not look then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not head or not torso then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child.Name == "HeroLook" then
			child:Destroy()
		end
	end
	local colors = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	colors.HeadColor3 = look.skin
	colors.LeftArmColor3 = look.skin
	colors.RightArmColor3 = look.skin
	colors.TorsoColor3 = look.shirt
	colors.LeftLegColor3 = look.pants
	colors.RightLegColor3 = look.pants
	colors.Parent = character
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local name = part.Name
			part.Color = if name == "Head" or string.find(name, "Arm") or string.find(name, "Hand")
				then look.skin
				elseif string.find(name, "Leg") or string.find(name, "Foot") then look.pants
				else look.shirt
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeroLook"
	local function add(base: BasePart, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
		local part = makePart("Part", {
			Name = "Look",
			Size = size,
			Shape = shape or Enum.PartType.Block,
			CFrame = base.CFrame * offset,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Anchored = false,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			Parent = folder,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = part
	end
	local top = head.Size.Y / 2
	if hero == "Patrick" then
		add(head, Vector3.new(1.25, 0.45, 1.25), CFrame.new(0, top + 0.1, 0), Color3.fromRGB(205, 45, 45))
		add(head, Vector3.new(1.2, 0.12, 0.7), CFrame.new(0, top - 0.05, -0.85), Color3.fromRGB(205, 45, 45))
	elseif hero == "Aurelia" then
		for _, x in { -0.38, 0.38 } do
			add(head, Vector3.new(0.38, 0.5, 0.18), CFrame.new(x, top + 0.2, 0) * CFrame.Angles(0, 0, math.rad(x * -40)), Color3.fromRGB(30, 30, 35))
			add(head, Vector3.new(0.2, 0.3, 0.05), CFrame.new(x, top + 0.18, -0.1) * CFrame.Angles(0, 0, math.rad(x * -40)), Color3.fromRGB(255, 160, 200))
		end
		add(torso, Vector3.new(0.18, 0.18, 1.4), CFrame.new(0, -torso.Size.Y / 2, torso.Size.Z / 2 + 0.6) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(30, 30, 35))
	elseif hero == "Milenkitka" then
		add(head, Vector3.one * 0.7, CFrame.new(0, top, 0.45), Color3.fromRGB(95, 60, 35), Enum.PartType.Ball)
		add(head, Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, top - 0.05, 0.1), Color3.fromRGB(95, 60, 35))
		add(torso, Vector3.new(torso.Size.X + 0.2, 0.35, torso.Size.Z + 0.25), CFrame.new(0, torso.Size.Y / 2 - 0.1, 0), Color3.fromRGB(240, 190, 50))
	end
	folder.Parent = character
end

local function giveLantern(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local tool = lantern:Clone()
	tool.Parent = player:WaitForChild("Backpack")
	humanoid:EquipTool(tool)
	applyHero(player)
	applyCosmetics(player)
	dressHero(player)
	task.delay(1.5, dressHero, player)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			task.defer(dressHero, player)
		end
	end)
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

type LiveDog = {
	brain: DogBrain.Dog,
	model: Model,
	body: BasePart,
	bark: TextLabel,
	cone: { BasePart },
	light: SpotLight,
	barkUntil: number,
	angry: boolean,
}
local liveDogs: { LiveDog } = {}
local packStart = 0
local escapeCalm = 0

local function clearDogs(kind: string?)
	for i = #liveDogs, 1, -1 do
		local dog = liveDogs[i]
		if not kind or dog.brain.kind == kind then
			dog.model:Destroy()
			table.remove(liveDogs, i)
		end
	end
end

local function dogSettings(): DogBrain.Settings
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	return Config.Dogs[mode] or Config.Dogs.Easy
end

local function clearUmulig()
	if escapeConn then
		escapeConn:Disconnect()
		escapeConn = nil
	end
	clearDogs("pack")
	workspace:SetAttribute("Escape", nil)
	for player, stack in stacks do
		for _, kitten in stack do
			removeCat(kitten)
		end
		player:SetAttribute("Kittens", nil)
	end
	table.clear(stacks)
end

local roundOver = 0

local function roundActive(): boolean
	return roundOver ~= round and (wildCat ~= nil or carried ~= nil or kittensLeft > 0 or umulig)
end

local function failRound(player: Player?, kind: string)
	if roundOver == round then
		return
	end
	roundOver = round
	local myRound = round
	umulig = false
	kittensLeft = 0
	clearUmulig()
	kittenFolder:ClearAllChildren()
	if wildTween then
		wildTween:Cancel()
		wildTween = nil
	end
	removeCat(wildCat)
	removeCat(carried)
	wildCat, carried, carrier = nil, nil, nil
	for _, key in { "KittenDeadline", "KittensLeft", "CatPosition", "Carrier", "CarryEnd" } do
		workspace:SetAttribute(key, nil)
	end
	catEvent:FireAllClients(kind, player)
	task.delay(5, function()
		if round == myRound then
			newRound()
		end
	end)
end

local function failUmulig(player: Player?)
	if umulig then
		failRound(player, "caught")
	end
end

local spawnKitten: (Vector3) -> ()
local kittenSpot: (Vector3, { Vector3 }) -> Vector3

-- A player's kittens run back into the forest
local function returnKittens(player: Player)
	local stack = stacks[player]
	if not stack or #stack == 0 then
		return
	end
	local character = player.Character
	local at = if character then character:GetPivot().Position else home
	local from = Vector3.new(at.X, 0, at.Z)
	local taken: { Vector3 } = {}
	for _, kitten in stack do
		removeCat(kitten)
		local pos = kittenSpot(from, taken)
		table.insert(taken, pos)
		spawnKitten(pos)
		kittensLeft += 1
	end
	table.clear(stack)
	player:SetAttribute("Kittens", 0)
	workspace:SetAttribute("KittensLeft", kittensLeft)
	catEvent:FireAllClients("kittensBack", player)
end

local function setGhost(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = math.max(part.Transparency, 0.6)
		end
	end
end

local function resetHearts(player: Player)
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	player:SetAttribute("Hearts", Config.Hearts[mode] or 3)
	if player:GetAttribute("Out") then
		player:SetAttribute("Out", nil)
		task.spawn(function()
			pcall(function()
				player:LoadCharacterAsync()
			end)
		end)
	end
end

-- Birds Pianka leaves for you, each gives a heart back
type Bird = { model: Model, pos: Vector3 }
local birds: { Bird } = {}
local birdFolder = Instance.new("Folder")
birdFolder.Name = "Birds"
birdFolder.Parent = workspace
local BIRD_COLORS = { Color3.fromRGB(90, 140, 220), Color3.fromRGB(200, 80, 60), Color3.fromRGB(150, 110, 70), Color3.fromRGB(240, 200, 60) }

local function makeBird(pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "Bird"
	local color = BIRD_COLORS[rng:NextInteger(1, #BIRD_COLORS)]
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local base = CFrame.new(pos.X, 0.35, pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0) * CFrame.Angles(0, 0, math.pi)
	local body = makePart("Part", {
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 0.8, 0.8),
		CFrame = base,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	local function add(name: string, shape: Enum.PartType, size: Vector3, offset: CFrame, c: Color3)
		local part = makePart("Part", {
			Name = name,
			Shape = shape,
			Size = size,
			CFrame = base * offset,
			Color = c,
			Material = Enum.Material.SmoothPlastic,
			Anchored = false,
			Massless = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	add("Head", Enum.PartType.Ball, Vector3.one * 0.55, CFrame.new(0, 0.05, -0.5), color)
	add("Beak", Enum.PartType.Block, Vector3.new(0.14, 0.1, 0.26), CFrame.new(0, 0.05, -0.85), Color3.fromRGB(230, 150, 40))
	for _, angle in { 45, -45 } do
		add("Eye", Enum.PartType.Block, Vector3.new(0.18, 0.04, 0.04), CFrame.new(0, -0.22, -0.55) * CFrame.Angles(0, math.rad(angle), 0), Color3.fromRGB(20, 20, 20))
	end
	for _, x in { -0.55, 0.55 } do
		add("Wing", Enum.PartType.Block, Vector3.new(0.7, 0.06, 0.5), CFrame.new(x, 0.1, 0.05) * CFrame.Angles(0, 0, math.rad(if x > 0 then 15 else -15)), dark)
	end
	add("Tail", Enum.PartType.Block, Vector3.new(0.35, 0.06, 0.4), CFrame.new(0, 0.1, 0.55), dark)
	for _, x in { -0.12, 0.12 } do
		add("Leg", Enum.PartType.Block, Vector3.new(0.05, 0.35, 0.05), CFrame.new(x, -0.5, 0.05), Color3.fromRGB(230, 150, 40))
	end
	for i = 1, 3 do
		local feather = makePart("Part", {
			Name = "Feather",
			Size = Vector3.new(0.25, 0.04, 0.12),
			CFrame = CFrame.new(pos.X + rng:NextNumber(-1.2, 1.2), 0.05, pos.Z + rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			Color = if i == 1 then Color3.new(1, 1, 1) else dark,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = model,
		})
		feather.Anchored = true
	end
	local glow = Instance.new("PointLight")
	glow.Range = 6
	glow.Brightness = 0.6
	glow.Color = Color3.fromRGB(255, 130, 170)
	glow.Parent = body
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(30, 24)
	tag.StudsOffset = Vector3.new(0, 1.4, 0)
	tag.MaxDistance = 40
	tag.Parent = body
	local heart = Instance.new("TextLabel")
	heart.Size = UDim2.fromScale(1, 1)
	heart.BackgroundTransparency = 1
	heart.TextScaled = true
	heart.Text = "❤️"
	heart.Parent = tag
	model.PrimaryPart = body
	model.Parent = birdFolder
	table.insert(birds, { model = model, pos = Vector3.new(pos.X, 0, pos.Z) })
end

-- A trail of birds from camp toward Pianka
local function spawnBirds(catPos: Vector3)
	birdFolder:ClearAllChildren()
	table.clear(birds)
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	local count = Config.BirdCount[mode] or 3
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Hero") == "Aurelia" then
			count += 2
			break
		end
	end
	for i = 1, count do
		local along = 0.3 + 0.55 * (i - 0.5) / count
		for _ = 1, 30 do
			local try = home:Lerp(catPos, along + rng:NextNumber(-0.04, 0.04)) + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
			try = Vector3.new(try.X, 0, try.Z)
			if math.abs(try.X) < half - 10 and math.abs(try.Z) < half - 10 and (try - home).Magnitude > Config.RatSafeRadius and isFree(try, 3) then
				makeBird(try)
				break
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
		local max = Config.Hearts[mode] or 3
		for i = #birds, 1, -1 do
			local bird = birds[i]
			for _, p in Players:GetPlayers() do
				local r = getRoot(p)
				if r and not p:GetAttribute("Out") and (Vector3.new(r.Position.X, 0, r.Position.Z) - bird.pos).Magnitude < 5 then
					local hearts = (p:GetAttribute("Hearts") :: number?) or max
					if hearts < max then
						p:SetAttribute("Hearts", hearts + 1)
						bird.model:Destroy()
						table.remove(birds, i)
						catEvent:FireClient(p, "bird", nil, hearts + 1)
						break
					end
				end
			end
		end
	end
end)

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
	if #birds < 8 then
		makeBird(catPos)
	end
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
local dropCat: (Player, string?) -> ()
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
	local radius = if player:GetAttribute("Hero") == "Milenkitka" then 30 else 20
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
			local root = player and getRoot(player)
			if not player or not root or (root.Position - fish.Position).Magnitude > 10 then
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

local mushroomFolder = Instance.new("Folder")
mushroomFolder.Name = "Mushrooms"
mushroomFolder.Parent = workspace
local mudFolder = Instance.new("Folder")
mudFolder.Name = "Mud"
mudFolder.Parent = workspace
local mudSpots: { { pos: Vector3, radius: number } } = {}

local POWERS = {
	{ kind = "speed", color = Color3.fromRGB(90, 170, 255), attribute = "BoostUntil", time = 6 },
	{ kind = "bright", color = Color3.fromRGB(255, 220, 70), attribute = "GlowUntil", time = 10 },
	{ kind = "jump", color = Color3.fromRGB(255, 120, 200), attribute = "JumpUntil", time = 8 },
}

local function spawnMushrooms()
	mushroomFolder:ClearAllChildren()
	local myRound = round
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	for i = 1, Config.MushroomCount[mode] or 6 do
		local power = POWERS[(i - 1) % #POWERS + 1]
		local pos = randomSpot(15)
		for _ = 1, 20 do
			if (pos - home).Magnitude > 30 and isFree(pos, 4) then
				break
			end
			pos = randomSpot(15)
		end
		local model = Instance.new("Model")
		model.Name = "Mushroom"
		makePart("Part", {
			Name = "Stem",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 0.7, 0.7),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(240, 235, 220),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		local cap = makePart("Part", {
			Name = "Cap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			Position = pos + Vector3.new(0, 1.6, 0),
			Color = power.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Range = 10
		light.Brightness = 1.5
		light.Color = power.color
		light.Shadows = false
		light.Parent = cap
		model.Parent = mushroomFolder
		local taken = false
		local function touched(hit: BasePart)
			local player = if taken then nil else playerFromHit(hit)
			local root = player and getRoot(player)
			if not player or not root or (root.Position - cap.Position).Magnitude > 8 then
				return
			end
			taken = true
			model.Parent = nil
			player:SetAttribute(power.attribute, os.clock() + power.time)
			applyHero(player)
			task.delay(power.time + 0.1, applyHero, player)
			catEvent:FireClient(player, "power", nil, power.kind)
			task.delay(45, function()
				if round == myRound then
					taken = false
					model.Parent = mushroomFolder
				else
					model:Destroy()
				end
			end)
		end
		cap.Touched:Connect(touched)
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part ~= cap then
				part.Touched:Connect(touched)
			end
		end
	end
end

local function spawnMud(catPos: Vector3)
	mudFolder:ClearAllChildren()
	table.clear(mudSpots)
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	for _ = 1, Config.MudCount[mode] or 8 do
		for _ = 1, 20 do
			local pos = randomSpot(15)
			local radius = rng:NextNumber(6, 10)
			if (pos - home).Magnitude > Config.RatSafeRadius + radius and (pos - catPos).Magnitude > radius + 8 and isFree(pos, radius * 0.6) then
				makePart("Part", {
					Name = "Mud",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.3, radius * 2, radius * 2),
					CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					Color = Color3.fromRGB(85, 60, 40),
					Material = Enum.Material.Mud,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					CastShadow = false,
					Parent = mudFolder,
				})
				table.insert(mudSpots, { pos = pos, radius = radius })
				break
			end
		end
	end
end

local hideInBushes: (Vector3) -> ()

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
	for _, friend in Players:GetPlayers() do
		local root = getRoot(friend)
		if friend ~= player and root and (root.Position - home).Magnitude < 40 then
			giveFish(friend, Config.TeamBonus)
		end
	end
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

kittenSpot = function(center: Vector3, taken: { Vector3 }): Vector3
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

local function makeDog(pos: Vector3, range: number, angle: number, coneColor: Color3): (Model, TextLabel, { BasePart }, SpotLight)
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

	local cone, light = makeCone(dog, body, Vector3.new(0, -1.78, -3.4), range, angle, coneColor)

	dog.Parent = dogFolder
	return dog, bark, cone, light
end

local function addDog(brain: DogBrain.Dog, range: number, angle: number)
	local color = if brain.kind == "pack" then CONE_PACK else CONE_CALM
	local model, bark, cone, light = makeDog(brain.pos, range, angle, color)
	table.insert(liveDogs, {
		brain = brain,
		model = model,
		body = model.PrimaryPart :: BasePart,
		bark = bark,
		cone = cone,
		light = light,
		barkUntil = 0,
		angry = false,
	})
end

local brainWorld: DogBrain.World = { trees = treeSpots, cabins = cabinSpots, half = half }
DogBrain.index(brainWorld)

local function spawnPatrols(catPos: Vector3)
	clearDogs()
	local s = dogSettings()
	local paths = DogBrain.patrolPaths(function(a: number, b: number): number
		return rng:NextNumber(a, b)
	end, brainWorld, catPos, home, s.patrolCount, Config.RatSafeRadius)
	for _, path in paths do
		local brain = DogBrain.newPatrol(path.a, path.b)
		brain.pos = path.a:Lerp(path.b, rng:NextNumber())
		addDog(brain, s.coneRange, s.coneAngle)
	end
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

	local s = dogSettings()
	local slots = DogBrain.formation(s.packCount)
	for i, slot in slots do
		local runner = runners[(i - 1) % #runners + 1]
		local root = getRoot(runner)
		local center = if root then Vector3.new(root.Position.X, 0, root.Position.Z) else Vector3.new(home.X, 0, home.Z)
		local toHome = Vector3.new(home.X, 0, home.Z) - center
		local heading = if toHome.Magnitude > 1 then toHome.Unit else Vector3.new(0, 0, -1)
		local right = Vector3.new(-heading.Z, 0, heading.X)
		local pos = center - heading * (s.packGap + 6 + slot.back) + right * slot.side
		pos = Vector3.new(math.clamp(pos.X, -half + 5, half - 5), 0, math.clamp(pos.Z, -half + 5, half - 5))
		addDog(DogBrain.newPack(pos, slot.side, slot.back, runner.UserId), s.packConeRange, s.coneAngle)
	end
	packStart = os.clock()
	escapeCalm = packStart + 3
	for _, dog in liveDogs do
		if dog.brain.kind == "patrol" and (dog.brain.state == "alert" or dog.brain.state == "chase") then
			dog.brain.state = "return"
			dog.brain.untilTime = packStart + 3
		end
	end

	local delivered = 0
	local finished = false
	escapeConn = RunService.Heartbeat:Connect(function()
		if finished or round ~= myRound then
			return
		end
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
						clearDogs("pack")
						workspace:SetAttribute("Escape", nil)
						catEvent:FireAllClients("escaped", player, seconds)
						giveFish(player, Config.Reward.Umulig * (if twist == "golden" then 2 else 1))
						fireworks()
						task.delay(8, function()
							if round == myRound then
								newRound()
							end
						end)
						return
					end
				end
			end
		end
	end)
end

local function collectKitten(kitten: Cat, player: Player)
	if kitten.model.Parent ~= kittenFolder or kittensLeft <= 0 or player:GetAttribute("Out") then
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
	giveFish(player, Config.Reward.Kitten * (if twist == "golden" then 2 else 1))
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

spawnKitten = function(pos: Vector3)
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
		spawnKitten(pos)
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
		if wildCat ~= cat or fleeing or not character or not getRoot(player) or player:GetAttribute("Out") then
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
	twist = if roll < 0.3
		then nil
		elseif roll < 0.44 then "tree"
		elseif roll < 0.58 then "bushes"
		elseif roll < 0.71 then "zoomies"
		elseif roll < 0.83 then "ratparty"
		elseif roll < 0.92 then "fullmoon"
		else "golden"
	if (twist == "tree" or twist == "bushes") and isHardMode() then
		twist = nil
	end
	zoomies = twist == "zoomies"
	workspace:SetAttribute("Twist", twist)

	for _, player in Players:GetPlayers() do
		resetHearts(player)
	end
	local pos = findCatSpot()
	fleesLeft = Config.HardFlees
	workspace:SetAttribute("RoundStart", workspace:GetServerTimeNow())
	placeWildCat(pos, if twist == "tree" then buildTree(pos) else 0)
	spawnRats(pos)
	spawnPatrols(pos)
	spawnFish()
	spawnMushrooms()
	spawnBirds(pos)
	spawnMud(pos)
	if twist == "bushes" then
		hideInBushes(pos)
	end
	if twist then
		catEvent:FireAllClients("twist", nil, twist)
	end
end

hideInBushes = function(catPos: Vector3)
	local cat = wildCat
	if not cat then
		return
	end
	cat.model.Parent = nil
	local spots = { catPos }
	for _ = 1, 80 do
		if #spots >= 5 then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local try = catPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(10, 24)
		local ok = math.abs(try.X) < half - 10 and math.abs(try.Z) < half - 10 and isFree(try, 3)
		for _, other in spots do
			if (other - try).Magnitude < 7 then
				ok = false
			end
		end
		if ok then
			table.insert(spots, try)
		end
	end
	local surprises = { "frog", "confetti", "rat", "frog" }
	for i, spot in spots do
		local bush = makePart("Part", {
			Name = "ShakyBush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6,
			Position = spot + Vector3.new(0, 2, 0),
			Color = Color3.fromRGB(70, 140, 60),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = twistFolder,
		})
		TweenService:Create(bush, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			CFrame = bush.CFrame * CFrame.Angles(0, 0, math.rad(6)),
		}):Play()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Search"
		prompt.ObjectText = "Bush"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = bush
		local real = i == 1
		local surprise = surprises[(i - 2) % #surprises + 1]
		prompt.Triggered:Connect(function(player)
			if not bush.Parent or player:GetAttribute("Out") then
				return
			end
			bush:Destroy()
			if real then
				if wildCat == cat then
					cat.model.Parent = workspace
				end
				catEvent:FireAllClients("bush", player, "found")
			else
				catEvent:FireClient(player, "bush", player, surprise)
				if surprise == "rat" then
					local model, body, bubble = makeRat(spot)
					table.insert(rats, {
						model = model,
						body = body,
						bubble = bubble,
						nest = spot,
						pos = spot,
						dir = Vector3.new(0, 0, -1),
						wander = spot,
						cooldown = os.clock() + 1,
						windup = 0,
						fleeUntil = 0,
						fleeFrom = spot,
						deadUntil = 0,
						speed = Config.RatSpeed.Easy,
					})
				elseif surprise == "confetti" then
					giveFish(player, 2)
				end
			end
		end)
	end
end

dropCat = function(player: Player, by: string?)
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
	catEvent:FireAllClients("dropped", player, by or "rats")
end

local function loseHeart(player: Player, all: boolean?)
	if not roundActive() or player:GetAttribute("Out") then
		return
	end
	local hearts = if all then 0 else math.max(((player:GetAttribute("Hearts") :: number?) or 1) - 1, 0)
	player:SetAttribute("Hearts", hearts)
	catEvent:FireClient(player, "heart", nil, hearts)
	if hearts > 0 then
		return
	end
	player:SetAttribute("Out", true)
	setGhost(player)
	catEvent:FireAllClients("out", player)
	returnKittens(player)
	for _, other in Players:GetPlayers() do
		if not other:GetAttribute("Out") then
			return
		end
	end
	failRound(player, "hearts")
end

-- A dog or a neighbor caught a player
local lastCaught: { [Player]: number } = {}
local function caughtBy(player: Player, from: Vector3, by: string)
	local stack = stacks[player]
	if workspace:GetAttribute("Escape") and stack and #stack > 0 then
		failUmulig(player)
		return
	end
	if os.clock() - (lastCaught[player] or -10) < 2.5 then
		return
	end
	lastCaught[player] = os.clock()
	local root = getRoot(player)
	if root then
		player:SetAttribute("SlowUntil", os.clock() + 2)
		applyHero(player)
		task.delay(2.1, applyHero, player)
		local away = Vector3.new(root.Position.X, 0, root.Position.Z) - from
		catEvent:FireClient(player, if by == "dog" then "dogbite" else "grabbed", nil, if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1))
	end
	if carrier == player then
		dropCat(player, by)
	end
	loseHeart(player)
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
local flashEvent = Instance.new("RemoteEvent")
flashEvent.Name = "Flash"
flashEvent.Parent = ReplicatedStorage
local lastToggle: { [Player]: number } = {}
flashEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (lastToggle[player] or 0) < 0.25 or player:GetAttribute("Held") then
		return
	end
	lastToggle[player] = now
	local off = not (player:GetAttribute("LightOff") == true)
	player:SetAttribute("LightOff", off)
	applyHero(player)
	if not off then
		onLanternFlash(player)
	end
end)
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
	count:GetPropertyChangedSignal("Value"):Connect(function()
		applyHero(player)
	end)
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

	player:SetAttribute("Hearts", Config.Hearts[(workspace:GetAttribute("Mode") :: string?) or "Easy"] or 3)
	player:GetAttributeChangedSignal("Hero"):Connect(function()
		dressHero(player)
	end)
	player.CharacterAdded:Connect(function(character)
		giveLantern(player, character)
		if player:GetAttribute("Out") then
			task.defer(setGhost, player)
		end
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
	lastCaught[player] = nil
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
	local anyone = false
	local everyoneOut = true
	for _, other in Players:GetPlayers() do
		if other ~= player then
			anyone = true
			everyoneOut = everyoneOut and other:GetAttribute("Out") == true
		end
	end
	if anyone and everyoneOut and roundActive() then
		failRound(nil, "hearts")
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		local cat, prompt = wildCat, wildPrompt
		if cat and prompt and not fleeing and (zoomies or (fleesLeft > 0 and isHardMode())) then
			local catPos = cat.model:GetPivot().Position
			for _, p in Players:GetPlayers() do
				local r = if p:GetAttribute("Out") then nil else getRoot(p)
				local limit = if p:GetAttribute("Hero") == "Aurelia" then Config.HardFlees - 1 else 0
				if r and (zoomies or fleesLeft > limit) and (r.Position - catPos).Magnitude < Config.FleeDistance then
					zoomies = false
					task.spawn(fleeFrom, cat, prompt, p, r.Position)
					break
				end
			end
		end

		for _, p in Players:GetPlayers() do
			local r = getRoot(p)
			local inMud = false
			if r then
				for _, puddle in mudSpots do
					if (Vector3.new(r.Position.X, 0, r.Position.Z) - puddle.pos).Magnitude < puddle.radius and r.Position.Y < 11 then
						inMud = true
						break
					end
				end
			end
			if (p:GetAttribute("Muddy") == true) ~= inMud then
				p:SetAttribute("Muddy", inMud)
				applyHero(p)
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
	local catPos = workspace:GetAttribute("CatPosition") :: Vector3?
	if catPos and rng:NextNumber() < 0.35 then
		n.cooldown = os.clock() + rng:NextNumber(10, 16)
		n.pointUntil = os.clock() + 4
		n.pointAt = Vector3.new(catPos.X, n.root.Position.Y, catPos.Z)
		n.lineNo.Text = "Katten gikk den veien! 👉"
		n.lineEn.Text = "The cat went that way!"
		n.bubble.Enabled = true
		task.delay(4, function()
			n.bubble.Enabled = false
		end)
		return
	end
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

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	for _, n in neighbors do
		if n.brain then
			continue
		end
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
		if now < n.pointUntil then
			face = n.pointAt
		elseif target then
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
			nextPos = pos + (n.spot - pos).Unit * math.min((n.spot - pos).Magnitude, 6 * dt)
			face = n.spot + (n.spot - pos)
		end
		if face and (Vector3.new(face.X, pos.Y, face.Z) - nextPos).Magnitude > 0.1 then
			n.root.CFrame = CFrame.lookAt(nextPos, Vector3.new(face.X, nextPos.Y, face.Z)) * CFrame.Angles(0, 0, math.sin(now * 3) * 0.04)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	if #rats == 0 then
		return
	end
	type Target = { player: Player, root: BasePart, humanoid: Humanoid, pos: Vector3 }
	local targets: { Target } = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local humanoid = root and (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
		if root and humanoid and not player:GetAttribute("Out") then
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
			if distance < 2.4 and t.root.AssemblyLinearVelocity.Y < -2 and t.root.Position.Y > 3.3 and t.root.Position.Y < 8 then
				squash(rat, t.player)
				squashed = true
				break
			end
			local safe = (t.pos - homeFlat).Magnitude < Config.RatSafeRadius
			local inLeash = (t.pos - rat.nest).Magnitude < Config.RatLeash
			if distance < targetDistance and inLeash and not safe and t.humanoid.Health > 25 and t.root.Position.Y < 5.5 then
				target, targetDistance = t, distance
			end
		end
		if squashed or nearest > 120 then
			continue
		end

		local goal: Vector3? = nil
		local speed = 0
		if target and ((target.player:GetAttribute("GlowUntil") :: number?) or 0) > now then
			rat.fleeUntil = now + 1
			rat.fleeFrom = target.pos
		end
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
RunService.Heartbeat:Connect(function(dt: number)
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
		if player:GetAttribute("Lantern") == "LanternRainbow" and player:GetAttribute("LightOff") ~= true and player.Character then
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

local headings: { [Player]: { pos: Vector3, heading: Vector3 } } = {}

local function onDogEvent(dog: LiveDog, event: string, player: Player?, now: number)
	if event == "alert" then
		dog.bark.Text = "!"
		dog.barkUntil = now + 0.8
		if player then
			catEvent:FireClient(player, "spotted")
		end
	elseif event == "chase" or event == "lunge" then
		dog.bark.Text = "WOOF!"
		dog.barkUntil = now + 1
		if player and event == "lunge" then
			catEvent:FireClient(player, "lunge")
		end
	elseif event == "caught" and player then
		dog.bark.Text = "WOOF!"
		dog.barkUntil = now + 1
		caughtBy(player, dog.brain.pos, "dog")
	end
end

local function collectRunners(): ({ DogBrain.Runner }, { [number]: Player })
	local homeFlat = Vector3.new(home.X, 0, home.Z)
	local dayStart = (workspace:GetAttribute("DayStart") :: number?) or 0
	local _, daylight = Sky.at(workspace:GetServerTimeNow() - dayStart, Config.DayMinutes, Config.NightShare)
	local night = daylight < 0.5
	local runners: { DogBrain.Runner } = {}
	local byId: { [number]: Player } = {}
	for _, player in Players:GetPlayers() do
		local root = getRoot(player)
		local humanoid = root and (root.Parent :: Model):FindFirstChildOfClass("Humanoid")
		if root and humanoid and not player:GetAttribute("Out") then
			local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
			local track = headings[player]
			local heading = if track then track.heading else Vector3.new(0, 0, -1)
			if track and (pos - track.pos).Magnitude > 0.05 then
				heading = (pos - track.pos).Unit
			end
			headings[player] = { pos = pos, heading = heading }
			local calm = if player:GetAttribute("Hero") == "Milenkitka" then 0.92 else 1
			table.insert(runners, {
				id = player.UserId,
				pos = pos,
				heading = heading,
				speed = humanoid.WalkSpeed * calm,
				safe = (pos - homeFlat).Magnitude < Config.RatSafeRadius or root.Position.Y > 7 or player:GetAttribute("Held") == true,
				hidden = night and player:GetAttribute("LightOff") == true,
			})
			byId[player.UserId] = player
		end
	end
	for player in headings do
		if not player.Parent then
			headings[player] = nil
		end
	end
	return runners, byId
end

RunService.Heartbeat:Connect(function(dt: number)
	if #liveDogs == 0 then
		return
	end
	local now = os.clock()
	local s = dogSettings()
	local runners, byId = collectRunners()
	local gap = DogBrain.gap(s, now - packStart)
	for _, dog in table.clone(liveDogs) do
		if not dog.model.Parent then
			continue
		end
		local event, id = DogBrain.step(dog.brain, dt, now, runners, brainWorld, s, gap)
		if event then
			onDogEvent(dog, event, if id then byId[id] else nil, now)
			if not dog.model.Parent then
				continue
			end
		end
		local state = dog.brain.state
		local angry = state == "alert" or state == "chase" or state == "lunge"
		if angry ~= dog.angry then
			dog.angry = angry
			local color = if angry then CONE_ANGRY elseif dog.brain.kind == "pack" then CONE_PACK else CONE_CALM
			for _, part in dog.cone do
				part.Color = color
			end
			dog.light.Color = color
		end
		dog.bark.Visible = now < dog.barkUntil
		local fast = state == "chase" or state == "lunge"
		local moving = state ~= "turn" and state ~= "alert" and state ~= "rest"
		local hop = if moving then math.abs(math.sin(now * (if fast then 14 else 8))) * (if fast then 0.4 else 0.15) else 0
		local at = dog.brain.pos + Vector3.new(0, 1.9 + hop, 0)
		dog.body.CFrame = CFrame.lookAt(at, at + dog.brain.dir)
	end
end)


-- Neighbors hunt at night
local NEIGHBOR_NOSE = Vector3.new(0, -3.45, -1)
local hunting = false
local huntMode = ""

local function rnd(a: number, b: number): number
	return rng:NextNumber(a, b)
end

local function hunterSettings(): DogBrain.Settings
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	return DogBrain.with(dogSettings(), Config.Hunters[mode] or Config.Hunters.Easy)
end

local function neighborSay(n: Neighbor, line: { string }, seconds: number)
	n.lineNo.Text = line[1]
	n.lineEn.Text = line[2]
	n.bubble.Enabled = true
	n.sayUntil = os.clock() + seconds
end

local function dropCone(n: Neighbor)
	for _, part in n.cone do
		part:Destroy()
	end
	n.cone = {}
	if n.light then
		n.light:Destroy()
		n.light = nil
	end
end

local function startHunt(now: number, mode: string, announce: boolean)
	local s = hunterSettings()
	local hunters: { Neighbor } = {}
	for _, n in neighbors do
		dropCone(n)
		n.brain = nil
		n.seeker = false
		local path = DogBrain.yardPath(rnd, brainWorld, n.cabin, home, Config.RatSafeRadius)
		if path then
			local brain = DogBrain.newPatrol(path.a, path.b)
			brain.pos = Vector3.new(n.root.Position.X, 0, n.root.Position.Z)
			brain.state = "return"
			brain.untilTime = now + 2
			n.brain = brain
			n.nextSeek = now + rng:NextNumber(8, 8 + Config.SeekEvery)
			n.angry = false
			n.cone, n.light = makeCone(n.model, n.root, NEIGHBOR_NOSE, s.coneRange, s.coneAngle, CONE_HUNT)
			n.lamp.Enabled = true
			n.model:SetAttribute("Hunting", true)
			table.insert(hunters, n)
		end
	end
	for i = #hunters, 2, -1 do
		local j = rng:NextInteger(1, i)
		hunters[i], hunters[j] = hunters[j], hunters[i]
	end
	for i = 1, math.min(Config.Seekers[mode] or 1, #hunters) do
		hunters[i].seeker = true
	end
	if announce then
		catEvent:FireAllClients("hunt")
	end
end

-- A neighbor catches you: he holds you up, then you are out
local function releaseHeld(n: Neighbor)
	local player = n.holding
	n.holding = nil
	if not player then
		return
	end
	player:SetAttribute("Held", nil)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
		root.CFrame = CFrame.new(home + Vector3.new(rng:NextNumber(-4, 4), 3, rng:NextNumber(-4, 4)))
	end
	if player.Parent and round == n.holdRound then
		loseHeart(player, true)
	end
end

local function grabbedBy(n: Neighbor, player: Player)
	if player:GetAttribute("Held") or player:GetAttribute("Out") or n.holding then
		return
	end
	local root = getRoot(player)
	if not root then
		return
	end
	neighborSay(n, Config.Grab, 3)
	sayEvent:FireAllClients(n.head, 4, n.pitch)
	if carrier == player then
		dropCat(player, "neighbor")
	end
	player:SetAttribute("Held", true)
	root.Anchored = true
	n.holding = player
	n.holdUntil = os.clock() + 3
	n.holdRound = round
	catEvent:FireAllClients("held", player, n.head)
	local stack = stacks[player]
	if workspace:GetAttribute("Escape") and stack and #stack > 0 then
		failUmulig(player)
	end
end

local function stopHunt(announce: boolean)
	for _, n in neighbors do
		releaseHeld(n)
		dropCone(n)
		n.brain = nil
		n.lamp.Enabled = false
		n.bubble.Enabled = false
		n.model:SetAttribute("Hunting", nil)
	end
	if announce then
		catEvent:FireAllClients("dawn")
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	local now = os.clock()
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Easy"
	local dayStart = (workspace:GetAttribute("DayStart") :: number?) or 0
	local _, daylight = Sky.at(workspace:GetServerTimeNow() - dayStart, Config.DayMinutes, Config.NightShare)
	local want = Config.HuntByDay[mode] == true or daylight < 0.5
	if want and (not hunting or huntMode ~= mode) then
		local announce = not hunting
		hunting, huntMode = true, mode
		startHunt(now, mode, announce)
	elseif not want and hunting then
		hunting = false
		stopHunt(daylight >= 0.5 and Config.HuntByDay[huntMode] ~= true)
	end
	if not hunting then
		return
	end
	local s = hunterSettings()
	local runners, byId = collectRunners()
	for _, n in neighbors do
		local held = n.holding
		if held then
			local character = held.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if now >= n.holdUntil or not held.Parent or not root then
				releaseHeld(n)
			else
				root.CFrame = n.root.CFrame * CFrame.new(0, 0.8, -2.2) * CFrame.Angles(0, math.pi, 0)
				continue
			end
		end
		local brain = n.brain
		if not brain then
			continue
		end
		local escaping = workspace:GetAttribute("Escape") ~= nil
		if escaping and now < escapeCalm and (brain.state == "alert" or brain.state == "chase") then
			brain.state = "return"
			brain.untilTime = escapeCalm
		end
		if n.seeker and not escaping and now >= n.nextSeek and (brain.state == "patrol" or brain.state == "turn") then
			n.nextSeek = now + Config.SeekEvery
			local target: DogBrain.Runner? = nil
			for _, r in runners do
				if not r.safe and (not target or (r.pos - brain.pos).Magnitude < (target.pos - brain.pos).Magnitude) then
					target = r
				end
			end
			local path = target and DogBrain.huntPath(rnd, brainWorld, target.pos, target.heading, home, Config.RatSafeRadius)
			if path then
				brain.a, brain.b = path.a, path.b
				brain.state = "return"
				brain.untilTime = now
				if (brain.pos - path.a).Magnitude > 60 then
					brain.pos = path.a
					n.graceUntil = now + 1
				end
			end
		end
		local event, id = DogBrain.step(brain, dt, now, if now < n.graceUntil then {} else runners, brainWorld, s, 0)
		local player = if id then byId[id] else nil
		if event == "alert" then
			neighborSay(n, Config.Hunt, 2)
			sayEvent:FireAllClients(n.head, 1, n.pitch)
			if player then
				catEvent:FireClient(player, "hunted")
			end
		elseif event == "chase" then
			neighborSay(n, Config.Chase, 2)
		elseif event == "caught" and player then
			grabbedBy(n, player)
		end
		if not n.brain then
			continue
		end
		if now > n.sayUntil then
			n.bubble.Enabled = false
		end
		local angry = brain.state == "alert" or brain.state == "chase"
		if angry ~= n.angry then
			n.angry = angry
			local color = if angry then CONE_ANGRY else CONE_HUNT
			for _, part in n.cone do
				part.Color = color
			end
			if n.light then
				n.light.Color = color
			end
		end
		local moving = brain.state ~= "turn" and brain.state ~= "alert"
		local bob = if moving then math.abs(math.sin(now * (if brain.state == "chase" then 12 else 6))) * 0.12 else 0
		local at = Vector3.new(brain.pos.X, n.spot.Y + bob, brain.pos.Z)
		n.root.CFrame = CFrame.lookAt(at, at + brain.dir)
	end
end)

newRound()
