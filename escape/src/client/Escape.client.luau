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

-- Sounds: sheets of clips. They play right away, and start again properly once Roblox has
-- loaded them, so nothing waits on a load that a phone never reports
local function source(id: number, looped: boolean?): Sound?
	if id == 0 then
		return nil
	end
	return new("Sound", { SoundId = "rbxassetid://" .. id, Looped = looped == true, Volume = 0.5, Parent = SoundService })
end
local sfx = source(Config.SfxId)
local voices = source(Config.VoicesId)
local meows = source(Config.SoundsId)
local music = source(Config.MusicId, true)
local tense = source(Config.TenseId, true)
local dreamBox = source(Config.DreamId)
local longCall = source(Config.LongCallId)
task.spawn(function()
	local list = {}
	for _, s in { sfx, voices, meows, music, tense, dreamBox, longCall } :: { Sound? } do
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
local function loaded(s: Sound): boolean
	return s.IsLoaded or s.TimeLength > 0
end

-- Runs f now, and once more when the sound has loaded if it had not yet
local function whenLoaded(s: Sound, f: () -> ())
	f()
	if not loaded(s) then
		s.Loaded:Once(f)
	end
end

-- One clip from a sound sheet. Little sounds are skipped until the sheet has loaded
local function playClip(parent: Instance, clip: { number }?, volume: number, speed: number, range: number, from: Sound?, optional: boolean?): Sound?
	if not from or not clip then
		return nil
	end
	local source = from :: Sound
	if optional and not loaded(source) then
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
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(c[1], c[1] + c[2])
	s.Parent = parent
	-- Cleaned up once the clip has really played. A sound that is not loaded yet "ends" at
	-- once, so it only gets cleaned up after it has loaded and played
	local function finish()
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(c[2] / speed + 1, function()
			s:Destroy()
		end)
	end
	s:Play()
	if loaded(s) then
		finish()
	else
		s.Loaded:Once(function()
			if s.Parent then
				s.PlaybackRegion = NumberRange.new(c[1], c[1] + c[2])
				s.TimePosition = c[1]
				s:Play()
				finish()
			end
		end)
		task.delay(20, function()
			if not s.IsPlaying then
				s:Destroy()
			end
		end)
	end
	return s
end
local function sound(name: string, volume: number?, speed: number?, parent: Instance?, range: number?): Sound?
	return playClip(parent or SoundService, SFX[name], volume or 1, speed or 1, range or 1000, sfx)
end
-- A clip that loops on its own, for breathing, crickets, clocks and camera motors
local function loopClip(parent: Instance, clip: { number }, volume: number, range: number, speed: number?): Sound?
	if not sfx then
		return nil
	end
	local s = (sfx :: Sound):Clone()
	s.Looped = true
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = range
	s.Parent = parent
	whenLoaded(s, function()
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(clip[1], clip[1] + clip[2])
		s.LoopRegion = s.PlaybackRegion
		s.TimePosition = clip[1] + math.random() * clip[2]
		s:Play()
	end)
	return s
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
-- The long "Piaaanka!" when she is sent back to bed
local function callHome()
	if longCall then
		local s = (longCall :: Sound):Clone()
		s.Volume = 1.6
		s.Parent = SoundService
		s:Play()
		task.delay(8, function()
			s:Destroy()
		end)
	end
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
	calm.Volume = 0.8
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
-- The version, small in the corner for a few seconds at the start
task.spawn(function()
	local version = require(Shared:WaitForChild("Version")) :: string
	local label = new("TextLabel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -6), Size = UDim2.fromOffset(160, 16), BackgroundTransparency = 1, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.3, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 40, Text = version, Parent = gui })
	task.wait(8)
	TweenService:Create(label, TweenInfo.new(1.5), { TextTransparency = 1 }):Play()
	task.wait(1.6)
	label:Destroy()
end)

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
local clipDanger = 0
local clipId = 0
local clipRank = 0
-- Starts a clip unless a more important one is playing, and gives its id
local function beginClip(rank: number, danger: number): number?
	if clipOn and rank < clipRank then
		return nil
	end
	clipId += 1
	clipRank = rank
	clipOn = true
	clipDanger = danger
	camera.CameraType = Enum.CameraType.Scriptable
	return clipId
end
-- Ends the clip if no other clip took over. True when it still owned the screen
local afterClip: (() -> ())? = nil
local function endClip(my: number): boolean
	if clipId ~= my then
		return false
	end
	clipOn = false
	clipRank = 0
	letterbox(false)
	camera.CameraType = Enum.CameraType.Custom
	if afterClip then
		task.defer(afterClip :: () -> ())
	end
	return true
end
-- The server moves everyone back to bed a moment after a fail: wait for it under the black
local roundCount = 0
local function waitForRound(since: number, limit: number)
	local start = os.clock()
	while roundCount <= since and os.clock() - start < limit do
		task.wait(0.05)
	end
	task.wait(0.2)
end
local skipClip: (() -> ())? = nil
local skipReady = 0
local function skipButton(after: number?): TextButton
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -190),
		Size = UDim2.fromOffset(64, 48),
		BackgroundColor3 = Color3.fromRGB(28, 26, 40),
		BackgroundTransparency = 0.2,
		TextScaled = true,
		Text = "⏭",
		ZIndex = 18,
		Parent = gui,
	})
	round(b, 14)
	skipReady = os.clock() + (after or 0)
	if after and after > 0 then
		b.Visible = false
		task.delay(after, function()
			if b.Parent then
				b.Visible = true
				if usingPad() then
					GuiService.SelectedObject = b
				end
			end
		end)
	elseif usingPad() then
		GuiService.SelectedObject = b
	end
	return b
end
UserInputService.InputBegan:Connect(function(input)
	local k = input.KeyCode
	if skipClip and os.clock() >= skipReady and (k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.ButtonX or k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.E) then
		skipClip()
	end
end)

-- Lost keys fly out of the bar once the clip is over
local function keysFlyOff(from: number, to: number, icon: string)
	task.spawn(function()
		local start = os.clock()
		while clipOn and os.clock() - start < 12 do
			task.wait(0.1)
		end
		task.wait(0.4)
		sound("KeyFly", 0.7, 0.9)
		for i = from, to do
			local slot = slots[i]
			if slot then
				local c = slot.AbsolutePosition + slot.AbsoluteSize / 2
				local ghost = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, TextScaled = true, Text = icon, ZIndex = 12, Parent = gui })
				local tween = TweenService:Create(ghost, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, (i - from) * 0.12), { Position = UDim2.fromOffset(c.X + (i - 2) * 60, c.Y + 260), Rotation = 200, TextTransparency = 1, Size = UDim2.fromOffset(24, 24) })
				tween.Completed:Once(function()
					ghost:Destroy()
				end)
				tween:Play()
			end
		end
	end)
end

