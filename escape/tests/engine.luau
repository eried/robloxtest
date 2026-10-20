-- Tiny headless Roblox engine. Runs the real game scripts with fake players.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local V3, CF, V2 = roblox.Vector3, roblox.CFrame, roblox.Vector2
local Enum = roblox.Enum
local realTypeof = typeof

local Engine = {}
Engine.now = 0
Engine.errors = {} :: { { msg: string, trace: string, count: number } }
local errorIndex: { [string]: any } = {}

local function report(msg: any, trace: string?)
	local key = tostring(msg)
	local entry = errorIndex[key]
	if entry then
		entry.count += 1
		return
	end
	entry = { msg = key, trace = trace or "", count = 1 }
	errorIndex[key] = entry
	table.insert(Engine.errors, entry)
end
Engine.report = report

-- Scheduler
local sleeping: { { t: number, th: thread, args: any } } = {}
local owner: { [thread]: any } = setmetatable({}, { __mode = "k" }) :: any
local cancelled: { [thread]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local current: any = nil

local function run(th: thread, ...)
	if cancelled[th] or coroutine.status(th) ~= "suspended" then
		return
	end
	local prev = current
	current = owner[th]
	local ok, err = coroutine.resume(th, ...)
	current = prev
	if Engine.trace then
		print("resume", ok, err, coroutine.status(th))
	end
	if not ok then
		report(err, debug.traceback(th))
	end
end

local function newThread(f: any): thread
	local th = if type(f) == "thread" then f else coroutine.create(f)
	if owner[th] == nil then
		owner[th] = current
	end
	return th
end

local task = {}
function task.spawn(f: any, ...)
	local th = newThread(f)
	run(th, ...)
	return th
end
function task.delay(s: number?, f: any, ...)
	local th = newThread(f)
	table.insert(sleeping, { t = Engine.now + (s or 0), th = th, args = table.pack(...) })
	return th
end
function task.defer(f: any, ...)
	return task.delay(0, f, ...)
end
function task.wait(s: number?)
	local th = coroutine.running()
	local start = Engine.now
	table.insert(sleeping, { t = Engine.now + math.max(s or 0, 1 / 60), th = th, args = table.pack() })
	coroutine.yield()
	return Engine.now - start
end
function task.cancel(th: thread)
	cancelled[th] = true
end
Engine.task = task

-- Signals
local Connection = {}
Connection.__index = Connection
function Connection:Disconnect()
	self.Connected = false
	local list = self.signal.conns
	for i, c in list do
		if c == self then
			table.remove(list, i)
			break
		end
	end
end

local Signal = {}
Signal.__index = Signal
function Signal.new(name: string?)
	return setmetatable({ conns = {}, name = name }, Signal)
end
function Signal:Connect(f: any)
	local c = setmetatable({ f = f, Connected = true, owner = current, signal = self }, Connection)
	table.insert(self.conns, c)
	return c
end
function Signal:Once(f: any)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		f(...)
	end)
	return c
end
function Signal:Wait()
	local th = coroutine.running()
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		run(th, ...)
	end)
	return coroutine.yield()
end
function Signal:FireIf(filter: ((any) -> boolean)?, ...)
	for _, c in table.clone(self.conns) do
		if c.Connected and (not filter or filter(c.owner)) then
			local th = coroutine.create(c.f)
			owner[th] = c.owner
			run(th, ...)
		end
	end
end
function Signal:Fire(...)
	self:FireIf(nil, ...)
end
Engine.Signal = Signal

-- Instances
local PARENT_CLASS: { [string]: string } = {
	Part = "BasePart", SpawnLocation = "Part", MeshPart = "BasePart", WedgePart = "BasePart", TrussPart = "BasePart",
	Terrain = "BasePart", BasePart = "PVInstance", Model = "PVInstance", Workspace = "Model", PVInstance = "Instance",
	TextLabel = "GuiObject", TextButton = "GuiButton", ImageButton = "GuiButton", GuiButton = "GuiObject", ImageLabel = "GuiObject",
	Frame = "GuiObject", ScrollingFrame = "GuiObject", TextBox = "GuiObject", GuiObject = "GuiBase2d",
	ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector", LayerCollector = "GuiBase2d",
	PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light", Tool = "BackpackItem",
	Script = "LuaSourceContainer", LocalScript = "Script", ModuleScript = "LuaSourceContainer",
	IntValue = "ValueBase", StringValue = "ValueBase", NumberValue = "ValueBase", BoolValue = "ValueBase",
	Atmosphere = "Instance", BloomEffect = "PostEffect", ColorCorrectionEffect = "PostEffect",
}

local function isA(class: string, target: string): boolean
	if target == "Instance" then
		return true
	end
	local c: string? = class
	while c do
		if c == target then
			return true
		end
		c = PARENT_CLASS[c]
	end
	return false
end

