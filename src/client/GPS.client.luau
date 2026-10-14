local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sky = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sky"))
local catEvent = ReplicatedStorage:WaitForChild("PiankaEvent") :: RemoteEvent
local modeEvent = ReplicatedStorage:WaitForChild("SetMode") :: RemoteEvent
local shopEvent = ReplicatedStorage:WaitForChild("Shop") :: RemoteEvent
local sayEvent = ReplicatedStorage:WaitForChild("NeighborSay") :: RemoteEvent
local flashEvent = ReplicatedStorage:WaitForChild("Flash") :: RemoteEvent
local boneEvent = ReplicatedStorage:WaitForChild("ThrowBone") :: RemoteEvent
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GREEN = Color3.fromRGB(90, 220, 110)
local PANEL = Color3.fromRGB(35, 40, 35)
local FONT = Enum.Font.FredokaOne
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function new(class: string, props: { [string]: any }): any
	local obj = Instance.new(class)
	for key, value in props do
		if key ~= "Parent" then
			(obj :: any)[key] = value
		end
	end
	obj.Parent = props.Parent
	return obj
end

local function round(parent: Instance, radius: UDim)
	new("UICorner", { CornerRadius = radius, Parent = parent })
end

local function outline(parent: Instance, thickness: number): UIStroke
	return new("UIStroke", { Color = GREEN, Thickness = thickness, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local gui = new("ScreenGui", {
	Name = "GPS",
	ResetOnSpawn = false,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Full screen layers that also cover the notch area on phones
local function layer(name: string, order: number): ScreenGui
	return new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false,
		DisplayOrder = order,
		Parent = player:WaitForChild("PlayerGui"),
	})
end
local backLayer = layer("Shade", -1)
local frontLayer = layer("Cover", 10)

-- GPS device
local device = new("Frame", {
	AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1),
	Position = if touch then UDim2.new(1, -10, 0, 10) else UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(200, 260),
	BackgroundColor3 = PANEL,
	Parent = gui,
})
round(device, UDim.new(0, 18))
outline(device, 3)
if touch then
	new("UIScale", { Scale = 0.7, Parent = device })
end

new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 28),
	Position = UDim2.fromOffset(0, 4),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 22,
	TextColor3 = GREEN,
	Text = "GPS",
	Parent = device,
})

local RADAR = 170
local RADAR_COLOR = Color3.fromRGB(15, 45, 22)
local radar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(RADAR, RADAR),
	BackgroundColor3 = RADAR_COLOR,
	Parent = device,
})
round(radar, UDim.new(1, 0))

for _, scale in { 0.33, 0.66 } do
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale),
		BackgroundTransparency = 1,
		Parent = radar,
	})
	round(ring, UDim.new(1, 0))
	new("UIStroke", { Color = GREEN, Transparency = 0.6, Parent = ring })
end

new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "▲",
	ZIndex = 3,
	Parent = radar,
})

local catDot = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1,
	TextSize = 24,
	Text = "🐱",
	ZIndex = 4,
	Parent = radar,
})

local distanceLabel = new("TextLabel", {
	Position = UDim2.new(0, 8, 1, -50),
	Size = UDim2.new(1, -16, 0, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	Parent = device,
})

local hintLabel = new("TextLabel", {
	Position = UDim2.new(0, 0, 1, -28),
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = GREEN,
	Text = "",
	Parent = device,
})

-- Sounds
local beep = new("Sound", {
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.3,
	Parent = gui,
})

local function chime()
	for i, speed in { 1, 1.26, 1.5, 2 } do
		task.delay((i - 1) * 0.1, function()
			local note = beep:Clone()
			note.PlaybackSpeed = speed
			note.Parent = gui
			note:Play()
			note.Ended:Once(function()
				note:Destroy()
			end)
		end)
	end
end

local music = new("Sound", {
	SoundId = if Config.MusicId ~= 0 then "rbxassetid://" .. Config.MusicId else "",
	Looped = true,
	Volume = 0.5,
	Parent = SoundService,
})
local musicOn = Config.MusicId ~= 0

local clipSound: Sound? = nil
if Config.SoundsId ~= 0 then
	local sound = new("Sound", { SoundId = "rbxassetid://" .. Config.SoundsId, Parent = SoundService })
	clipSound = sound
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound })
	end)
end

local voiceSound: Sound? = nil
if Config.VoicesId ~= 0 then
	local sound = new("Sound", { SoundId = "rbxassetid://" .. Config.VoicesId, Parent = SoundService })
	voiceSound = sound
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound })
	end)
end

local function playClip(parent: Instance, clip: { any }, volume: number, speed: number, range: number, source: Sound?)
	local from = source or clipSound
	if not from then
		return
	end
	local sound = from:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = range
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	task.delay(clip[2] / speed + 2, function()
		sound:Destroy()
	end)
end

-- Top bar
local function topButton(text: string, x: number, width: number): TextButton
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, x, 0, 10),
		Size = UDim2.fromOffset(width, 40),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.2,
		Font = FONT,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		Parent = gui,
	})
	round(button, UDim.new(0, 12))
	return button
end

local timerLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(140, 40),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.2,
	Font = FONT,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "⏱ 0:00",
	Parent = gui,
})
round(timerLabel, UDim.new(0, 12))

local heartsLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 54),
	Size = UDim2.fromOffset(260, 28),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 22,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	Parent = gui,
})

local function showHearts()
	local mode = (workspace:GetAttribute("Mode") :: string?) or "Practice"
	local max = (player:GetAttribute("MaxHearts") :: number?) or Config.Hearts[mode] or 3
	local hearts = math.clamp((player:GetAttribute("Hearts") :: number?) or max, 0, max)
	local tag = "Lv " .. tostring(workspace:GetAttribute("Level") or 1) .. "  "
	heartsLabel.Text = tag .. if player:GetAttribute("Out") then "👻 Ghost" else string.rep("❤️", hearts) .. string.rep("🖤", max - hearts)
end
-- Lantern button
task.spawn(function()
	for _ = 1, 10 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end) then
			return
		end
		task.wait(1)
	end
end)

local METAL = Color3.fromRGB(45, 40, 35)
local lanternButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(84, 84),
	BackgroundColor3 = Color3.fromRGB(25, 28, 34),
	BackgroundTransparency = 0.15,
	Text = "",
	ZIndex = 2,
	Parent = gui,
})
round(lanternButton, UDim.new(1, 0))
local lanternRing = new("UIStroke", { Color = Color3.fromRGB(255, 190, 110), Thickness = 3, Parent = lanternButton })
local lanternGlow = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromOffset(56, 56),
	BackgroundColor3 = Color3.fromRGB(255, 190, 110),
	BackgroundTransparency = 0.8,
	ZIndex = 3,
	Parent = lanternButton,
})
round(lanternGlow, UDim.new(1, 0))
local function lanternBit(size: Vector2, y: number, color: Color3, corner: number): Frame
	local bit = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
		ZIndex = 4,
		Parent = lanternButton,
	})
	round(bit, UDim.new(0, corner))
	return bit
end
local loop = lanternBit(Vector2.new(20, 16), 9, METAL, 10)
loop.BackgroundTransparency = 1
new("UIStroke", { Color = METAL, Thickness = 3, Parent = loop })
lanternBit(Vector2.new(30, 7), 21, METAL, 3)
local lanternGlass = lanternBit(Vector2.new(24, 30), 28, Color3.fromRGB(255, 190, 110), 5)
for _, x in { -12, 10 } do
	new("Frame", {
		Position = UDim2.new(0.5, x, 0, 0),
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = METAL,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = lanternGlass,
	})
end
local flame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.6),
	Size = UDim2.fromOffset(9, 13),
	BackgroundColor3 = Color3.fromRGB(255, 250, 215),
	ZIndex = 5,
	Parent = lanternGlass,
})
round(flame, UDim.new(1, 0))
lanternBit(Vector2.new(32, 7), 57, METAL, 3)
if not touch then
	new("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -2, 1, -2),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = METAL,
		Font = FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "F",
		ZIndex = 6,
		Parent = lanternButton,
	})
end

local function lanternColor(): Color3
	local id = player:GetAttribute("Lantern")
	if id == "LanternRainbow" then
		return Color3.fromHSV((os.clock() * 0.2) % 1, 0.6, 1)
	end
	for _, item in Config.Shop do
		if item.id == id then
			return item.color
		end
	end
	return Color3.fromRGB(255, 190, 110)
end

local function lightOff(): boolean
	return player:GetAttribute("LightOff") == true
end

local function toggleLantern()
	if lightOff() then
		lanternGlow.Size = UDim2.fromOffset(84, 84)
		lanternGlow.BackgroundTransparency = 0.2
		TweenService:Create(lanternGlow, TweenInfo.new(0.6), { Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 0.8 }):Play()
	end
	flashEvent:FireServer()
end
lanternButton.Activated:Connect(toggleLantern)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F then
		toggleLantern()
	end
end)
RunService.RenderStepped:Connect(function()
	local off = lightOff()
	local color = lanternColor()
	lanternGlass.BackgroundColor3 = if off then Color3.fromRGB(55, 55, 62) else color
	lanternGlow.BackgroundColor3 = color
	lanternGlow.Visible = not off
	flame.Visible = not off
	lanternRing.Color = if off then Color3.fromRGB(90, 90, 100) else color
	flame.Size = UDim2.fromOffset(9, 12 + math.sin(os.clock() * 9) * 1.5)
end)

-- Bone button
local boneButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -96, 1, -24),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = Color3.fromRGB(25, 28, 34),
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "🦴",
	ZIndex = 2,
	Parent = gui,
})
round(boneButton, UDim.new(1, 0))
local boneRing = new("UIStroke", { Color = Color3.fromRGB(245, 240, 225), Thickness = 3, Parent = boneButton })
local boneCount = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 2, 1, 2),
	Size = UDim2.fromOffset(26, 22),
	BackgroundColor3 = Color3.fromRGB(45, 40, 35),
	Font = FONT,
	TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "0",
	ZIndex = 3,
	Parent = boneButton,
})
round(boneCount, UDim.new(1, 0))
if not touch then
	new("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -2, 1, 2),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(45, 40, 35),
		Font = FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "G",
		ZIndex = 3,
		Parent = boneButton,
	})