-- Keys in the bar: 🔑 for the house, 🗝️ for the gate
local lastCount, lastYard = 0, false
local function showKeys()
	local yard = player:GetAttribute("Out") == true
	local n = (workspace:GetAttribute(if yard then "GateKeys" else "Keys") :: number?) or 0
	local total = if yard then Config.GateKeyCount else Config.KeyCount
	if yard == lastYard and n < lastCount then
		keysFlyOff(n + 1, lastCount, if yard then "🗝️" else "🔑")
	elseif lastYard and not yard and lastCount > 0 then
		keysFlyOff(1, lastCount, "🗝️")
	end
	lastCount, lastYard = n, yard
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
player:GetAttributeChangedSignal("Out"):Connect(showKeys)
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
type Sleeper = { model: Model, head: BasePart, breath: Sound?, mark: TextLabel, phase: string, cone: { BasePart }, drawn: string }
local sleepers: { Sleeper } = {}
local MARKS = { sleep = "💤", warn = "❗", look = "👀", awake = "‼️" }
local SIGHT_SLICES = 36
local sightFolder = new("Folder", { Name = "SightCones", Parent = workspace })
-- Where a sleeper looks: about to look covers both sides, looking is the real view
local function sightDir(model: Instance, head: BasePart, phase: string): (Vector3, number)
	local facing = model:GetAttribute("Facing")
	local v = if phase == "look" and typeof(facing) == "Vector3" then facing else head.CFrame.LookVector
	local flat = Vector3.new(v.X, 0, v.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.zero, 0
	end
	return flat.Unit, math.rad(if phase == "look" then Config.SightHalf else math.min(Config.SightHalf + 48, 170))
end
local function seesMe(model: Instance, head: BasePart, phase: string): boolean
	local root = myRoot()
	if not root or math.abs(root.Position.Y - head.Position.Y) > 12 then
		return false
	end
	local d = Vector3.new(root.Position.X - head.Position.X, 0, root.Position.Z - head.Position.Z)
	local dir, half = sightDir(model, head, phase)
	if d.Magnitude >= Config.StirRange or (dir ~= Vector3.zero and d.Magnitude >= 1 and d.Unit:Dot(dir) < math.cos(half)) then
		return false
	end
	-- Walls in between: the same low line of sight as the server
	local floorY = if head.Position.Y > Config.Floor2 - 3 then Config.Floor2 else 0
	local from = Vector3.new(head.Position.X, floorY + 1.5, head.Position.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { model }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	local keys = world:FindFirstChild("Keys")
	if keys then
		table.insert(skip, keys)
	end
	params.FilterDescendantsInstances = skip
	return workspace:Raycast(from, Vector3.new(root.Position.X, floorY + 1.5, root.Position.Z) - from, params) == nil
end
-- A big ❗ and a red flash at the screen edges when someone who can see you is about to look
local warnIcon = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1, TextScaled = true, Text = "❗", TextTransparency = 1, ZIndex = 30, Parent = gui })
local edges: { Frame } = {}
local EDGES: { { anchor: Vector2, size: UDim2, rotation: number } } = {
	{ anchor = Vector2.new(0, 0), size = UDim2.new(1, 0, 0.22, 0), rotation = 90 },
	{ anchor = Vector2.new(0, 1), size = UDim2.new(1, 0, 0.22, 0), rotation = -90 },
	{ anchor = Vector2.new(0, 0), size = UDim2.new(0.18, 0, 1, 0), rotation = 0 },
	{ anchor = Vector2.new(1, 0), size = UDim2.new(0.18, 0, 1, 0), rotation = 180 },
}
for i, e in EDGES do
	local edge = new("Frame", { AnchorPoint = e.anchor, Position = UDim2.fromScale(e.anchor.X, e.anchor.Y), Size = e.size, BackgroundColor3 = Color3.fromRGB(255, 30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 29, Parent = gui })
	new("UIGradient", { Rotation = e.rotation, Transparency = NumberSequence.new(0, 1), Parent = edge })
	edges[i] = edge
end
local function warnFlash()
	warnIcon.TextTransparency = 0
	warnIcon.Size = UDim2.fromOffset(150, 150)
	TweenService:Create(warnIcon, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(90, 90) }):Play()
	task.delay(Config.StirWarn, function()
		TweenService:Create(warnIcon, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
	for _, edge in edges do
		edge.BackgroundTransparency = 0.25
		TweenService:Create(edge, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end
end
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
	-- Their view lights up the floor in yellow while they stir
	local cone = {}
	for i = 1, SIGHT_SLICES * 2 do
		cone[i] = new("WedgePart", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 215, 70), Transparency = 1, Size = Vector3.one * 0.1, Parent = sightFolder })
	end
	local entry: Sleeper = { model = model, head = head, breath = breath, mark = mark, phase = "sleep", cone = cone, drawn = "" }
	table.insert(sleepers, entry)
	model:GetAttributeChangedSignal("Stir"):Connect(function()
		local phase = (model:GetAttribute("Stir") :: string?) or "sleep"
		if phase == "sleep" and entry.phase == "look" then
			sound("Sigh", 1.2, if model:GetAttribute("Sleeper") ~= "Milenkitka" then 1.2 else 1, head, 80)
		end
		entry.phase = phase
		mark.Text = MARKS[phase] or MARKS.sleep
		local kid = model:GetAttribute("Sleeper") ~= "Milenkitka"
		if phase == "warn" then
			sound("Snort", 1.5, if kid then 1.2 else 1, head, 90)
			if Config.LookWakes and not clipOn and seesMe(model, head, "warn") then
				warnFlash()
			end
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
afterClip = function()
	if not Config.LookWakes then
		return
	end
	for _, sl in sleepers do
		if (sl.phase == "warn" or sl.phase == "look") and seesMe(sl.model, sl.head, sl.phase) then
			warnFlash()
			break
		end
	end
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

-- The kid's TV still plays a blocky obby game, no sound
local function playTvGame(screen: BasePart)
	local W, H = 304, 224
	local sg = new("SurfaceGui", { Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(W, H), LightInfluence = 0, Brightness = 1.3, Parent = screen })
	local sky = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 190, 255), BorderSizePixel = 0, ClipsDescendants = true, Parent = sg })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(200, 235, 255)), Parent = sky })
	local sun = new("Frame", { Position = UDim2.fromOffset(240, 18), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromRGB(255, 230, 90), BorderSizePixel = 0, Parent = sky })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = sun })
	local clouds = {}
	for i = 1, 3 do
		local cloud = new("Frame", { Position = UDim2.fromOffset(i * 110 - 60, 20 + (i % 2) * 26), Size = UDim2.fromOffset(54, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sky })
		new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = cloud })
		table.insert(clouds, cloud)
	end
	local lava = new("Frame", { Position = UDim2.fromOffset(0, H - 26), Size = UDim2.fromOffset(W, 26), BackgroundColor3 = Color3.fromRGB(255, 90, 30), BorderSizePixel = 0, ZIndex = 3, Parent = sky })
	local worldFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2, Parent = sky })
	-- Platforms with coins, the last one has a flag
	local COLORS = { Color3.fromRGB(240, 70, 70), Color3.fromRGB(250, 200, 60), Color3.fromRGB(90, 200, 90), Color3.fromRGB(70, 140, 240), Color3.fromRGB(180, 100, 230) }
	local steps: { { x: number, y: number, w: number } } = {}
	local coins: { Frame } = {}
	for i = 0, 9 do
		local w = if i == 0 or i == 9 then 70 else 34 + (i * 7) % 20
		local y = if i == 0 then 150 else 120 + ((i * 37) % 60)
		local x = if i == 0 then 30 else steps[i].x + steps[i].w / 2 + 40 + w / 2 + (i % 3) * 8
		table.insert(steps, { x = x, y = y, w = w })
		local plat = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 14), BackgroundColor3 = COLORS[i % #COLORS + 1], BorderSizePixel = 0, ZIndex = 2, Parent = worldFrame })
		new("Frame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 2, Parent = plat })
		if i > 0 and i < 9 then
			local coin = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y - 40), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(255, 215, 40), BorderSizePixel = 0, ZIndex = 2, Parent = worldFrame })
			new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = coin })
			coins[i + 1] = coin
		end
		if i == 9 then
			new("Frame", { Position = UDim2.fromOffset(x + 14, y - 46), Size = UDim2.fromOffset(3, 46), BackgroundColor3 = Color3.fromRGB(240, 240, 240), BorderSizePixel = 0, ZIndex = 2, Parent = worldFrame })
			new("Frame", { Position = UDim2.fromOffset(x + 17, y - 46), Size = UDim2.fromOffset(22, 14), BackgroundColor3 = Color3.fromRGB(60, 210, 90), BorderSizePixel = 0, ZIndex = 2, Parent = worldFrame })
		end
	end
	-- The blocky player
	local guy = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(22, 44), BackgroundTransparency = 1, ZIndex = 4, Parent = sky })
	local function piece(pos: Vector2, size: Vector2, color: Color3): Frame
		return new("Frame", { Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 4, Parent = guy })
	end
	local yellow = Color3.fromRGB(250, 210, 70)
	local head = piece(Vector2.new(5, 0), Vector2.new(12, 12), yellow)
	for _, x in { 3, 7 } do
		new("Frame", { Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = head })
	end
	new("Frame", { Position = UDim2.fromOffset(3, 8), Size = UDim2.fromOffset(6, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 5, Parent = head })
	piece(Vector2.new(4, 12), Vector2.new(14, 15), Color3.fromRGB(40, 120, 230))
	local armL = piece(Vector2.new(0, 12), Vector2.new(4, 14), yellow)
	local armR = piece(Vector2.new(18, 12), Vector2.new(4, 14), yellow)
	local legL = piece(Vector2.new(4, 27), Vector2.new(7, 17), Color3.fromRGB(70, 180, 80))
	local legR = piece(Vector2.new(11, 27), Vector2.new(7, 17), Color3.fromRGB(70, 180, 80))
	local light = new("SurfaceLight", { Face = Enum.NormalId.Front, Range = 16, Angle = 110, Brightness = 0.7, Color = Color3.fromRGB(140, 190, 255), Parent = screen })
	local HOP, GUY_X = 0.85, 90
	local start = os.clock()
	while screen.Parent do
		local cam = workspace.CurrentCamera
		if not cam or (cam.CFrame.Position - screen.Position).Magnitude > 80 then
			task.wait(0.5)
			continue
		end
		local t = (os.clock() - start) % (HOP * (#steps - 1) + 1.5)
		local hop = math.min(math.floor(t / HOP), #steps - 1)
		local k = if hop >= #steps - 1 then 1 else (t - hop * HOP) / HOP
		local a = steps[hop + 1]
		local b = steps[math.min(hop + 2, #steps)]
		local x = a.x + (b.x - a.x) * k
		local y = a.y + (b.y - a.y) * k - math.sin(k * math.pi) * 46
		local camX = x - GUY_X
		worldFrame.Position = UDim2.fromOffset(-camX, 0)
		guy.Position = UDim2.fromOffset(GUY_X, y)
		local swing = if k < 1 then math.sin(k * math.pi * 2) * 30 else 0
		armL.Rotation, armR.Rotation = swing, -swing
		legL.Rotation, legR.Rotation = -swing * 0.6, swing * 0.6
		for i, coin in coins do
			coin.Visible = hop + 1 < i or (hop + 1 == i and k < 0.5) or t < HOP * 0.5
			coin.Size = UDim2.fromOffset(12 * math.abs(math.cos(os.clock() * 3 + i)), 12)
		end
		for i, cloud in clouds do
			cloud.Position = UDim2.fromOffset((i * 110 - 60 - os.clock() * 6) % (W + 80) - 60, 20 + (i % 2) * 26)
		end
		lava.BackgroundColor3 = Color3.fromRGB(255, 80 + math.floor(30 * math.sin(os.clock() * 4)), 30)
		light.Color = COLORS[hop % #COLORS + 1]:Lerp(Color3.fromRGB(140, 190, 255), 0.6)
		task.wait(1 / 30)
	end
end
task.spawn(function()
	task.wait(2)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "GameScreen" then
			task.spawn(playTvGame, d)
		end
	end
end)

-- Backyard cameras turn, blink and light a red cone on the ground
type Cam = { model: Model, eye: Vector3, yaw: number, phase: number, period: number, cone: { BasePart }, led: BasePart?, reach: { [number]: number } }
local cams: { Cam } = {}
local hums: { Sound } = {}
local coneFolder = new("Folder", { Name = "Cones", Parent = workspace })
local RED = Color3.fromRGB(255, 60, 60)
local SLICES = 10
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
	new("SpotLight", { Color = RED, Brightness = 3, Range = if UserInputService.TouchEnabled then 36 else Config.CameraRange, Angle = Config.CameraHalf * 2, Face = Enum.NormalId.Front, Shadows = false, Parent = head })
	local hum = loopClip(head, SFX.Servo, 0, 32, 0.9 + math.random() * 0.2)
	if hum then
		table.insert(hums, hum)
	end
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
	-- The garage door moved: work the cone shapes out again
	for _, c in cams do
		table.clear(c.reach)
	end
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
	local inYard = player:GetAttribute("Out") == true
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
			for _, h in hums do
				h.Volume = 0
			end
		end
		return
	end
	if not conesShown then
		for _, h in hums do
			h.Volume = 0.5
		end
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
		-- Cameras far away are not drawn
		if root and Vector3.new(c.eye.X - root.Position.X, 0, c.eye.Z - root.Position.Z).Magnitude > 120 then
			if c.cone[1].Transparency ~= 1 then
				for _, w in c.cone do
					w.Transparency = 1
				end
			end
			continue
		end
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
			local low = Vector3.new(c.eye.X, 1.5, c.eye.Z)
			if Watch.inCone(c.eye, look, root.Position) and not workspace:Raycast(low, Vector3.new(root.Position.X, 1.5, root.Position.Z) - low, seenRay) then
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

-- Sleepers' views on the floor, and red rings that pulse when Pianka is close to a toy
local sightRay = RaycastParams.new()
sightRay.FilterType = Enum.RaycastFilterType.Exclude
local rings: { BasePart } = {}
task.spawn(function()
	task.wait(2)
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "DangerRing" then
			table.insert(rings, d)
		end
	end
end)
local sightAt = 0
RunService.RenderStepped:Connect(function()
	if os.clock() < sightAt then
		return
	end
	sightAt = os.clock() + 1 / 30
	local root = myRoot()
	local filter: { Instance } = { sightFolder, coneFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(filter, other.Character)
		end
	end
	local keys = world:FindFirstChild("Keys")
	if keys then
		table.insert(filter, keys)
	end
	for _, sl in sleepers do
		local stirring = Config.LookWakes and (sl.phase == "warn" or sl.phase == "look")
		local dir, half = sightDir(sl.model, sl.head, sl.phase)
		if not stirring or dir == Vector3.zero then
			if sl.drawn ~= "" then
				sl.drawn = ""
				for _, w in sl.cone do
					w.Transparency = 1
				end
			end
			continue
		end
		-- The view only changes with the phase: draw it once
		local key = sl.phase .. tostring(dir)
		if sl.drawn == key then
			continue
		end
		sl.drawn = key
		local hp = sl.head.Position
		local floorY = if hp.Y > Config.Floor2 - 3 then Config.Floor2 else 0
		local from = Vector3.new(hp.X, floorY + 1.5, hp.Z)
		local apex = Vector3.new(hp.X, floorY + 0.22, hp.Z)
		local yaw = math.atan2(dir.X, -dir.Z)
		filter[#filter + 1] = sl.model
		sightRay.FilterDescendantsInstances = filter
		filter[#filter] = nil
		local points = {}
		for i = 0, SIGHT_SLICES do
			local a = yaw - half + i * half * 2 / SIGHT_SLICES
			local ray = Vector3.new(math.sin(a), 0, -math.cos(a))
			local hit = workspace:Raycast(from, ray * Config.StirRange, sightRay)
			local length = if hit then math.max(1.5, (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude) else Config.StirRange
			points[i + 1] = apex + ray * length
		end
		for i = 1, SIGHT_SLICES do
			triangle(apex, points[i], points[i + 1], sl.cone[i * 2 - 1], sl.cone[i * 2])
		end
		local alpha = if sl.phase == "look" then 0.6 else 0.84
		for _, w in sl.cone do
			w.Transparency = alpha
		end
	end
	local t = os.clock()
	for _, ring in rings do
		local near = false
		if root and ring.Parent then
			local p = ring.Position
			near = math.abs(root.Position.Y - p.Y) < 6 and (Vector3.new(root.Position.X - p.X, 0, root.Position.Z - p.Z)).Magnitude < 10
		end
		ring.Transparency = if near then 0.45 + 0.25 * (0.5 + 0.5 * math.sin(t * 9)) else 0.75
	end
end)

-- Moving like a cat: slow and low near sleepers, soft paws, legs and tail
local floor2 = Config.Floor2
local syncAt = 0
local crouch = 0
-- During the dream Pianka lies curled up: low, legs tucked in, eyes shut
local catAsleep = false
-- Sneaking: worked out 10 times a second
local sneaking = false
local sneakAt = 0
local sneakRay = RaycastParams.new()
sneakRay.FilterType = Enum.RaycastFilterType.Exclude
local asleepShown = false
local stride = 0
local lastPaw = 0
type Rig = { joints: { { weld: Weld, base: CFrame, swing: number, wag: boolean } }, moving: number, low: number }
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local keyBases: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = myRoot()
	local alarm = 0
	local near = sneaking
	if humanoid and root then
		local up = root.Position.Y > floor2 - 3
		local check = os.clock() >= sneakAt
		if check then
			sneakAt = os.clock() + 0.1
			near = false
		end
		for _, s in sleepers do
			local hp = s.head.Position
			if (hp.Y > floor2 - 3) == up then
				local d = (Vector3.new(hp.X, 0, hp.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
				if d < Config.SnoreRange then
					alarm = math.max(alarm, 0.3)
					if check and not near then
						local floorY = if up then floor2 else 0
						local from = Vector3.new(hp.X, floorY + 1.5, hp.Z)
						sneakRay.FilterDescendantsInstances = { s.model, character :: Instance, sightFolder, coneFolder }
						near = workspace:Raycast(from, Vector3.new(root.Position.X, floorY + 1.5, root.Position.Z) - from, sneakRay) == nil
					end
				end
				if d < Config.StirRange + 10 then
					if Config.LookWakes then
						alarm = math.max(alarm, if s.phase == "look" then 1 elseif s.phase == "warn" then 0.75 else 0)
					end
				end
			end
		end
		sneaking = near
		humanoid.WalkSpeed = if clipOn then 0 elseif near then Config.SneakSpeed else Config.WalkSpeed
		humanoid.JumpHeight = if clipOn then 0 else Config.JumpHeight
		humanoid.HipHeight = 0.9
		crouch += ((if catAsleep then 0.9 elseif near then 0.35 else 0) - crouch) * math.min(1, dt * (if catAsleep then 8 else 3))
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
		target = clipDanger
	end
	danger += (target - danger) * math.min(1, dt * (if target > danger then 3 else 0.6))
	if music and musicOn then
		music.Volume = if tense then 0.8 * (1 - 0.65 * danger) else 0.8
	end
	if tense and musicOn then
		tense.Volume = 0.9 * danger
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
	local character2 = player.Character
	if character2 and asleepShown ~= catAsleep then
		asleepShown = catAsleep
		for _, p in character2:GetChildren() do
			if p:IsA("BasePart") and (p.Name == "Eye" or type(p:GetAttribute("Swing")) == "number") then
				p.LocalTransparencyModifier = if catAsleep then 1 else 0
			end
		end
	end
	-- Every cat walks, keys float and spin
	local t = os.clock()
	for _, other in Players:GetPlayers() do
		local c = other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c and r then
			local rig = rigs[c]
			if not rig then
				local joints = {}
				for _, p in c:GetChildren() do
					local weld = p:FindFirstChildOfClass("Weld")
					if weld and p:IsA("BasePart") then
						local swing = p:GetAttribute("Swing")
						table.insert(joints, { weld = weld, base = weld.C0, swing = if type(swing) == "number" then swing else 0, wag = p:GetAttribute("Wag") == true })
					end
				end
				rig = { joints = joints, moving = -1, low = -1 }
				rigs[c] = rig
			end
			local v = r.AssemblyLinearVelocity
			local moving = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 10, 0, 1)
			local low = if other == player then crouch else 0
			local walking = moving > 0.01 or rig.moving > 0.01
			local lowering = math.abs(low - rig.low) > 0.002
			rig.moving, rig.low = moving, low
			local lowCf = CFrame.new(0, -low, 0)
			for _, j in rig.joints do
				if j.swing ~= 0 then
					if walking then
						j.weld.C0 = j.base * CFrame.new(0, 0.4, 0) * CFrame.Angles(math.sin(t * 14) * 0.7 * moving * j.swing, 0, 0) * CFrame.new(0, -0.4, 0)
					end
				elseif j.wag then
					j.weld.C0 = lowCf * j.base * CFrame.Angles(0, math.sin(t * 3) * 0.35, 0)
				elseif lowering then
					j.weld.C0 = lowCf * j.base
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
type Mom = { model: Model, arms: { BasePart }, shoulders: { CFrame }, upper: { BasePart }, happy: { BasePart }, shock: { BasePart } }
local function buildMom(parent: Instance): Mom
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
	local happy = {}
	for _, p in upper do
		if p.Name == "Eye" or p.Name == "Smile" then
			table.insert(happy, p)
		end
	end
	-- Her horrified face: eyes wide open, brows up, mouth a big O
	local shock = {}
	for _, x in { -0.32, 0.32 } do
		table.insert(shock, add("ShockEye", Vector3.one * 0.44, Vector3.new(x, 5.98, -0.66), Color3.new(1, 1, 1), true))
		table.insert(shock, add("ShockPupil", Vector3.one * 0.15, Vector3.new(x, 5.98, -0.88), Color3.fromRGB(20, 20, 20), true))
		table.insert(shock, add("Brow", Vector3.new(0.36, 0.08, 0.08), Vector3.new(x, 6.34, -0.7), Color3.fromRGB(70, 45, 30), false, CFrame.Angles(0, 0, math.rad(if x > 0 then -18 else 18))))
	end
	table.insert(shock, add("ShockMouth", Vector3.one * 0.42, Vector3.new(0, 5.4, -0.68), Color3.fromRGB(90, 20, 35), true))
	for _, p in shock do
		p.Transparency = 1
		table.insert(upper, p)
	end
	local arms, shoulders = {}, {}
	for _, x in { -1, 1 } do
		local shoulder = CFrame.new(x * 0.95, 4.75, 0)
		table.insert(shoulders, shoulder)
		table.insert(arms, add("Arm", Vector3.new(0.45, 1.9, 0.45), (shoulder * CFrame.new(0, -0.95, 0)).Position, skin))
	end
	model.Parent = parent
	return { model = model, arms = arms, shoulders = shoulders, upper = upper, happy = happy, shock = shock }
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

-- The garden by the house door, for the dream at night and the real thing at dawn
type Garden = {
	wm: WorldModel,
	cam: Camera,
	block: (Vector3, CFrame, Color3, boolean?, boolean?) -> BasePart,
	door: BasePart,
	hinge: CFrame,
	cat: any,
	mouse: Model,
	mouseDead: (boolean) -> (),
	mom: Mom,
	pose: (CFrame, number, number, number, number, number) -> (),
	face: (boolean) -> (),
}
local function gardenScene(vf: ViewportFrame, dawn: boolean): Garden
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
	-- The garden: grass, the moon and stars at night, the sun coming up at dawn, the house door
	block(Vector3.new(80, 1, 30), CFrame.new(12, -0.5, 0), if dawn then Color3.fromRGB(95, 160, 85) else Color3.fromRGB(70, 130, 70))
	local rnd = Random.new(4)
	if dawn then
		block(Vector3.one * 8, CFrame.new(26, 3, -26), Color3.fromRGB(255, 200, 110), true, true)
		for i = 0, 2 do
			for j, size in { 2.4, 3.2, 2.4 } do
				block(Vector3.one * size, CFrame.new(-6 + i * 15 + (j - 2) * 2, 12 + (i % 2) * 2 + (if j == 2 then 0.5 else 0), -24), Color3.fromRGB(255, 240, 238), true, false)
			end
		end
	else
		block(Vector3.one * 5, CFrame.new(10, 11, -22), Color3.fromRGB(255, 245, 200), true, true)
		for _ = 1, 30 do
			block(Vector3.one * 0.3, CFrame.new(rnd:NextNumber(-20, 44), rnd:NextNumber(6, 16), -24), Color3.new(1, 1, 1), true, true)
		end
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
	-- Little flowers by Milenkitka: a stem, a yellow middle and five petals
	for i = 0, 6 do
		local base = Vector3.new(19.5 + i * 1.4, 0, -2.2 + (i % 2) * 0.9)
		local h = 1.1 + (i % 3) * 0.25
		block(Vector3.new(0.12, h, 0.12), CFrame.new(base + Vector3.new(0, h / 2, 0)), Color3.fromRGB(70, 150, 70))
		block(Vector3.new(0.5, 0.08, 0.25), CFrame.new(base + Vector3.new(0.2, h * 0.4, 0)) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(80, 170, 80))
		local top = base + Vector3.new(0, h, 0)
		local petal = ({ Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 200, 80), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 255, 255) })[i % 4 + 1]
		for j = 0, 4 do
			local a = j / 5 * math.pi * 2
			block(Vector3.new(0.34, 0.1, 0.34), CFrame.new(top + Vector3.new(math.cos(a) * 0.24, 0, math.sin(a) * 0.24)) * CFrame.Angles(math.rad(70), a, 0), petal, true)
		end
		block(Vector3.one * 0.2, CFrame.new(top + Vector3.new(0, 0.05, 0)), Color3.fromRGB(255, 220, 60), true)
	end
	local cat = Cat.build(CFrame.new(-10, 0, 0), 1)
	cat.model.Parent = wm
	local mouse, mouseDead = buildMouse(wm)
	local mom = buildMom(wm)
	local momParts: { [BasePart]: CFrame } = {}
	for _, p in mom.model:GetDescendants() do
		if p:IsA("BasePart") then
			momParts[p] = p.CFrame
		end
	end
	-- Arms up with joy, forward and around Pianka in a hug, straight up in horror.
	-- Running swings the legs and flails the arms
	local function pose(at: CFrame, kneel: number, joy: number, hug: number, shock: number, run: number)
		local base = at * CFrame.new(0, -kneel * 1.3, 0)
		local lean = CFrame.Angles(-kneel * 0.25 + shock * 0.18, 0, 0)
		for p, rest in momParts do
			local isArm = table.find(mom.arms, p)
			if isArm then
				local shoulder = mom.shoulders[isArm]
				local side = if isArm == 1 then -1 else 1
				local up = joy * (1 - hug) * (1 - shock)
				local flail = if run ~= 0 then math.sin(run * 2 + isArm * 2.5) * 0.45 else 0
				local tremble = shock * math.sin(os.clock() * 40 + isArm) * 0.06
				local raise = CFrame.Angles(2.4 * up + 1.3 * hug + 2.9 * shock + flail + tremble, 0, side * (0.15 + 0.5 * up - 0.55 * hug + 0.2 * shock))
				p.CFrame = base * lean * shoulder * raise * CFrame.new(0, -0.95, 0)
			elseif p.Name == "Leg" then
				local swing = math.sin(run) * 0.75 * (if rest.Position.X < 0 then 1 else -1)
				p.CFrame = at * CFrame.new(0, 2.2, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -2.2, 0) * rest
			else
				p.CFrame = base * lean * rest
			end
		end
	end
	local function face(shocked: boolean)
		for _, p in mom.happy do
			p.Transparency = if shocked then 1 else 0
		end
		for _, p in mom.shock do
			p.Transparency = if shocked then 0 else 1
		end
	end
	return { wm = wm, cam = cam, block = block, door = door, hinge = hinge, cat = cat, mouse = mouse, mouseDead = mouseDead, mom = mom, pose = pose, face = face }
end

-- The dream plays inside a bubble: out of the door, a mouse, and Milenkitka so happy she hugs Pianka
local function dreamBubble(): (Frame, (number) -> (), { Frame })
	local bubble = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.64, 0.37),
		Size = UDim2.fromScale(0.5, 0.56),
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
	local scene = gardenScene(vf, false)
	local cam, block = scene.cam, scene.block
	local door, hinge, cat, mouse, mouseDead = scene.door, scene.hinge, scene.cat, scene.mouse, scene.mouseDead
	local momBase = CFrame.lookAt(Vector3.new(26, 0, 0), Vector3.new(20, 0, 5))
	local function poseMom(kneel: number, joy: number, hug: number)
		scene.pose(momBase, kneel, joy, hug, 0, 0)
	end
	local rnd = Random.new(4)
	poseMom(0, 0, 0)
	-- Where she holds Pianka: in front of her chest, leaning in as she kneels
	local function momHold(kneel: number): CFrame
		return momBase * CFrame.new(0, -kneel * 1.3, 0) * CFrame.Angles(-kneel * 0.25, 0, 0) * CFrame.new(0, 3.45, -1.6)
	end
	-- Little 3D hearts that pop around the hug
	local pops: { { at: number, angle: number, size: number, parts: { BasePart } } } = {}
	local heartColors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 60, 90), Color3.fromRGB(255, 150, 200) }
	for i = 0, 15 do
		local color = heartColors[i % 3 + 1]
		local hp = { block(Vector3.one, CFrame.identity, color, true, true), block(Vector3.one, CFrame.identity, color, true, true), block(Vector3.one, CFrame.identity, color, false, true) }
		for _, p in hp do
			p.Transparency = 1
		end
		table.insert(pops, { at = 10.1 + i * 0.2, angle = -0.45 + ((i * 0.618) % 1) * (math.pi + 0.9), size = rnd:NextNumber(0.55, 0.95), parts = hp })
	end
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
		-- Milenkitka: arms up with joy, kneels down and hugs
		local joy = math.clamp((t - 9.1) / 0.4, 0, 1)
		local kneel = math.clamp((t - 9.7) / 0.7, 0, 1)
		poseMom(kneel, joy, kneel)
		-- The model pivots on the body, so lift it to stand on the grass
		local catPivot = catCf * CFrame.new(0, 1.4, 0)
		if t >= 9.6 then
			-- Lifted into her arms, turned to lie across her chest
			local k = math.clamp((t - 9.6) / 0.6, 0, 1)
			local held = momHold(kneel) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0.15, 0, 0)
			catPivot = catPivot:Lerp(held, k * k * (3 - 2 * k))
		end
		cat.model:PivotTo(catPivot)
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
		-- Hearts pop up big, settle, float away and shrink
		local camPos = cam.CFrame.Position
		local right = cam.CFrame.RightVector
		for i, h in pops do
			local age = t - h.at
			local shown = age >= 0 and age < 1.7
			for _, p in h.parts do
				p.Transparency = if shown then 0 else 1
			end
			if shown then
				local grow = if age < 0.14 then age / 0.14 * 1.35 elseif age < 0.3 then 1.35 - (age - 0.14) / 0.16 * 0.35 else 1 - math.max(0, age - 1.2) / 0.5
				local sz = math.max(0.05, h.size * grow)
				local center = Vector3.new(25.2, 4.3 + age * 0.9, 0.5) + right * math.cos(h.angle) * 3.1 + Vector3.new(0, math.sin(h.angle) * 2.3, 0) + (camPos - Vector3.new(25.2, 4.3, 0.5)).Unit * 1.2
				local face = CFrame.lookAt(center, camPos) * CFrame.Angles(0, 0, math.sin(age * 6 + i) * 0.2)
				h.parts[1].Size = Vector3.one * sz
				h.parts[1].CFrame = face * CFrame.new(-0.36 * sz, 0.15 * sz, 0)
				h.parts[2].Size = Vector3.one * sz
				h.parts[2].CFrame = face * CFrame.new(0.36 * sz, 0.15 * sz, 0)
				h.parts[3].Size = Vector3.new(0.95 * sz, 0.95 * sz, 0.3 * sz)
				h.parts[3].CFrame = face * CFrame.new(0, -0.22 * sz, 0) * CFrame.Angles(0, 0, math.rad(45))
			end
			if once("pop" .. i, h.at, t) then
				sound("Pop", 0.45, 1.1 + (i % 4) * 0.12)
			end
		end
		-- The trail of little bubbles breathes
		for i, dot in trail do
			dot.Rotation = math.sin(t * 2 + i) * 8
		end
	end
	return bubble, update, trail
end

-- A camera spot looking at a point from a few studs away, kept out of walls
local function viewOf(target: Vector3, from: Vector3, skip: Instance?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance, coneFolder, sightFolder, skip or coneFolder }
	local hit = workspace:Raycast(target, from - target, params)
	return if hit then hit.Position + (target - hit.Position).Unit * 1 else from
end

-- Pianka asleep in her bed, dreaming. Then she wakes up and wants to go out
local introOn = false
local function intro()
	introOn = true
	local my = beginClip(4, 0) :: number
	local bed = (workspace:GetAttribute("CatBed") :: Vector3?) or Vector3.zero
	letterbox(true)
	keyBar.Visible = false
	local skip = skipButton(3.2)
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
	catAsleep = true
	local root = myRoot()
	local zzz: BillboardGui? = nil
	if root then
		zzz = new("BillboardGui", { Size = UDim2.fromOffset(40, 40), StudsOffsetWorldSpace = Vector3.new(-1.2, 2.2, 0), Parent = root })
		local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = "💤", Parent = zzz })
		TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0.15, -0.3) }):Play()
	end
	local bubble, update, trailDots = dreamBubble()
	bubble.Size = UDim2.fromScale(0, 0)
	TweenService:Create(bubble, TweenInfo.new(0.9, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.5, 0.56) }):Play()
	local start = os.clock()
	local popped = false
	local LENGTH = 13.2
	while not done and clipId == my and os.clock() - start < LENGTH do
		local t = os.clock() - start
		local a = t * 0.06
		-- The camera shifted so the sleeping cat sits down left, under the little bubbles
		local want = CFrame.lookAt(bed + Vector3.new(math.sin(a) * 10, 5 - t * 0.1, math.cos(a) * 10), bed + Vector3.new(0, 0.5, 0)) * CFrame.new(3.4, 1.8, 0)
		camera.CFrame = CFrame.new(viewOf(bed + Vector3.new(0, 2.5, 0), want.Position)) * want.Rotation
		local head, onScreen = camera:WorldToViewportPoint(bed + Vector3.new(0, 1.6, 0))
		local size = camera.ViewportSize
		if onScreen and size and size.X > 0 then
			for i, dot in trailDots do
				local k = i / (#trailDots + 1)
				local x = head.X / size.X + (0.42 - head.X / size.X) * k
				local y = head.Y / size.Y + (0.6 - head.Y / size.Y) * k
				dot.Position = UDim2.fromScale(x, y)
			end
		end
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
	-- Awake: a stretch and a yawn
	catAsleep = false
	if zzz then
		zzz:Destroy()
	end
	meow(Config.Mew, 1, 0.85)
	TweenService:Create(fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	keyBar.Visible = true
	introOn = false
	endClip(my)
	startMusic()
	-- The clock for the speed score starts now
	event:FireServer("start")
end

-- Ghost keys fly along a path: up the stairwell when their key is upstairs
local function ghostPath(from: Vector3, to: Vector3): { Vector3 }
	local house = world:FindFirstChild("House")
	local stairs = house and house:FindFirstChild("Stairs")
	local ramp = stairs and stairs:FindFirstChild("Ramp") :: BasePart?
	if ramp and to.Y > Config.Floor2 - 3 then
		local look = ramp.CFrame.LookVector
		local half = ramp.Size.Z / 2
		return { from, ramp.Position - look * half + Vector3.new(0, 4, 0), ramp.Position + look * half + Vector3.new(0, 5, 0), to + Vector3.new(0, 2, 0) }
	end
	return { from, (from + to) / 2 + Vector3.new(0, 8, 0), to + Vector3.new(0, 2, 0) }
end
local function along(path: { Vector3 }, k: number): Vector3
	local lengths, total = {}, 0
	for i = 1, #path - 1 do
		lengths[i] = (path[i + 1] - path[i]).Magnitude
		total += lengths[i]
	end
	local d = k * total
	for i = 1, #path - 1 do
		if d <= lengths[i] or i == #path - 1 then
			return path[i]:Lerp(path[i + 1], math.clamp(d / math.max(lengths[i], 0.01), 0, 1))
		end
		d -= lengths[i]
	end
	return path[#path]
end
local function ghostKey(at: Vector3): Model
	local m = Instance.new("Model")
	local p = new("Part", { Size = Vector3.new(0.7, 0.7, 2.6), Material = Enum.Material.Neon, Color = GOLD, Anchored = true, CanCollide = false, CanQuery = false, Transparency = 0.15, CFrame = CFrame.new(at), Parent = m })
	new("Sparkles", { SparkleColor = GOLD, Parent = p })
	new("PointLight", { Color = GOLD, Range = 14, Brightness = 2, Parent = p })
	m.PrimaryPart = p
	m.Parent = workspace
	return m
end

-- The front door is locked: it rattles, three locks clunk, three keys fly off to where they hide
local lockedShown = false
local doorHint: BillboardGui? = nil
local function lockedClip(door: BasePart)
	lockedShown = true
	if doorHint then
		doorHint:Destroy()
		doorHint = nil
	end
	local my = beginClip(1, 0.25)
	if not my then
		lockedShown = false
		return
	end
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
	local keysFolder = world:FindFirstChild("Keys")
	local targets = {}
	for _, k in (if keysFolder then keysFolder:GetChildren() else {}) do
		if k:IsA("Model") and not k:GetAttribute("Gate") then
			table.insert(targets, k:GetPivot().Position)
		end
	end
	-- Follow the key that goes upstairs, it shows where the sleepers are
	table.sort(targets, function(a, b)
		return a.Y > b.Y
	end)
	local ghosts: { { model: Model, path: { Vector3 }, landed: boolean } } = {}
	local lead: Vector3? = targets[1]
	local leadSleeper: Vector3? = nil
	if lead then
		local best = math.huge
		for _, sl in sleepers do
			local d = (sl.head.Position - lead).Magnitude
			if d < best and d < 45 then
				best, leadSleeper = d, sl.head.Position
			end
		end
	end
	local skip = skipButton(3.2)
	local done = false
	skip.Activated:Connect(function()
		done = true
	end)
	skipClip = function()
		done = true
	end
	local FLY = 2.2
	while not done and clipId == my and os.clock() - start < Config.LockedClipTime do
		local t = os.clock() - start
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
		-- Golden key ghosts leave the locks and fly off to where the keys hide
		if t >= 2.6 and not cues.fly then
			cues.fly = true
			sound("KeyFly", 1.2)
			for i, to in targets do
				local lock = locks[math.min(i, #locks)]
				local from = if lock then lock.Position else door.Position
				table.insert(ghosts, { model = ghostKey(from), path = ghostPath(from, to), landed = false })
			end
		end
		local leadPos: Vector3? = nil
		for i, g in ghosts do
			local k = math.clamp((t - 2.6 - (i - 1) * 0.15) / FLY, 0, 1)
			local e = k * k * (3 - 2 * k)
			local pos = along(g.path, e)
			g.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, t * 8, 0))
			if i == 1 then
				leadPos = pos
			end
			if k >= 1 and not g.landed then
				g.landed = true
				sound("Key", 0.6, 1.5)
			end
		end
		-- Camera: the hall and the door, then the keys going up the stairs, then where one lands
		local shake = if t < 0.9 then Vector3.new(math.sin(t * 70) * 0.25, math.sin(t * 53) * 0.12, 0) else Vector3.zero
		if t < 2.6 or not leadPos then
			camera.CFrame = CFrame.lookAt(inside + Vector3.new(math.sin(t * 0.4) * 2, 0, 0) + shake, door.Position + Vector3.new(0, 2, 0) + shake)
		elseif t < 2.6 + FLY - 0.3 then
			camera.CFrame = CFrame.lookAt(inside + Vector3.new(0, 2, 0), leadPos :: Vector3)
		else
			if not cues.cut then
				cues.cut = true
				fade.BackgroundTransparency = 0.2
				TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
			local key = targets[1] or (leadPos :: Vector3)
			local other = leadSleeper or key + Vector3.new(0, 0, -8)
			local away = Vector3.new(key.X - other.X, 0, key.Z - other.Z)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
			local spot = viewOf(key + Vector3.new(0, 3, 0), key + away * 12 + Vector3.new(0, 7, 0))
			camera.CFrame = CFrame.lookAt(spot, key:Lerp(other, 0.4) + Vector3.new(0, 1, 0))
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
	if not endClip(my) then
		return
	end
	-- The empty key slots wiggle: find them
	for _, slot in slots do
		TweenService:Create(slot, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 5, true), { Rotation = 15 }):Play()
	end
end

-- After the dream a door picture pulses on the front door until Pianka tries it
local function showDoorHint()
	if lockedShown or doorHint or workspace:GetAttribute("Stage") ~= "house" or ((workspace:GetAttribute("Keys") :: number?) or 0) >= Config.KeyCount then
		return
	end
	local house = world:FindFirstChild("House")
	local door = house and house:FindFirstChild("ExitDoor") :: BasePart?
	if not door then
		return
	end
	local bill = new("BillboardGui", { Size = UDim2.fromOffset(70, 70), StudsOffsetWorldSpace = Vector3.new(0, 11, 0), AlwaysOnTop = true, MaxDistance = 300, Parent = door })
	local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = "🚪", Parent = bill })
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromScale(1.35, 1.35), Position = UDim2.fromScale(-0.17, -0.17) }):Play()
	doorHint = bill
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
-- The cat that made it happen, or ours
local function culpritRoot(culprit: any): BasePart?
	if typeof(culprit) == "Instance" and culprit:IsA("Player") and culprit.Character then
		local r = culprit.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			return r
		end
	end
	return myRoot()