local EVENTS: { [string]: boolean } = {}
for _, name in {
	"Triggered", "Activated", "MouseButton1Click", "Died", "CharacterAdded", "CharacterRemoving", "OnServerEvent",
	"OnClientEvent", "Changed", "Touched", "TouchEnded", "Completed", "Ended", "Played", "InputBegan", "InputEnded",
	"InputChanged", "PlayerAdded", "PlayerRemoving", "Heartbeat", "RenderStepped", "Stepped", "ChildAdded",
	"ChildRemoved", "DescendantAdded", "DescendantRemoving", "Equipped", "Unequipped", "PromptTriggered", "MessageOut",
	"AncestryChanged", "Destroying", "HealthChanged", "Running", "StateChanged", "Hit", "PromptShown", "PromptHidden",
	"TriggerEnded", "MouseEnter", "MouseLeave", "FocusLost", "Deactivated", "Loaded", "LastInputTypeChanged",
	"CharacterAppearanceLoaded", "WindowFocused", "WindowFocusReleased", "PromptGamePassPurchaseFinished", "JumpRequest",
} do
	EVENTS[name] = true
end

local function defaults(class: string): { [string]: any }
	local p: { [string]: any } = { Name = class, Archivable = true }
	if isA(class, "BasePart") then
		p.Size = V3.new(4, 1, 2)
		p.CFrame = CF.new()
		p.Anchored = false
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = true
		p.Transparency = 0
		p.Massless = false
		p.AssemblyLinearVelocity = V3.zero
		p.Color = roblox.Color3.new(0.6, 0.6, 0.6)
		p.Material = Enum.Material.Plastic
		p.Shape = Enum.PartType.Block
		p.LocalTransparencyModifier = 0
	elseif class == "Humanoid" then
		p.Health = 100
		p.MaxHealth = 100
		p.WalkSpeed = 16
		p.JumpHeight = 7.2
		p.JumpPower = 50
		p.UseJumpPower = false
		p.DisplayName = ""
		p.HipHeight = 2
	elseif class == "ProximityPrompt" then
		p.Enabled = true
		p.MaxActivationDistance = 10
		p.HoldDuration = 0
		p.RequiresLineOfSight = true
		p.ActionText = ""
		p.ObjectText = ""
	elseif class == "Sound" then
		p.Playing = false
		p.IsPlaying = false
		p.TimeLength = 10
		p.Volume = 0.5
		p.TimePosition = 0
		p.Looped = false
		p.PlaybackSpeed = 1
	elseif class == "Camera" then
		p.CFrame = CF.new(0, 20, 20)
		p.ViewportSize = V2.new(1280, 720)
		p.FieldOfView = 70
	elseif isA(class, "GuiObject") then
		p.Visible = true
		p.Size = roblox.UDim2.new()
		p.Position = roblox.UDim2.new()
		p.AbsoluteSize = V2.new(100, 40)
		p.AbsolutePosition = V2.new(0, 0)
		p.BackgroundTransparency = 0
		p.Text = ""
		p.TextTransparency = 0
		p.ZIndex = 1
		p.Rotation = 0
	elseif isA(class, "LayerCollector") then
		p.Enabled = true
	elseif isA(class, "Light") then
		p.Enabled = true
		p.Range = 8
		p.Brightness = 1
	elseif isA(class, "ValueBase") then
		p.Value = if class == "StringValue" then "" elseif class == "BoolValue" then false else 0
	elseif class == "Tool" then
		p.Enabled = true
		p.RequiresHandle = true
	end
	return p
end

local Inst = {}
local InstMT: any = {}
Engine.parts = setmetatable({}, { __mode = "k" }) :: { [any]: boolean }
Engine.prompts = setmetatable({}, { __mode = "k" }) :: { [any]: boolean }

local function newInstance(class: string): any
	local self = setmetatable({
		_class = class,
		_props = defaults(class),
		_children = {},
		_attrs = {},
		_events = {},
		_attrSig = {},
		_propSig = {},
		_parent = nil,
		_destroyed = false,
	}, InstMT)
	if isA(class, "BasePart") then
		Engine.parts[self] = true
	elseif class == "ProximityPrompt" then
		Engine.prompts[self] = true
	end
	return self
end
Engine.new = newInstance

local function isInstance(v: any): boolean
	return type(v) == "table" and getmetatable(v) == InstMT
end
Engine.isInstance = isInstance

local function event(self: any, name: string): any
	local e = self._events[name]
	if not e then
		e = Signal.new(name)
		self._events[name] = e
	end
	return e
end

local function setParent(self: any, parent: any)
	if self._destroyed then
		error("The Parent property of " .. tostring(self._props.Name) .. " is locked", 3)
	end
	if parent ~= nil and not isInstance(parent) then
		error("Parent must be an Instance", 3)
	end
	local old = self._parent
	if old == parent then
		return
	end
	if old then
		for i, c in old._children do
			if c == self then
				table.remove(old._children, i)
				break
			end
		end
		if old._events.ChildRemoved then
			old._events.ChildRemoved:Fire(self)
		end
	end
	self._parent = parent
	if parent then
		table.insert(parent._children, self)
		if parent._events.ChildAdded then
			parent._events.ChildAdded:Fire(self)
		end
	end
end

local CLASS_METHODS: { [string]: { [string]: any } } = {}