end
local function showBones()
	local count = (player:GetAttribute("Bones") :: number?) or 0
	boneCount.Text = tostring(count)
	boneButton.TextTransparency = if count > 0 then 0 else 0.6
	boneRing.Transparency = if count > 0 then 0 else 0.6
end
player:GetAttributeChangedSignal("Bones"):Connect(showBones)
showBones()
local function throwBone()
	if ((player:GetAttribute("Bones") :: number?) or 0) > 0 then
		boneEvent:FireServer()
	end
end
boneButton.Activated:Connect(throwBone)

-- Call button: Pianka meows back, but dogs and neighbors nearby hear it
local callEvent = ReplicatedStorage:WaitForChild("Call") :: RemoteEvent
local callButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 96, 1, -24),
	Size = UDim2.fromOffset(68, 68),
	BackgroundColor3 = Color3.fromRGB(25, 28, 34),
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "📣",
	ZIndex = 2,
	Parent = gui,
})
round(callButton, UDim.new(1, 0))
local callRing = new("UIStroke", { Color = Color3.fromRGB(120, 200, 255), Thickness = 3, Parent = callButton })
if not touch then
	new("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -2, 1, 2),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(45, 40, 35),
		Font = FONT,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "C",
		ZIndex = 3,
		Parent = callButton,
	})
end
local lastCallTime = -100
local function callPianka()
	local ok = workspace:GetAttribute("Mode") == "Hard" and not player:GetAttribute("Out")
	if ok and os.clock() - lastCallTime >= Config.CallCooldown then
		lastCallTime = os.clock()
		callEvent:FireServer()
	end
end
callButton.Activated:Connect(callPianka)
RunService.Heartbeat:Connect(function()
	local ready = os.clock() - lastCallTime >= Config.CallCooldown
	callButton.Visible = workspace:GetAttribute("Mode") == "Hard"
	callButton.TextTransparency = if ready then 0 else 0.6
	callRing.Transparency = if ready then 0 else 0.6
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.G then
		throwBone()
	elseif not processed and input.KeyCode == Enum.KeyCode.C then
		callPianka()
	end
end)

local hiddenLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 82),
	Size = UDim2.fromOffset(160, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(170, 190, 255),
	TextStrokeTransparency = 0.4,
	Text = "🌑 Hidden",
	Visible = false,
	Parent = gui,
})

-- Game over screen
local over = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
	Parent = frontLayer,
})
local overTitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.new(0.8, 0, 0, 110),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 70, 70),
	Text = "GAME OVER",
	ZIndex = 21,
	Parent = over,
})
new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(40, 0, 0), Parent = overTitle })
local overText = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.new(0.8, 0, 0, 80),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextWrapped = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "",
	ZIndex = 21,
	Parent = over,
})
new("UITextSizeConstraint", { MaxTextSize = 34, Parent = overText })
local overCount = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.66),
	Size = UDim2.new(0.8, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 24,
	TextColor3 = Color3.fromRGB(255, 225, 120),
	Text = "",
	ZIndex = 21,
	Parent = over,
})
local function overButton(text: string, x: number, color: Color3): TextButton
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, x, 0.78, 0),
		Size = UDim2.fromOffset(210, 60),
		BackgroundColor3 = color,
		Font = FONT,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(20, 20, 20),
		Text = text,
		ZIndex = 22,
		Parent = over,
	})
	round(button, UDim.new(0, 16))
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	return button
end
local againButton = overButton("▶ Play again", -115, GREEN)
local overMenuButton = overButton("☰ Menu", 115, Color3.fromRGB(200, 200, 200))
local overId = 0
local function gameOver(text: string)
	overId += 1
	local id = overId
	overText.Text = text
	over.BackgroundTransparency = 1
	over.Visible = true
	TweenService:Create(over, TweenInfo.new(0.6), { BackgroundTransparency = 0.35 }):Play()
	local start = workspace:GetAttribute("RoundStart")
	task.spawn(function()
		for left = 5, 1, -1 do
			if id ~= overId or workspace:GetAttribute("RoundStart") ~= start then
				break
			end
			overCount.Text = "New round in " .. left
			task.wait(1)
		end
		while id == overId and workspace:GetAttribute("RoundStart") == start do
			overCount.Text = "New round soon"
			task.wait(0.5)
		end
		if id == overId then
			over.Visible = false
		end
	end)
end

-- Running effects: speed lines, wider view, red edges when chased
local chasedUntil = 0
local speedLines: { { frame: Frame, angle: number, r: number } } = {}
for _ = 1, 12 do
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(140, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = gui,
	})
	table.insert(speedLines, { frame = line, angle = math.random() * math.pi * 2, r = 0.3 + math.random() * 0.4 })
end
local edges: { Frame } = {}
for i, rotation in { 90, 270, 0, 180 } do
	local edge = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = ({ UDim2.fromScale(0.5, 0.06), UDim2.fromScale(0.5, 0.94), UDim2.fromScale(0.04, 0.5), UDim2.fromScale(0.96, 0.5) })[i],
		Size = if i <= 2 then UDim2.fromScale(1, 0.14) else UDim2.fromScale(0.1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = gui,
	})
	new("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		Parent = edge,
	})
	table.insert(edges, edge)
end

local chaseMusic = new("Sound", {
	SoundId = if Config.ChaseMusicId ~= 0 then "rbxassetid://" .. Config.ChaseMusicId else "",
	Looped = true,
	Volume = 0,
	Parent = SoundService,
})
local rush = 0
local lastSpot: Vector3? = nil
local function runEffects(dt: number)
	local now = os.clock()
	local chase = workspace:GetAttribute("Carrier") ~= nil or workspace:GetAttribute("Escape") ~= nil or workspace:GetAttribute("KittenDeadline") ~= nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local speed = 0
	if root then
		if lastSpot and dt > 0 then
			speed = (Vector3.new(root.Position.X, 0, root.Position.Z) - (lastSpot :: Vector3)).Magnitude / dt
		end
		lastSpot = Vector3.new(root.Position.X, 0, root.Position.Z)
	end
	local want = if (chase or now < chasedUntil) and speed > 10 then 1 elseif speed > 22 then 0.6 else 0
	rush += (want - rush) * math.min(1, dt * 4)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.FieldOfView = 70 + 12 * rush
	end
	for _, line in speedLines do
		line.r += dt * (0.6 + rush)
		if line.r > 0.75 then
			line.r = 0.3 + math.random() * 0.1
			line.angle = math.random() * math.pi * 2
		end
		line.frame.Position = UDim2.fromScale(0.5 + math.cos(line.angle) * line.r, 0.5 + math.sin(line.angle) * line.r)
		line.frame.Rotation = math.deg(line.angle)
		line.frame.BackgroundTransparency = 1 - 0.55 * rush * math.clamp((line.r - 0.3) * 4, 0, 1)
	end
	local alarm = if now < chasedUntil then 0.55 + 0.25 * math.sin(now * 9) else 0
	for _, edge in edges do
		edge.BackgroundTransparency = 1 - alarm * 0.6
	end
	local deadline = (workspace:GetAttribute("KittenDeadline") or workspace:GetAttribute("CarryEnd")) :: number?
	local urgency = if deadline then math.clamp(1 - (deadline - workspace:GetServerTimeNow()) / 60, 0, 1)
		elseif workspace:GetAttribute("Escape") then 0.6
		else 0
	if musicOn and not music.Playing then
		music:Play()
	end
	if Config.ChaseMusicId ~= 0 then
		chaseMusic.PlaybackSpeed = 1 + 0.2 * urgency
		local mix = if chase and chaseMusic.IsLoaded then 1 else 0
		chaseMusic.Volume += (0.6 * mix - chaseMusic.Volume) * math.min(1, dt * 2)
		music.Volume += (0.5 * (1 - mix) - music.Volume) * math.min(1, dt * 2)
		if music.Playing and not chaseMusic.Playing then
			chaseMusic:Play()
		elseif not music.Playing and chaseMusic.Playing then
			chaseMusic:Stop()
		end
	else
		music.PlaybackSpeed += ((if chase then 1.3 + 0.25 * urgency else 1) - music.PlaybackSpeed) * math.min(1, dt * 2)
	end
end

-- A neighbor holds you up: short camera clip
local function heldClip(head: BasePart?)
	if not head then
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > 3 or not head.Parent then
			if conn then
				conn:Disconnect()
			end
			camera.CameraType = Enum.CameraType.Custom
			return
		end
		local look = head.CFrame.LookVector
		local eye = head.Position + look * (7 - t * 0.8) + head.CFrame.RightVector * 2.5 + Vector3.new(0, 0.6 + t * 0.2, 0)
		camera.CFrame = CFrame.lookAt(eye, head.Position + look * 1.5 - Vector3.new(0, 1, 0))
	end)
end

player:GetAttributeChangedSignal("Hearts"):Connect(showHearts)
player:GetAttributeChangedSignal("Out"):Connect(showHearts)
player:GetAttributeChangedSignal("MaxHearts"):Connect(showHearts)
workspace:GetAttributeChangedSignal("Mode"):Connect(showHearts)
workspace:GetAttributeChangedSignal("Level"):Connect(showHearts)
showHearts()

local menuButton = topButton("Menu", -120, 80)
local musicButton = topButton("🎵", 100, 40)
local shopButton = topButton("🐟 Shop", 175, 90)
musicButton.Visible = Config.MusicId ~= 0
musicButton.Activated:Connect(function()
	musicOn = not musicOn
	music.Playing = musicOn
	musicButton.Text = if musicOn then "🎵" else "🔇"
end)
if Config.MusicId ~= 0 then
	music:Play()
