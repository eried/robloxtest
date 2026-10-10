local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local catEvent = ReplicatedStorage:WaitForChild("PiankaEvent") :: RemoteEvent
local modeEvent = ReplicatedStorage:WaitForChild("SetMode") :: RemoteEvent
local sayEvent = ReplicatedStorage:WaitForChild("NeighborSay") :: RemoteEvent

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

-- GPS device
local device = new("Frame", {
	AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1),
	Position = if touch then UDim2.new(1, -10, 0, 60) else UDim2.new(1, -20, 1, -20),
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
	Parent = gui,
})

local clipSound: Sound? = nil
if Config.SoundsId ~= 0 then
	local sound = new("Sound", { SoundId = "rbxassetid://" .. Config.SoundsId, Parent = SoundService })
	clipSound = sound
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound })
	end)
end

local function playClip(parent: Instance, clip: { any }, volume: number, speed: number, range: number)
	if not clipSound then
		return
	end
	local sound = clipSound:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = range
	sound.TimePosition = clip[1]
	sound.Parent = parent
	sound:Play()
	task.delay(clip[2] / speed, function()
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

local menuButton = topButton("Menu", -120, 80)
local musicButton = topButton("🎵", 100, 40)
musicButton.Visible = Config.MusicId ~= 0
musicButton.Activated:Connect(function()
	music.Playing = not music.Playing
	musicButton.Text = if music.Playing then "🎵" else "🔇"
end)

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
local function showBanner(text: string, duration: number)
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
	Parent = gui,
})
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(540, 450),
	BackgroundColor3 = PANEL,
	ZIndex = 11,
	Parent = intro,
})
round(card, UDim.new(0, 20))
outline(card, 4)
if touch then
	new("UIScale", { Scale = 0.7, Parent = card })
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
cardText(Config.GameName .. " 🐱", 14, 50, 46, Color3.fromRGB(255, 180, 90))
cardText("by " .. Config.Creator, 62, 22, 18, GRAY)
cardText(Config.CatName .. " the cat is lost in the dark forest. Use your GPS to find her!", 90, 52, 21, WHITE)
cardText("Who are you?", 146, 26, 22, GREEN)
cardText("Pick a mode", 276, 26, 22, GREEN)

local selectedHero = "Patrick"
local heroStrokes: { [string]: UIStroke } = {}
local modeStrokes: { [string]: UIStroke } = {}

local function refreshIntro()
	for name, stroke in heroStrokes do
		stroke.Enabled = name == selectedHero
	end
	for name, stroke in modeStrokes do
		stroke.Enabled = name == workspace:GetAttribute("Mode")
	end
end

for i, name in Config.HeroOrder do
	local hero = Config.Heroes[name]
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 176),
		Size = UDim2.fromOffset(156, 86),
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
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 26,
		TextColor3 = WHITE,
		Text = hero.Emoji .. " " .. name,
		ZIndex = 13,
		Parent = button,
	})
	new("TextLabel", {
		Position = UDim2.fromOffset(6, 48),
		Size = UDim2.new(1, -12, 0, 32),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
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

local DARK = Color3.fromRGB(20, 20, 20)
local MODES = {
	{ mode = "Easy", color = GREEN, note = "Find her", text = DARK },
	{ mode = "Hard", color = Color3.fromRGB(255, 120, 90), note = "7 kittens!", text = DARK },
	{ mode = "Umulig", color = Color3.fromRGB(150, 25, 40), note = "Almost impossible", text = WHITE },
}
for i, info in MODES do
	local mode = info.mode
	local button = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 306),
		Size = UDim2.fromOffset(156, 60),
		BackgroundColor3 = info.color,
		Font = FONT,
		TextSize = 28,
		TextColor3 = info.text,
		Text = mode,
		ZIndex = 12,
		Parent = card,
	})
	round(button, UDim.new(0, 14))
	modeStrokes[mode] = new("UIStroke", {
		Color = WHITE,
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = button,
	})
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, (i - 2) * 168, 0, 370),
		Size = UDim2.fromOffset(156, 22),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 16,
		TextColor3 = GRAY,
		Text = info.note,
		ZIndex = 12,
		Parent = card,
	})
	button.Activated:Connect(function()
		playing = true
		modeEvent:FireServer(mode, selectedHero)
		if Config.MusicId ~= 0 and not music.IsPlaying and musicButton.Text == "🎵" then
			music:Play()
		end
		intro.Visible = false
	end)
