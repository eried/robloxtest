-- Pianka the Escape: what you see and hear
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local event = ReplicatedStorage:WaitForChild("Escape") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local world = workspace:WaitForChild("World")
local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 205, 60)
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function new(class: string, props: { [string]: any }): any
	local obj = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(obj :: any)[k] = v
		end
	end
	obj.Parent = props.Parent
	return obj
end
local function round(obj: Instance, r: number)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = obj })
end

-- Sounds
local function source(id: number): Sound?
	if id == 0 then
		return nil
	end
	return new("Sound", { SoundId = "rbxassetid://" .. id, Parent = SoundService })
end
local sfx = source(Config.SfxId)
local voices = source(Config.VoicesId)
local meows = source(Config.SoundsId)
local function playClip(parent: Instance, clip: { number }, volume: number, speed: number, range: number, from: Sound?): Sound?
	if not from then
		return nil
	end
	local s = from:Clone()
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = range
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
	s.Parent = parent
	s:Play()
	task.delay(clip[2] / speed + 1, function()
		s:Destroy()
	end)
	return s
end
local music: Sound? = nil
if Config.MusicId ~= 0 then
	music = new("Sound", { SoundId = "rbxassetid://" .. Config.MusicId, Looped = true, Volume = 0.3, Parent = SoundService })
end

-- Screen
local gui = new("ScreenGui", { Name = "Escape", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })
local keyBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(186, 58),
	BackgroundColor3 = Color3.fromRGB(28, 26, 40),
	BackgroundTransparency = 0.2,
	Parent = gui,
})
round(keyBar, 16)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = keyBar })
local slots: { TextLabel } = {}
for i = 1, Config.KeyCount do
	slots[i] = new("TextLabel", { Size = UDim2.fromOffset(50, 46), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "🔑", TextTransparency = 0.75, Parent = keyBar })
end
local hint = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(420, 28),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 20,
	TextColor3 = Color3.new(1, 1, 1),
	TextStrokeTransparency = 0.4,
	Text = "",
	Parent = gui,
})
local meter = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(260, 34),
	BackgroundColor3 = Color3.fromRGB(28, 26, 40),
	BackgroundTransparency = 0.25,
	Visible = false,
	Parent = gui,
})
round(meter, 12)
local meterFace = new("TextLabel", { Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, TextScaled = true, Text = "😴", Parent = meter })
local meterBack = new("Frame", { Position = UDim2.fromOffset(42, 12), Size = UDim2.new(1, -52, 0, 10), BackgroundColor3 = Color3.fromRGB(70, 70, 90), Parent = meter })
round(meterBack, 5)
local meterFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(120, 220, 140), Parent = meterBack })
round(meterFill, 5)
local banner = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.32),
	Size = UDim2.fromOffset(560, 110),
	BackgroundColor3 = Color3.fromRGB(28, 26, 40),
	BackgroundTransparency = 0.15,
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
	ZIndex = 5,
	Parent = gui,
})
round(banner, 18)
new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = banner })
local bannerId = 0
local function showBanner(text: string, seconds: number)
	bannerId += 1
	local id = bannerId
	banner.Text = text
	banner.Visible = true
	task.delay(seconds, function()
		if bannerId == id then
			banner.Visible = false
		end
	end)
end
local fade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
local function popText(text: string, color: Color3)
	local label = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(520, 48),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 34,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		Text = text,
		ZIndex = 6,
		Parent = gui,
	})
	local tween = TweenService:Create(label, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.47), TextTransparency = 1, TextStrokeTransparency = 1 })
	tween.Completed:Once(function()
		label:Destroy()
	end)
	tween:Play()
end

-- Sprint: Shift, the right trigger or the button on phones
local sprinting = false
local sprintButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -170),
	Size = UDim2.fromOffset(78, 78),
	BackgroundColor3 = Color3.fromRGB(28, 26, 40),
	BackgroundTransparency = 0.2,
	Font = FONT,
	TextScaled = true,
	Text = "💨",
	Visible = touch,
	Parent = gui,
})
round(sprintButton, 39)
sprintButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		sprinting = true
	end