end

-- Banner
local banner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(560, 110),
	BackgroundColor3 = PANEL,
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	TextWrapped = true,
	Visible = false,
	ZIndex = 5,
	Parent = gui,
})
round(banner, UDim.new(0, 18))
outline(banner, 3)
new("UITextSizeConstraint", { MaxTextSize = 34, Parent = banner })
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = banner })
if touch then
	new("UIScale", { Scale = 0.65, Parent = banner })
end

local bannerId = 0
local bannerFree = 0
local function showNow(text: string, duration: number)
	bannerId += 1
	local id = bannerId
	banner.Text = text
	banner.Visible = true
	banner.Size = UDim2.fromOffset(480, 94)
	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(560, 110) }):Play()
	task.delay(duration, function()
		if id == bannerId then
			banner.Visible = false
		end
	end)
end

local function showBanner(text: string, duration: number)
	local now = os.clock()
	local wait = math.max(0, bannerFree - now)
	bannerFree = math.max(now, bannerFree) + math.min(duration, 1.8)
	if wait > 6 then
		return
	end
	task.delay(wait, showNow, text, duration)
end

local function confetti()
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 210, 70), GREEN, Color3.fromRGB(90, 160, 255), Color3.fromRGB(255, 130, 200) }
	for _ = 1, 60 do
		local piece = new("Frame", {
			Position = UDim2.new(math.random(), 0, 0, -20),
			Size = UDim2.fromOffset(10, 16),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = gui,
		})
		local tween = TweenService:Create(piece, TweenInfo.new(math.random(20, 40) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(math.random(), 0, 1, 20),
			Rotation = piece.Rotation + math.random(-360, 360),
		})
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		tween:Play()
	end
end

-- Intro
local intro = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.4,
	ZIndex = 10,
	Parent = frontLayer,
})
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(540, 446),
	BackgroundColor3 = PANEL,
	ZIndex = 11,
	Parent = intro,
})
round(card, UDim.new(0, 20))
outline(card, 4)
if touch then
	new("UIScale", { Scale = math.clamp((camera.ViewportSize.Y - 70) / 446, 0.5, 0.7), Parent = card })
end

local function cardText(text: string, y: number, height: number, size: number, color: Color3)
	return new("TextLabel", {
		Position = UDim2.fromOffset(20, y),
		Size = UDim2.new(1, -40, 0, height),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = size,
		TextWrapped = true,
		TextColor3 = color,
		Text = text,
		ZIndex = 12,
		Parent = card,
	})
end

local WHITE = Color3.new(1, 1, 1)
local GRAY = Color3.fromRGB(180, 180, 180)
cardText(Config.GameName .. " 🐱", 12, 50, 32, Color3.fromRGB(255, 180, 90))
cardText("by " .. Config.Creator, 56, 22, 18, GRAY)
cardText("Find " .. Config.CatName .. " with your GPS and bring her home!", 82, 26, 20, WHITE)
cardText("1. Who are you?", 114, 26, 22, GREEN)
cardText("2. Pick a mode", 214, 26, 22, GREEN)

local DARK = Color3.fromRGB(20, 20, 20)
local selectedHero = "Patrick"
local selectedMode = "Practice"
local heroStrokes: { [string]: UIStroke } = {}
local modeStrokes: { [string]: UIStroke } = {}
local playButton: TextButton
local levelLabel: TextLabel

local function currentMode(): string
	return (workspace:GetAttribute("Mode") :: string?) or "Practice"
end

local function refreshIntro()
	for name, stroke in heroStrokes do
		stroke.Enabled = name == selectedHero
	end
	for name, stroke in modeStrokes do
		stroke.Enabled = name == selectedMode
	end
	local level = if selectedMode == currentMode() then (workspace:GetAttribute("Level") :: number?) or 1 else 1
	levelLabel.Text = if selectedMode == "Practice" then "One round to learn" else "Level " .. level
end

for i, name in Config.HeroOrder do
	local hero = Config.Heroes[name]
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 142),
		Size = UDim2.fromOffset(156, 66),
		BackgroundColor3 = Color3.fromRGB(55, 62, 55),
		Text = "",
		ZIndex = 12,
		Parent = card,
	})
	round(button, UDim.new(0, 14))
	heroStrokes[name] = new("UIStroke", {
		Color = Color3.fromRGB(255, 210, 70),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = if #name > 8 then 20 else 26,
		TextColor3 = WHITE,
		Text = hero.Emoji .. " " .. name,
		ZIndex = 13,
		Parent = button,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 36),
		Size = UDim2.new(1, -12, 0, 26),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = GRAY,
		Text = hero.Skill,
		ZIndex = 13,
		Parent = button,
	})
	button.Activated:Connect(function()
		selectedHero = name
		refreshIntro()
	end)
end

local playing = false

local MODES = {
	{ mode = "Practice", color = GREEN, note = "Learn to play", text = DARK },
	{ mode = "Normal", color = Color3.fromRGB(255, 120, 90), note = "7 kittens!", text = DARK },
	{ mode = "Hard", color = Color3.fromRGB(150, 25, 40), note = "Distance only", text = WHITE },
}
for i, info in MODES do
	local mode = info.mode
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 242),
		Size = UDim2.fromOffset(156, 50),
		BackgroundColor3 = info.color,
		Font = FONT,
		TextSize = 26,
		TextColor3 = info.text,
		Text = mode,
		ZIndex = 12,
		Parent = card,
	})
	round(button, UDim.new(0, 14))
	modeStrokes[mode] = new("UIStroke", {
		Color = WHITE,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 294),
		Size = UDim2.fromOffset(156, 20),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextColor3 = GRAY,
		Text = info.note,
		ZIndex = 12,
		Parent = card,
	})
	button.Activated:Connect(function()
		selectedMode = mode
		refreshIntro()
	end)
end
playButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 326),
	Size = UDim2.fromOffset(492, 56),
	BackgroundColor3 = GREEN,
	Font = FONT,
	TextSize = 30,
	TextColor3 = DARK,
	Text = "▶ Play",
	ZIndex = 12,
	Parent = card,
})
round(playButton, UDim.new(0, 18))
new("UIStroke", { Color = WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = playButton })
levelLabel = cardText("", 390, 22, 17, Color3.fromRGB(255, 225, 120))
cardText("The mode is the same for everyone here.", 414, 20, 14, GRAY)

playButton.Activated:Connect(function()
	playing = true
	modeEvent:FireServer(selectedMode, selectedHero)
	intro.Visible = false
end)

local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(70, 75, 70),
	Font = FONT,
	TextSize = 26,
	TextColor3 = WHITE,
	Text = "X",
	Visible = false,
	ZIndex = 13,
	Parent = card,
})
round(closeButton, UDim.new(0, 12))
closeButton.Activated:Connect(function()
	modeEvent:FireServer(nil, selectedHero)
	intro.Visible = false
end)
selectedMode = currentMode()
refreshIntro()
workspace:GetAttributeChangedSignal("Level"):Connect(refreshIntro)

local function openMenu(want: string?)
	selectedMode = want or currentMode()
	refreshIntro()
	closeButton.Visible = playing
	intro.Visible = true
end
menuButton.Activated:Connect(function()
	openMenu()
end)

-- Map: the whole forest from above, to plan a way past the guards
local mapButton = topButton("🗺 Map", 270, 80)
local MAP = 420
local mapFrame = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(MAP + 20, MAP + 56),
	BackgroundColor3 = PANEL,
	Visible = false,
	ZIndex = 25,
	Parent = gui,
})
round(mapFrame, UDim.new(0, 16))
outline(mapFrame, 3)
if touch then
	new("UIScale", { Scale = math.clamp((camera.ViewportSize.Y - 70) / (MAP + 56), 0.5, 0.8), Parent = mapFrame })
end
new("TextLabel", {
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 24,
	TextColor3 = GREEN,
	Text = if touch then "🗺 Map" else "🗺 Map (M)",
	ZIndex = 26,
	Parent = mapFrame,
})
local mapClose = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(70, 75, 70),
	Font = FONT,
	TextSize = 20,
	TextColor3 = WHITE,
	Text = "X",
	ZIndex = 27,
	Parent = mapFrame,
})
round(mapClose, UDim.new(0, 10))
local mapArea = new("Frame", {
	Position = UDim2.fromOffset(10, 46),
	Size = UDim2.fromOffset(MAP, MAP),
	BackgroundColor3 = Color3.fromRGB(28, 52, 30),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 26,
	Parent = mapFrame,
})
local mapScale = 1
local mapCenter = Vector3.zero

-- Zoom on home, you and Pianka's area so the guard lines are easy to see
local function fitMap()
	local points = { Config.HomePosition }
	local catPos = workspace:GetAttribute("CatPosition") :: Vector3?
	if catPos and workspace:GetAttribute("Mode") ~= "Hard" then
		table.insert(points, catPos)
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		table.insert(points, root.Position)
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in points do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	mapCenter = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	mapScale = MAP / math.max(math.max(maxX - minX, maxZ - minZ) + 140, 260)
end

local function toMap(p: Vector3): UDim2
	return UDim2.fromOffset((p.X - mapCenter.X) * mapScale + MAP / 2, (p.Z - mapCenter.Z) * mapScale + MAP / 2)
end

local function mapLine(a: Vector3, b: Vector3, color: Color3, thick: number)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap((a + b) / 2),
		Size = UDim2.fromOffset(math.max(d.Magnitude * mapScale, 2), thick),
		Rotation = math.deg(math.atan2(d.Z, d.X)),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 27,
		Parent = mapArea,
	})
end

local function mapIcon(p: Vector3, text: string, size: number, rotation: number?)
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(p),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = text,
		Rotation = rotation or 0,
		ZIndex = 28,
		Parent = mapArea,
	})
end

