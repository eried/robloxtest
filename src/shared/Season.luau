-- Seasons: Halloween in October, Christmas in December, and the props they bring
local Season = {}

local ORANGE = Color3.fromRGB(235, 125, 30)
local DEEP_ORANGE = Color3.fromRGB(205, 95, 20)
local GLOW = Color3.fromRGB(255, 190, 70)
local SNOW = Color3.fromRGB(240, 245, 250)

-- "auto" picks by date: a hero's birthday, Halloween in October, Christmas in December.
-- Or the season named in Config ("None", "Halloween", "Christmas", "Birthday:Patrick").
-- Returns the season and, on a birthday, whose it is
function Season.pick(setting: string, month: number, day: number, birthdays: { [string]: { number } }): (string?, string?)
	if setting == "auto" then
		for hero, date in birthdays do
			if date[1] == month and date[2] == day then
				return "Birthday", hero
			end
		end
		return if month == 10 then "Halloween" elseif month == 12 then "Christmas" else nil, nil
	end
	-- Only heroes with a birthday date
	local hero = string.match(setting, "^Birthday:(%w+)$")
	if hero and birthdays[hero] then
		return "Birthday", hero
	elseif hero then
		return nil, nil
	end
	return if setting == "None" then nil else setting, nil
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.Class or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Class" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- A round pumpkin with a carved glowing face. Lit ones also light up the ground
function Season.pumpkin(pos: Vector3, size: number, lit: boolean, rand: Random, parent: Instance?): BasePart
	local r = size / 2
	local main = part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = pos + Vector3.new(0, r * 0.9, 0),
		Color = ORANGE,
		Parent = parent,
	})
	main:SetAttribute("Look", "Pumpkin")
	-- Soft lobes keep it round but give the pumpkin its ridges
	for i = 1, 4 do
		local a = i * math.pi / 2 + math.pi / 4
		part({
			Name = "Lobe",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * 0.93,
			Position = main.Position + Vector3.new(math.cos(a), -0.04, math.sin(a)) * size * 0.06,
			Color = DEEP_ORANGE,
			CanQuery = false,
			Parent = main,
		})
	end
	part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(size * 0.24, size * 0.12, size * 0.12),
		CFrame = CFrame.new(main.Position + Vector3.new(0, r * 1.02, 0)) * CFrame.Angles(0, 0, math.rad(80)),
		Color = Color3.fromRGB(80, 95, 40),
		CanQuery = false,
		Parent = main,
	})
	-- The face is carved on the front, each piece turned to follow the round shape
	local face = CFrame.new(main.Position) * CFrame.Angles(0, rand:NextNumber(0, math.pi * 2), 0)
	local function carve(name: string, x: number, y: number, w: number, h: number, tilt: number, color: Color3, lift: number)
		local z = math.sqrt(math.max(1 - x * x - y * y, 0.01))
		part({
			Name = name,
			Size = Vector3.new(w * size, h * size, size * 0.06),
			CFrame = face * CFrame.lookAt(Vector3.zero, Vector3.new(x, y, -z)) * CFrame.new(0, 0, -r - size * lift) * CFrame.Angles(0, 0, math.rad(tilt)),
			Color = color,
			Material = if color == GLOW then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			CanQuery = false,
			Parent = main,
		})
	end
	for _, x in { -0.36, 0.36 } do
		carve("Eye", x, 0.26, 0.19, 0.19, 45, GLOW, 0)
	end
	carve("Nose", 0, 0.02, 0.11, 0.11, 45, GLOW, 0)
	-- A wide smile made of short pieces along a curve
	for i = -2, 2 do
		local x = i * 0.2
		local y = -0.3 - 0.14 * (1 - (x / 0.42) ^ 2)
		carve("Mouth", x, y, 0.13, 0.1, math.deg(math.atan(0.28 * x / 0.42 ^ 2)), GLOW, 0)
	end
	for _, x in { -0.1, 0.1 } do
		carve("Tooth", x, -0.39, 0.06, 0.06, 0, ORANGE, 0.01)
	end
	if lit then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 60)
		light.Range = 10
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = main
	end
	return main