end
-- A shot of a sleeper's face from the foot of the bed, kept inside the room
local function bedShot(head: BasePart, model: Instance, k: number): CFrame
	local bed = model:FindFirstChild("Frame") :: BasePart?
	local frame = if bed then bed.CFrame else head.CFrame
	local at = head.Position
	local want = at + frame.LookVector * (7 - k * 0.6) + frame.RightVector * 3 + Vector3.new(0, 4 + k * 0.3, 0)
	return CFrame.lookAt(viewOf(at + Vector3.new(0, 1, 0), want, model), at + Vector3.new(0, 0.5, 0))
end
-- Looking at Pianka from behind and above, pulled in front of walls
local function catShot(root: BasePart): CFrame
	local at = root.Position + Vector3.new(0, 1, 0)
	return CFrame.lookAt(viewOf(at, root.Position - root.CFrame.LookVector * 9 + Vector3.new(0, 6, 0)), at)
end

local function wakeClip(name: string, at: Vector3, cause: string?, culprit: any)
	if introOn then
		return
	end
	local since = roundCount
	local my = beginClip(3, 1) :: number
	spike = 1
	letterbox(true)
	-- First a second on the cat that did it: the squeak she stepped on, or the eyes that saw her move
	local root = culpritRoot(culprit)
	if root then
		popIcon(root, if cause == "toy" then "💥" else "👀", 1.6, 90)
		local first = os.clock()
		while clipId == my and os.clock() - first < 1 do
			camera.CFrame = catShot(root)
			RunService.RenderStepped:Wait()
		end
	end
	local start = os.clock()
	sound("Snort", 1.6)
	task.delay(0.5, callHome)
	local who: Sleeper? = nil
	for _, s in sleepers do
		if s.model:GetAttribute("Sleeper") == name then
			popIcon(s.head, "‼️", 2.5, 80)
			who = s
		end
	end
	while clipId == my and os.clock() - start < Config.CaughtTime - 1 do
		local t = os.clock() - start
		camera.CFrame = if who then bedShot(who.head, who.model, t) else CFrame.lookAt(at + Vector3.new(6 - t, 4 + t * 0.4, 7), at + Vector3.new(0, 1, 0))
		RunService.RenderStepped:Wait()
	end
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	sound("Whoosh", 0.7, 0.7)
	waitForRound(since, 3)
	if endClip(my) then
		TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end