local function drawMap()
	mapArea:ClearAllChildren()
	fitMap()
	local hedges = workspace:FindFirstChild("Hedges")
	for _, hedge in (if hedges then hedges:GetChildren() else {}) do
		local core = hedge:FindFirstChild("Core") :: BasePart?
		if core then
			local half = core.CFrame.LookVector * core.Size.Z / 2
			mapLine(core.Position - half, core.Position + half, Color3.fromRGB(30, 140, 50), 4)
		end
	end
	local catPos = workspace:GetAttribute("CatPosition") :: Vector3?
	if catPos and workspace:GetAttribute("Mode") ~= "Hard" then
		local area = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(catPos),
			Size = UDim2.fromOffset(70 * mapScale, 70 * mapScale),
			BackgroundColor3 = Color3.fromRGB(255, 210, 90),
			BackgroundTransparency = 0.6,
			ZIndex = 27,
			Parent = mapArea,
		})
		round(area, UDim.new(1, 0))
		mapIcon(catPos, "❓", 18)
	end
	local dogs = workspace:FindFirstChild("Dogs")
	for _, dog in (if dogs then dogs:GetChildren() else {}) do
		local a, b = dog:GetAttribute("PathA") :: Vector3?, dog:GetAttribute("PathB") :: Vector3?
		if a and b then
			mapLine(a, b, Color3.fromRGB(230, 70, 60), 3)
		end
		if dog:IsA("Model") and dog.PrimaryPart then
			mapIcon(dog.PrimaryPart.Position, "🐕", 16)
		end
	end
	local neighbors = workspace:FindFirstChild("Neighbors")
	for _, m in (if neighbors then neighbors:GetChildren() else {}) do
		if m.Name == "Cabin" and m:IsA("Model") then
			mapIcon(m:GetPivot().Position, "🏚", 18)
		elseif m:GetAttribute("Hunting") and m:IsA("Model") and m.PrimaryPart then
			local a, b = m:GetAttribute("PathA") :: Vector3?, m:GetAttribute("PathB") :: Vector3?
			if a and b then
				mapLine(a, b, Color3.fromRGB(255, 170, 60), 3)
			end
			mapIcon(m.PrimaryPart.Position, "🔦", 14)
		end
	end
	mapIcon(Config.HomePosition, "🏠", 22)
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and other == player then
			local look = camera.CFrame.LookVector
			mapIcon(root.Position, "▲", 18, math.deg(math.atan2(look.X, -look.Z)))
		elseif root then
			mapIcon(root.Position, "🔵", 12)
		end
	end
end

local function toggleMap(show: boolean?)
	mapFrame.Visible = if show == nil then not mapFrame.Visible else show
	if mapFrame.Visible then
		drawMap()
	end
end
mapButton.Activated:Connect(function()
	toggleMap()
end)
mapClose.Activated:Connect(function()
	toggleMap(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		toggleMap()
	end
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		if mapFrame.Visible then
			drawMap()
		end
	end
end)
againButton.Activated:Connect(function()
	over.Visible = false
	modeEvent:FireServer(currentMode(), selectedHero)
end)
overMenuButton.Activated:Connect(function()
	over.Visible = false
	openMenu()
end)

-- Intro clip: Pianka runs out of the house at dusk
local introClock: number? = nil
local callSound = new("Sound", {
	SoundId = if Config.CallId ~= 0 then "rbxassetid://" .. Config.CallId else "",
	Volume = 1,
	Parent = gui,
})
-- Only the clip on screen: no buttons, no GPS, no Roblox controls
local function showControls(on: boolean)
	gui.Enabled = on
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, on)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = on
	end
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module and module:IsA("ModuleScript") then
			local controls = (require(module) :: any):GetControls()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

local function playIntro()
	local camp = workspace:WaitForChild("Camp", 10)
	local house = camp and camp:WaitForChild("House", 10)
	local door = house and house:FindFirstChild("Door") :: BasePart?
	local floor = house and house:FindFirstChild("Floor") :: BasePart?
	local template = ReplicatedStorage:WaitForChild("CatTemplate", 10) :: Model?
	if not house or not door or not floor or not template then
		return
	end
	intro.Visible = false
	showControls(false)
	local parts: { GuiObject } = {}
	for i, y in { 0, 1 } do
		parts[i] = new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, 0.12),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 30,
			Parent = frontLayer,
		})
	end
	local caption = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.new(0.9, 0, 0, 80),
		BackgroundTransparency = 1,
		Font = FONT,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		Text = "",
		ZIndex = 31,
		Parent = frontLayer,
	})
	new("UITextSizeConstraint", { MaxTextSize = 40, Parent = caption })
	local skip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(110, 44),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0.2,
		Font = FONT,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "Skip ▶",
		ZIndex = 32,
		Parent = frontLayer,
	})
	round(skip, UDim.new(0, 12))
	local fade = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 33,
		Parent = frontLayer,
	})
	table.insert(parts, caption)
	table.insert(parts, skip)

	local cat = template:Clone()
	local lift = template:GetPivot().Y
	local doorCF = door.CFrame
	local hinge = doorCF * CFrame.new(0, 0, -door.Size.Z / 2)
	local closed = hinge:ToObjectSpace(doorCF)
	local foot = Vector3.new(door.Position.X, 0, door.Position.Z)
	local out = Vector3.new(foot.X - floor.Position.X, 0, foot.Z - floor.Position.Z).Unit
	local side = Vector3.new(-out.Z, 0, out.X)
	local hide = workspace:GetAttribute("CatPosition") :: Vector3?
	local away = if hide then Vector3.new(hide.X - foot.X, 0, hide.Z - foot.Z) else out
	away = if away.Magnitude > 1 then away.Unit else out
	-- She runs into the forest in front of the house, never back through it
	if away:Dot(out) < 0.4 then
		away = (out * 0.6 + side * (if away:Dot(side) >= 0 then 0.8 else -0.8)).Unit
	end
	-- The camera always stays in front of the house
	local function outside(p: Vector3): Vector3
		local along = (p - floor.Position):Dot(out)
		return if along < 9 then p + out * (9 - along) else p
	end
	local eyeStart = outside(foot + out * 15 + side * 4 + Vector3.new(0, 4.5, 0))
	camera.CameraType = Enum.CameraType.Scriptable
	cat.Parent = workspace

	local start = os.clock()
	local finished, spoke, said = false, false, false
	local conn: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
		end
		introClock = nil
		door.CFrame = doorCF
		cat:Destroy()
		for _, part in parts do
			part:Destroy()
		end
		camera.CameraType = Enum.CameraType.Custom
		showControls(true)
		if not playing then
			intro.Visible = true
		end
		fade.BackgroundTransparency = 0
		local tween = TweenService:Create(fade, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			fade:Destroy()
		end)
		tween:Play()
	end
	skip.Activated:Connect(finish)
	local up = Vector3.new(0, 1, 0)
	local runStart = foot + out * 6
	local edge = runStart + away * 50
	local function turned(from: Vector3, alpha: number): Vector3
		return CFrame.Angles(0, math.pi * math.clamp(alpha, 0, 1), 0):VectorToWorldSpace(from)
	end
	local meowed = false
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		-- Late afternoon turns into night
		introClock = 16.6 + math.clamp((t - 7) / 7, 0, 1) * 2.2
		local open = math.clamp((t - 0.6) / 0.5, 0, 1)
		door.CFrame = hinge * CFrame.Angles(0, -math.rad(105) * open, 0) * closed
		-- Pianka runs out, stops at the forest edge, looks back, then runs into the trees
		local at: Vector3
		local dir: Vector3
		if t < 1 then
			at, dir = foot - out * 2, out
		elseif t < 1.8 then
			at, dir = (foot - out * 2):Lerp(runStart, (t - 1) / 0.8), out
		elseif t < 6 then
			at, dir = runStart:Lerp(edge, (t - 1.8) / 4.2), away
		elseif t < 8.5 then
			at = edge
			dir = if t < 8 then turned(away, (t - 6) / 0.6) else turned(-away, (t - 8) / 0.5)
		else
			at, dir = edge + away * (t - 8.5) * 14, away
		end
		local running = (t > 1 and t < 6) or t > 8.5
		local hop = if running then math.abs(math.sin(t * 14)) * 0.5 else 0
		local body = at + Vector3.new(0, lift + hop, 0)
		cat:PivotTo(CFrame.lookAt(body, body + dir))
		if t > 6.5 and not meowed then
			meowed = true
			if cat.PrimaryPart then
				playClip(cat.PrimaryPart, Config.Meow, 1.4, 1, 90)
			end
		end
		-- Camera: the door, then following her, a close look, then the dark forest
		local eye: Vector3
		local focus: Vector3
		if t < 2.2 then
			eye, focus = eyeStart, foot + up * 3
		elseif t < 6 then
			local follow = outside(at + side * 9 + out * 3 - away * 6 + up * 4)
			eye, focus = eyeStart:Lerp(follow, math.clamp((t - 2.2) / 0.8, 0, 1)), at + up
		elseif t < 8.5 then
			eye, focus = edge - away * 6 + side * 2.5 + up * 2.2, edge + up * 1.8
		else
			local k = math.clamp((t - 8.5) / 8, 0, 1)
			eye = (edge - away * 24 + up * 16):Lerp(edge - away * 6 + up * 9, k)
			focus = at:Lerp(edge + away * 70, math.clamp((t - 11) / 4, 0, 1))
		end
		camera.CFrame = CFrame.lookAt(outside(eye), focus)
		-- Phone controls can appear late, keep them hidden while the clip plays
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
		if touchGui and touchGui:IsA("ScreenGui") then
			touchGui.Enabled = false
		end
		if t > 1.1 and not spoke then
			spoke = true
			caption.Text = "\"Pianka! Piankaaaa! Piaaaaanka!\""
			if Config.CallId ~= 0 then
				callSound:Play()
			end
		end
		if t > 6 and t < 10.5 then
			caption.Text = ""
		end
		if t > 10.5 and not said then
			said = true
			caption.Text = "It's getting dark..."
		end
		if t > 13 then
			caption.Text = "It's getting dark...\nSomeone has to find her! 🔦"
		end
		fade.BackgroundTransparency = 1 - math.clamp((t - 16.6) / 0.5, 0, 1)
		if t > 17.3 then
			finish()
		end
	end)