end)
sprintButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		sprinting = false
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		sprinting = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		sprinting = false
	end
end)

-- Sleepers snore. Their Zzz turns into eyes when they are about to wake
type Sleeper = { model: Model, head: BasePart, snore: Sound?, mark: TextLabel }
local sleepers: { Sleeper } = {}
local function addSleeper(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("Sleeper") then
		return
	end
	local head = model:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local clip = Config.Sfx[model:GetAttribute("Snore") :: string] or Config.Sfx.SnoreDeep
	local snore: Sound? = nil
	if sfx then
		snore = sfx:Clone()
		local s = snore :: Sound
		s.Looped = true
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
		s.LoopRegion = NumberRange.new(clip[1], clip[1] + clip[2])
		s.PlaybackSpeed = (model:GetAttribute("Pitch") :: number?) or 1
		s.Volume = 1.3
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = Config.SnoreRange + 30
		s.Parent = head
		s.TimePosition = clip[1] + math.random() * clip[2]
		s:Play()
	end
	local bill = new("BillboardGui", { Size = UDim2.fromOffset(70, 50), StudsOffsetWorldSpace = Vector3.new(0, 5, 0), MaxDistance = 90, Parent = head })
	local mark = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(190, 210, 255), TextStrokeTransparency = 0.5, Text = "Zzz", Parent = bill })
	table.insert(sleepers, { model = model, head = head, snore = snore, mark = mark })
end
for _, d in world:GetDescendants() do
	task.spawn(addSleeper, d)
end
world.DescendantAdded:Connect(function(d)
	task.defer(addSleeper, d)
end)

-- The front door shows its locks
local lockText: TextLabel? = nil
task.spawn(function()
	local door = world:WaitForChild("House"):WaitForChild("ExitDoor", 10)
	if door then
		local bill = new("BillboardGui", { Size = UDim2.fromOffset(150, 50), StudsOffsetWorldSpace = Vector3.new(0, 10, 0), MaxDistance = 70, Parent = door })
		lockText = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = "🔒🔒🔒", Parent = bill })
	end
end)
local function showKeys()
	local n = (workspace:GetAttribute("Keys") :: number?) or 0
	for i, slot in slots do
		slot.TextTransparency = if i <= n then 0 else 0.75
	end
	if lockText then
		lockText.Text = string.rep("🔓", n) .. string.rep("🔒", Config.KeyCount - n)
	end
end
workspace:GetAttributeChangedSignal("Keys"):Connect(showKeys)
showKeys()