end

-- Out of the house: Pianka spots the cameras and meows a warning
local exitSeen = 0
local function exitClip()
	local root = myRoot()
	if introOn or not root then
		return
	end
	local my = beginClip(2, 0.35)
	if not my then
		return
	end
	letterbox(true)
	-- After the first time only the look at the cameras
	exitSeen += 1
	local short = exitSeen > 1
	local skip = skipButton(2)
	local skipped = false
	skip.Activated:Connect(function()
		skipped = true
	end)
	skipClip = function()
		skipped = true
	end
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
	-- The gate, its locks and where its keys hide, one always in the garage
	local gate = yardPart("Gate")
	local locks: { BasePart } = {}
	local gateParts: { Instance } = if gate then gate:GetChildren() else {}
	for _, p in gateParts do
		if p:IsA("BasePart") and p.Name == "Lock" then
			table.insert(locks, p)
		end
	end
	local keysFolder = world:FindFirstChild("Keys")
	local targets = {}
	for _, k in (if keysFolder then keysFolder:GetChildren() else {}) do
		if k:IsA("Model") and k:GetAttribute("Gate") then
			table.insert(targets, k:GetPivot().Position)
		end
	end
	local button: BasePart? = nil
	for _, p in (if yard then yard:GetChildren() else {}) do
		if p:IsA("BasePart") and p.Name == "GarageButton" and p.CanCollide then
			button = p
		end
	end
	local ghosts: { { model: Model, from: Vector3, to: Vector3, landed: boolean } } = {}
	local cues: { [string]: boolean } = {}
	local start = os.clock()
	local PAN = if short then 3.6 else 4.6
	local length = if short then PAN else Config.ExitClipTime - 0.4
	while clipId == my and not skipped and os.clock() - start < length do
		local t = os.clock() - start
		local cat = root.Position
		if t < PAN then
			local target: Vector3
			if #look == 0 or t < 1.2 then
				target = cat + root.CFrame.LookVector * 20
			else
				local k = math.clamp((t - 1.2) / (PAN - 1.6), 0, 0.999) * #look
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
			if t > 1.4 and not cues.meow then
				cues.meow = true
				meow(Config.Meow, 1.2, 1.1)
				popIcon(root, "📹❗", 2.4, 70)
			end
		elseif gate and t < PAN + 2 then
			-- The gate clunks shut three times
			camera.CFrame = CFrame.lookAt(gate.Position + Vector3.new(6, 9, -24), gate.Position + Vector3.new(0, 2, 0))
			for i, lock in locks do
				if t >= PAN + 0.3 + (i - 1) * 0.4 and not cues["lock" .. i] then
					cues["lock" .. i] = true
					sound("Lock", 1.2, 0.95 + i * 0.05)
					popIcon(lock, "🔒", 1.2, 48)
				end
			end
		elseif gate and t < PAN + 4.2 then
			-- The gate keys fly to where they hide: watch from up high
			if not cues.fly then
				cues.fly = true
				sound("KeyFly", 1.2)
				for i, lock in locks do
					table.insert(ghosts, { model = ghostKey(lock.Position), from = lock.Position, to = (targets[i] or lock.Position) + Vector3.new(0, 2, 0), landed = false })
				end
			end
			local mid = gate.Position
			for _, g in ghosts do
				mid += g.model:GetPivot().Position
			end
			mid /= (#ghosts + 1)
			camera.CFrame = CFrame.lookAt(mid + Vector3.new(0, 70, 45), mid)
		elseif button then
			-- And the garage button, watched by the cameras
			if not cues.button then
				cues.button = true
				popIcon(button, "🔘", 1.6, 90)
				sound("Click", 1.2)
			end
			camera.CFrame = CFrame.lookAt(button.Position + Vector3.new(8, 8, 14), button.Position)
		end
		for _, g in ghosts do
			local k = math.clamp((t - PAN - 2) / 1.8, 0, 1)
			local e = k * k * (3 - 2 * k)
			g.model:PivotTo(CFrame.new(g.from:Lerp(g.to, e) + Vector3.new(0, math.sin(e * math.pi) * 20, 0)) * CFrame.Angles(0, t * 8, 0))
			if k >= 1 and not g.landed then
				g.landed = true
				sound("Key", 0.5, 1.5)
			end
		end
		RunService.RenderStepped:Wait()
	end
	for _, g in ghosts do
		g.model:Destroy()
	end
	skipClip = nil
	skip:Destroy()
	endClip(my)
	event:FireServer("exitDone")
end

-- The garage button: a quick look at the door rolling up, then hurry
local function garageClip()
	local door = yardPart("GarageDoor")
	local root = myRoot()
	if introOn or not door or not root then
		return
	end
	local my = beginClip(1, 0.3)
	if not my then
		return
	end
	local from = root.Position
	local start = os.clock()
	while clipId == my and os.clock() - start < Config.GarageClipTime - 0.1 do
		local t = (os.clock() - start) / Config.GarageClipTime
		local side = Vector3.new(from.X - door.Position.X, 0, from.Z - door.Position.Z)
		side = if side.Magnitude > 0.1 then side.Unit else Vector3.new(0, 0, 1)
		camera.CFrame = CFrame.lookAt(door.Position + side * (26 - t * 6) + Vector3.new(0, 9, 0), door.Position + Vector3.new(0, 2, 0))
		RunService.RenderStepped:Wait()
	end
	endClip(my)
end

-- A camera saw Pianka: mom's phone lights up and buzzes, she wakes up
local function spottedClip(eye: Vector3, culprit: any)
	if introOn then
		return
	end
	local since = roundCount
	-- Cues follow the server's clock from the moment the alarm came
	local arrived = os.clock()
	local my = beginClip(3, 1) :: number
	spike = 1
	letterbox(true)
	-- Click! A white flash on the cat in the red light
	local caught = culpritRoot(culprit)
	if caught then
		sound("Click", 1.4)
		fade.BackgroundColor3 = Color3.new(1, 1, 1)
		fade.BackgroundTransparency = 0.1
		TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		popIcon(caught, "📹", 1.6, 90)
		local first = os.clock()
		while clipId == my and os.clock() - first < 0.9 do
			camera.CFrame = catShot(caught)
			RunService.RenderStepped:Wait()
		end
		fade.BackgroundColor3 = Color3.new(0, 0, 0)
	end
	sound("Alert", 1)
	local momBed = world:FindFirstChild("bedMom", true)
	local head = momBed and momBed:FindFirstChild("Head") :: BasePart?
	local screen = momBed and momBed:FindFirstChild("PhoneScreen") :: BasePart?
	local cat = if caught then caught.Position else eye - Vector3.new(0, 12, 0)
	local start = os.clock()
	local phase = 0
	while clipId == my and os.clock() - arrived < Config.SpottedTime - 0.1 do
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
			camera.CFrame = bedShot(head, momBed :: Instance, t - 1.8)
			if phase == 1 and os.clock() - arrived > Config.SpottedTime * 0.55 then
				phase = 2
				sound("Snort", 1.4)
				popIcon(head, "‼️", 2, 80)
				task.delay(0.5, callHome)
			end
		end
		RunService.RenderStepped:Wait()
	end
	TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	sound("Whoosh", 0.7, 0.7)
	waitForRound(since, 3)
	if screen then
		screen.Material = Enum.Material.Glass
		screen.Color = Color3.fromRGB(12, 14, 20)
	end
	if endClip(my) then
		TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	end
end

-- All the keys: the locks fall off and the door swings open
-- Padlocks pop off one by one and fall, only on this screen. They come back on a new round
local hiddenLocks: { BasePart } = {}
local function dropLocks(holder: BasePart, delay: number)
	local list = {}
	for _, p in holder:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Lock" then
			table.insert(list, p)
		end
	end
	for i, lock in list do
		task.delay(delay + (i - 1) * 0.25, function()
			lock.LocalTransparencyModifier = 1
			table.insert(hiddenLocks, lock)
			sound("Lock", 1, 1.4, lock, 120)
			popIcon(lock, "🔓", 1, 44)
			local piece = new("Part", { Size = lock.Size, CFrame = lock.CFrame, Color = lock.Color, Material = Enum.Material.Metal, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = workspace })
			local start = os.clock()
			local spin = (math.random() - 0.5) * 8
			while os.clock() - start < 0.9 do
				local k = os.clock() - start
				piece.CFrame = lock.CFrame * CFrame.new(spin * 0.2 * k, 3 * k - 22 * k * k, -1.2 * k) * CFrame.Angles(k * 9, spin * k, 0)
				piece.Transparency = math.max(0, (k - 0.5) / 0.4)
				RunService.RenderStepped:Wait()
			end
			piece:Destroy()
		end)
	end
end

local function doorClip()
	local house = world:FindFirstChild("House")
	local door = house and house:FindFirstChild("ExitDoor") :: BasePart?
	if introOn or not door then
		return
	end
	local my = beginClip(1, 0)
	if not my then
		return
	end
	local at = door.Position
	sound("AllKeys", 1)
	dropLocks(door, 0.5)
	task.delay(0.8, function()
		sound("Unlock", 1.2)
	end)
	task.delay(1.4, function()
		sound("Creak", 1)
	end)
	local start = os.clock()
	while clipId == my and os.clock() - start < 2.6 do
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(at + Vector3.new(4 - t, 5, -16 + t), at)
		RunService.RenderStepped:Wait()
	end
	endClip(my)
end

-- The gate opens: its locks drop, it sinks, and a moon shows the way out until Pianka is free
local moonMark: BillboardGui? = nil
local function gateClip(gate: BasePart)
	dropLocks(gate, 0.2)
	if not moonMark then
		local bill = new("BillboardGui", { Size = UDim2.fromOffset(70, 70), StudsOffsetWorldSpace = Vector3.new(0, 12, 0), AlwaysOnTop = true, MaxDistance = 400, Parent = gate })
		local label = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = "🌙", Parent = bill })
		TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromScale(1.35, 1.35), Position = UDim2.fromScale(-0.17, -0.17) }):Play()
		moonMark = bill
	end
	if introOn then
		return
	end
	local my = beginClip(1, 0)
	if not my then
		return
	end
	local at = gate.Position
	local start = os.clock()
	while clipId == my and os.clock() - start < 2.2 do
		local t = os.clock() - start
		camera.CFrame = CFrame.lookAt(at + Vector3.new(8 - t * 2, 10, -26 + t), at + Vector3.new(0, 2, 0))
		RunService.RenderStepped:Wait()
	end
	endClip(my)
