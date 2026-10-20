-- Pianka the Escape: what you see and hear. Sounds and pictures tell the story, no text
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Watch = require(Shared:WaitForChild("Watch"))
local Cat = require(Shared:WaitForChild("Cat"))
local event = ReplicatedStorage:WaitForChild("Escape") :: RemoteEvent

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local world = workspace:WaitForChild("World")
local GOLD = Color3.fromRGB(255, 205, 60)
local SFX = Config.Sfx

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
local function usingPad(): boolean
	return string.find(tostring(UserInputService:GetLastInputType()), "Gamepad", 1, true) ~= nil
end
local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Sounds: one sheet of clips, preloaded. A clip only plays once its sound is loaded,
-- before that Roblox does not know how long it is and cuts the clip to nothing
local function source(id: number, looped: boolean?): Sound?
	if id == 0 then
		return nil
	end
	return new("Sound", { SoundId = "rbxassetid://" .. id, Looped = looped == true, Volume = 0, Parent = SoundService })
end
local sfx = source(Config.SfxId)
local voices = source(Config.VoicesId)
local meows = source(Config.SoundsId)
local music = source(Config.MusicId, true)
local tense = source(Config.TenseId, true)
local dreamBox = source(Config.DreamId)
task.spawn(function()
	local list = {}
	for _, s in { sfx, voices, meows, music, tense, dreamBox } do
		if s then
			table.insert(list, s)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list, function(asset: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				warn("Sound did not load:", asset, status)
			end
		end)
	end)
end)

-- Runs f once the sound has loaded, or warns after a while
local function whenLoaded(s: Sound, f: () -> ())
	if s.IsLoaded then
		f()
		return
	end
	local fired = false
	local conn = s.Loaded:Once(function()
		if not fired then
			fired = true
			f()
		end
	end)
	task.delay(15, function()
		conn:Disconnect()
		if not fired then
			fired = true
			if s.IsLoaded then
				f()
			else
				warn("Sound still not loaded:", s.SoundId)
			end
		end
	end)
end

-- One clip from a sound sheet. Little sounds are skipped until the sheet has loaded
local function playClip(parent: Instance, clip: { number }?, volume: number, speed: number, range: number, from: Sound?, optional: boolean?): Sound?
	if not from or not clip then
		return nil
	end
	local source = from :: Sound
	if optional and not source.IsLoaded then
		return nil
	end
	local c = clip :: { number }
	local s = source:Clone()
	s.Volume = volume
	s.Looped = false
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = range
	s.Parent = parent
	whenLoaded(source, function()
		if not s.Parent then
			return
		end
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(c[1], c[1] + c[2])
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(c[2] / speed + 1, function()
			s:Destroy()
		end)
	end)
	task.delay(18, function()
		if not s.IsPlaying then
			s:Destroy()
		end
	end)
	return s
end
local function sound(name: string, volume: number?, speed: number?, parent: Instance?, range: number?): Sound?
	return playClip(parent or SoundService, SFX[name], volume or 1, speed or 1, range or 1000, sfx)
end
-- Pianka's own little sounds play close to the ear
local function small(name: string, volume: number, speed: number?)
	playClip(SoundService, SFX[name], volume, speed or 1, 1000, sfx, true)
end
local function voice(clip: { number }, volume: number, speed: number?)
	playClip(SoundService, clip, volume, speed or 1, 1000, voices)
end
local function meow(clip: { number }, volume: number, speed: number?, parent: Instance?)
	playClip(parent or SoundService, clip, volume, speed or 1, 120, meows)
end

-- Music: the sneaky tune and its tense layer play in sync. Danger fades the tense one in
local danger, spike = 0, 0
local musicOn = false
local function startMusic()
	if musicOn or not music then
		return
	end
	musicOn = true
	local calm = music :: Sound
	whenLoaded(calm, function()
		calm.TimePosition = 0
		calm:Play()
		if tense then
			local t = tense :: Sound
			whenLoaded(t, function()
				t.TimePosition = calm.TimePosition
				t:Play()
			end)
		end
	end)
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
for i = 1, math.max(Config.KeyCount, Config.GateKeyCount) do
	slots[i] = new("TextLabel", { Size = UDim2.fromOffset(50, 46), BackgroundTransparency = 1, TextScaled = true, Text = "🔑", TextTransparency = 0.75, Parent = keyBar })
end
local meter = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(220, 34),
	BackgroundColor3 = Color3.fromRGB(28, 26, 40),
	BackgroundTransparency = 0.25,
	Visible = false,
	Parent = gui,
})
round(meter, 12)
new("TextLabel", { Position = UDim2.fromOffset(6, 2), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, TextScaled = true, Text = "📹", Parent = meter })
local meterBack = new("Frame", { Position = UDim2.fromOffset(42, 12), Size = UDim2.new(1, -52, 0, 10), BackgroundColor3 = Color3.fromRGB(70, 70, 90), Parent = meter })
round(meterBack, 5)
local meterFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 90, 90), Parent = meterBack })
round(meterFill, 5)
local fade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })

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

-- A picture above something in the world that pops and floats away
local function popIcon(at: Instance, icon: string, seconds: number?, size: number?)
	local s = size or 64
	local bill = new("BillboardGui", { Size = UDim2.fromOffset(s, s), StudsOffsetWorldSpace = Vector3.new(0, 4, 0), AlwaysOnTop = true, MaxDistance = 200, Parent = at })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = icon, Parent = bill })
	local d = seconds or 1.4
	TweenService:Create(bill, TweenInfo.new(d, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 7, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(d * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, d * 0.6), { TextTransparency = 1 }):Play()
	task.delay(d + 0.1, function()
		bill:Destroy()
	end)
end

-- Clips can be skipped with the button or A, B, X on a controller
local clipOn = false
local skipClip: (() -> ())? = nil
local function skipButton(): TextButton
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(64, 48),
		BackgroundColor3 = Color3.fromRGB(28, 26, 40),
		BackgroundTransparency = 0.2,
		TextScaled = true,
		Text = "⏭",
		ZIndex = 18,
		Parent = gui,
	})
	round(b, 14)
	if usingPad() then
		GuiService.SelectedObject = b
	end
	return b
end
UserInputService.InputBegan:Connect(function(input)
	local k = input.KeyCode
	if skipClip and (k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.ButtonX) then
		skipClip()
	end
end)

-- Keys in the bar: 🔑 for the house, 🗝️ for the gate
local function showKeys()
	local yard = workspace:GetAttribute("Stage") == "yard"
	local n = (workspace:GetAttribute(if yard then "GateKeys" else "Keys") :: number?) or 0
	local total = if yard then Config.GateKeyCount else Config.KeyCount
	for i, slot in slots do
		slot.Visible = i <= total
		slot.Text = if yard then "🗝️" else "🔑"
		slot.TextTransparency = if i <= n then 0 else 0.75
	end
	keyBar.BackgroundColor3 = if yard then Color3.fromRGB(26, 44, 34) else Color3.fromRGB(28, 26, 40)