InstMT.__index = function(self: any, key: string): any
	local m = Inst[key]
	if m then
		return m
	end
	local c: string? = self._class
	while c do
		local t = CLASS_METHODS[c]
		if t and t[key] then
			return t[key]
		end
		c = PARENT_CLASS[c]
	end
	if key == "Parent" then
		return self._parent
	elseif key == "ClassName" then
		return self._class
	elseif key == "Position" and self._props.CFrame then
		return self._props.CFrame.Position
	end
	local v = self._props[key]
	if v ~= nil then
		return v
	end
	if EVENTS[key] then
		return event(self, key)
	end
	for _, child in self._children do
		if child._props.Name == key then
			return child
		end
	end
	return nil
end

-- WeldConstraints keep the offset they had when both parts were set
local function linkWeld(weld: any)
	local p0, p1 = weld._props.Part0, weld._props.Part1
	if weld._linked then
		local list = weld._linked._welds
		for i, w in list do
			if w.weld == weld then
				table.remove(list, i)
				break
			end
		end
		weld._linked = nil
	end
	if p0 and p1 and p0._props.CFrame and p1._props.CFrame then
		p0._welds = p0._welds or {}
		table.insert(p0._welds, { weld = weld, part = p1, offset = p0._props.CFrame:Inverse() * p1._props.CFrame })
		weld._linked = p0
	end
end

local function follow(part: any)
	local welds = part._welds
	if not welds then
		return
	end
	for _, w in welds do
		if not w.part._destroyed then
			w.part._props.CFrame = part._props.CFrame * w.offset
			follow(w.part)
		end
	end
end

InstMT.__newindex = function(self: any, key: string, value: any)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	local props = self._props
	if self._class == "WeldConstraint" and (key == "Part0" or key == "Part1") then
		props[key] = value
		linkWeld(self)
		return
	end
	if key == "Position" and props.CFrame then
		local old = props.CFrame
		props.CFrame = old - old.Position + value
		key = "CFrame"
	elseif key == "Health" and self._class == "Humanoid" then
		local before = props.Health
		props.Health = math.clamp(value, 0, props.MaxHealth)
		if before > 0 and props.Health <= 0 then
			event(self, "Died"):Fire()
		end
	else
		props[key] = value
	end
	if key == "CFrame" then
		follow(self)
	end
	local sig = self._propSig[key]
	if sig then
		sig:Fire()
	end
	if self._events.Changed then
		self._events.Changed:Fire(key)
	end
end

InstMT.__tostring = function(self: any)
	return tostring(self._props.Name)
end

function Inst:IsA(class: string): boolean
	return isA(self._class, class)
end
function Inst:GetChildren(): { any }
	return table.clone(self._children)
end
function Inst:GetDescendants(): { any }
	local out = {}
	local function walk(i: any)
		for _, c in i._children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(name: string, recursive: boolean?): any
	for _, c in self._children do
		if c._props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in self._children do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(class: string): any
	for _, c in self._children do
		if c._class == class then
			return c
		end
	end
	return nil