end

-- After the way out: a picture card and a button to play again
-- Scores from the server: everyone's time this run and the best times ever
local myTime: number? = nil
local bestList: { { name: string, time: number, id: number } } = {}
local endCard: Frame? = nil
local function clockText(seconds: number): string
	local sec = math.floor(seconds + 0.5)
	return string.format("%d:%02d", sec // 60, sec % 60)
end
local function fillCard(card: Frame)
	for _, c in card:GetChildren() do
		if c:IsA("GuiObject") and c.Name ~= "Again" then
			c:Destroy()
		end
	end
	local function label(text: string, pos: UDim2, size: UDim2, color: Color3?, parent: Instance?): TextLabel
		return new("TextLabel", { Position = pos, Size = size, BackgroundTransparency = 1, TextScaled = true, Text = text, TextColor3 = color or Color3.new(1, 1, 1), Font = Enum.Font.FredokaOne, ZIndex = 26, Parent = parent or card })
	end
	-- Left: the story in pictures, your time and stars
	label("🌙🐈🐭😱", UDim2.fromScale(0.04, 0.05), UDim2.fromScale(0.44, 0.2))
	if myTime then
		local t = myTime :: number
		label("⏱️ " .. clockText(t), UDim2.fromScale(0.04, 0.28), UDim2.fromScale(0.44, 0.2), Color3.fromRGB(255, 230, 120))
		local stars = if t < Config.Stars[1] then 3 elseif t < Config.Stars[2] then 2 else 1
		label(string.rep("⭐", stars) .. string.rep("☆", 3 - stars), UDim2.fromScale(0.08, 0.5), UDim2.fromScale(0.36, 0.14))
	end
	-- Right: the best times ever, yours in gold
	local board = new("Frame", { Position = UDim2.fromScale(0.52, 0.05), Size = UDim2.fromScale(0.44, 0.9), BackgroundColor3 = Color3.fromRGB(45, 42, 62), ZIndex = 26, Parent = card })
	round(board, 14)
	label("🏆", UDim2.fromScale(0.35, 0.01), UDim2.fromScale(0.3, 0.12), nil, board)
	for i, entry in bestList do
		if i > 10 then
			break
		end
		local mine = entry.id == player.UserId
		local color = if mine then Color3.fromRGB(255, 215, 80) else Color3.fromRGB(235, 235, 245)
		local y = 0.14 + (i - 1) * 0.085
		label(tostring(i), UDim2.fromScale(0.02, y), UDim2.fromScale(0.12, 0.075), color, board)
		local name = label(entry.name, UDim2.fromScale(0.15, y), UDim2.fromScale(0.55, 0.075), color, board)
		name.TextXAlignment = Enum.TextXAlignment.Left
		label(clockText(entry.time), UDim2.fromScale(0.72, y), UDim2.fromScale(0.26, 0.075), color, board)
	end
end
local function showEndCard()
	if workspace:GetAttribute("State") ~= "won" then
		return
	end
	if endCard then
		fillCard(endCard)
		return
	end
	local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.8), BackgroundColor3 = Color3.fromRGB(28, 26, 40), BackgroundTransparency = 0.05, ZIndex = 25, Parent = gui })
	new("UIAspectRatioConstraint", { AspectRatio = 1.7, Parent = card })
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 450), Parent = card })
	round(card, 24)
	local again = new("TextButton", { Name = "Again", Position = UDim2.fromScale(0.12, 0.68), Size = UDim2.fromScale(0.28, 0.24), BackgroundColor3 = Color3.fromRGB(90, 200, 120), TextScaled = true, Text = "▶", TextColor3 = Color3.new(1, 1, 1), ZIndex = 26, Parent = card })
	round(again, 18)
	again.Activated:Connect(function()
		sound("Pop", 1)
		event:FireServer("again")
	end)
	fillCard(card)
	if usingPad() then
		GuiService.SelectedObject = again
	end
	card.Size = UDim2.fromScale(0.35, 0.4)
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.7, 0.8) }):Play()
	sound("AllKeys", 0.8)
	endCard = card