end
task.spawn(playIntro)

-- Shop
local shop = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(420, 440),
	BackgroundColor3 = PANEL,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
})
round(shop, UDim.new(0, 20))
outline(shop, 4)
if touch then
	new("UIScale", { Name = "Fit", Scale = math.clamp((camera.ViewportSize.Y - 70) / 440, 0.5, 0.75), Parent = shop })
end
new("TextLabel", {
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 34,
	TextColor3 = Color3.fromRGB(255, 180, 90),
	Text = "Shop 🐟",
	ZIndex = 21,
	Parent = shop,
})
local fishLabel = new("TextLabel", {
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(200, 200, 200),
	Text = "",
	ZIndex = 21,
	Parent = shop,
})
local shopClose = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(70, 75, 70),
	Font = FONT,
	TextSize = 26,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "X",
	ZIndex = 22,
	Parent = shop,
})
round(shopClose, UDim.new(0, 12))
shopClose.Activated:Connect(function()
	shop.Visible = false
end)

local shopRows: { { item: any, button: TextButton } } = {}
for i, item in Config.Shop do
	local row = new("Frame", {
		Position = UDim2.fromOffset(20, 84 + (i - 1) * 56),
		Size = UDim2.new(1, -40, 0, 48),
		BackgroundColor3 = Color3.fromRGB(55, 62, 55),
		ZIndex = 21,
		Parent = shop,
	})
	round(row, UDim.new(0, 12))
	new("Frame", {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = item.color,
		ZIndex = 22,
		Parent = row,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -160, 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1, 1, 1),
		Text = item.name,
		ZIndex = 22,
		Parent = row,
	})
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(100, 36),
		BackgroundColor3 = GREEN,
		Font = FONT,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(20, 20, 20),
		Text = "",
		ZIndex = 22,
		Parent = row,
	})
	round(button, UDim.new(0, 10))
	table.insert(shopRows, { item = item, button = button })
end

-- Robux passes
local MarketplaceService = game:GetService("MarketplaceService")
local passRows: { { pass: any, button: TextButton } } = {}
local passTop = 84 + #Config.Shop * 56 + 6
local visiblePasses = 0
for _, pass in Config.Passes do
	if pass.id ~= 0 then
		visiblePasses += 1
	end
end
if visiblePasses > 0 then
	new("TextLabel", {
		Position = UDim2.fromOffset(0, passTop),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(120, 230, 140),
		Text = "With Robux",
		ZIndex = 21,
		Parent = shop,
	})
	local y = passTop + 30
	for _, pass in Config.Passes do
		if pass.id == 0 then
			continue
		end
		local row = new("Frame", {
			Position = UDim2.fromOffset(20, y),
			Size = UDim2.new(1, -40, 0, 48),
			BackgroundColor3 = Color3.fromRGB(45, 70, 55),
			ZIndex = 21,
			Parent = shop,
		})
		round(row, UDim.new(0, 12))
		new("TextLabel", {
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -140, 1, 0),
			BackgroundTransparency = 1,
			Font = FONT,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = (if pass.key == "ExtraHeart" then "❤️ " elseif pass.key == "Crown" then "👑 " elseif pass.key == "Pet" then "🐱 " else "🌈 ") .. pass.name,
			ZIndex = 22,
			Parent = row,
		})
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(100, 36),
			BackgroundColor3 = Color3.fromRGB(0, 176, 111),
			Font = FONT,
			TextSize = 20,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "R$ " .. tostring(pass.price),
			ZIndex = 22,
			Parent = row,
		})
		round(button, UDim.new(0, 10))
		button.Activated:Connect(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		table.insert(passRows, { pass = pass, button = button })
		y += 56
	end
	shop.Size = UDim2.fromOffset(420, y + 12)
	local fit = shop:FindFirstChild("Fit") :: UIScale?
	if fit then
		fit.Scale = math.clamp((camera.ViewportSize.Y - 70) / (y + 12), 0.4, 0.75)
	end
end

local function fishCount(): number
	local stats = player:FindFirstChild("leaderstats")
	local fish = stats and stats:FindFirstChild("Fish") :: IntValue?
	return if fish then fish.Value else 0
end

local function refreshShop()
	local fish = fishCount()
	fishLabel.Text = "You have " .. fish .. " fish. Find glowing fish in the forest!"
	local owned = string.split((player:GetAttribute("Owned") :: string?) or "", ",")
	for _, row in shopRows do
		local id = row.item.id
		local has = table.find(owned, id) ~= nil
		local on = (row.item.kind == "lantern" and player:GetAttribute("Lantern") == id)
			or (row.item.kind == "crown" and player:GetAttribute("Crown") == true)
			or (row.item.kind == "pet" and player:GetAttribute("Pet") == true)
		if not has then
			row.button.Text = "🐟 " .. row.item.price
			row.button.BackgroundColor3 = if fish >= row.item.price then GREEN else Color3.fromRGB(110, 110, 110)
		elseif on then
			row.button.Text = "On"
			row.button.BackgroundColor3 = Color3.fromRGB(255, 210, 70)
		else
			row.button.Text = "Use"
			row.button.BackgroundColor3 = Color3.fromRGB(140, 200, 255)
		end
	end
	for _, row in passRows do
		local has = if row.pass.key == "ExtraHeart" then player:GetAttribute("ExtraHeart") == true else table.find(owned, row.pass.key) ~= nil
		row.button.Text = if has then "Owned ✓" else "R$ " .. tostring(row.pass.price)
		row.button.BackgroundColor3 = if has then Color3.fromRGB(110, 110, 110) else Color3.fromRGB(0, 176, 111)
		row.button.Active = not has
	end
end

for _, row in shopRows do
	row.button.Activated:Connect(function()
		local owned = string.split((player:GetAttribute("Owned") :: string?) or "", ",")
		shopEvent:FireServer(if table.find(owned, row.item.id) then "equip" else "buy", row.item.id)
	end)
end
shopButton.Activated:Connect(function()
	refreshShop()
	shop.Visible = not shop.Visible
end)
for _, name in { "Owned", "Lantern", "Crown", "Pet", "ExtraHeart" } do
	player:GetAttributeChangedSignal(name):Connect(refreshShop)
end
task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local fish = stats:WaitForChild("Fish") :: IntValue
	fish.Changed:Connect(refreshShop)
	refreshShop()
end)

-- Feedback
local flash = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 40, 40),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = gui,
})

local popCount = 0
local lastPop: { [string]: number } = {}
local function popText(text: string, color: Color3)
	local now = os.clock()
	if now - (lastPop[text] or -10) < 2 then
		return
	end
	lastPop[text] = now
	popCount += 1
	local row = popCount - 1
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45 + row * 0.07),
		Size = UDim2.fromOffset(600, 50),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 36,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		Text = text,
		ZIndex = 6,
		Parent = gui,
	})
	local tween = TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.39 + row * 0.07),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Once(function()
		label:Destroy()
		popCount -= 1
	end)
	tween:Play()
end

local function note(speed: number)
	local sound = beep:Clone()
	sound.PlaybackSpeed = speed
	sound.Parent = gui
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local TWISTS = {
	tree = "Twist: Pianka is up a tree! 🌳\nClimb the steps.",
	zoomies = "Twist: Pianka has the zoomies! 💨",
	ratparty = "Twist: Rat party! 🐀🐀🐀",
	fullmoon = "Twist: Full moon tonight! 🌕",
	golden = "Twist: Golden Pianka! ✨\nDouble rewards!",
}

-- Events
local wobble = Vector2.zero
local lastWobble = 0
local hardRadar = { reveal = 0, nextGlitch = 0, glitchEnd = 0, angle = 0 }
local best: { [string]: number } = {}

local function nameOf(who: Player?): string
	return if who then who.DisplayName else "Someone"
end

local function winText(text: string, seconds: number): string
	local mode = workspace:GetAttribute("Mode") :: string? or "Practice"
	text ..= "\nTime: " .. formatTime(seconds)
	if seconds < (best[mode] or math.huge) then
		if best[mode] then
			text ..= "  New record! ⭐"
		end
		best[mode] = seconds
	end
	return text
end

-- A hiding spot wobbles: Pianka moving inside
local shaking: { [BasePart]: boolean } = {}
local function shake(part: BasePart, strength: number)
	if shaking[part] then
		return
	end
	shaking[part] = true
	local base = part.CFrame
	local kids: { [BasePart]: CFrame } = {}
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			kids[d] = base:ToObjectSpace(d.CFrame)
		end
	end
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local cf = base
		if t < 0.8 and part.Parent then
			cf = base * CFrame.Angles(math.sin(t * 38) * 0.05 * strength, 0, math.cos(t * 31) * 0.05 * strength)
		end
		part.CFrame = cf
		for d, offset in kids do
			d.CFrame = cf * offset
		end
		if t >= 0.8 or not part.Parent then
			shaking[part] = nil
			if conn then
				conn:Disconnect()
			end
		end
	end)
end

local function hidingPlace(near: Vector3): BasePart?
	local spots = workspace:FindFirstChild("Twist")
	for _, spot in (if spots then spots:GetChildren() else {}) do
		if spot:IsA("BasePart") and spot:GetAttribute("Pianka") and (spot.Position - near).Magnitude < 4 then
			return spot
		end
	end
	return nil
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tryAgain(delay: number)
	task.delay(delay, function()
		showBanner("Try again! Use your GPS.", 3)
	end)
end

