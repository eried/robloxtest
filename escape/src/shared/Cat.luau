-- Pianka, the same black cat as in Find Pianka the Cat
local Cat = {}

Cat.Color = Color3.fromRGB(34, 34, 40)
Cat.Eyes = Color3.fromRGB(255, 210, 40)
Cat.Collar = Color3.fromRGB(255, 90, 170)

export type Built = {
	model: Model,
	body: BasePart,
	head: BasePart,
	tail: BasePart,
	legs: { BasePart },
}

function Cat.build(base: CFrame, scale: number): Built
	local model = Instance.new("Model")
	model.Name = "Pianka"
	local function add(name: string, class: string, size: Vector3, pos: Vector3, color: Color3?, rotation: CFrame?): BasePart
		local p = Instance.new(class) :: BasePart
		p.Name = name
		p.Size = size * scale
		p.CFrame = base * CFrame.new(pos * scale) * (rotation or CFrame.identity)
		p.Color = color or Cat.Color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = model
		return p
	end
	local body = add("Body", "Part", Vector3.new(1.6, 1.4, 2.6), Vector3.new(0, 1.4, 0))
	local head = add("Head", "Part", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 2.3, -1.5))
	local collar = add("Collar", "Part", Vector3.new(1.55, 0.3, 0.35), Vector3.new(0, 1.85, -1.3), Cat.Collar)
	collar.Material = Enum.Material.Neon
	add("Muzzle", "Part", Vector3.new(0.8, 0.5, 0.2), Vector3.new(0, 2.05, -2.2))
	add("Nose", "Part", Vector3.new(0.25, 0.2, 0.1), Vector3.new(0, 2.25, -2.32), Color3.fromRGB(55, 55, 60))
	for _, x in { -0.38, 0.38 } do
		local eye = add("Eye", "Part", Vector3.new(0.3, 0.3, 0.3), Vector3.new(x, 2.55, -2.15), Cat.Eyes) :: Part
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Neon
	end
	add("EarL", "WedgePart", Vector3.new(0.4, 0.6, 0.5), Vector3.new(-0.45, 3.25, -1.5), nil, CFrame.Angles(0, math.rad(90), 0))
	add("EarR", "WedgePart", Vector3.new(0.4, 0.6, 0.5), Vector3.new(0.45, 3.25, -1.5), nil, CFrame.Angles(0, math.rad(-90), 0))
	local legs = {}
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.9, 0.9 } do
			local leg = add("Leg", "Part", Vector3.new(0.4, 0.8, 0.4), Vector3.new(x, 0.4, z))
			leg:SetAttribute("Swing", if (x < 0) == (z < 0) then 1 else -1)
			table.insert(legs, leg)
		end
	end
	local tail = add("Tail", "Part", Vector3.new(0.3, 0.3, 1.8), Vector3.new(0, 2, 1.7), nil, CFrame.Angles(math.rad(-50), 0, 0))
	tail:SetAttribute("Wag", true)
	model.PrimaryPart = body
	return { model = model, body = body, head = head, tail = tail, legs = legs }
end

-- The player's character: Pianka on an invisible root, legs and tail on welds so they can move
function Cat.character(): Model
	local cat = Cat.build(CFrame.new(), 1)
	local model = cat.model
	model.Name = "StarterCharacter"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	-- Short and a little high so it slides up the steep stair ramp instead of digging in
	root.Size = Vector3.new(1.4, 1, 1)
	root.CFrame = CFrame.new(0, 1.4, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = p
			weld.C0 = root.CFrame:ToObjectSpace(p.CFrame)
			weld.Parent = p
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 0.9
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.UseJumpPower = false
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

return Cat