-- Moving like a cat: sneak near sleepers, sprint when you dare
local floor2 = Config.Floor2
local sneaking = false
RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local loudest, near = 0, false
	if humanoid and root then
		local up = root.Position.Y > floor2 - 3
		for _, s in sleepers do
			local hp = s.head.Position
			if (hp.Y > floor2 - 3) == up then
				local d = (Vector3.new(hp.X, 0, hp.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d < Config.SnoreRange then
					near = true
				end
				if d < Config.HearRange then
					loudest = math.max(loudest, (s.model:GetAttribute("Sleep") :: number?) or 0)
				end
			end
		end
		sneaking = near and not sprinting
		humanoid.WalkSpeed = if sprinting then Config.SprintSpeed elseif near then Config.SneakSpeed else Config.WalkSpeed
		humanoid.HipHeight = if sneaking then 0.45 else 0.7
	end
	hint.Text = if sneaking then "🐾 Sneaking... someone is asleep" elseif near and sprinting then "💨 Too loud!" else ""
	meter.Visible = loudest > 0 or near
	meterFill.Size = UDim2.fromScale(loudest / 100, 1)
	meterFill.BackgroundColor3 = if loudest > 65 then Color3.fromRGB(255, 90, 90) elseif loudest > 35 then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(120, 220, 140)
	meterFace.Text = if loudest > 65 then "😳" elseif loudest > 35 then "😪" else "😴"
	for _, s in sleepers do
		local sleep = (s.model:GetAttribute("Sleep") :: number?) or 0
		s.mark.Text = if sleep > 65 then "😳" elseif sleep > 35 then "z?" else "Zzz"
		if s.snore then
			s.snore.Volume = if sleep > 65 then 0.2 else 1.3
		end
	end
end)

-- Legs and tail move on every cat, keys spin, camera lights blink
local stride = 0
local bases: { [Weld]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local keyBases: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
RunService.RenderStepped:Connect(function(dt: number)
	stride += dt * 14
	local t = os.clock()
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			local v = root.AssemblyLinearVelocity
			local moving = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 10, 0, 1)
			for _, p in character:GetChildren() do
				local weld = p:FindFirstChildOfClass("Weld")
				if weld and p:IsA("BasePart") then
					local base = bases[weld] or weld.C0
					bases[weld] = base
					local swing = p:GetAttribute("Swing")
					if type(swing) == "number" then
						weld.C0 = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(math.sin(stride) * 0.7 * moving * swing, 0, 0) * CFrame.new(0, -0.4, 0)
					elseif p:GetAttribute("Wag") then
						weld.C0 = base * CFrame.Angles(0, math.sin(t * 3) * 0.35, 0)
					end
				end
			end
		end
	end
	local keys = world:FindFirstChild("Keys")
	for _, key in (if keys then keys:GetChildren() else {}) do
		if key:IsA("Model") then
			local base = keyBases[key] or key:GetPivot()
			keyBases[key] = base
			key:PivotTo(base * CFrame.new(0, math.sin(t * 2.5) * 0.4, 0) * CFrame.Angles(0, t * 2, 0))
		end
	end
end)

-- Clips
local function letterbox(on: boolean)
	for _, y in { 0, 1 } do
		local bar = gui:FindFirstChild("Bar" .. y)
		if on and not bar then
			new("Frame", { Name = "Bar" .. y, AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 15, Parent = gui })
		elseif not on and bar then
			bar:Destroy()
		end
	end
end

-- Pianka asleep in her bed, dreaming of a mouse and a hug from Milenkitka
local introOn = false
local function intro()
	introOn = true
	local bed = (workspace:GetAttribute("CatBed") :: Vector3?) or Vector3.zero
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	keyBar.Visible = false
	local skip = new("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.fromOffset(100, 40), BackgroundColor3 = Color3.fromRGB(28, 26, 40), Font = FONT, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), Text = "Skip ▶", ZIndex = 16, Parent = gui })
	round(skip, 12)
	local bubble = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.36), Size = UDim2.fromOffset(330, 150), BackgroundColor3 = Color3.fromRGB(255, 235, 248), BackgroundTransparency = 1, Font = FONT, TextScaled = true, TextColor3 = Color3.fromRGB(90, 50, 90), TextTransparency = 1, Text = "", ZIndex = 16, Parent = gui })
	round(bubble, 60)
	local done = false
	skip.Activated:Connect(function()
		done = true
	end)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if sfx and root then
		playClip(root, Config.Sfx.Purr, 1, 1, 40, sfx)
	end
	local start = os.clock()
	local steps: { { any } } = {
		{ 2.5, "💤" },
		{ 4.5, "🐭💨" },
		{ 6.5, "🐈💥🐭 Got it!" },
		{ 8.8, "🤗 Milenkitka: My hero! 💕" },
	}
	local shown = 0
	while not done and os.clock() - start < 12 do
		local t = os.clock() - start
		local a = t * 0.18
		camera.CFrame = CFrame.lookAt(bed + Vector3.new(math.sin(a) * 9, 5 - t * 0.15, math.cos(a) * 9), bed + Vector3.new(0, 0.5, 0))
		for i, s in steps do
			if t >= s[1] and shown < i then
				shown = i
				bubble.Text = s[2]
				bubble.BackgroundTransparency = 0.1
				bubble.TextTransparency = 0
				if i == 2 and sfx then
					playClip(SoundService, Config.Sfx.Dream, 0.8, 1, 1000, sfx)
				elseif i == 4 and meows then
					playClip(SoundService, Config.Mew, 0.8, 1.1, 1000, meows)
				end
			end
		end
		RunService.RenderStepped:Wait()
	end
	bubble:Destroy()
	skip:Destroy()
	letterbox(false)
	keyBar.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	introOn = false
	showBanner("Escape the house! 🔑🔑🔑\nFind 3 keys. Don't wake anyone up.", 5)
	if music then
		music:Play()
	end