end
cardText("The mode is the same for everyone here.", 404, 22, 15, GRAY)
refreshIntro()
workspace:GetAttributeChangedSignal("Mode"):Connect(refreshIntro)

menuButton.Activated:Connect(function()
	refreshIntro()
	intro.Visible = true
end)

-- Events
local best: { [string]: number } = {}

local function nameOf(who: Player?): string
	return if who then who.DisplayName else "Someone"
end

local function winText(text: string, seconds: number): string
	local mode = workspace:GetAttribute("Mode") :: string? or "Easy"
	text ..= "\nTime: " .. formatTime(seconds)
	if seconds < (best[mode] or math.huge) then
		if best[mode] then
			text ..= "  New record! ⭐"
		end
		best[mode] = seconds
	end
	return text
end

local function tryAgain(delay: number)
	task.delay(delay, function()
		showBanner("Try again! Use your GPS.", 3)
	end)
end

catEvent.OnClientEvent:Connect(function(kind: string, who: Player?, value: any)
	local cat = Config.CatName
	local seconds = if type(value) == "number" then value else 0
	if kind == "picked" then
		if who == player then
			showBanner("You found " .. cat .. "! 🐱\nBring her home to her bed.", 4)
			chime()
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
		task.delay(6, function()
			showBanner(cat .. " ran away again! Use your GPS.", 3)
		end)
	elseif kind == "lost" then
		showBanner("Oh no! " .. cat .. " ran away!", 3)
		tryAgain(3)
	elseif kind == "fled" then
		showBanner(cat .. " ran off! Chase her!", 2)
	elseif kind == "kittens" then
		showBanner("💥 Pop! " .. cat .. " is safe at home.\nFind her " .. Config.KittenCount .. " kittens!", 5)
		chime()
	elseif kind == "kitten" then
		local finder = if who == player then "You" else nameOf(who)
		showBanner(finder .. " found a kitten! 🐾\n" .. seconds .. " left", 2)
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
		showBanner(if runner then "🐕 Dogs! Run home!" else "🐕 Dogs! Watch out!", 2)
	elseif kind == "caught" then
		showBanner("The dogs got " .. (if who == player then "you" else nameOf(who)) .. "! 🐕\nThe kittens ran home.", 5)
		tryAgain(5)
	elseif kind == "escaped" then
		showBanner(winText("You beat UMULIG! 🏆", seconds), 6)
		confetti()
		chime()
		task.delay(8, function()
			showBanner(cat .. " ran away again! Use your GPS.", 3)
		end)
	elseif kind == "timeUp" then
		showBanner("Time's up! ⏰\nThe kittens ran home.", 4)
		tryAgain(4)
	elseif kind == "mode" then
		showBanner(nameOf(who) .. " picked " .. tostring(value) .. "!\nNew round.", 3)
	end
end)

sayEvent.OnClientEvent:Connect(function(head: BasePart, index: number, pitch: number)
	local line = Config.Lines[index]
	if line and head then
		playClip(head, line, 1, pitch, 90)
	end
end)

-- Day and night
local START_PHASE = Config.NightShare + (1 - Config.NightShare) * 10.5 / 12
local DAY_AMBIENT = Color3.fromRGB(120, 140, 120)
local NIGHT_AMBIENT = Color3.fromRGB(8, 10, 20)
local tint = new("ColorCorrectionEffect", { Parent = Lighting })