end
for _, name in { "Keys", "GateKeys", "Stage" } do
	workspace:GetAttributeChangedSignal(name):Connect(showKeys)
end
showKeys()

-- A found key flies from the world into its slot
local function flyKey(from: Vector3, index: number, gateKey: boolean)
	local p, onScreen = camera:WorldToViewportPoint(from)
	local slot = slots[index]
	if not slot then
		return
	end
	local start = if onScreen then UDim2.fromOffset(p.X, p.Y) else UDim2.fromScale(0.5, 0.5)
	local icon = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = start, Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, TextScaled = true, Text = if gateKey then "🗝️" else "🔑", ZIndex = 12, Parent = gui })
	local goal = (slot.AbsolutePosition or Vector2.zero) + (slot.AbsoluteSize or Vector2.zero) / 2
	sound("Whoosh", 0.6)
	local tween = TweenService:Create(icon, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(46, 46) })
	tween.Completed:Once(function()
		icon:Destroy()
		showKeys()
		local grow = TweenService:Create(slot, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 1, true), { Size = UDim2.fromOffset(62, 58) })
		grow:Play()
	end)
	tween:Play()
end

-- Sleepers breathe. A snort means they are about to look around: freeze!
type Sleeper = { model: Model, head: BasePart, breath: Sound?, mark: TextLabel, phase: string }
local sleepers: { Sleeper } = {}
local MARKS = { sleep = "💤", warn = "❗", look = "👀", awake = "‼️" }
local function addSleeper(model: Instance)
	if not model:IsA("Model") or not model:GetAttribute("Sleeper") then
		return
	end
	local head = model:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local clip = SFX[model:GetAttribute("Snore") :: string] or SFX.Breath
	local breath: Sound? = nil
	if sfx then
		local s = (sfx :: Sound):Clone()
		s.Looped = true
		s.PlaybackSpeed = (model:GetAttribute("Pitch") :: number?) or 1
		s.Volume = 1.6
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 7
		s.RollOffMaxDistance = Config.SnoreRange + 30
		s.Parent = head
		breath = s
		whenLoaded(s, function()
			s.PlaybackRegionsEnabled = true
			s.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
			s.LoopRegion = NumberRange.new(clip[1], clip[1] + clip[2])
			s.TimePosition = clip[1] + math.random() * clip[2]
			s:Play()
		end)
	end
	local bill = new("BillboardGui", { Size = UDim2.fromOffset(56, 56), StudsOffsetWorldSpace = Vector3.new(0, 5, 0), MaxDistance = 90, Parent = head })
	local mark = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = MARKS.sleep, Parent = bill })
	local entry: Sleeper = { model = model, head = head, breath = breath, mark = mark, phase = "sleep" }
	table.insert(sleepers, entry)
	model:GetAttributeChangedSignal("Stir"):Connect(function()
		local phase = (model:GetAttribute("Stir") :: string?) or "sleep"
		entry.phase = phase
		mark.Text = MARKS[phase] or MARKS.sleep
		local kid = model:GetAttribute("Sleeper") ~= "Milenkitka"
		if phase == "warn" then
			sound("Snort", 1.5, if kid then 1.2 else 1, head, 90)
		elseif phase == "look" then
			sound(if kid then "HmmKid" else "Hmm", 1.4, 1, head, 90)
		end
		if breath then
			TweenService:Create(breath, TweenInfo.new(0.4), { Volume = if phase == "sleep" then 1.6 else 0 }):Play()
		end
	end)
end
for _, d in world:GetDescendants() do
	task.spawn(addSleeper, d)
end

-- The wall clock ticks in the living room downstairs
task.spawn(function()
	task.wait(2)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Ticks") and sfx then
			local s = (sfx :: Sound):Clone()
			s.Looped = true
			s.Volume = 0.8
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 6
			s.RollOffMaxDistance = 70
			s.Parent = d
			whenLoaded(s, function()
				s.PlaybackRegionsEnabled = true
				s.PlaybackRegion = NumberRange.new(SFX.Clock[1], SFX.Clock[1] + SFX.Clock[2])
				s.LoopRegion = s.PlaybackRegion
				s:Play()
			end)
			break
		end
	end
end)

-- Backyard cameras turn, blink and light a red cone on the ground
type Cam = { model: Model, eye: Vector3, yaw: number, phase: number, period: number, cone: { BasePart }, led: BasePart?, reach: { [number]: number } }
local cams: { Cam } = {}
local coneFolder = new("Folder", { Name = "Cones", Parent = workspace })
local RED = Color3.fromRGB(255, 60, 60)
local SLICES = 6
local function addCam(model: Instance)
	if not model:IsA("Model") or model.Name ~= "Cam" then
		return
	end
	local head = model:WaitForChild("Camera", 5) :: BasePart?
	if not head then
		return
	end
	local cone = {}
	for i = 1, SLICES * 2 do
		cone[i] = new("WedgePart", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = RED, Transparency = 0.8, Size = Vector3.one * 0.1, Parent = coneFolder })
	end
	new("SpotLight", { Color = RED, Brightness = 3, Range = Config.CameraRange, Angle = Config.CameraHalf * 2, Face = Enum.NormalId.Front, Parent = head })
	table.insert(cams, {
		model = model,
		eye = head.Position,
		yaw = (model:GetAttribute("Yaw") :: number?) or 0,
		phase = (model:GetAttribute("Phase") :: number?) or 0,
		period = (model:GetAttribute("Period") :: number?) or Config.CameraPeriod,
		cone = cone,
		led = model:FindFirstChild("Led") :: BasePart?,
		reach = {},
	})
end
for _, d in world:GetDescendants() do
	task.spawn(addCam, d)
end

-- Garage buttons get a marker, the door hums when it moves
local function addButton(p: Instance)
	if p:IsA("BasePart") and p.Name == "GarageButton" then
		local bill = new("BillboardGui", { Size = UDim2.fromOffset(44, 44), StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0), MaxDistance = 80, Parent = p })
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = "🔘", Parent = bill })
	end
end
for _, d in world:GetDescendants() do
	addButton(d)
end
world.DescendantAdded:Connect(function(d)
	task.defer(addSleeper, d)
	task.defer(addCam, d)
	addButton(d)
end)
local function yardPart(name: string): BasePart?
	local yard = world:FindFirstChild("Yard")
	return yard and yard:FindFirstChild(name) :: BasePart?