end
function Inst:FindFirstChildWhichIsA(class: string, recursive: boolean?): any
	for _, c in self._children do
		if isA(c._class, class) then
			return c
		end
	end
	if recursive then
		for _, c in self._children do
			local found = c:FindFirstChildWhichIsA(class, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function Inst:FindFirstAncestorOfClass(class: string): any
	local p = self._parent
	while p do
		if p._class == class then
			return p
		end
		p = p._parent
	end
	return nil
end
function Inst:FindFirstAncestorWhichIsA(class: string): any
	local p = self._parent
	while p do
		if isA(p._class, class) then
			return p
		end
		p = p._parent
	end
	return nil
end
function Inst:FindFirstAncestor(name: string): any
	local p = self._parent
	while p do
		if p._props.Name == name then
			return p
		end
		p = p._parent
	end
	return nil
end
function Inst:IsDescendantOf(other: any): boolean
	local p = self._parent
	while p do
		if p == other then
			return true
		end
		p = p._parent
	end
	return false
end
function Inst:WaitForChild(name: string, timeout: number?): any
	local start = Engine.now
	while true do
		local found = self:FindFirstChild(name)
		if found then
			return found
		end
		if timeout and Engine.now - start >= timeout then
			return nil
		end
		if not timeout and Engine.now - start > 10 then
			report("Infinite yield possible on WaitForChild(" .. name .. ") under " .. tostring(self._props.Name))
			start = math.huge
		end
		task.wait()
	end
end
function Inst:Destroy()
	if self._destroyed then
		return
	end
	if self._events.Destroying then
		self._events.Destroying:Fire()
	end
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
	setParent(self, nil)
	self._destroyed = true
	for _, e in self._events do
		table.clear(e.conns)
	end
end
function Inst:ClearAllChildren()
	for _, c in table.clone(self._children) do
		c:Destroy()
	end
end
function Inst:Clone(): any
	local map: { [any]: any } = {}
	local function copy(i: any): any
		local n = newInstance(i._class)
		for k, v in i._props do
			n._props[k] = v
		end
		for k, v in i._attrs do
			n._attrs[k] = v
		end
		map[i] = n
		for _, c in i._children do
			local cc = copy(c)
			cc._parent = n
			table.insert(n._children, cc)
		end
		return n
	end
	local root = copy(self)
	for _, n in map do
		for k, v in n._props do
			if isInstance(v) and map[v] then
				n._props[k] = map[v]
			end
		end
	end
	return root
end
function Inst:GetAttribute(name: string): any
	return self._attrs[name]
end
function Inst:GetAttributes(): { [string]: any }
	return table.clone(self._attrs)
end
function Inst:SetAttribute(name: string, value: any)
	if self._attrs[name] == value then
		return
	end
	self._attrs[name] = value
	local sig = self._attrSig[name]
	if sig then
		sig:Fire()
	end
end
function Inst:GetAttributeChangedSignal(name: string): any
	local sig = self._attrSig[name]
	if not sig then
		sig = Signal.new(name)
		self._attrSig[name] = sig
	end
	return sig
end
function Inst:GetPropertyChangedSignal(name: string): any
	local sig = self._propSig[name]
	if not sig then
		sig = Signal.new(name)
		self._propSig[name] = sig
	end
	return sig
end
function Inst:GetFullName(): string
	local names = {}
	local i = self
	while i do
		table.insert(names, 1, tostring(i._props.Name))
		i = i._parent
	end
	return table.concat(names, ".")
end

local function pivotOf(self: any): any
	if self._props.CFrame then
		return self._props.CFrame
	end
	local primary = self._props.PrimaryPart
	if primary then
		return primary._props.CFrame
	end
	for _, d in self:GetDescendants() do
		if d._props.CFrame and isA(d._class, "BasePart") then
			return d._props.CFrame
		end
	end
	return CF.new()
end

CLASS_METHODS.PVInstance = {
	GetPivot = function(self: any)
		return pivotOf(self)
	end,
	PivotTo = function(self: any, cf: any)
		local delta = cf * pivotOf(self):Inverse()
		local list = self:GetDescendants()
		table.insert(list, self)
		for _, d in list do
			if d._props.CFrame and isA(d._class, "BasePart") then
				d.CFrame = delta * d._props.CFrame
			end
		end
	end,
	GetBoundingBox = function(self: any)
		return pivotOf(self), V3.new(4, 4, 4)
	end,
}

CLASS_METHODS.ParticleEmitter = {
	Emit = function(self: any) end,
	Clear = function(self: any) end,
}

CLASS_METHODS.Humanoid = {
	TakeDamage = function(self: any, amount: number)
		self.Health = self._props.Health - amount
	end,
	EquipTool = function(self: any, tool: any)
		if self._parent then
			tool.Parent = self._parent
		end
	end,
	UnequipTools = function(self: any) end,
	MoveTo = function(self: any) end,
	ChangeState = function(self: any) end,
	GetState = function(self: any)
		return Enum.HumanoidStateType.Running
	end,
	LoadAnimation = function(self: any)
		return { Play = function() end, Stop = function() end }
	end,
}

CLASS_METHODS.Sound = {
	Play = function(self: any)
		self._props.Playing = true
		self._props.IsPlaying = true
	end,
	Stop = function(self: any)
		self._props.Playing = false
		self._props.IsPlaying = false
	end,
	Pause = function(self: any)
		self._props.Playing = false
		self._props.IsPlaying = false
	end,
	Resume = function(self: any)
		self._props.Playing = true
		self._props.IsPlaying = true
	end,
}

-- Contexts: one server, one per client
Engine.server = { name = "server", isClient = false, modules = {} }
Engine.clients = {} :: { any }
local serverCtx = Engine.server

CLASS_METHODS.RemoteEvent = {
	FireServer = function(self: any, ...)
		local ctx = current
		if not ctx or not ctx.isClient then
			error("FireServer can only be called from the client", 2)
		end
		local args = table.pack(...)
		local th = coroutine.create(function()
			event(self, "OnServerEvent"):FireIf(function(o)
				return o == serverCtx
			end, ctx.player, table.unpack(args, 1, args.n))
		end)
		owner[th] = serverCtx
		table.insert(sleeping, { t = Engine.now, th = th, args = table.pack() })
	end,
	FireClient = function(self: any, player: any, ...)
		if current and current.isClient then
			error("FireClient can only be called from the server", 2)
		end
		if not isInstance(player) or player._class ~= "Player" then
			error("FireClient: player argument must be a Player", 2)
		end
		local args = table.pack(...)
		if Engine.onFire then
			Engine.onFire(self, player, args)
		end
		local th = coroutine.create(function()
			event(self, "OnClientEvent"):FireIf(function(o)
				return o ~= nil and o.isClient and o.player == player
			end, table.unpack(args, 1, args.n))
		end)
		owner[th] = serverCtx
		table.insert(sleeping, { t = Engine.now, th = th, args = table.pack() })
	end,
	FireAllClients = function(self: any, ...)
		if current and current.isClient then
			error("FireAllClients can only be called from the server", 2)
		end
		local args = table.pack(...)
		if Engine.onFire then
			Engine.onFire(self, nil, args)
		end
		local th = coroutine.create(function()
			event(self, "OnClientEvent"):FireIf(function(o)
				return o ~= nil and o.isClient
			end, table.unpack(args, 1, args.n))
		end)
		owner[th] = serverCtx
		table.insert(sleeping, { t = Engine.now, th = th, args = table.pack() })
	end,
}

-- Data model
local game = newInstance("DataModel")
game._props.Name = "Game"
game._props.PlaceId = 89612399968042
game._props.JobId = "test"
local workspace = newInstance("Workspace")
workspace._props.Name = "Workspace"
workspace.Parent = game
local terrain = newInstance("Terrain")
terrain._props.Name = "Terrain"
terrain.Parent = workspace
local camera = newInstance("Camera")
camera._props.Name = "Camera"
camera.Parent = workspace
workspace._props.CurrentCamera = camera
Engine.game = game
Engine.workspace = workspace

CLASS_METHODS.Terrain = {
	Clear = function() end,
	FillBlock = function() end,
	FillBall = function() end,
	FillCylinder = function() end,
	SetMaterialColor = function() end,
}

local serviceClasses: { [string]: boolean } = {}
for _, name in {
	"Players", "ReplicatedStorage", "ServerScriptService", "Lighting", "TweenService", "RunService", "SoundService",
	"StarterGui", "UserInputService", "ContentProvider", "DataStoreService", "StarterPlayer", "ServerStorage",
	"ProximityPromptService", "Debris", "HttpService", "TextChatService", "CollectionService", "MarketplaceService", "GuiService",
} do
	serviceClasses[name] = true
end

CLASS_METHODS.DataModel = {
	GetService = function(self: any, name: string)
		if name == "Workspace" then
			return workspace
		end
		if not serviceClasses[name] then
			error("'" .. name .. "' is not a valid Service name", 2)
		end
		local found = self:FindFirstChildOfClass(name)
		if not found then
			found = newInstance(name)
			found._props.Name = name
			found._parent = self
			table.insert(self._children, found)
		end
		return found
	end,
	BindToClose = function(self: any, f: any)
		Engine.onClose = f
	end,
}

CLASS_METHODS.Workspace = {
	GetServerTimeNow = function()
		return 1.7e9 + Engine.now
	end,
	Raycast = function(self: any, origin: any, direction: any, params: any)
		return Engine.raycast(origin, direction, params)
	end,
}

CLASS_METHODS.RunService = {
	IsServer = function()
		return not (current and current.isClient)
	end,
	IsClient = function()
		return current ~= nil and current.isClient
	end,
	IsStudio = function()
		return false
	end,
	IsRunning = function()
		return true
	end,
}

-- Game passes: Engine.passes[userId][passId] = true means owned
Engine.passes = {} :: { [number]: { [number]: boolean } }
CLASS_METHODS.MarketplaceService = {
	UserOwnsGamePassAsync = function(self: any, userId: number, passId: number)
		return (Engine.passes[userId] or {})[passId] == true
	end,
	PromptGamePassPurchase = function(self: any, player: any, passId: number)
		local service = self
		task.defer(function()
			local owned = Engine.passes[player._props.UserId] or {}
			Engine.passes[player._props.UserId] = owned
			owned[passId] = true
			event(service, "PromptGamePassPurchaseFinished"):FireIf(function(o)
				return o == serverCtx
			end, player, passId, true)
		end)
	end,
}

CLASS_METHODS.ContentProvider = {
	PreloadAsync = function() end,
}

CLASS_METHODS.StarterGui = {
	SetCoreGuiEnabled = function() end,
	GetCoreGuiEnabled = function()
		return true
	end,
	SetCore = function() end,
}

CLASS_METHODS.UserInputService = {
	GetLastInputType = function()
		return Enum.UserInputType.Keyboard
	end,
	IsKeyDown = function()
		return false
	end,
}

CLASS_METHODS.Players = {
	GetPlayers = function(self: any)
		local list = {}
		for _, c in self._children do
			if c._class == "Player" then
				table.insert(list, c)
			end
		end
		return list
	end,
	GetPlayerByUserId = function(self: any, id: number)
		for _, c in self._children do
			if c._class == "Player" and c._props.UserId == id then
				return c
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(self: any, character: any)
		for _, c in self._children do
			if c._class == "Player" and c._props.Character == character then
				return c
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(self: any, id: number)
		return "Player" .. tostring(id)
	end,
}

-- Tweens finish after their time, looping tweens never finish
CLASS_METHODS.TweenService = {
	Create = function(self: any, target: any, info: any, goals: any)
		local tween = { PlaybackState = Enum.PlaybackState.Begin, Completed = Signal.new("Completed") }
		local th: thread? = nil
		function tween.Play(t: any)
			if (info.RepeatCount or 0) < 0 then
				t.PlaybackState = Enum.PlaybackState.Playing
				return
			end
			t.PlaybackState = Enum.PlaybackState.Playing
			th = task.delay((info.Time or 1) * (if info.Reverses then 2 else 1) * ((info.RepeatCount or 0) + 1) + (info.DelayTime or 0), function()
				if not target._destroyed and not info.Reverses then
					for k, v in goals do
						target[k] = v
					end
				end
				t.PlaybackState = Enum.PlaybackState.Completed
				t.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function tween.Cancel(t: any)
			if th then
				task.cancel(th)
			end
			t.PlaybackState = Enum.PlaybackState.Cancelled
		end
		function tween.Pause(t: any)
			tween.Cancel(t)
		end
		function tween.Destroy() end
		return tween
	end,
}

-- In-memory data stores
local stores: { [string]: { [string]: any } } = {}
CLASS_METHODS.DataStoreService = {
	GetDataStore = function(self: any, name: string)
		stores[name] = stores[name] or {}
		local data = stores[name]
		return {
			GetAsync = function(_, key: string)
				return data[key]
			end,
			SetAsync = function(_, key: string, value: any)
				data[key] = value
			end,
			UpdateAsync = function(_, key: string, f: any)
				data[key] = f(data[key])
				return data[key]
			end,
			RemoveAsync = function(_, key: string)
				data[key] = nil
			end,
		}
	end,
	GetOrderedDataStore = function(self: any, name: string)
		stores["ordered:" .. name] = stores["ordered:" .. name] or {}
		local data = stores["ordered:" .. name]
		return {
			SetAsync = function(_, key: string, value: any)
				data[key] = value
			end,
			GetAsync = function(_, key: string)
				return data[key]
			end,
			GetSortedAsync = function(_, ascending: boolean, size: number)
				local list = {}
				for k, v in data do
					table.insert(list, { key = k, value = v })
				end
				table.sort(list, function(a, b)
					return if ascending then a.value < b.value else a.value > b.value
				end)
				local page = {}
				for i = 1, math.min(size, #list) do
					page[i] = list[i]
				end
				return {
					GetCurrentPage = function()
						return page
					end,
					IsFinished = true,
				}
			end,
		}
	end,
}
Engine.stores = stores

-- Raycast against part boxes
function Engine.raycast(origin: any, direction: any, params: any): any
	local exclude = params and params.FilterDescendantsInstances or {}
	local include = params and params.FilterType == Enum.RaycastFilterType.Include
	local best: number = 1
	local hit: any = nil
	for part in Engine.parts do
		if part._destroyed or part._class == "Terrain" or part._props.CanQuery == false then
			continue
		end
		if not part:IsDescendantOf(workspace) then
			continue
		end
		local listed = false
		for _, f in exclude do
			if part == f or part:IsDescendantOf(f) then
				listed = true
				break
			end
		end
		if listed ~= (include == true) then
			continue
		end
		local cf = part._props.CFrame
		local o = cf:PointToObjectSpace(origin)
		local d = cf:VectorToObjectSpace(direction)
		local h = part._props.Size / 2
		local tmin, tmax = 0, best
		local ok = true
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, ha = (o :: any)[axis], (d :: any)[axis], (h :: any)[axis]
			if math.abs(da) < 1e-9 then
				if oa < -ha or oa > ha then
					ok = false
					break
				end
			else
				local t1, t2 = (-ha - oa) / da, (ha - oa) / da
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin = math.max(tmin, t1)
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		if ok and tmin < best then
			best = tmin
			hit = part
		end
	end
	if not hit then
		return nil
	end
	local pos = origin + direction * best
	return { Instance = hit, Position = pos, Distance = (direction * best).Magnitude, Normal = V3.yAxis, Material = Enum.Material.Plastic }
end

-- Small datatypes Lune does not have
local RandomMT = {}
RandomMT.__index = RandomMT
function RandomMT:NextNumber(a: number?, b: number?): number
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	local lo, hi = a or 0, b or 1
	return lo + (self.s / 2147483648) * (hi - lo)
end
function RandomMT:NextInteger(a: number, b: number): number
	return math.floor(self:NextNumber(a, b + 1 - 1e-9))
end
function RandomMT:NextUnitVector(): any
	local v = V3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
	return if v.Magnitude > 0.01 then v.Unit else V3.xAxis
end
function RandomMT:Shuffle(t: { any })
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
Engine.seed = 84
local Random = {
	new = function(seed: number?)
		Engine.seed += 7919
		return setmetatable({ s = math.floor(seed or Engine.seed) % 2147483647 + 1 }, RandomMT)
	end,
}

local TweenInfo = {
	new = function(time: number?, style: any?, dir: any?, repeatCount: number?, reverses: boolean?, delayTime: number?)
		return {
			Time = time or 1,
			EasingStyle = style or Enum.EasingStyle.Quad,
			EasingDirection = dir or Enum.EasingDirection.Out,
			RepeatCount = repeatCount or 0,
			Reverses = reverses or false,
			DelayTime = delayTime or 0,
		}
	end,
}

local RaycastParams = {
	new = function()
		return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, IgnoreWater = false }
	end,
}

local function mockTypeof(v: any): string
	if isInstance(v) then
		return "Instance"
	elseif type(v) == "table" and getmetatable(v) == Signal then
		return "RBXScriptSignal"
	elseif type(v) == "table" and getmetatable(v) == Connection then
		return "RBXScriptConnection"
	end
	return realTypeof(v)
end

-- Lune's CFrame.lookAt flips Z for some directions, so build it the way Roblox does
local function lookAt(at: any, target: any, up: any?): any
	local look = target - at
	if look.Magnitude < 1e-6 then
		return CF.new(at)
	end
	look = look.Unit
	local right = look:Cross(up or V3.new(0, 1, 0))
	if right.Magnitude < 1e-6 then
		right = look:Cross(V3.new(0, 0, 1))
	end
	right = right.Unit
	return CF.fromMatrix(at, right, right:Cross(look), -look)
end
local FixedCFrame = setmetatable({ lookAt = lookAt }, { __index = CF })
Engine.CFrame = FixedCFrame

-- Scripts
local BUILTINS = {
	math = math, table = table, string = string, coroutine = coroutine, debug = debug, utf8 = utf8, bit32 = bit32,
	buffer = buffer, pcall = pcall, xpcall = xpcall, error = error, assert = assert, select = select, type = type,
	tostring = tostring, tonumber = tonumber, pairs = pairs, ipairs = ipairs, next = next, rawget = rawget,
	rawset = rawset, rawequal = rawequal, rawlen = rawlen, setmetatable = setmetatable, getmetatable = getmetatable,
	unpack = table.unpack, newproxy = newproxy, gcinfo = gcinfo,
}

local function makeEnv(ctx: any, scriptInst: any): any
	local env: any = setmetatable({}, { __index = BUILTINS })
	env.game = ctx.game
	env.workspace = workspace
	env.Workspace = workspace
	env.script = scriptInst
	env.Instance = {
		new = function(class: string, parent: any?)
			local i = newInstance(class)
			if parent then
				i.Parent = parent
			end
			return i
		end,
	}
	env.Enum = Enum
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "BrickColor", "NumberSequence",
		"NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Font", "Rect", "Ray",
		"PhysicalProperties", "Axes", "Faces", "Region3" } do
		env[name] = (roblox :: any)[name]
	end
	env.CFrame = FixedCFrame
	env.Random = Random
	env.TweenInfo = TweenInfo
	env.RaycastParams = RaycastParams
	env.task = task
	env.wait = task.wait
	env.delay = task.delay
	env.spawn = task.spawn
	env.tick = function()
		return 1.7e9 + Engine.now
	end
	env.time = function()
		return Engine.now
	end
	env.os = setmetatable({
		clock = function()
			return Engine.now
		end,
	}, { __index = os })
	env.typeof = mockTypeof
	env.print = function(...) end
	env.warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		Engine.warnings = (Engine.warnings or 0) + 1
		if Engine.verbose then
			print("[warn " .. ctx.name .. "] " .. table.concat(parts, " "))
		end
	end
	env.require = function(module: any)
		if not isInstance(module) or module._class ~= "ModuleScript" then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		local cached = ctx.modules[module]
		if cached ~= nil then
			return cached
		end
		local factory = ctx.factories and ctx.factories[module]
		if not factory then
			error("Module was not prepared: " .. tostring(module._props.Name), 2)
		end
		local result = factory()
		if Engine.patch then
			Engine.patch(module._props.Name, result)
		end
		ctx.modules[module] = result
		return result
	end
	return env
end

-- Lune runs loaded chunks on its own scheduler, so wrap the source in a plain function
function Engine.compile(path: string, env: any): any
	local source = "return function(...)\n" .. fs.readFile(path) .. "\nend"
	return luau.load(source, { debugName = path, environment = env, injectGlobals = false } :: any)()
end

-- Compile every shared module for a context ahead of time
local function prepare(ctx: any)
	ctx.factories = {}
	local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
	for _, m in shared:GetChildren() do
		if m._class == "ModuleScript" then
			ctx.factories[m] = Engine.compile(m._path, makeEnv(ctx, m))
		end
	end
end

function Engine.runScript(ctx: any, scriptInst: any, path: string)
	if not ctx.factories then
		prepare(ctx)
	end
	local chunk = Engine.compile(path, makeEnv(ctx, scriptInst))
	local th = coroutine.create(chunk)
	owner[th] = ctx
	run(th)
end

-- Builds the place the same way default.project.json does
function Engine.build()
	serverCtx.game = game
	local rs = game:GetService("ReplicatedStorage")
	local shared = newInstance("Folder")
	shared._props.Name = "Shared"
	shared.Parent = rs
	for _, file in fs.readDir("src/shared") do
		local name = string.match(file, "^(.-)%.luau$")
		if name then
			local m = newInstance("ModuleScript")
			m._props.Name = name
			m._path = "src/shared/" .. file
			m.Parent = shared
		end
	end
	local sss = game:GetService("ServerScriptService")
	local serverFolder = newInstance("Folder")
	serverFolder._props.Name = "Server"
	serverFolder.Parent = sss
	local forest = newInstance("Script")
	forest._props.Name = "Escape"
	forest.Parent = serverFolder
	Engine.serverScript = forest
	for _, name in { "Lighting", "TweenService", "RunService", "Players", "SoundService", "StarterGui", "UserInputService", "ContentProvider", "DataStoreService" } do
		game:GetService(name)
	end
	local uis = game:GetService("UserInputService")
	uis._props.TouchEnabled = false
	uis._props.KeyboardEnabled = true
	uis._props.MouseEnabled = true
	local players = game:GetService("Players")
	players._props.RespawnTime = 5
	players._props.CharacterAutoLoads = true
end

function Engine.startServer()
	Engine.runScript(serverCtx, Engine.serverScript, "src/server/Escape.server.luau")
end

-- Players and characters
local nextUserId = 1000

function Engine.loadCharacter(player: any)
	local old = player._props.Character
	if old then
		event(player, "CharacterRemoving"):Fire(old)
		old:Destroy()
	end
	local character = newInstance("Model")
	character._props.Name = player._props.Name
	local spawnAt = V3.new(math.random(-3, 3), 3, math.random(-3, 3))
	local root = newInstance("Part")
	root._props.Name = "HumanoidRootPart"
	root._props.Size = V3.new(2, 2, 1)
	root._props.CFrame = CF.new(spawnAt)
	root._props.Transparency = 1
	root.Parent = character
	local head = newInstance("Part")
	head._props.Name = "Head"
	head._props.Size = V3.new(2, 1, 1)
	head._props.CFrame = CF.new(spawnAt + V3.new(0, 1.5, 0))
	head.Parent = character
	local torso = newInstance("Part")
	torso._props.Name = "UpperTorso"
	torso._props.CFrame = CF.new(spawnAt)
	torso.Parent = character
	local humanoid = newInstance("Humanoid")
	humanoid._props.Name = "Humanoid"
	humanoid.Parent = character
	character._props.PrimaryPart = root
	player._props.Character = character
	character.Parent = workspace
	humanoid.Died:Connect(function()
		task.delay(game:GetService("Players")._props.RespawnTime or 5, function()
			if player._parent and player._props.Character == character then
				Engine.loadCharacter(player)
			end
		end)
	end)
	event(player, "CharacterAdded"):Fire(character)
	return character
end

CLASS_METHODS.Player = {
	LoadCharacterAsync = function(self: any)
		Engine.loadCharacter(self)
	end,
	LoadCharacter = function(self: any)
		Engine.loadCharacter(self)
	end,
	Kick = function(self: any)
		Engine.removePlayer(self)
	end,
	GetMouse = function()
		return { Hit = CF.new(), Target = nil }
	end,
}

function Engine.addPlayer(name: string, userId: number?): any
	nextUserId += 1
	local players = game:GetService("Players")
	local player = newInstance("Player")
	player._props.Name = name
	player._props.DisplayName = name
	player._props.UserId = userId or nextUserId
	for _, class in { "Backpack", "PlayerGui", "PlayerScripts" } do
		local i = newInstance(class)
		i._props.Name = class
		i.Parent = player
	end
	player.Parent = players
	local ctx = { name = name, isClient = true, player = player, modules = {} }
	local playersView = setmetatable({ LocalPlayer = player }, {
		__index = function(_, k)
			local v = players[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(players, ...)
				end
			end
			return v
		end,
	})
	ctx.game = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, service: string)
					if service == "Players" then
						return playersView
					end
					return game:GetService(service)
				end
			end
			local v = game[k]
			if type(v) == "function" then
				return function(_, ...)
					return v(game, ...)
				end
			end
			return v
		end,
	})
	table.insert(Engine.clients, ctx)
	players.PlayerAdded:Fire(player)
	Engine.loadCharacter(player)
	local gps = newInstance("LocalScript")
	gps._props.Name = "GPS"
	gps.Parent = player:FindFirstChild("PlayerScripts")
	Engine.runScript(ctx, gps, "src/client/Escape.client.luau")
	return player, ctx