end

-- A wrapped present with a ribbon
function Season.present(pos: Vector3, rand: Random, parent: Instance?): BasePart
	local colors = { Color3.fromRGB(200, 40, 45), Color3.fromRGB(40, 140, 70), Color3.fromRGB(50, 90, 200) }
	local size = Vector3.new(rand:NextNumber(2.6, 3.4), rand:NextNumber(2.2, 3), rand:NextNumber(2.6, 3.4))
	local yaw = CFrame.Angles(0, rand:NextNumber(0, math.pi * 2), 0)
	local main = part({
		Name = "HidingSpot",
		Size = size,
		CFrame = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)) * yaw,
		Color = colors[rand:NextInteger(1, #colors)],
		Parent = parent,
	})
	local gold = Color3.fromRGB(255, 205, 60)
	part({ Name = "Ribbon", Size = Vector3.new(size.X + 0.06, size.Y + 0.06, 0.35), CFrame = main.CFrame, Color = gold, CanQuery = false, Parent = main })
	part({ Name = "Ribbon", Size = Vector3.new(0.35, size.Y + 0.06, size.Z + 0.06), CFrame = main.CFrame, Color = gold, CanQuery = false, Parent = main })
	for _, a in { 45, -45 } do
		part({
			Name = "Bow",
			Size = Vector3.new(0.9, 0.5, 0.25),
			CFrame = main.CFrame * CFrame.new(0, size.Y / 2 + 0.2, 0) * CFrame.Angles(0, math.rad(a), 0),
			Color = gold,
			CanQuery = false,
			Parent = main,
		})
	end
	return main
end

-- A mound of snow, half in the ground
function Season.snowPile(pos: Vector3, size: number, parent: Instance?): BasePart
	local main = part({
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = pos + Vector3.new(0, size * 0.18, 0),
		Color = SNOW,
		Material = Enum.Material.Snow,
		Parent = parent,
	})
	main:SetAttribute("Look", "Snow")
	return main
end