end
workspace:GetAttributeChangedSignal("Garage"):Connect(function()
	local door = yardPart("GarageDoor")
	if door and workspace:GetAttribute("Garage") == "closing" then
		sound("Gate", 1.2, SFX.Gate[2] / Config.GarageCloseTime, door, 160)
	end
end)

-- A flat triangle from two wedges
local function triangle(a: Vector3, b: Vector3, c: Vector3, w1: BasePart, w2: BasePart)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(0.05, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	w2.Size = Vector3.new(0.05, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

local beepAt = 0
local camNear = 0
local conesAt = 0
local conesShown = true
local seenRay = RaycastParams.new()
seenRay.FilterType = Enum.RaycastFilterType.Exclude
RunService.RenderStepped:Connect(function()
	-- Only in the yard, and 30 times a second is plenty
	local inYard = workspace:GetAttribute("Stage") == "yard" or player:GetAttribute("Out") == true
	if not inYard then
		camNear = 0
		meter.Visible = false
		if conesShown then
			conesShown = false
			for _, c in cams do
				for _, w in c.cone do
					w.Transparency = 1
				end
			end
		end
		return
	end
	if os.clock() < conesAt then
		return
	end
	conesAt = os.clock() + 1 / 30
	conesShown = true
	local t = workspace:GetServerTimeNow()
	local half = math.rad(Config.CameraHalf)
	local root = myRoot()
	local out = player:GetAttribute("Out") == true
	local seen = (player:GetAttribute("Seen") :: number?) or 0
	local yard = world:FindFirstChild("Yard")
	local filter: { Instance } = { coneFolder, yard and yard:FindFirstChild("Cameras") or coneFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(filter, other.Character)
		end
	end
	local keys = world:FindFirstChild("Keys")
	if keys then
		table.insert(filter, keys)
	end
	seenRay.FilterDescendantsInstances = filter
	camNear = 0
	for _, c in cams do
		local look = Watch.look(c.yaw, c.phase, t, c.period)
		c.model:PivotTo(CFrame.lookAt(c.eye, c.eye + look * 10 - Vector3.new(0, 4, 0)))
		if c.led then
			c.led.Transparency = if math.floor(t * 2) % 2 == 0 then 0 else 0.85
		end
		-- The cone on the ground stops at walls and bushes
		local apex = Vector3.new(c.eye.X, 0.3, c.eye.Z)
		local yaw = math.atan2(look.X, -look.Z)
		local points = {}
		for i = 0, SLICES do
			local a = yaw - half + i * half * 2 / SLICES
			local dir = Vector3.new(math.sin(a), 0, -math.cos(a))
			-- How far the light reaches this way, worked out once every 2 degrees
			local step = math.floor(math.deg((a - c.yaw + math.pi) % (2 * math.pi) - math.pi) / 2 + 0.5)
			local length = c.reach[step]
			if not length then
				local d = math.rad(step * 2) + c.yaw
				local hit = workspace:Raycast(apex + Vector3.new(0, 1.2, 0), Vector3.new(math.sin(d), 0, -math.cos(d)) * Config.CameraRange, seenRay)
				length = if hit then math.max(1, (hit.Position - apex).Magnitude) else Config.CameraRange
				c.reach[step] = length
			end
			points[i + 1] = apex + dir * (length :: number)
		end
		for i = 1, SLICES do
			triangle(apex, points[i], points[i + 1], c.cone[i * 2 - 1], c.cone[i * 2])
		end
		local mine = false
		if out and root then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(c.eye.X, 0, c.eye.Z)).Magnitude
			camNear = math.max(camNear, math.clamp(1.3 - d / Config.CameraRange, 0, 1) * 0.5)
			if Watch.inCone(c.eye, look, root.Position) and not workspace:Raycast(c.eye, root.Position - c.eye, seenRay) then
				mine = true
			end
		end
		local alpha = if mine then 0.55 else 0.8
		if c.cone[1].Transparency ~= alpha then
			for _, w in c.cone do
				w.Transparency = alpha
			end
		end
	end
	meter.Visible = out and seen > 0
	meterFill.Size = UDim2.fromScale(seen, 1)
	if out and seen > 0 and os.clock() >= beepAt then
		beepAt = os.clock() + 0.45 - seen * 0.25
		sound("Beep", 0.7, 1 + seen * 0.5)
	end
end)

-- Moving like a cat: slow and low near sleepers, soft paws, legs and tail
local floor2 = Config.Floor2
local syncAt = 0
local stride = 0
local lastPaw = 0
local bases: { [Weld]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local keyBases: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = myRoot()
	local near, alarm = false, 0
	if humanoid and root then
		local up = root.Position.Y > floor2 - 3
		for _, s in sleepers do
			local hp = s.head.Position
			if (hp.Y > floor2 - 3) == up then
				local d = (Vector3.new(hp.X, 0, hp.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d < Config.SnoreRange then
					near = true
					alarm = math.max(alarm, 0.3)
				end
				if d < Config.StirRange + 10 then
					alarm = math.max(alarm, if s.phase == "look" then 1 elseif s.phase == "warn" then 0.75 else 0)
				end
			end
		end
		humanoid.WalkSpeed = if clipOn then 0 elseif near then Config.SneakSpeed else Config.WalkSpeed
		humanoid.JumpHeight = if clipOn then 0 else Config.JumpHeight
		humanoid.HipHeight = if near then 0.65 else 0.9
		-- Paws
		local v = root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		if speed > 1.5 and humanoid.FloorMaterial ~= Enum.Material.Air then
			stride += dt * speed * 0.55
			if stride - lastPaw > 1 then
				lastPaw = stride
				small(if math.floor(stride) % 2 == 0 then "Paw1" else "Paw2", if near then 0.18 else 0.3, 0.9 + math.random() * 0.2)
			end
		end
	end
	-- Music follows the danger: sleepers looking around, a squeak, a camera
	spike = math.max(0, spike - dt * 0.35)
	local target = math.max(alarm, spike, camNear, (player:GetAttribute("Seen") :: number?) or 0)
	if clipOn then
		target = math.max(target, 0.4)
	end
	danger += (target - danger) * math.min(1, dt * (if target > danger then 3 else 0.6))
	if music and musicOn then
		music.Volume = if tense then 0.6 * (1 - 0.65 * danger) else 0.6
	end
	if tense and musicOn then
		tense.Volume = 0.85 * danger
	end
	-- Keep the tense layer in step with the tune, checked now and then
	local now = os.clock()
	if music and tense and musicOn and now >= syncAt then
		syncAt = now + 2
		local length = math.max(music.TimeLength, 1)
		local drift = (tense.TimePosition - music.TimePosition) % length
		if tense.IsPlaying and math.min(drift, length - drift) > 0.2 then
			tense.TimePosition = music.TimePosition
		end
	end
	-- Every cat walks, keys float and spin
	local t = os.clock()
	for _, other in Players:GetPlayers() do
		local c = other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c and r then
			local v = r.AssemblyLinearVelocity
			local moving = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 10, 0, 1)
			for _, p in c:GetChildren() do
				local weld = p:FindFirstChildOfClass("Weld")
				if weld and p:IsA("BasePart") then
					local base = bases[weld] or weld.C0
					bases[weld] = base
					local swing = p:GetAttribute("Swing")
					if type(swing) == "number" then
						weld.C0 = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(math.sin(t * 14) * 0.7 * moving * swing, 0, 0) * CFrame.new(0, -0.4, 0)
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

-- Jumps and landings
local function watchJumps(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		local airborne = 0
		humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
			if new == Enum.HumanoidStateType.Freefall then
				airborne = os.clock()
			elseif new == Enum.HumanoidStateType.Landed and airborne > 0 and os.clock() - airborne > 0.3 then
				airborne = 0
				small("Land", 0.5)
			elseif new == Enum.HumanoidStateType.Jumping then
				small("Whoosh", 0.2, 1.4)
			end
		end)
	end
end
player.CharacterAdded:Connect(watchJumps)
if player.Character then
	task.spawn(watchJumps, player.Character)
end

-- The dream ---------------------------------------------------------------

-- Milenkitka, super happy, for the dream bubble
local function buildMom(parent: Instance): { model: Model, arms: { BasePart }, shoulders: { CFrame }, upper: { BasePart } }
	local model = Instance.new("Model")
	model.Name = "Mom"
	local look = Config.Sleepers.bedMom
	local skin, hair = look.skin, look.hair
	local function add(name: string, size: Vector3, pos: Vector3, color: Color3, ball: boolean?, rot: CFrame?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos) * (rot or CFrame.identity)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = model
		return p
	end
	local dress = Color3.fromRGB(120, 180, 150)
	for _, x in { -0.35, 0.35 } do
		add("Leg", Vector3.new(0.5, 2.2, 0.5), Vector3.new(x, 1.1, 0), Color3.fromRGB(70, 60, 80))
	end
	local upper = {}
	table.insert(upper, add("Skirt", Vector3.new(1.9, 1.8, 1.3), Vector3.new(0, 2.6, 0), dress))
	table.insert(upper, add("Torso", Vector3.new(1.5, 1.6, 0.9), Vector3.new(0, 4.1, 0), dress))
	table.insert(upper, add("Head", Vector3.one * 1.6, Vector3.new(0, 5.8, 0), skin, true))
	table.insert(upper, add("Hair", Vector3.one * 1.72, Vector3.new(0, 5.95, 0.18), hair, true))
	table.insert(upper, add("Bun", Vector3.one * 0.8, Vector3.new(0, 6.5, 0.75), hair, true))
	-- Happy closed eyes, a big smile and pink cheeks, facing -Z
	for _, x in { -0.32, 0.32 } do
		for _, a in { -40, 40 } do
			table.insert(upper, add("Eye", Vector3.new(0.3, 0.08, 0.08), Vector3.new(x + math.sin(math.rad(a)) * 0.1, 5.95, -0.78), Color3.fromRGB(50, 35, 35), false, CFrame.Angles(0, 0, math.rad(a))))
		end
		table.insert(upper, add("Cheek", Vector3.new(0.34, 0.22, 0.1), Vector3.new(x * 1.6, 5.62, -0.7), Color3.fromRGB(255, 140, 160), true))
	end
	for i = 0, 6 do
		local a = math.rad(200 + i * 140 / 6)
		table.insert(upper, add("Smile", Vector3.one * 0.13, Vector3.new(math.cos(a) * 0.32, 5.62 + math.sin(a) * 0.28, -0.8), Color3.fromRGB(180, 50, 70)))
	end
	local arms, shoulders = {}, {}
	for _, x in { -1, 1 } do
		local shoulder = CFrame.new(x * 0.95, 4.75, 0)
		table.insert(shoulders, shoulder)
		table.insert(arms, add("Arm", Vector3.new(0.45, 1.9, 0.45), (shoulder * CFrame.new(0, -0.95, 0)).Position, skin))
	end
	model.Parent = parent
	return { model = model, arms = arms, shoulders = shoulders, upper = upper }
end

-- The dream mouse. Once caught its eyes turn to x x
local function buildMouse(parent: Instance): (Model, (boolean) -> ())
	local model = Instance.new("Model")
	model.Name = "Mouse"
	local gray = Color3.fromRGB(150, 150, 160)
	local function add(size: Vector3, pos: Vector3, color: Color3, ball: boolean): BasePart
		local p = Instance.new("Part")
		p.Size = size * 1.5
		p.CFrame = CFrame.new(pos * 1.5)
		p.Color = color
		p.Anchored = true
		p.CanCollide = false
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = model
		return p
	end
	local body = add(Vector3.new(0.7, 0.55, 0.7), Vector3.new(0, 0.3, 0), gray, true)
	add(Vector3.one * 0.42, Vector3.new(0, 0.38, -0.42), gray, true)
	local alive, dead = {}, {}
	for _, x in { -0.16, 0.16 } do
		add(Vector3.one * 0.24, Vector3.new(x, 0.62, -0.38), Color3.fromRGB(255, 170, 190), true)
		table.insert(alive, add(Vector3.one * 0.08, Vector3.new(x * 0.6, 0.45, -0.6), Color3.new(0, 0, 0), true))
		for _, a in { 45, -45 } do
			local bar = add(Vector3.new(0.28, 0.075, 0.06), Vector3.new(x * 0.85, 0.47, -0.62), Color3.new(0, 0, 0), false)
			bar.CFrame = bar.CFrame * CFrame.Angles(0, 0, math.rad(a))
			bar.Transparency = 1
			table.insert(dead, bar)
		end
	end
	local tongue = add(Vector3.new(0.12, 0.05, 0.18), Vector3.new(0.05, 0.27, -0.66), Color3.fromRGB(255, 110, 140), false)
	tongue.Transparency = 1
	table.insert(dead, tongue)
	for _, x in { -0.2, 0.2 } do
		for _, z in { -0.2, 0.22 } do
			add(Vector3.one * 0.13, Vector3.new(x, 0.04, z), Color3.fromRGB(255, 170, 190), true)
		end
	end
	add(Vector3.new(0.07, 0.07, 1.1), Vector3.new(0, 0.2, 0.85), Color3.fromRGB(255, 170, 190), false)
	model.PrimaryPart = body
	model.Parent = parent
	return model, function(isDead: boolean)
		for _, p in alive do
			p.Transparency = if isDead then 1 else 0
		end
		for _, p in dead do
			p.Transparency = if isDead then 0 else 1
		end
	end
end

-- The dream plays inside a bubble: out of the door, a mouse, and Milenkitka so happy she hugs Pianka
local function dreamBubble(): (Frame, (number) -> ())
	local bubble = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.62, 0.4),
		Size = UDim2.fromScale(0.52, 0.6),
		BackgroundColor3 = Color3.fromRGB(240, 235, 255),
		ZIndex = 16,
		Parent = gui,
	})
	new("UIAspectRatioConstraint", { AspectRatio = 1.45, Parent = bubble })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bubble })
	new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 6, Parent = bubble })
	local vf = new("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.94),
		BackgroundColor3 = Color3.fromRGB(28, 34, 78),
		Ambient = Color3.fromRGB(150, 150, 190),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 17,
		Parent = bubble,
	})
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = vf })
	local trail = {}
	for i, s in { 22, 34, 50 } do
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(s, s), Position = UDim2.fromScale(0.38 + i * 0.03, 0.82 - i * 0.07), BackgroundColor3 = Color3.fromRGB(240, 235, 255), ZIndex = 16, Parent = gui })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
		table.insert(trail, dot)
	end
	local wm = new("WorldModel", { Parent = vf })
	local cam = new("Camera", { FieldOfView = 45, Parent = vf })
	vf.CurrentCamera = cam
	local function block(size: Vector3, cf: CFrame, color: Color3, ball: boolean?, neon: boolean?): BasePart
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Anchored = true
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Parent = wm
		return p
	end
	-- The night garden: grass, moon, stars, the house door
	block(Vector3.new(80, 1, 30), CFrame.new(12, -0.5, 0), Color3.fromRGB(70, 130, 70))
	block(Vector3.one * 5, CFrame.new(10, 11, -22), Color3.fromRGB(255, 245, 200), true, true)
	local rnd = Random.new(4)
	for _ = 1, 30 do
		block(Vector3.one * 0.3, CFrame.new(rnd:NextNumber(-20, 44), rnd:NextNumber(6, 16), -24), Color3.new(1, 1, 1), true, true)
	end
	-- The house wall with a doorway: dark inside, the door swings open behind Pianka
	local wallColor = Color3.fromRGB(236, 228, 214)
	block(Vector3.new(2, 14, 6.2), CFrame.new(-13, 7, -4.9), wallColor)
	block(Vector3.new(2, 14, 2.2), CFrame.new(-13, 7, 2.9), wallColor)
	block(Vector3.new(2, 8, 3.6), CFrame.new(-13, 10, 0), wallColor)
	block(Vector3.new(6, 6, 4), CFrame.new(-16.5, 3, 0), Color3.fromRGB(20, 16, 24))
	block(Vector3.new(1.2, 4, 2.4), CFrame.new(-11.9, 9.5, -5), Color3.fromRGB(255, 220, 150), false, true)
	local hinge = CFrame.new(-12, 3, -1.8)
	local door = block(Vector3.new(0.4, 6, 3.6), hinge * CFrame.new(0, 0, 1.8), Color3.fromRGB(110, 60, 40))
	for i = 0, 5 do
		block(Vector3.one * 0.7, CFrame.new(20 + i * 1.3, 0.3, -1.5 + (i % 2) * 0.6), Color3.fromRGB(255, 120 + i * 20, 170), true)
	end
	local cat = Cat.build(CFrame.new(-10, 0, 0), 1)
	cat.model.Parent = wm
	local mouse, mouseDead = buildMouse(wm)
	local mom = buildMom(wm)
	local momBase = CFrame.lookAt(Vector3.new(26, 0, 0), Vector3.new(20, 0, 5))
	local momParts: { [BasePart]: CFrame } = {}
	for _, p in mom.model:GetDescendants() do
		if p:IsA("BasePart") then
			momParts[p] = p.CFrame
		end
	end
	-- Arms: up with joy, then forward and around Pianka
	local function poseMom(kneel: number, joy: number, hug: number)
		local base = momBase * CFrame.new(0, -kneel * 1.3, 0)
		for p, rest in momParts do
			local isArm = table.find(mom.arms, p)
			if isArm then
				local shoulder = mom.shoulders[isArm]
				local side = if isArm == 1 then -1 else 1
				local up = joy * (1 - hug)
				local raise = CFrame.Angles(2.4 * up + 1.3 * hug, 0, side * (0.15 + 0.5 * up - 0.55 * hug))
				p.CFrame = base * CFrame.Angles(-kneel * 0.25, 0, 0) * shoulder * raise * CFrame.new(0, -0.95, 0)
			elseif p.Name == "Leg" then
				p.CFrame = momBase * rest
			else
				p.CFrame = base * CFrame.Angles(-kneel * 0.25, 0, 0) * rest
			end
		end
	end
	poseMom(0, 0, 0)
	local hearts: { TextLabel } = {}
	local function heartBurst()
		for _ = 1, 7 do
			local h = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62 + math.random() * 0.2, 0.55), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, TextScaled = true, Text = if math.random() < 0.5 then "💕" else "❤️", ZIndex = 18, Parent = bubble })
			table.insert(hearts, h)
			TweenService:Create(h, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5 + math.random() * 0.4, 0.05 + math.random() * 0.2), TextTransparency = 1 }):Play()
		end
	end
	local cues: { [string]: boolean } = {}
	local function once(name: string, at: number, now: number): boolean
		if now >= at and not cues[name] then
			cues[name] = true
			return true
		end
		return false
	end
	local function update(t: number)
		-- The door opens, Pianka walks out under the moon
		local open = math.clamp((t - 1.2) / 0.8, 0, 1)
		door.CFrame = hinge * CFrame.Angles(0, open * 1.55, 0) * CFrame.new(0, 0, 1.8)
		if once("creak", 1.2, t) then
			sound("Creak", 0.9)
		end
		local catX, catY, carry = -14, 0, false
		if t < 2 then
			catX = -14
		elseif t < 4.3 then
			catX = -14 + (t - 2) / 2.3 * 15
		elseif t < 5.4 then
			catX = 1
			catY = -0.3
		elseif t < 6.0 then
			local k = (t - 5.4) / 0.6
			catX = 1 + k * 7.5
			catY = math.sin(k * math.pi) * 3
		elseif t < 6.6 then
			catX = 8.5
		elseif t < 9 then
			catX = 8.5 + (t - 6.6) / 2.4 * 13
			carry = true
		else
			catX = 21.5
		end
		carry = carry or (t >= 6.0 and t < 9.1)
		local wiggle = if t >= 4.4 and t < 5.4 then math.sin(t * 30) * 0.08 else 0
		local bob = if (t > 2 and t < 4.3) or (t > 6.6 and t < 9) then math.abs(math.sin(t * 9)) * 0.25 else 0
		local catCf = CFrame.lookAt(Vector3.new(catX, catY + bob, 0), Vector3.new(catX + 1, catY + bob, 0)) * CFrame.Angles(0, wiggle, 0)
		if t >= 9.6 then
			-- Lifted into the hug
			local k = math.clamp((t - 9.6) / 0.6, 0, 1)
			local at = Vector3.new(21.5, 0, 0):Lerp(Vector3.new(24.4, 1.6, 1.2), k)
			catCf = CFrame.lookAt(at, Vector3.new(26, at.Y, 0))
		end
		-- The model pivots on the body, so lift it to stand on the grass
		cat.model:PivotTo(catCf * CFrame.new(0, 1.4, 0))
		-- The mouse runs in, gets caught, is carried and dropped at her feet
		local mouseCf: CFrame
		local lift = CFrame.new(0, 0.45, 0)
		if t < 3.6 then
			mouseCf = CFrame.new(40, 0, 0.5) * lift
		elseif t < 4.4 then
			-- Sniffing, facing Pianka
			local sniff = math.sin(t * 25) * 0.05
			mouseCf = CFrame.lookAt(Vector3.new(5, 0, 0.5), Vector3.new(0, 0, 0.5)) * lift * CFrame.Angles(sniff, 0, 0)
		elseif t < 6.0 then
			-- Runs away from her as fast as it can
			local k = math.clamp((t - 4.4) / 1.6, 0, 1)
			local hop = math.abs(math.sin(t * 16)) * 0.2
			mouseCf = CFrame.lookAt(Vector3.new(5 + k * 4.5, hop, 0.5), Vector3.new(20, hop, 0.5)) * lift
		elseif carry then
			-- Limp in Pianka's mouth
			mouseCf = catCf * CFrame.new(0, 1.85, -2.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.5 + math.sin(t * 9) * 0.15)
		else
			-- Dropped at her feet, belly up, feet in the air
			mouseCf = CFrame.lookAt(Vector3.new(23.2, 0, 1.4), Vector3.new(20, 0, 2.5)) * lift * CFrame.Angles(0, 0, math.pi)
		end
		mouseDead(t >= 6.0)
		mouse:PivotTo(mouseCf)
		if once("squeak", 4.2, t) then
			sound("Mouse", 1)
		end
		if once("pounce", 5.4, t) then
			sound("Pounce", 1)
		end
		if once("caught", 6.0, t) then
			sound("Mouse", 0.8, 1.2)
			sound("Key", 0.5, 1.3)
		end
		-- Milenkitka: arms up with joy, kneels down and hugs
		local joy = math.clamp((t - 9.1) / 0.4, 0, 1)
		local kneel = math.clamp((t - 9.7) / 0.7, 0, 1)
		poseMom(kneel, joy, kneel)
		if once("aww", 9.2, t) then
			sound("Aww", 1.4)
			sound("Hearts", 0.9)
			heartBurst()
		end
		if once("purr", 10.2, t) then
			sound("Purr", 1.2)
			heartBurst()
		end
		if once("kiss", 11.2, t) then
			sound("Kiss", 1.3)
			heartBurst()
		end
		-- The dream camera follows along
		local camX = math.clamp(catX + 3, -6, 22)
		if t >= 9.0 then
			-- Close on Milenkitka's happy face
			local k = math.clamp((t - 9.0) / 0.8, 0, 1)
			local from = Vector3.new(camX, 5.5, 16):Lerp(Vector3.new(19.5, 5.2, 10.5), k)
			cam.CFrame = CFrame.lookAt(from, Vector3.new(camX, 2, 0):Lerp(Vector3.new(24.6, 3.6, 0.6), k))
		else
			cam.CFrame = CFrame.lookAt(Vector3.new(camX, 5.5, 16), Vector3.new(camX, 2, 0))
		end
		-- The trail of little bubbles breathes
		for i, dot in trail do
			dot.Rotation = math.sin(t * 2 + i) * 8
		end
	end
	return bubble, update