catEvent.OnClientEvent:Connect(function(kind: string, who: Player?, value: any, part: Instance?)
	local cat = Config.CatName
	local seconds = if type(value) == "number" then value else 0
	if kind == "picked" then
		if who == player then
			showBanner("You found " .. cat .. "! 🐱\nBring her home to her bed.", 4)
			chime()
			local root = myRoot()
			if root then
				playClip(root, Config.Voices.Got, 1, 1, 80, voiceSound)
			end
		else
			showBanner(nameOf(who) .. " found " .. cat .. "!", 3)
		end
	elseif kind == "home" then
		if who == player then
			showBanner(winText(cat .. " is home! 🎉", seconds), 5)
			confetti()
			chime()
		else
			showBanner(nameOf(who) .. " brought " .. cat .. " home!", 5)
		end
		task.delay(5, function()
			if currentMode() == "Practice" then
				openMenu("Normal")
			end
		end)
	elseif kind == "lost" then
		gameOver(cat .. " ran away! 😿")
		tryAgain(5)
	elseif kind == "fled" then
		popText(cat .. " ran off! 💨", Color3.fromRGB(255, 200, 120))
		local root = myRoot()
		if root then
			playClip(root, Config.Voices.Back, 1, 1, 80, voiceSound)
		end
	elseif kind == "call" then
		if typeof(value) == "Instance" and value:IsA("BasePart") then
			local calls = Config.Voices.Call
			playClip(value, calls[math.random(1, #calls)], 1, 1, 120, voiceSound)
		end
	elseif kind == "meowBack" and typeof(value) == "Vector3" then
		local at = Instance.new("Attachment")
		at.Position = value
		at.Parent = workspace.Terrain
		local kitten = workspace:GetAttribute("KittenDeadline") ~= nil
		playClip(at, if kitten then Config.Mew else Config.Meow, 2, 1, 400)
		local tag = new("BillboardGui", {
			Size = UDim2.fromOffset(130, 44),
			StudsOffset = Vector3.new(0, 4, 0),
			AlwaysOnTop = true,
			MaxDistance = if workspace:GetAttribute("Mode") == "Hard" then 120 else 400,
			Parent = at,
		})
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = FONT,
			TextScaled = true,
			TextColor3 = Color3.fromRGB(255, 220, 140),
			TextStrokeTransparency = 0.2,
			Text = if kitten then "Mew! 🐈" else "Meow! 🐱",
			Parent = tag,
		})
		local spot = hidingPlace(value)
		if spot then
			shake(spot, 1.6)
		end
		hardRadar.reveal = os.clock() + 5
		task.delay(3, function()
			at:Destroy()
		end)
	elseif kind == "heard" then
		popText("Shh! Something heard you 👂", Color3.fromRGB(255, 170, 80))
	elseif kind == "heyYou" then
		if typeof(value) == "Instance" and value:IsA("BasePart") then
			playClip(value, Config.Voices.HeyYou, 1.3, 1, 110, voiceSound)
		end
	elseif kind == "kittens" then
		-- She screams, pops into confetti and her kittens run off
		local template = ReplicatedStorage:FindFirstChild("CatTemplate") :: Model?
		if type(value) == "table" and typeof(value.from) == "Vector3" and template then
			local from = Vector3.new(value.from.X, 0, value.from.Z)
			local at = Instance.new("Attachment")
			at.Position = from + Vector3.new(0, 2, 0)
			at.Parent = workspace.Terrain
			playClip(at, Config.Scream, 3, 1, 300, voiceSound)
			popText(cat .. ": MEEOOOWW!! 😱", Color3.fromRGB(255, 150, 200))
			task.delay(Config.KittenBurst[1], function()
				new("ParticleEmitter", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
						ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 70)),
						ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 160, 255)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 200)),
					}),
					LightEmission = 0.5,
					Size = NumberSequence.new(0.5),
					Speed = NumberRange.new(18, 36),
					SpreadAngle = Vector2.new(180, 180),
					Lifetime = NumberRange.new(1.5, 2.5),
					Acceleration = Vector3.new(0, -30, 0),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-300, 300),
					Rate = 0,
					Parent = at,
				}):Emit(120)
				confetti()
				chime()
				local runners: { { model: Model, to: Vector3 } } = {}
				for _, pos in value.to do
					local kitten = template:Clone()
					local pivot = kitten:GetPivot()
					for _, part in kitten:GetDescendants() do
						if part:IsA("BasePart") then
							local rel = pivot:ToObjectSpace(part.CFrame)
							part.Size *= 0.45
							part.CFrame = pivot * (rel - rel.Position + rel.Position * 0.45)
							part.Anchored = true
							part.CanCollide = false
						end
					end
					kitten.Parent = workspace
					table.insert(runners, { model = kitten, to = Vector3.new(pos.X, 0, pos.Z) })
				end
				local start = os.clock()
				local conn: RBXScriptConnection? = nil
				conn = RunService.RenderStepped:Connect(function()
					local t = math.min((os.clock() - start) / Config.KittenBurst[2], 1)
					local ease = 1 - (1 - t) ^ 2
					for i, r in runners do
						local dir = r.to - from
						local face = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
						local p = from:Lerp(r.to, ease) + Vector3.new(0, 0.63 + math.abs(math.sin(t * 20 + i)) * (1 - t), 0)
						r.model:PivotTo(CFrame.lookAt(p, p + face))
					end
					if t >= 1 and conn then
						conn:Disconnect()
						for _, r in runners do
							r.model:Destroy()
						end
						at:Destroy()
					end
				end)
				showBanner("💥 Pop! " .. Config.KittenCount .. " kittens!\nStack them all on your head! 🐈", 5)
			end)
		end
	elseif kind == "kitten" then
		local finder = if who == player then "You" else nameOf(who)
		showBanner(finder .. " found a kitten! 🐈\n" .. seconds .. " left", 2)
		if who == player then
			chime()
		end
	elseif kind == "allKittens" then
		showBanner(winText("All kittens found! 🎉", seconds), 6)
		confetti()
		chime()
		task.delay(8, function()
			showBanner(cat .. " ran away again! Use your GPS.", 3)
		end)
	elseif kind == "dogs" then
		local runner = ((player:GetAttribute("Kittens") :: number?) or 0) > 0
		showBanner(if runner then "🐕 Dogs! Run home!\nStay out of their light!" else "🐕 Dogs! Watch out!", 3)
	elseif kind == "caught" then
		gameOver("They got " .. (if who == player then "you" else nameOf(who)) .. "!\nThe kittens ran home.")
		tryAgain(5)
	elseif kind == "escaped" then
		showBanner(winText("You beat HARD! 🏆", seconds), 6)
		confetti()
		chime()
		task.delay(8, function()
			showBanner(cat .. " ran away again! Use your GPS.", 3)
		end)
	elseif kind == "timeUp" then
		gameOver("Time's up! ⏰\nThe kittens ran home.")
		tryAgain(5)
	elseif kind == "heroLater" then
		showBanner("You will be " .. tostring(value) .. "\nnext round.", 3)
	elseif kind == "modeLocked" then
		showBanner("Wait! Someone is saving " .. cat .. ".\nTry again soon.", 3)
	elseif kind == "fish" then
		popText("+" .. seconds .. " 🐟", Color3.fromRGB(255, 190, 80))
		note(2)
	elseif kind == "bitten" then
		flash.BackgroundTransparency = 0.6
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		popText("Rat bite! -1 ❤️ 🐀", Color3.fromRGB(255, 120, 120))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and clipSound then
			playClip(root, Config.Mew, 1, 2.3, 60)
		else
			note(2.5)
		end
	elseif kind == "power" then
		local texts = { speed = "Super speed! ⚡", bright = "Super light! 💡", jump = "Super jump! 🦘" }
		popText(texts[tostring(value)] or "Power up!", Color3.fromRGB(150, 220, 255))
		chime()
	elseif kind == "bush" then
		if part and part:IsA("BasePart") then
			shake(part, 1)
		end
		if value == "found" then
			showBanner((if who == player then "You" else nameOf(who)) .. " found " .. cat .. "! 🐱", 3)
			chime()
		elseif value == "frog" then
			popText("Ribbit! 🐸", Color3.fromRGB(140, 255, 140))
		elseif value == "rat" then
			popText("A rat! 🐀 Run!", Color3.fromRGB(255, 150, 150))
		elseif value == "empty" then
			popText("Empty... 🍂", Color3.fromRGB(200, 200, 200))
		elseif value == "fish" then
			popText("+1 🐟", Color3.fromRGB(120, 200, 255))
		else
			popText("Confetti! 🎉", Color3.fromRGB(255, 210, 90))
			confetti()
		end
	elseif kind == "spotted" or kind == "hunted" or kind == "lunge" then
		chasedUntil = os.clock() + 3
	end
	if kind == "spotted" then
		popText("A dog saw you! Run! 🐕", Color3.fromRGB(255, 170, 80))
		note(1.6)
	elseif kind == "lunge" then
		popText("Watch out! 🐕", Color3.fromRGB(255, 120, 100))
	elseif kind == "dogbite" then
		flash.BackgroundTransparency = 0.5
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		popText("Ouch! -1 ❤️", Color3.fromRGB(255, 120, 120))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and typeof(value) == "Vector3" then
			root.AssemblyLinearVelocity = value * 45 + Vector3.new(0, 25, 0)
		end
	elseif kind == "squash" then
		popText("Squash! 🐀", Color3.fromRGB(150, 255, 150))
		note(0.6)
	elseif kind == "twist" then
		local text = TWISTS[tostring(value)]
		if text then
			task.delay(1, function()
				showBanner(text, 4)
			end)
		end
	elseif kind == "dropped" then
		local scarer = if value == "dog" then "A dog" elseif value == "neighbor" then "The neighbor" else "The rats"
		showBanner(if who == player then scarer .. " scared " .. cat .. "!\nGet her back!" else cat .. " jumped down!", 3)
	elseif kind == "bird" then
		popText("+1 ❤️ 🐦", Color3.fromRGB(255, 140, 180))
		chime()
	elseif kind == "gotBone" then
		popText("+1 🦴", Color3.fromRGB(245, 240, 225))
	elseif kind == "bone" then
		popText(if seconds > 0 then "🦴 Dogs went for the bone!" else "🦴 No dogs near it", Color3.fromRGB(245, 240, 225))
	elseif kind == "kittensBack" then
		showBanner(if who == player then "Your kittens ran back\ninto the forest! 🐈" else nameOf(who) .. "'s kittens ran\nback into the forest! 🐈", 3)
	elseif kind == "heart" then
		local root = myRoot()
		if root then
			playClip(root, Config.Voices.Ouch, 1, 1, 60, voiceSound)
		end
		heartsLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		heartsLabel.TextSize = 30
		TweenService:Create(heartsLabel, TweenInfo.new(0.8), { TextSize = 22, TextColor3 = Color3.new(1, 1, 1) }):Play()
	elseif kind == "out" then
		if who == player then
			showBanner("😵 Out of hearts!\nYou are a ghost 👻 until the next round.", 5)
		else
			showBanner(nameOf(who) .. " is out of hearts! 😵", 3)
		end
	elseif kind == "hearts" then
		gameOver((if #Players:GetPlayers() > 1 then "Everyone is out of hearts.\n" else "Out of hearts! 😵\n") .. cat .. " is still lost 😿")
		tryAgain(5)
	elseif kind == "held" then
		if who == player then
			flash.BackgroundTransparency = 0.4
			TweenService:Create(flash, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
			showBanner("Ut herfra! 😱\nThe neighbor caught you!", 3)
			heldClip(if typeof(value) == "Instance" and value:IsA("BasePart") then value else nil)
		else
			showBanner(nameOf(who) .. " was caught\nby a neighbor! 😱", 3)
		end
	elseif kind == "hunt" then
		showBanner("🌙 Night! The neighbors are hunting.\nLantern off 🔦 = they can't see you!", 4)
	elseif kind == "dawn" then
		showBanner("☀️ Morning! The neighbors went home.", 3)
	elseif kind == "hunted" then
		popText("A neighbor saw you! Run! 🔦", Color3.fromRGB(255, 170, 80))
		note(1.4)
	elseif kind == "grabbed" then
		flash.BackgroundTransparency = 0.5
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		popText("Ut herfra! -1 ❤️", Color3.fromRGB(255, 120, 120))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and typeof(value) == "Vector3" then
			root.AssemblyLinearVelocity = value * 45 + Vector3.new(0, 25, 0)
		end
	elseif kind == "poor" then
		showBanner("Not enough fish 🐟\nFind more in the forest!", 2)
	elseif kind == "bought" then
		showBanner("You got " .. tostring(value) .. "! 🎉", 2)
		chime()
	elseif kind == "level" then
		showBanner("Level " .. tostring(value) .. "! ⬆️\nMore dogs. Better hiding.", 3)
		chime()
	elseif kind == "mode" then
		showBanner((if who == player then "You" else nameOf(who)) .. " picked " .. tostring(value) .. "!\nNew round.", 3)
	end
end)

sayEvent.OnClientEvent:Connect(function(head: BasePart, index: number, pitch: number)
	local line = Config.Lines[index]
	if line and head then
		playClip(head, line, 1, pitch, 90)
	end
end)

-- Day and night
local DAY_AMBIENT = Color3.fromRGB(120, 140, 120)
local NIGHT_AMBIENT = Color3.fromRGB(24, 28, 46)
local tint = new("ColorCorrectionEffect", { Parent = Lighting })

local blackout = 0
local lastSky = os.clock()
local shade = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = backLayer,
})

