local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local foundEvent = ReplicatedStorage:WaitForChild("PiankaFound") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GREEN = Color3.fromRGB(90, 220, 110)
local FONT = Enum.Font.FredokaOne

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
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -20),
	Size = UDim2.fromOffset(200, 260),
	BackgroundColor3 = Color3.fromRGB(35, 40, 35),
	Parent = gui,
})
round(device, UDim.new(0, 18))
new("UIStroke", { Color = GREEN, Thickness = 3, Parent = device })

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
local radar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 34),
	Size = UDim2.fromOffset(RADAR, RADAR),
	BackgroundColor3 = Color3.fromRGB(15, 45, 22),
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
	Position = UDim2.new(0, 0, 1, -50),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 20,
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

local beep = new("Sound", {
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.3,
	Parent = gui,
})

-- Timer
local timerLabel = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(140, 40),
	BackgroundColor3 = Color3.fromRGB(35, 40, 35),
	BackgroundTransparency = 0.2,
	Font = FONT,
	TextSize = 24,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "⏱ 0:00",
	Parent = gui,
})
round(timerLabel, UDim.new(0, 12))

-- Banner
local banner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromOffset(560, 110),
	BackgroundColor3 = Color3.fromRGB(35, 40, 35),
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextSize = 34,
	TextColor3 = Color3.new(1, 1, 1),
	TextWrapped = true,
	Visible = false,
	Parent = gui,
})
round(banner, UDim.new(0, 18))
new("UIStroke", { Color = GREEN, Thickness = 3, Parent = banner })

local bannerId = 0
local function showBanner(text: string, duration: number)
	bannerId += 1
	local id = bannerId
	banner.Text = text
	banner.Visible = true
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
	Size = UDim2.fromOffset(460, 300),
	BackgroundColor3 = Color3.fromRGB(35, 40, 35),
	ZIndex = 11,
	Parent = intro,
})
round(card, UDim.new(0, 20))
new("UIStroke", { Color = GREEN, Thickness = 4, Parent = card })
new("TextLabel", {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 46,
	TextColor3 = Color3.fromRGB(255, 180, 90),
	Text = Config.GameName .. " 🐱",
	ZIndex = 12,
	Parent = card,
})
new("TextLabel", {
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(180, 180, 180),
	Text = "by " .. Config.Creator,
	ZIndex = 12,
	Parent = card,
})
new("TextLabel", {
	Position = UDim2.fromOffset(30, 110),
	Size = UDim2.new(1, -60, 0, 80),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 22,
	TextWrapped = true,
	TextColor3 = Color3.new(1, 1, 1),
	Text = Config.CatName .. " the cat is lost in the forest! Use your GPS to find her.",
	ZIndex = 12,
	Parent = card,
})
local playButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(180, 56),
	BackgroundColor3 = GREEN,
	Font = FONT,
	TextSize = 30,
	TextColor3 = Color3.fromRGB(20, 40, 20),
	Text = "Play",
	ZIndex = 12,
	Parent = card,
})
round(playButton, UDim.new(0, 14))
local playing = false
playButton.Activated:Connect(function()
	playing = true
	intro:Destroy()
end)

-- Found
foundEvent.OnClientEvent:Connect(function(finder: Player, seconds: number)
	local time = formatTime(seconds)
	if finder == player then
		showBanner("You found " .. Config.CatName .. "! 🎉\nTime: " .. time, 5)
		confetti()
	else
		local name = if finder then finder.DisplayName else "Someone"
		showBanner(name .. " found " .. Config.CatName .. "!\nTime: " .. time, 5)
	end
	task.delay(5, function()
		showBanner(Config.CatName .. " ran away again! Use your GPS.", 3)
	end)
end)

-- Update loop
local lastBeep = 0
local lastForward = Vector3.new(0, 0, -1)

RunService.RenderStepped:Connect(function()
	local start = workspace:GetAttribute("RoundStart")
	local catPos = workspace:GetAttribute("CatPosition")
	if start and catPos then
		timerLabel.Text = "⏱ " .. formatTime(workspace:GetServerTimeNow() - start)
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not catPos then
		catDot.Visible = false
		distanceLabel.Text = if catPos then "" else "Found!"
		hintLabel.Text = ""
		return
	end

	local offset = catPos - root.Position
	offset = Vector3.new(offset.X, 0, offset.Z)
	local distance = offset.Magnitude

	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		lastForward = flatLook.Unit
	end
	local right = Vector3.new(-lastForward.Z, 0, lastForward.X)

	local x = offset:Dot(right)
	local y = -offset:Dot(lastForward)
	if distance > Config.GpsRange then
		x = x / distance * Config.GpsRange
		y = y / distance * Config.GpsRange
	end
	local scale = (RADAR / 2 - 14) / Config.GpsRange
	catDot.Visible = true
	catDot.Position = UDim2.new(0.5, x * scale, 0.5, y * scale)

	local meters = math.floor(distance * 0.28)
	distanceLabel.Text = Config.CatName .. ": " .. meters .. " m"
	if distance < 15 then
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