end

function Engine.removePlayer(player: any)
	local players = game:GetService("Players")
	players.PlayerRemoving:Fire(player)
	local character = player._props.Character
	if character then
		character:Destroy()
	end
	player:Destroy()
	for i, ctx in Engine.clients do
		if ctx.player == player then
			table.remove(Engine.clients, i)
			break
		end
	end
end

-- Fire an input or UI event as a given client
function Engine.asClient(ctx: any, f: () -> ())
	local prev = current
	current = ctx
	local ok, err = pcall(f)
	current = prev
	if not ok then
		report(err)
	end
end

function Engine.fireForClient(ctx: any, signal: any, ...)
	signal:FireIf(function(o)
		return o == ctx
	end, ...)
end

function Engine.fireServer(signal: any, ...)
	signal:FireIf(function(o)
		return o == serverCtx
	end, ...)
end

-- Advance time
function Engine.step(dt: number)
	Engine.now += dt
	for _ = 1, 20 do
		local due = {}
		local keep = {}
		for _, s in sleeping do
			if s.t <= Engine.now + 1e-9 then
				table.insert(due, s)
			else
				table.insert(keep, s)
			end
		end
		if #due == 0 then
			break
		end
		sleeping = keep
		table.sort(due, function(a, b)
			return a.t < b.t
		end)
		for _, s in due do
			run(s.th, table.unpack(s.args, 1, s.args.n))
		end
	end
	local rs = game:GetService("RunService")
	rs.Stepped:Fire(Engine.now, dt)
	rs.Heartbeat:Fire(dt)
	rs.RenderStepped:Fire(dt)
end

function Engine.pending(): number
	return #sleeping
end

return Engine