end

-- Pianka asleep in her bed, dreaming. Then she wakes up and wants to go out
local introOn = false
local function intro()
	introOn = true
	clipOn = true
	local bed = (workspace:GetAttribute("CatBed") :: Vector3?) or Vector3.zero
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	keyBar.Visible = false
	local skip = skipButton()
	local done = false
	skip.Activated:Connect(function()
		done = true
	end)
	skipClip = function()
		done = true
	end
	local box: Sound? = nil
	if dreamBox then
		box = (dreamBox :: Sound):Clone()
		local b = box :: Sound
		b.Volume = 0.8
		b.Parent = SoundService
		whenLoaded(b, function()
			b:Play()
		end)
	end
	sound("Purr", 0.7)
	local bubble, update = dreamBubble()
	bubble.Size = UDim2.fromScale(0, 0)
	TweenService:Create(bubble, TweenInfo.new(0.9, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.52, 0.6) }):Play()
	local start = os.clock()
	local popped = false
	local LENGTH = 14.5
	while not done and os.clock() - start < LENGTH do
		local t = os.clock() - start
		local a = t * 0.12
		camera.CFrame = CFrame.lookAt(bed + Vector3.new(math.sin(a) * 9, 5 - t * 0.12, math.cos(a) * 9), bed + Vector3.new(0, 0.5, 0))
		update(t)
		if t > 12.6 and not popped then
			popped = true
			sound("Pop", 1.2)
			TweenService:Create(bubble, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 0) }):Play()
		end
		RunService.RenderStepped:Wait()
	end
	skipClip = nil
	skip:Destroy()
	for _, d in gui:GetChildren() do
		if d:IsA("Frame") and d.ZIndex == 16 then
			d:Destroy()
		end
	end
	if box then
		local b = box :: Sound
		TweenService:Create(b, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function()
			b:Destroy()
		end)
	end
	-- Awake: a yawn, a look at the door
	meow(Config.Mew, 1, 0.85)
	TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	letterbox(false)
	keyBar.Visible = true
	camera.CameraType = Enum.CameraType.Custom
	introOn = false
	clipOn = false
	startMusic()