local function updateSky(): number
	local dayStart = workspace:GetAttribute("DayStart") :: number?
	if not dayStart then
		return 1
	end
	local clock, daylight = Sky.at(workspace:GetServerTimeNow() - dayStart, Config.DayMinutes, Config.NightShare)
	if introClock then
		clock, daylight = introClock, Sky.light(introClock)
	end
	local night = daylight < 0.5
	if workspace:GetAttribute("Twist") == "fullmoon" then
		daylight = math.max(daylight, 0.3)
	end
	local dark = 1 - daylight
	local now = os.clock()
	local hide = night and player:GetAttribute("LightOff") == true
	blackout += ((if hide then 1 else 0) - blackout) * math.min(1, (now - lastSky) * 3)
	lastSky = now
	hiddenLabel.Visible = hide
	Lighting.ClockTime = clock
	Lighting.Brightness = 0.35 + 1.65 * daylight
	Lighting.OutdoorAmbient = NIGHT_AMBIENT:Lerp(DAY_AMBIENT, daylight)
	Lighting.Ambient = Color3.fromRGB(14, 16, 28):Lerp(Color3.fromRGB(70, 75, 70), daylight)

	local mode = workspace:GetAttribute("Mode")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local base = if mode == "Hard" then 0.64 elseif mode == "Normal" then 0.56 else 0.4
		atmosphere.Density = base + 0.08 * dark
		atmosphere.Color = Color3.fromRGB(60, 70, 96):Lerp(Color3.fromRGB(190, 215, 190), daylight)
		atmosphere.Decay = Color3.fromRGB(30, 35, 54):Lerp(Color3.fromRGB(90, 120, 90), daylight)
	end
	tint.TintColor = Color3.fromRGB(208, 216, 255):Lerp(Color3.new(1, 1, 1), daylight)
	tint.Saturation = -0.18 * dark
	tint.Brightness = 0.01 * dark
	Lighting.ExposureCompensation = -1.5 * blackout
	tint.Contrast = 0.25 * blackout
	shade.BackgroundTransparency = 1 - 0.45 * blackout
	if blackout > 0.01 then
		-- Lantern off at night: black, only shapes against the sky
		Lighting.Brightness *= 1 - blackout
		Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(Color3.new(0, 0, 0), blackout)
		Lighting.Ambient = Lighting.Ambient:Lerp(Color3.new(0, 0, 0), blackout)
		tint.Saturation = tint.Saturation + (-0.85 - tint.Saturation) * blackout
		tint.Brightness = tint.Brightness - 0.12 * blackout
		if atmosphere then
			atmosphere.Density = atmosphere.Density + (0.3 - atmosphere.Density) * blackout
			atmosphere.Color = atmosphere.Color:Lerp(Color3.fromRGB(22, 26, 46), blackout)
			atmosphere.Decay = atmosphere.Decay:Lerp(Color3.new(0, 0, 0), blackout)
		end
	end
	return daylight
end

-- Radar helpers
local lastBeep = 0
local lastForward = Vector3.new(0, 0, -1)
local dogDots: { TextLabel } = {}

local function radarPos(offset: Vector3, right: Vector3): UDim2
	local distance = offset.Magnitude
	local x = offset:Dot(right)
	local y = -offset:Dot(lastForward)
	if distance > Config.GpsRange then
		x = x / distance * Config.GpsRange
		y = y / distance * Config.GpsRange
	end
	local scale = (RADAR / 2 - 14) / Config.GpsRange
	return UDim2.new(0.5, x * scale, 0.5, y * scale)
end

local seeParams = RaycastParams.new()
seeParams.FilterType = Enum.RaycastFilterType.Exclude
local seen: { [Instance]: boolean } = {}
local lastLook = 0

-- Enemies near you, and whether you can see them
local function enemies(from: Vector3): { { model: Model, pos: Vector3, icon: string, range: number } }
	local list = {}
	local function scan(folder: Instance?, icon: string, range: number, hunting: boolean)
		if not folder then
			return
		end
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and (not hunting or child:GetAttribute("Hunting")) then
				local pos = child:GetPivot().Position
				if (pos - from).Magnitude < range then
					table.insert(list, { model = child, pos = pos, icon = icon, range = range })
				end
			end
		end
	end
	scan(workspace:FindFirstChild("Dogs"), "🐕", 90, false)
	scan(workspace:FindFirstChild("Neighbors"), "🔦", 90, true)
	scan(workspace:FindFirstChild("Rats"), "🐀", 45, false)
	return list
end

local function showDogs(from: Vector3?, right: Vector3?)
	local marks: { { pos: Vector3, icon: string } } = {}
	if from and right then
		local now = os.clock()
		local list = enemies(from)
		if now - lastLook > 0.25 then
			lastLook = now
			table.clear(seen)
			local eye = from + Vector3.new(0, 1.5, 0)
			for _, e in list do
				seeParams.FilterDescendantsInstances = { player.Character :: Instance, e.model }
				local target = e.pos + Vector3.new(0, 0.5, 0)
				seen[e.model] = workspace:Raycast(eye, target - eye, seeParams) == nil
			end
		end
		for _, e in list do
			if seen[e.model] then
				table.insert(marks, { pos = e.pos, icon = e.icon })
			end
		end
	end
	for i, mark in marks do
		local dot = dogDots[i]
		if not dot then
			dot = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1,
				TextSize = 16,
				ZIndex = 4,
				Parent = radar,
			})
			dogDots[i] = dot
		end
		local offset = mark.pos - (from :: Vector3)
		dot.Text = mark.icon
		dot.Position = radarPos(Vector3.new(offset.X, 0, offset.Z), right :: Vector3)
		dot.Visible = true
	end
	for i = #marks + 1, #dogDots do
		dogDots[i].Visible = false
	end
end

local function nearestKitten(from: Vector3): (Vector3?, number)
	local folder = workspace:FindFirstChild("Kittens")
	local bestPos: Vector3? = nil
	local bestDistance = math.huge
	local count = 0
	if folder then
		for _, kitten in folder:GetChildren() do
			if kitten:IsA("Model") then
				count += 1
				local pos = kitten:GetPivot().Position
				local distance = (pos - from).Magnitude
				if distance < bestDistance then
					bestPos, bestDistance = pos, distance
				end
			end
		end
	end
	return bestPos, count