end

-- Where a point in a viewport scene shows up on the screen
local function project(cam: Camera, size: Vector2, at: Vector3): UDim2
	local rel = cam.CFrame:PointToObjectSpace(at)
	if rel.Z >= -0.1 then
		return UDim2.fromScale(-1, -1)
	end
	local f = 1 / math.tan(math.rad(cam.FieldOfView) / 2)
	local aspect = size.X / math.max(size.Y, 1)
	return UDim2.fromScale(0.5 + rel.X / -rel.Z * f / aspect * 0.5, 0.5 - rel.Y / -rel.Z * f * 0.5)
end

-- After the first win the ending can be skipped
local winsSeen = 0
local endingSkipped = false
local function endingSkip(): TextButton?
	if winsSeen < 2 then
		return nil
	end
	local skip = skipButton(1)
	skip.ZIndex = 26
	skip.Activated:Connect(function()
		endingSkipped = true
	end)
	skipClip = function()
		endingSkipped = true
	end
	return skip
end

-- Home at dawn, like the dream: Pianka brings the mouse, Milenkitka screams and runs
local function homeClip()
	local my = beginClip(2, 0)
	if not my then
		return
	end
	local screen = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 21, Parent = gui })
	local vf = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 196, 160),
		Ambient = Color3.fromRGB(200, 180, 175),
		LightColor = Color3.fromRGB(255, 225, 190),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		ZIndex = 22,
		Parent = screen,
	})
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(140, 170, 235), Color3.fromRGB(255, 205, 165)), Parent = vf })
	for _, y in { 0, 1 } do
		new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0.11), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 24, Parent = screen })
	end
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 25, Parent = screen })
	TweenService:Create(black, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	local scene = gardenScene(vf, true)
	local cam = scene.cam
	local mark = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, TextScaled = true, Text = "", ZIndex = 23, Parent = screen })
	local box: Sound? = nil
	if dreamBox then
		box = (dreamBox :: Sound):Clone()
		local b = box :: Sound
		b.Volume = 0.7
		b.Parent = SoundService
		whenLoaded(b, function()
			b:Play()
		end)
	end
	local cues: { [string]: boolean } = {}
	local function once(name: string, at: number, now: number): boolean
		if now >= at and not cues[name] then
			cues[name] = true
			return true
		end
		return false
	end
	local LENGTH = 11
	local start = os.clock()
	local skip = endingSkip()
	while clipId == my and not endingSkipped and os.clock() - start < LENGTH do
		local t = os.clock() - start
		-- Pianka trots in from the garden with the mouse and drops it at the door
		local catX = if t < 3.2 then 24 - (t / 3.2) * 27 else -3
		local bob = if t < 3.2 then math.abs(math.sin(t * 9)) * 0.25 else 0
		local catLook = Vector3.new(-1, 0, 0)
		local momAt: Vector3
		local momNext = Vector3.new(1, 0, 0)
		if t >= 7 then
			-- Away from the cat, to the back of the garden and off
			local k = math.clamp((t - 7) / 3, 0, 1)
			local path = { Vector3.new(-10, 0, 0.6), Vector3.new(-9, 0, -7), Vector3.new(4, 0, -13), Vector3.new(36, 0, -13) }
			local seg = math.min(math.floor(k * 3) + 1, 3)
			momAt = path[seg]:Lerp(path[seg + 1], k * 3 - (seg - 1))
			momNext = path[seg + 1]
			catLook = (Vector3.new(momAt.X, 0, momAt.Z) - Vector3.new(catX, 0, 0)).Unit
			if t >= 9.6 then
				catLook = Vector3.new(0, 0, 1)
			end
		else
			local k = math.clamp((t - 4) / 1, 0, 1)
			momAt = Vector3.new(-16 + k * 6, 0, k * 0.6)
			momNext = momAt + Vector3.new(1, 0, 0.1)
		end
		local catCf = CFrame.lookAt(Vector3.new(catX, bob, 0), Vector3.new(catX, bob, 0) + catLook)
		scene.cat.model:PivotTo(catCf * CFrame.new(0, 1.4, 0))
		if t < 3.2 then
			scene.mouse:PivotTo(catCf * CFrame.new(0, 1.85, -2.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.5 + math.sin(t * 9) * 0.15))
		else
			scene.mouse:PivotTo(CFrame.lookAt(Vector3.new(-6, 0, 1.2), Vector3.new(-9, 0, 2.5)) * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.pi))
		end
		scene.mouseDead(true)
		if once("drop", 3.2, t) then
			sound("Pop", 0.8, 0.8)
			meow(Config.Mew, 1, 1.15)
		end
		-- The door opens and Milenkitka comes out, stretching in the morning
		local open = math.clamp((t - 3.8) / 0.6, 0, 1)
		scene.door.CFrame = scene.hinge * CFrame.Angles(0, -open * 1.55, 0) * CFrame.new(0, 0, 1.8)
		if once("creak", 3.8, t) then
			sound("Creak", 0.9)
		end
		local walking = t >= 4 and t < 5
		local stretch = math.clamp((t - 5) / 0.3, 0, 1) * (1 - math.clamp((t - 5.6) / 0.3, 0, 1))
		local shock = if t >= 6 and t < 7 then 1 else 0
		local running = t >= 7
		local momCf = CFrame.lookAt(momAt, if (momNext - momAt).Magnitude > 0.1 then momNext else momAt + Vector3.new(1, 0, 0))
		local runPhase = if running then t * 16 elseif walking then t * 9 else 0
		scene.pose(momCf, if t >= 5.6 and t < 6 then 0.2 else 0, if running then 1 else stretch, 0, shock, runPhase)
		scene.face(t >= 6)
		-- She sees it
		if once("see", 6, t) then
			if box then
				(box :: Sound):Stop()
			end
			sound("Scratch", 1.2)
			mark.Text = "❗"
		end
		if once("scream", 6.15, t) then
			sound("Scream", 1.5)
		end
		if once("puzzled", 9.6, t) then
			mark.Text = "❓"
			meow(Config.Meow, 0.8, 1.2)
		end
		-- The camera: wide like the dream, close on her face, then watching her run
		local size = screen.AbsoluteSize
		if t < 5.6 then
			local follow = math.clamp(catX + 2, -8, 14)
			local camX = follow + (-5 - follow) * math.clamp((t - 3.4) / 1.2, 0, 1)
			cam.CFrame = CFrame.lookAt(Vector3.new(camX, 5.5, 16), Vector3.new(camX, 2, 0))
		elseif t < 7 then
			local shake = if t >= 6 then Vector3.new(math.sin(t * 60) * 0.12, math.cos(t * 55) * 0.12, 0) else Vector3.zero
			cam.CFrame = CFrame.lookAt(Vector3.new(-6.5, 6, 7) + shake, Vector3.new(-10, 5.2, 0.6))
		elseif t < 9.6 then
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 11, 22), momAt:Lerp(Vector3.new(-3, 2, 0), 0.4) + Vector3.new(0, 2, 0))
		else
			cam.CFrame = CFrame.lookAt(Vector3.new(-3, 4, 9), Vector3.new(-3, 2.2, 0))
		end
		local markAt = if t < 9.6 then momAt + Vector3.new(0, 8, 0) else Vector3.new(-3, 4.6, 0)
		mark.Position = if mark.Text ~= "" and size then project(cam, size, markAt) else UDim2.fromScale(-1, -1)
		if once("out", LENGTH - 0.8, t) then
			TweenService:Create(black, TweenInfo.new(0.7), { BackgroundTransparency = 0 }):Play()
		end
		RunService.RenderStepped:Wait()
	end
	if box then
		(box :: Sound):Destroy()
	end
	if skip then
		skipClip = nil
		skip:Destroy()
	end
	fade.BackgroundTransparency = 0
	screen:Destroy()
	letterbox(false)
	endClip(my)
	TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