end

-- The front door is locked: it rattles, three locks clunk, three keys fly off to where they hide
local lockedShown = false
local function lockedClip(door: BasePart)
	lockedShown = true
	clipOn = true
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	local inside = door.Position + Vector3.new(0, 4, -18)
	local start = os.clock()
	local cues: { [string]: boolean } = {}
	local locks = {}
	for _, p in door:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Lock" then
			table.insert(locks, p)
		end
	end
	table.sort(locks, function(a, b)
		return a.Position.X < b.Position.X
	end)
	local ghosts: { { model: Model, from: Vector3, to: Vector3 } } = {}
	local keysFolder = world:FindFirstChild("Keys")
	local targets = {}
	for _, k in (if keysFolder then keysFolder:GetChildren() else {}) do
		if k:IsA("Model") and not k:GetAttribute("Gate") then
			table.insert(targets, k:GetPivot().Position)
		end
	end
	local skip = skipButton()
	local done = false
	skip.Activated:Connect(function()
		done = true
	end)
	skipClip = function()
		done = true
	end
	while not done and os.clock() - start < Config.LockedClipTime do
		local t = os.clock() - start
		local shake = if t < 0.9 then Vector3.new(math.sin(t * 70) * 0.25, math.sin(t * 53) * 0.12, 0) else Vector3.zero
		camera.CFrame = CFrame.lookAt(inside + Vector3.new(math.sin(t * 0.4) * 2, 0, 0) + shake, door.Position + Vector3.new(0, 2 + math.max(0, t - 2.6) * 2.5, 0) + shake)
		if not cues.rattle then
			cues.rattle = true
			sound("Rattle", 1.4)
			meow(Config.Mew, 0.8, 1.2)
		end
		for i, lock in locks do
			local at = 1 + (i - 1) * 0.45
			if t >= at and not cues["lock" .. i] then
				cues["lock" .. i] = true
				sound("Lock", 1.2, 0.95 + i * 0.05)
				lock.Color = Color3.fromRGB(255, 80, 70)
				popIcon(lock, "🔒", 1.2, 48)
			end
		end
		-- Golden key ghosts leave the locks and fly away to where the keys are hidden
		if t >= 2.6 and not cues.fly then
			cues.fly = true
			sound("KeyFly", 1.2)
			for i, lock in locks do
				local m = Instance.new("Model")
				local p = new("Part", { Size = Vector3.new(0.6, 0.6, 2.4), Material = Enum.Material.Neon, Color = GOLD, Anchored = true, CanCollide = false, CanQuery = false, Transparency = 0.2, CFrame = CFrame.new(lock.Position), Parent = m })
				new("Sparkles", { SparkleColor = GOLD, Parent = p })
				m.PrimaryPart = p
				m.Parent = workspace
				local to = targets[i] or (lock.Position + Vector3.new((i - 2) * 30, 40, -40))
				table.insert(ghosts, { model = m, from = lock.Position, to = to })
			end
		end
		for i, g in ghosts do
			local k = math.clamp((t - 2.6 - i * 0.12) / 1.6, 0, 1)
			local pos = g.from:Lerp(g.to, k) + Vector3.new(0, math.sin(k * math.pi) * 14, 0)
			g.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 8, 0))
		end
		RunService.RenderStepped:Wait()
	end
	for _, g in ghosts do
		g.model:Destroy()
	end
	for _, lock in locks do
		lock.Color = Color3.fromRGB(220, 180, 60)
	end
	skipClip = nil
	skip:Destroy()
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
	-- The empty key slots wiggle: find them
	for _, slot in slots do
		TweenService:Create(slot, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 5, true), { Rotation = 15 }):Play()
	end