end

local function wakeClip(name: string, at: Vector3)
	if introOn then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	local start = os.clock()
	if sfx then
		playClip(SoundService, Config.Sfx.Snort, 1.4, 1, 1000, sfx)
	end
	task.delay(0.8, function()
		if voices then
			local calls = Config.Calls
			playClip(SoundService, calls[math.random(1, #calls)], 1.6, 1, 1000, voices)
		end
	end)
	showBanner("😳 " .. name .. " woke up!\n\"PIANKA!\" Back to bed...", Config.CaughtTime - 0.5)
	while os.clock() - start < Config.CaughtTime - 1 do
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(at + Vector3.new(6 - t, 4 + t * 0.4, 7), at + Vector3.new(0, 1, 0))
		RunService.RenderStepped:Wait()
	end
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	task.wait(0.9)
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

event.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "key" then
		if sfx then
			playClip(SoundService, Config.Sfx.Key, 1, 1, 1000, sfx)
		end
		local who = if a == player then "You" else (a and a.DisplayName or "Someone")
		popText(who .. " found a key! 🔑 " .. tostring(b) .. "/" .. Config.KeyCount, GOLD)
	elseif kind == "allKeys" then
		if sfx then
			playClip(SoundService, Config.Sfx.AllKeys, 1, 1, 1000, sfx)
			task.delay(1.2, function()
				playClip(SoundService, Config.Sfx.Unlock, 1, 1, 1000, sfx)
			end)
		end
		showBanner("All 3 keys! 🔓\nThe front door is open. Run! 🐈", 5)
	elseif kind == "toy" and typeof(a) == "Instance" then
		local model = a :: Model
		local main = model.PrimaryPart
		if main and sfx then
			local clip = if b == "ballTrack" then Config.Sfx.Track elseif math.random() < 0.5 then Config.Sfx.Squeak else Config.Sfx.Squeak2
			playClip(main, clip, 2, 0.9 + math.random() * 0.2, 120, sfx)
			popText(if b == "ballTrack" then "Rattle rattle! 🔴" else "SQUEAK! 🐤", Color3.fromRGB(255, 220, 120))
			local base = main.CFrame
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and p.Name == "Ball" then
					local center = main.Position
					local start = os.clock()
					task.spawn(function()
						local radius = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
						while os.clock() - start < 2.2 and p.Parent do
							local k = os.clock() - start
							local ang = k * 12 * math.exp(-k * 0.9)
							p.Position = center + Vector3.new(math.cos(ang) * radius, p.Position.Y - center.Y, math.sin(ang) * radius)
							RunService.Heartbeat:Wait()
						end
					end)
				end
			end
			TweenService:Create(main, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 2, true), { CFrame = base * CFrame.new(0, 0.5, 0) }):Play()
		end
	elseif kind == "tease" then
		if voices then
			local calls = Config.Calls
			playClip(SoundService, calls[math.random(1, #calls)], 0.45, 1, 1000, voices)
		end
		popText("Upstairs: \"Piaaaanka?\" 😴", Color3.fromRGB(200, 200, 255))
	elseif kind == "wake" then
		task.spawn(wakeClip, tostring(a), b)
	elseif kind == "escaped" then
		local who = if a == player then "You" else (a and a.DisplayName or "Someone")
		if a == player and meows then
			playClip(SoundService, Config.Meow, 1, 1.05, 1000, meows)
		end
		showBanner("🎉 " .. who .. " escaped the house!\nNext: the backyard... coming soon 🌙", 8)
	elseif kind == "round" then
		showKeys()
		showBanner("Back in bed. Try again! 🔑🔑🔑", 3)
	end
end)

-- Start
player.CharacterAdded:Connect(function()
	showKeys()
end)
task.spawn(function()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	task.wait(1)
	intro()
end)