-- Free! Out in the night a mouse runs across the road, and Pianka gets it
local function freeClip(root: BasePart)
	if introOn then
		return
	end
	local my = beginClip(2, 0)
	if not my then
		return
	end
	letterbox(true)
	local at = root.Position
	local ahead = Vector3.new(0, 0, 1)
	local side = Vector3.new(1, 0, 0)
	local holder = Instance.new("Model")
	holder.Parent = workspace
	local mouse, dead = buildMouse(holder)
	-- A stand-in Pianka does the pounce, the real one hides for the clip
	local hunter = Cat.build(CFrame.new(at), 1)
	hunter.model.Parent = holder
	local hidden: { BasePart } = {}
	for _, p in (root.Parent :: Instance):GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
			table.insert(hidden, p)
		end
	end
	local start = os.clock()
	local cues: { [string]: boolean } = {}
	local caughtAt = at + ahead * 26
	winsSeen += 1
	endingSkipped = false
	local skip = endingSkip()
	while clipId == my and not endingSkipped and os.clock() - start < 6.6 do
		local t = os.clock() - start
		local k = math.clamp((t - 1.5) / 2.5, 0, 1)
		local pos = at + ahead * 26 + side * (-24 + k * 48)
		local catPos = at
		local catLook = ahead
		if t >= 2.8 and t < 3.8 then
			-- The pounce: a big leap onto the mouse
			local j = (t - 2.8) / 1
			caughtAt = at + ahead * 26 + side * (-24 + math.clamp((3.8 - 1.5) / 2.5, 0, 1) * 48)
			catPos = at:Lerp(caughtAt - ahead * 1.5, j) + Vector3.new(0, math.sin(j * math.pi) * 6, 0)
			catLook = (Vector3.new(caughtAt.X, at.Y, caughtAt.Z) - Vector3.new(at.X, at.Y, at.Z)).Unit
		elseif t >= 3.8 then
			-- Got it: she turns proudly to the camera with it
			catPos = caughtAt - ahead * 1.5
			local turn = math.clamp((t - 4.2) / 0.6, 0, 1)
			catLook = ((Vector3.new(caughtAt.X, at.Y, caughtAt.Z) - Vector3.new(at.X, at.Y, at.Z)).Unit):Lerp(-ahead, turn)
			if catLook.Magnitude < 0.01 then
				catLook = -ahead
			end
			catLook = catLook.Unit
		end
		local catCf = CFrame.lookAt(Vector3.new(catPos.X, at.Y - 1.4, catPos.Z), Vector3.new(catPos.X, at.Y - 1.4, catPos.Z) + catLook)
		hunter.model:PivotTo(catCf * CFrame.new(0, 1.4 + (catPos.Y - at.Y), 0))
		if t < 3.8 then
			mouse:PivotTo(CFrame.lookAt(pos, pos + side) * CFrame.new(0, 0.45 + math.abs(math.sin(t * 16)) * 0.2 - 1.4, 0))
		else
			mouse:PivotTo(catCf * CFrame.new(0, 1.85, -2.8) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.5))
		end
		dead(t >= 3.8)
		local camFrom = if t < 3.8 then at - ahead * 10 + Vector3.new(0, 5 + t * 0.4, 0) else caughtAt - ahead * 9 + Vector3.new(0, 4, 0)
		local camTo = if t < 3.8 then at + ahead * 22 + Vector3.new(0, 1, 0) else caughtAt - ahead * 1.5 + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(camFrom, camTo)
		if t > 1.6 and not cues.squeak then
			cues.squeak = true
			sound("Mouse", 1)
		end
		if t > 2.4 and not cues.look then
			cues.look = true
			popIcon(hunter.body or root, "🐭❗", 1.4, 80)
			meow(Config.Mew, 1, 1.3)
		end
		if t > 2.8 and not cues.pounce then
			cues.pounce = true
			sound("Pounce", 1.2)
		end
		if t > 3.8 and not cues.caught then
			cues.caught = true
			sound("Mouse", 0.9, 1.3)
			sound("Key", 0.5, 1.3)
			popIcon(hunter.body or root, "⭐", 1.4, 80)
		end
		if t > 5.6 and not cues.fade then
			cues.fade = true
			TweenService:Create(fade, TweenInfo.new(0.9), { BackgroundTransparency = 0 }):Play()
		end
		RunService.RenderStepped:Wait()
	end
	holder:Destroy()
	for _, p in hidden do
		p.LocalTransparencyModifier = 0
	end
	if skip then
		skipClip = nil
		skip:Destroy()
	end
	if not endClip(my) then
		return
	end
	if endingSkipped then
		fade.BackgroundTransparency = 1
	else
		homeClip()
	end
	showEndCard()