end

-- Animal sounds
local nextMeow = os.clock() + 4
local nextMew = 0
local nextBark = 0
local barking: { [Instance]: boolean } = {}

local function animalSounds()
	local now = os.clock()
	if now > nextMeow then
		nextMeow = now + math.random(60, 100) / 10
		for _, child in workspace:GetChildren() do
			if child.Name == Config.CatName and child:GetAttribute("Wild") and child:IsA("Model") and child.PrimaryPart then
				playClip(child.PrimaryPart, Config.Meow, 1.5, math.random(95, 105) / 100, 300)
			end
		end
		-- Hidden: the meow comes from her hiding spot
		local spots = workspace:FindFirstChild("Twist")
		if spots then
			for _, spot in spots:GetChildren() do
				if spot:IsA("BasePart") and spot:GetAttribute("Pianka") then
					-- Quiet meow and a rustle only up close; call her to hear her from far
					playClip(spot, Config.Meow, 1, math.random(95, 105) / 100, 40)
					nextMeow = now + math.random(70, 100) / 10
					local root = myRoot()
					if root and (root.Position - spot.Position).Magnitude < 25 then
						shake(spot, 0.6)
					end
				end
			end
		end
	end
	local kittens = workspace:FindFirstChild("Kittens")
	if kittens and now > nextMew then
		nextMew = now + math.random(40, 70) / 10
		local list = kittens:GetChildren()
		local kitten = list[math.random(1, math.max(#list, 1))]
		if kitten and kitten:IsA("Model") and kitten.PrimaryPart then
			playClip(kitten.PrimaryPart, Config.Mew, 1.2, math.random(90, 115) / 100, 160)
		end
	end
	local dogs = workspace:FindFirstChild("Dogs")
	if dogs then
		for _, dog in dogs:GetChildren() do
			local body = (dog :: Model).PrimaryPart
			local bark = body and body:FindFirstChild("TextLabel", true) :: TextLabel?
			local loud = bark ~= nil and bark.Visible
			if loud and not barking[dog] and body and now > nextBark then
				nextBark = now + 0.4
				playClip(body, Config.Bark, 1, math.random(90, 110) / 100, 150)
			end
			barking[dog] = loud
		end
	end
	for dog in barking do
		if not dog.Parent then
			barking[dog] = nil
		end
	end
end

-- Update loop
RunService.RenderStepped:Connect(function(dt: number)
	updateSky()
	runEffects(dt)
	animalSounds()
	local fishFolder = workspace:FindFirstChild("Fish")
	if fishFolder then
		for _, fish in fishFolder:GetChildren() do
			if fish:IsA("BasePart") then
				fish.CFrame *= CFrame.Angles(0, dt * 2, 0)
			end
		end
	end

	local start = workspace:GetAttribute("RoundStart") :: number?
	local catPos = workspace:GetAttribute("CatPosition") :: Vector3?
	local carrierId = workspace:GetAttribute("Carrier") :: number?
	local deadline = workspace:GetAttribute("KittenDeadline") :: number?
	local escape = workspace:GetAttribute("Escape") == true
	local serverNow = workspace:GetServerTimeNow()
	if deadline then
		local left = deadline - serverNow
		timerLabel.Text = "⏳ " .. formatTime(left)
		timerLabel.TextColor3 = if left < 30 then Color3.fromRGB(255, 90, 90) else WHITE
	elseif start and (catPos or carrierId or escape) then
		local carryEnd = workspace:GetAttribute("CarryEnd") :: number?
		if carryEnd and carrierId then
			local left = carryEnd - serverNow
			timerLabel.Text = "🐱 " .. formatTime(left)
			local pulse = if left < 20 then 0.5 + 0.5 * math.sin(os.clock() * 10) else 0
			timerLabel.TextColor3 = WHITE:Lerp(Color3.fromRGB(255, 70, 70), if left < 30 then 0.6 + 0.4 * pulse else 0)
			timerLabel.TextSize = 24 + 4 * pulse
		else
			timerLabel.Text = "⏱ " .. formatTime(serverNow - start)
			timerLabel.TextColor3 = WHITE
			timerLabel.TextSize = 24
		end
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local runner = ((player:GetAttribute("Kittens") :: number?) or 0) > 0

	local target: Vector3?, mode = nil, "cat"
	local kittensLeft = 0
	if catPos then
		target = catPos
	elseif escape and runner then
		target, mode = Config.HomePosition, "escape"
	elseif deadline and root then
		target, kittensLeft = nearestKitten(root.Position)
		mode = "kitten"
	elseif carrierId == player.UserId then
		target, mode = Config.HomePosition, "home"
	end

	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		lastForward = flatLook.Unit
	end
	local right = Vector3.new(-lastForward.Z, 0, lastForward.X)

	local fuzz = 0
	if root and player:GetAttribute("Hero") ~= "Aurelia" then
		for _, e in enemies(root.Position) do
			local near = (e.pos - root.Position).Magnitude
			local reach = if e.icon == "🐀" then 18 else 35
			local weight = if e.icon == "🐀" then 0.6 else 1
			fuzz = math.max(fuzz, math.clamp(1 - (near - 6) / (reach - 6), 0, 1) * weight)
		end
	end
	local now = os.clock()
	if now - lastWobble > 0.12 then
		lastWobble = now
		wobble = Vector2.new(math.random() - 0.5, math.random() - 0.5) * 2
	end
	radar.BackgroundColor3 = RADAR_COLOR:Lerp(Color3.fromRGB(60, 60, 60), fuzz * (0.6 + 0.4 * math.random()))

	if not root or not target then
		catDot.Visible = false
		hintLabel.Text = ""
		showDogs(if root and escape then root.Position else nil, right)
		if escape then
			distanceLabel.Text = "Watch out! 🐕"
		elseif carrierId then
			distanceLabel.Text = nameOf(Players:GetPlayerByUserId(carrierId)) .. " has " .. Config.CatName
		else
			distanceLabel.Text = ""
		end
		return
	end

	local offset = target - root.Position
	offset = Vector3.new(offset.X, 0, offset.Z)
	local distance = offset.Magnitude

	showDogs(root.Position, right)
	-- Enemies nearby, seen or not, make the signal fade
	local danger = 0
	if player:GetAttribute("Hero") ~= "Aurelia" then
		for _, folderName in { "Dogs", "Neighbors" } do
			local folder = workspace:FindFirstChild(folderName)
			for _, m in (if folder then folder:GetChildren() else {}) do
				local body = if m:IsA("Model") then m.PrimaryPart else nil
				if body and (folderName == "Dogs" or m:GetAttribute("Hunting")) then
					danger = math.max(danger, 1 - (body.Position - root.Position).Magnitude / 60)
				end
			end
		end
	end
	local flicker = danger * (0.6 + 0.4 * math.random())
	-- Hard: only the distance. A call shows her for a few seconds, a glitch now and then shows a faint hint
	local blind = workspace:GetAttribute("Mode") == "Hard" and (mode == "cat" or mode == "kitten")
	local revealed = blind and now < hardRadar.reveal
	local glitch = blind and not revealed and now < hardRadar.glitchEnd
	if blind and not revealed and now > hardRadar.nextGlitch then
		hardRadar.nextGlitch = now + math.random(50, 80) / 10
		hardRadar.glitchEnd = now + 0.5
		hardRadar.angle = math.rad(math.random(-40, 40))
	end
	catDot.Visible = not blind or revealed or glitch
	catDot.TextTransparency = if glitch then 0.55 + 0.3 * math.random() else 0.8 * flicker
	distanceLabel.TextTransparency = 0.6 * flicker
	local hidden = mode == "cat" and workspace:GetAttribute("CatHidden") == true
	catDot.Text = if mode == "home" or mode == "escape" then "🏠" elseif mode == "kitten" then "🐈" elseif hidden then "❓" else "🐱"
	local shown = offset
	local jitter = fuzz * 30
	if glitch then
		local c, s = math.cos(hardRadar.angle), math.sin(hardRadar.angle)
		shown = Vector3.new(offset.X * c - offset.Z * s, 0, offset.X * s + offset.Z * c)
		jitter = 25
		radar.BackgroundColor3 = RADAR_COLOR:Lerp(Color3.fromRGB(90, 90, 90), 0.3 + 0.5 * math.random())
	end
	local spot = radarPos(shown, right)
	catDot.Position = spot + UDim2.fromOffset(wobble.X * jitter, wobble.Y * jitter)

	local meters = math.floor(distance * 0.28)
	local label = if mode == "home" or mode == "escape" then "Home" elseif mode == "kitten" then "Kitten" else Config.CatName
	distanceLabel.Text = label .. ": " .. meters .. " m"
	if fuzz > 0.35 or danger > 0.5 then
		hintLabel.Text = "📡 Fuzzy signal!"
	elseif blind then
		hintLabel.Text = if revealed then "There! 👀" elseif distance < 15 then "Right here!" else "Call 📣"
	elseif mode == "escape" then
		hintLabel.Text = "Run! 🐕🐕🐕"
	elseif mode == "home" then
		hintLabel.Text = if distance < 50 then "Almost home!" else "Bring her home!"
	elseif mode == "kitten" then
		hintLabel.Text = kittensLeft .. " of " .. Config.KittenCount .. " kittens left"
	elseif hidden and distance < 45 then
		hintLabel.Text = "Hiding here! Listen 👂"
	elseif distance < 15 then
		hintLabel.Text = "She is right here!"
	elseif distance < 50 then
		hintLabel.Text = "Very close!"
	elseif distance < 150 then
		hintLabel.Text = "Getting closer"
	else
		hintLabel.Text = "Far away"
	end

	local interval = math.clamp(distance / 100, 0.15, 2)
	if playing and now - lastBeep > interval then
		lastBeep = now
		beep.PlaybackSpeed = if distance < 50 then 1.3 else 1
		beep:Play()
	end
end)