local function updateSky(): number
	local dayStart = workspace:GetAttribute("DayStart") :: number?
	if not dayStart then
		return 1
	end
	local phase = ((workspace:GetServerTimeNow() - dayStart) / (Config.DayMinutes * 60) + START_PHASE) % 1
	local clock = if phase < Config.NightShare
		then (18 + 12 * phase / Config.NightShare) % 24
		else 6 + 12 * (phase - Config.NightShare) / (1 - Config.NightShare)
	local daylight = math.clamp(math.sin((clock - 6) / 12 * math.pi) * 3, 0, 1)
	local dark = 1 - daylight
	Lighting.ClockTime = clock
	Lighting.Brightness = 0.05 + 1.95 * daylight
	Lighting.OutdoorAmbient = NIGHT_AMBIENT:Lerp(DAY_AMBIENT, daylight)
	Lighting.Ambient = Color3.fromRGB(5, 6, 12):Lerp(Color3.fromRGB(70, 75, 70), daylight)

	local mode = workspace:GetAttribute("Mode")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local base = if mode == "Umulig" then 0.75 elseif mode == "Hard" then 0.65 else 0.45
		atmosphere.Density = base + 0.1 * dark
		atmosphere.Color = Color3.fromRGB(40, 48, 70):Lerp(Color3.fromRGB(190, 215, 190), daylight)
		atmosphere.Decay = Color3.fromRGB(20, 25, 40):Lerp(Color3.fromRGB(90, 120, 90), daylight)
	end
	tint.TintColor = Color3.fromRGB(170, 185, 255):Lerp(Color3.new(1, 1, 1), daylight)
	tint.Saturation = -0.35 * dark
	return daylight
end

-- Radar helpers
local lastBeep = 0
local lastForward = Vector3.new(0, 0, -1)
local dogDots: { TextLabel } = {}
local nextGlitch = 0
local glitchUntil = 0

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

local function showDogs(from: Vector3?, right: Vector3?)
	local dogs = workspace:FindFirstChild("Dogs")
	local list: { Instance } = if dogs and from and right then dogs:GetChildren() else {}
	for i, dog in list do
		local dot = dogDots[i]
		if not dot then
			dot = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(20, 20),
				BackgroundTransparency = 1,
				TextSize = 16,
				Text = "🐕",
				ZIndex = 4,
				Parent = radar,
			})
			dogDots[i] = dot
		end
		local pos = (dog :: Model):GetPivot().Position - (from :: Vector3)
		dot.Position = radarPos(Vector3.new(pos.X, 0, pos.Z), right :: Vector3)
		dot.Visible = true
	end
	for i = #list + 1, #dogDots do
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
			if loud and not barking[dog] and body then
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
RunService.RenderStepped:Connect(function()
	updateSky()
	animalSounds()

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
		timerLabel.Text = "⏱ " .. formatTime(serverNow - start)
		timerLabel.TextColor3 = WHITE
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

	local hard = workspace:GetAttribute("Mode") ~= "Easy"
	if hard and player:GetAttribute("Hero") ~= "Aurelia" and root then
		local now = os.clock()
		if nextGlitch == 0 then
			nextGlitch = now + 12
		elseif now > nextGlitch then
			glitchUntil = now + math.random(3, 5)
			nextGlitch = glitchUntil + math.random(10, 18)
		end
		if now < glitchUntil then
			local static = math.random(20, 60)
			radar.BackgroundColor3 = Color3.fromRGB(static, static, static)
			catDot.Visible = false
			showDogs(nil, nil)
			distanceLabel.Text = "No signal"
			hintLabel.Text = "..."
			return
		end
	end
	radar.BackgroundColor3 = RADAR_COLOR

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
	catDot.Visible = true
	catDot.Text = if mode == "home" or mode == "escape" then "🏠" elseif mode == "kitten" then "🐾" else "🐱"
	catDot.Position = radarPos(offset, right)

	local meters = math.floor(distance * 0.28)
	local label = if mode == "home" or mode == "escape" then "Home" elseif mode == "kitten" then "Kitten" else Config.CatName
	distanceLabel.Text = label .. ": " .. meters .. " m"
	if mode == "escape" then
		hintLabel.Text = "Run! 🐕🐕🐕"
	elseif mode == "home" then
		hintLabel.Text = if distance < 50 then "Almost home!" else "Bring her home!"
	elseif mode == "kitten" then
		hintLabel.Text = kittensLeft .. " of " .. Config.KittenCount .. " kittens left"
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
	local now = os.clock()
	if playing and now - lastBeep > interval then
		lastBeep = now
		beep.PlaybackSpeed = if distance < 50 then 1.3 else 1
		beep:Play()
	end
end)