-- A small bat with two wings that can flap
function Season.bat(parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = "Bat"
	local dark = Color3.fromRGB(25, 20, 30)
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, Color = dark, CanQuery = false, CastShadow = false, Parent = model })
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		part({
			Name = "Wing",
			Class = "WedgePart",
			Size = Vector3.new(0.08, 0.6, 1.3),
			CFrame = body.CFrame * CFrame.new(side * 0.75, 0, 0) * CFrame.Angles(0, math.rad(90 * side), 0),
			Color = dark,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	for _, x in { -0.14, 0.14 } do
		part({
			Name = "Eye",
			Size = Vector3.one * 0.1,
			CFrame = body.CFrame * CFrame.new(x, 0.08, -0.33),
			Color = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.Neon,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

-- Hat parts for a cat head: witch hat for Halloween, Santa hat for Christmas.
-- Returns size, offset and color for each part, the caller builds them its own way.
function Season.hat(season: string?): { { size: Vector3, offset: Vector3, color: Color3, ball: boolean? } }
	if season == "Halloween" then
		local black = Color3.fromRGB(30, 25, 35)
		return {
			{ size = Vector3.new(1.4, 0.12, 1.4), offset = Vector3.new(0, 3.0, -1.5), color = black },
			{ size = Vector3.new(0.85, 0.5, 0.85), offset = Vector3.new(0, 3.3, -1.5), color = black },
			{ size = Vector3.new(0.88, 0.12, 0.88), offset = Vector3.new(0, 3.15, -1.5), color = Color3.fromRGB(140, 60, 170) },
			{ size = Vector3.new(0.55, 0.45, 0.55), offset = Vector3.new(0, 3.75, -1.4), color = black },
			{ size = Vector3.new(0.25, 0.4, 0.25), offset = Vector3.new(0, 4.15, -1.25), color = black },
		}
	elseif season == "Birthday" then
		return {
			{ size = Vector3.new(0.85, 0.4, 0.85), offset = Vector3.new(0, 3.1, -1.5), color = Color3.fromRGB(80, 160, 255) },
			{ size = Vector3.new(0.6, 0.4, 0.6), offset = Vector3.new(0, 3.5, -1.5), color = Color3.fromRGB(255, 210, 60) },
			{ size = Vector3.new(0.38, 0.4, 0.38), offset = Vector3.new(0, 3.9, -1.5), color = Color3.fromRGB(255, 90, 160) },
			{ size = Vector3.one * 0.32, offset = Vector3.new(0, 4.2, -1.5), color = Color3.fromRGB(255, 255, 255), ball = true },
		}
	elseif season == "Christmas" then
		local red = Color3.fromRGB(200, 30, 40)
		return {
			{ size = Vector3.new(1.3, 0.25, 1.3), offset = Vector3.new(0, 3.0, -1.5), color = SNOW },
			{ size = Vector3.new(0.95, 0.45, 0.95), offset = Vector3.new(0, 3.3, -1.45), color = red },
			{ size = Vector3.new(0.6, 0.4, 0.6), offset = Vector3.new(0, 3.7, -1.3), color = red },
			{ size = Vector3.new(0.3, 0.35, 0.3), offset = Vector3.new(0, 4.0, -1.1), color = red },
			{ size = Vector3.one * 0.35, offset = Vector3.new(0, 4.2, -0.95), color = SNOW, ball = true },
		}
	end
	return {}
end

-- A bunch of balloons on strings, for a birthday
function Season.balloons(at: Vector3, count: number, rand: Random, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = "Balloons"
	local colors = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(120, 220, 120), Color3.fromRGB(230, 120, 255) }
	for i = 1, count do
		local top = at + Vector3.new(rand:NextNumber(-1.6, 1.6), rand:NextNumber(5.5, 8), rand:NextNumber(-1.6, 1.6))
		part({
			Name = "Balloon",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.4, 1.4, 1.4),
			Position = top,
			Color = colors[(i - 1) % #colors + 1],
			Material = Enum.Material.Glass,
			Reflectance = 0.1,
			CanQuery = false,
			Parent = model,
		})
		local mid = (top + at) / 2
		part({
			Name = "String",
			Size = Vector3.new(0.05, (top - at).Magnitude, 0.05),
			CFrame = CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0),
			Color = Color3.fromRGB(240, 240, 240),
			CanQuery = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return model
end

-- A friendly little ghost: a sheet with dark eyes
function Season.ghost(parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = "Ghost"
	local sheet = Color3.fromRGB(245, 245, 255)
	local head = part({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, Color = sheet, Transparency = 0.15, CanQuery = false, CastShadow = false, Parent = model })
	model.PrimaryPart = head
	part({
		Name = "Sheet",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.2, 2.3, 2.3),
		CFrame = head.CFrame * CFrame.new(0, -1.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = sheet,
		Transparency = 0.15,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})
	for i = 0, 3 do
		local a = i * math.pi / 2
		part({
			Name = "Tail",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.8,
			Position = head.Position + Vector3.new(math.cos(a) * 0.75, -2.2, math.sin(a) * 0.75),
			Color = sheet,
			Transparency = 0.15,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
	for _, x in { -0.4, 0.4 } do
		part({ Name = "Eye", Size = Vector3.new(0.3, 0.45, 0.1), CFrame = head.CFrame * CFrame.new(x, 0.15, -1.12), Color = Color3.fromRGB(20, 20, 25), CanQuery = false, CastShadow = false, Parent = model })
	end
	part({ Name = "Mouth", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35, CFrame = head.CFrame * CFrame.new(0, -0.45, -1.08), Color = Color3.fromRGB(20, 20, 25), CanQuery = false, CastShadow = false, Parent = model })
	model.Parent = parent
	return model
end

-- A gravestone with a round top, a bit crooked
function Season.grave(pos: Vector3, rand: Random, parent: Instance?): BasePart
	local tilt = CFrame.Angles(math.rad(rand:NextNumber(-8, 8)), rand:NextNumber(0, math.pi * 2), math.rad(rand:NextNumber(-6, 6)))
	local stone = Color3.fromRGB(125, 125, 130)
	local slab = part({ Name = "Grave", Size = Vector3.new(2.2, 2.4, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 1.1, 0)) * tilt, Color = stone, Material = Enum.Material.Slate, Parent = parent })
	part({
		Name = "Top",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 2.2, 2.2),
		CFrame = slab.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = stone,
		Material = Enum.Material.Slate,
		CanQuery = false,
		Parent = slab,
	})
	part({ Name = "Mark", Size = Vector3.new(1.1, 0.12, 0.05), CFrame = slab.CFrame * CFrame.new(0, 0.6, -0.27), Color = Color3.fromRGB(60, 60, 65), CanQuery = false, Parent = slab })
	part({ Name = "Mark", Size = Vector3.new(0.12, 0.8, 0.05), CFrame = slab.CFrame * CFrame.new(0, 0.6, -0.27), Color = Color3.fromRGB(60, 60, 65), CanQuery = false, Parent = slab })
	return slab
end

-- A spider web: spokes and a ring, standing up next to a tree
function Season.web(center: CFrame, radius: number, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = "Web"
	local silk = Color3.fromRGB(235, 235, 240)
	for i = 0, 3 do
		part({ Name = "Spoke", Size = Vector3.new(radius * 2, 0.05, 0.05), CFrame = center * CFrame.Angles(0, 0, i * math.pi / 4), Color = silk, CanQuery = false, CastShadow = false, Parent = model })
	end
	for _, k in { 0.5, 0.9 } do
		for i = 0, 7 do
			local a = i * math.pi / 4 + math.pi / 8
			local len = 2 * radius * k * math.sin(math.pi / 8)
			part({
				Name = "Ring",
				Size = Vector3.new(len, 0.05, 0.05),
				CFrame = center * CFrame.new(math.cos(a) * radius * k * math.cos(math.pi / 8), math.sin(a) * radius * k * math.cos(math.pi / 8), 0) * CFrame.Angles(0, 0, a + math.pi / 2),
				Color = silk,
				CanQuery = false,
				CastShadow = false,
				Parent = model,
			})
		end
	end
	model.Parent = parent
	return model
end

-- A witch's cauldron with green bubbling brew
function Season.cauldron(pos: Vector3, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = "Cauldron"
	local iron = Color3.fromRGB(30, 30, 35)
	part({ Name = "Pot", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.2, Position = pos + Vector3.new(0, 1.6, 0), Color = iron, Material = Enum.Material.Metal, Parent = model })
	local brew = part({
		Name = "Brew",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2.6, 2.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 255, 90),
		Material = Enum.Material.Neon,
		CanQuery = false,
		Parent = model,
	})
	part({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2.9, 2.9),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = iron,
		Material = Enum.Material.Metal,
		CanQuery = false,
		Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(110, 255, 90)
	light.Range = 14
	light.Brightness = 2
	light.Shadows = false
	light.Parent = brew
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Color = ColorSequence.new(Color3.fromRGB(150, 255, 120))
	bubbles.LightEmission = 0.6
	bubbles.Size = NumberSequence.new(0.35)
	bubbles.Speed = NumberRange.new(1.5, 3)
	bubbles.Lifetime = NumberRange.new(0.8, 1.6)
	bubbles.Rate = 12
	bubbles.EmissionDirection = Enum.NormalId.Right
	bubbles.Parent = brew
	model.Parent = parent
	return model
end

Season.SNOW = SNOW

return Season