end

-- A key picture floats over every key nearby, walls hide it
local function markKey(key: Instance)
	task.defer(function()
		local main = key:IsA("Model") and key.PrimaryPart
		if main then
			local bill = new("BillboardGui", { Size = UDim2.fromOffset(40, 40), StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0), MaxDistance = 34, Parent = main })
			new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextScaled = true, Text = if key:GetAttribute("Gate") then "🗝️" else "🔑", Parent = bill })
		end
	end)
end
task.spawn(function()
	local keys = world:WaitForChild("Keys", 20)
	if keys then
		for _, k in keys:GetChildren() do
			markKey(k)
		end
		keys.ChildAdded:Connect(markKey)
	end
end)

-- Keys twinkle now and then so you can find them by ear. Outside, crickets
local crickets: Sound? = nil
task.spawn(function()
	while true do
		task.wait(4)
		local root = myRoot()
		local keys = world:FindFirstChild("Keys")
		-- Only the nearest key, and not while someone close is about to look
		local hush = false
		for _, sl in sleepers do
			if root and (sl.phase == "warn" or sl.phase == "look") and (sl.head.Position - root.Position).Magnitude < Config.StirRange then
				hush = true
			end
		end
		if root and keys and not clipOn and not hush then
			local best, bestD = nil, 70
			for _, key in keys:GetChildren() do
				local main = key:IsA("Model") and key.PrimaryPart
				if main and (main.Position - root.Position).Magnitude < bestD then
					best, bestD = main, (main.Position - root.Position).Magnitude
				end
			end
			if best then
				playClip(best, SFX.Key, 0.45, 1.6, 40, sfx, true)
			end
		end
		if not crickets and sfx then
			crickets = loopClip(SoundService, SFX.Crickets, 0, 1000)
		end
		if crickets then
			local outside = player:GetAttribute("Out") == true
			TweenService:Create(crickets :: Sound, TweenInfo.new(2), { Volume = if outside then 0.6 else 0.05 }):Play()
		end
	end
end)

event.OnClientEvent:Connect(function(kind: string, a: any, b: any, ...: any)
	if kind == "key" or kind == "gateKey" then
		sound("Key", 1)
		local root = if typeof(a) == "Instance" and a:IsA("Player") and a.Character then a.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		flyKey(if root then root.Position else camera.CFrame.Position, tonumber(b) or 1, kind == "gateKey")
	elseif kind == "allKeys" then
		lockedShown = true
		if doorHint then
			doorHint:Destroy()
			doorHint = nil
		end
		task.spawn(doorClip)
	elseif kind == "gateOpen" then
		local gate = yardPart("Gate")
		sound("AllKeys", 1)
		task.delay(1.2, function()
			sound("Unlock", 1, 1, gate)
			sound("Gate", 1.4, 1, gate, 200)
		end)
		if gate then
			task.spawn(gateClip, gate)
		end
	elseif kind == "toy" and typeof(a) == "Instance" then
		local model = a :: Model
		local main = model.PrimaryPart
		spike = 1
		if main then
			local info = Config.Toys[b] or Config.Toys.squeaky
			local clip = if b == "squeaky" and math.random() < 0.5 then "Squeak2" else info.sound
			sound(clip, 2, 0.9 + math.random() * 0.2, main, 140)
			popIcon(main, "💥", 0.9, 54)
			-- The controller's light flashes while it buzzes
			local lightBar = model:FindFirstChild("Light") :: BasePart?
			if lightBar then
				task.spawn(function()
					for i = 1, 8 do
						lightBar.Color = if i % 2 == 0 then Color3.fromRGB(80, 150, 255) else Color3.fromRGB(255, 255, 255)
						task.wait(0.1)
					end
				end)
			end
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
			local pivot = model:GetPivot()
			task.spawn(function()
				local start = os.clock()
				local small = Config.Toys[b] and Config.Toys[b].small
				local length = if small then 0.9 else 0.5
				while os.clock() - start < length and model.Parent do
					local k = (os.clock() - start) / length
					if small then
						-- Small things shake and rattle on the floor
						model:PivotTo(pivot * CFrame.new(math.sin(k * 60) * 0.12 * (1 - k), math.abs(math.sin(k * 40)) * 0.15 * (1 - k), 0) * CFrame.Angles(0, math.sin(k * 30) * 0.3 * (1 - k), 0))
					else
						model:PivotTo(pivot * CFrame.new(0, math.abs(math.sin(k * math.pi * 2)) * 0.8 * (1 - k), 0))
					end
					RunService.Heartbeat:Wait()
				end
				model:PivotTo(pivot)
			end)
		end
	elseif kind == "grumble" then
		spike = math.max(spike, 0.6)
		sound("Grumble", 0.7, 0.9 + math.random() * 0.2)
	elseif kind == "tease" then
		spike = math.max(spike, 0.8)
		local calls = Config.Calls
		voice(calls[math.random(1, #calls)], 0.55)
	elseif kind == "wake" then
		task.spawn(wakeClip, tostring(a), b, select(1, ...))
	elseif kind == "escaped" then
		if a == player then
			task.spawn(exitClip)
		end
	elseif kind == "spotted" then
		task.spawn(spottedClip, b, a)
	elseif kind == "garage" then
		local door = yardPart("GarageDoor")
		sound("Click", 1.2)
		if door then
			sound("Gate", 1.3, 1.6, door, 160)
		end
		if a == player and b == "outside" then
			task.spawn(garageClip)
		end
	elseif kind == "free" then
		if moonMark then
			moonMark:Destroy()
			moonMark = nil
		end
		sound("AllKeys", 1)
		meow(Config.Meow, 1, 1.05)
		local root = if typeof(a) == "Instance" and a:IsA("Player") and a.Character then a.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root then
			popIcon(root, "🌙🐈", 4, 100)
			task.spawn(freeClip, root)
		end
	elseif kind == "scores" and type(a) == "table" then
		for _, entry in a do
			if type(entry) == "table" and entry.id == player.UserId then
				myTime = tonumber(entry.time)
			end
		end
		bestList = if type(b) == "table" then b else {}
		if endCard then
			fillCard(endCard)
		end
	elseif kind == "round" then
		roundCount += 1
		myTime = nil
		for _, lock in hiddenLocks do
			lock.LocalTransparencyModifier = 0
		end
		table.clear(hiddenLocks)
		for _, thing in { moonMark, endCard } :: { Instance? } do
			if thing then
				thing:Destroy()
			end
		end
		moonMark, endCard = nil, nil
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
	local house = world:FindFirstChild("House")
	for _, holder in { house and house:FindFirstChild("ExitDoor"), yardPart("Gate") } :: { Instance? } do
		if holder and holder:IsA("BasePart") and not holder.CanCollide then
			for _, lock in holder:GetChildren() do
				if lock:IsA("BasePart") and lock.Name == "Lock" then
					lock.LocalTransparencyModifier = 1
					table.insert(hiddenLocks, lock)
				end
			end
		end
	end
	intro()
	showDoorHint()
end)