end

-- Watch for the first walk to the locked door
RunService.Heartbeat:Connect(function()
	if lockedShown or clipOn or introOn or workspace:GetAttribute("State") ~= "play" or workspace:GetAttribute("Stage") ~= "house" then
		return
	end
	local house = world:FindFirstChild("House")
	local door = house and house:FindFirstChild("ExitDoor") :: BasePart?
	local root = myRoot()
	if door and root and ((workspace:GetAttribute("Keys") :: number?) or 0) < Config.KeyCount and (root.Position - door.Position).Magnitude < 14 and root.Position.Y < 10 then
		task.spawn(lockedClip, door)
	end
end)

-- Someone woke up
local function wakeClip(name: string, at: Vector3)
	if introOn then
		return
	end
	clipOn = true
	spike = 1
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	local start = os.clock()
	sound("Snort", 1.6)
	task.delay(0.6, function()
		local calls = Config.Calls
		voice(calls[math.random(1, #calls)], 1.8)
	end)
	for _, s in sleepers do
		if s.model:GetAttribute("Sleeper") == name then
			popIcon(s.head, "‼️", 2.5, 80)
		end
	end
	while os.clock() - start < Config.CaughtTime - 1 do
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(at + Vector3.new(6 - t, 4 + t * 0.4, 7), at + Vector3.new(0, 1, 0))
		RunService.RenderStepped:Wait()
	end
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	task.wait(0.9)
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
	TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- Out of the house: Pianka spots the cameras and meows a warning
local function exitClip()
	local root = myRoot()
	if introOn or not root then
		return
	end
	clipOn = true
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	-- The closest cameras she can see from the door
	local from = root.Position + Vector3.new(0, 2, 0)
	local view = RaycastParams.new()
	view.FilterType = Enum.RaycastFilterType.Exclude
	local yard = world:FindFirstChild("Yard")
	view.FilterDescendantsInstances = { coneFolder, player.Character :: Instance, yard and yard:FindFirstChild("Cameras") or coneFolder }
	local eyes = {}
	for _, c in cams do
		if not workspace:Raycast(from, c.eye - from, view) then
			table.insert(eyes, c.eye)
		end
	end
	table.sort(eyes, function(a, b)
		return (a - from).Magnitude < (b - from).Magnitude
	end)
	local look = {}
	for i = 1, math.min(3, #eyes) do
		look[i] = eyes[i]
	end
	if #look > 0 then
		local first = look[1]
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(first.X, root.Position.Y, first.Z))
	end
	local start = os.clock()
	local meowed = false
	local length = Config.ExitClipTime - 0.5
	while os.clock() - start < length do
		local t = os.clock() - start
		local cat = root.Position
		local target: Vector3
		if #look == 0 or t < 1.2 then
			target = cat + root.CFrame.LookVector * 20
		else
			local k = math.clamp((t - 1.2) / (length - 1.6), 0, 0.999) * #look
			local i = math.floor(k) + 1
			local a = look[i]
			local b = look[math.min(i + 1, #look)]
			local f = math.clamp((k % 1) * 2.5 - 1.5, 0, 1)
			target = a:Lerp(b, f * f * (3 - 2 * f))
		end
		local back = (Vector3.new(target.X, cat.Y, target.Z) - cat)
		back = if back.Magnitude > 0.1 then back.Unit else Vector3.new(0, 0, -1)
		local head = cat + Vector3.new(0, 2, 0)
		local want = cat - back * 9 + Vector3.new(0, 4.5, 0)
		local hit = workspace:Raycast(head, want - head, view)
		if hit then
			want = hit.Position + (head - hit.Position).Unit * 0.8
		end
		camera.CFrame = CFrame.lookAt(want, target)
		if t > 1.4 and not meowed then
			meowed = true
			meow(Config.Meow, 1.2, 1.1)
			popIcon(root, "📹❗", 2.4, 70)
		end
		RunService.RenderStepped:Wait()
	end
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
end

-- The garage button: a quick look at the door rolling up, then hurry
local function garageClip()
	local door = yardPart("GarageDoor")
	local root = myRoot()
	if introOn or not door or not root then
		return
	end
	clipOn = true
	camera.CameraType = Enum.CameraType.Scriptable
	local from = root.Position
	local start = os.clock()
	while os.clock() - start < Config.GarageClipTime - 0.1 do
		local t = (os.clock() - start) / Config.GarageClipTime
		local side = Vector3.new(from.X - door.Position.X, 0, from.Z - door.Position.Z)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(0, 0, 1)
		camera.CFrame = CFrame.lookAt(door.Position + side * (26 - t * 6) + Vector3.new(0, 9, 0), door.Position + Vector3.new(0, 2, 0))
		RunService.RenderStepped:Wait()
	end
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
end

-- A camera saw Pianka: mom's phone lights up and buzzes, she wakes up
local function spottedClip(eye: Vector3)
	if introOn then
		return
	end
	clipOn = true
	spike = 1
	camera.CameraType = Enum.CameraType.Scriptable
	letterbox(true)
	sound("Alert", 1)
	local momBed = world:FindFirstChild("bedMom", true)
	local head = momBed and momBed:FindFirstChild("Head") :: BasePart?
	local screen = momBed and momBed:FindFirstChild("PhoneScreen") :: BasePart?
	local root = myRoot()
	local cat = if root then root.Position else eye - Vector3.new(0, 12, 0)
	local start = os.clock()
	local phase = 0
	while os.clock() - start < Config.SpottedTime - 1 do
		local t = os.clock() - start
		if t < 1.8 then
			local toward = Vector3.new(cat.X - eye.X, 0, cat.Z - eye.Z)
			toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, 1)
			camera.CFrame = CFrame.lookAt(eye + toward * (8 - t * 2) + Vector3.new(0, 1.5, 0), eye)
		elseif head then
			if phase == 0 then
				phase = 1
				fade.BackgroundTransparency = 0
				TweenService:Create(fade, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				if screen then
					screen.Material = Enum.Material.Neon
					screen.Color = Color3.fromRGB(190, 220, 255)
					popIcon(screen, "📱📹", 2.4, 70)
				end
				sound("Buzz", 1.2)
				sound("Ding", 0.9)
			end
			local at = head.Position
			local k = t - 1.8
			camera.CFrame = CFrame.lookAt(at + Vector3.new(7 - k * 0.6, 4 + k * 0.3, 6), at + Vector3.new(0, -0.5, 0))
			if phase == 1 and t > Config.SpottedTime * 0.55 then
				phase = 2
				sound("Snort", 1.4)
				popIcon(head, "‼️", 2, 80)
				task.delay(0.6, function()
					local calls = Config.Calls
					voice(calls[math.random(1, #calls)], 1.8)
				end)
			end
		end
		RunService.RenderStepped:Wait()
	end
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	task.wait(0.9)
	if screen then
		screen.Material = Enum.Material.Glass
		screen.Color = Color3.fromRGB(12, 14, 20)
	end
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
	TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- All the keys: the locks fall off and the door swings open
local function doorClip()
	local house = world:FindFirstChild("House")
	local door = house and house:FindFirstChild("ExitDoor") :: BasePart?
	if introOn or not door then
		return
	end
	clipOn = true
	camera.CameraType = Enum.CameraType.Scriptable
	local at = door.Position
	sound("AllKeys", 1)
	task.delay(0.8, function()
		sound("Unlock", 1.2)
	end)
	task.delay(1.4, function()
		sound("Creak", 1)
	end)
	local start = os.clock()
	while os.clock() - start < 2.6 do
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(at + Vector3.new(4 - t, 5, -16 + t), at)
		RunService.RenderStepped:Wait()
	end
	camera.CameraType = Enum.CameraType.Custom
	clipOn = false
end

event.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "key" or kind == "gateKey" then
		sound("Key", 1)
		local root = if typeof(a) == "Instance" and a:IsA("Player") and a.Character then a.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		flyKey(if root then root.Position else camera.CFrame.Position, tonumber(b) or 1, kind == "gateKey")
	elseif kind == "allKeys" then
		task.spawn(doorClip)
	elseif kind == "gateOpen" then
		local gate = yardPart("Gate")
		sound("AllKeys", 1)
		task.delay(1.2, function()
			sound("Unlock", 1, 1, gate)
			sound("Gate", 1.4, 1, gate, 200)
		end)
		if gate then
			popIcon(gate, "🔓", 2, 80)
		end
	elseif kind == "toy" and typeof(a) == "Instance" then
		local model = a :: Model
		local main = model.PrimaryPart
		spike = 1
		if main then
			local clip = if b == "ballTrack" then "Track" elseif math.random() < 0.5 then "Squeak" else "Squeak2"
			sound(clip, 2, 0.9 + math.random() * 0.2, main, 140)
			popIcon(main, "💥", 0.9, 54)
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
	elseif kind == "grumble" then
		spike = math.max(spike, 0.6)
		sound("Grumble", 0.7, 0.9 + math.random() * 0.2)
	elseif kind == "tease" then
		spike = math.max(spike, 0.8)
		local calls = Config.Calls
		voice(calls[math.random(1, #calls)], 0.55)
	elseif kind == "wake" then
		task.spawn(wakeClip, tostring(a), b)
	elseif kind == "escaped" then
		if a == player then
			task.spawn(exitClip)
		end
	elseif kind == "spotted" then
		task.spawn(spottedClip, b)
	elseif kind == "garage" then
		local door = yardPart("GarageDoor")
		if door then
			sound("Gate", 1.3, 1.6, door, 160)
		end
		if a == player and b == "outside" then
			task.spawn(garageClip)
		end
	elseif kind == "free" then
		sound("AllKeys", 1)
		meow(Config.Meow, 1, 1.05)
		local root = if typeof(a) == "Instance" and a:IsA("Player") and a.Character then a.Character:FindFirstChild("HumanoidRootPart") else nil
		if root then
			popIcon(root, "🌙🐈", 4, 100)
		end
	elseif kind == "round" then
		showKeys()
		meow(Config.Mew, 0.7, 0.8)
	end
end)

-- Start: the dream, then the music
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
