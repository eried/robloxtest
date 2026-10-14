return {
	GameName = "Find Pianka the Cat L2",
	Creator = "Mr. Scientist 84",
	CatName = "Pianka",
	CatColor = Color3.fromRGB(34, 34, 40),
	EyeColor = Color3.fromRGB(255, 210, 40),

	ForestSize = 840,
	TreeCount = 680,
	BushCount = 290,
	RockCount = 115,
	SpawnClearRadius = 30,
	MinCatDistance = 150,
	CatDistance = { Practice = 200, Normal = 330, Hard = 370 },
	Hedges = { Practice = 3, Normal = 12, Hard = 16 },
	HomePosition = Vector3.new(10, 0, 0),
	HomeRadius = 8,
	CarryTime = 75,

	GpsRange = 200,

	FleeDistance = 20,
	HardFlees = 3,
	KittenCount = 7,
	KittenTime = 150,
	KittenHomeMin = 120,
	KittenBurst = { 0.9, 3 },

	Dogs = {
		Practice = {
			patrolCount = 4, patrolSpeed = 6, coneAngle = 30, coneRange = 16, alertDelay = 0.8, lines = 0,
			chaseFactor = 1.1, chaseTime = 2.5, catch = 3,
			packCount = 0, packConeRange = 10, packSpeedFactor = 1, packGap = 18, packGapMin = 6,
			packClose = 0.5, lungeFactor = 1.5, lungeTime = 1.2, restTime = 1.5, hiddenFactor = 0.6,
		},
		Normal = {
			patrolCount = 8, patrolSpeed = 6, coneAngle = 34, coneRange = 20, alertDelay = 0.7, lines = 3,
			chaseFactor = 1.15, chaseTime = 3, catch = 3,
			packCount = 0, packConeRange = 10, packSpeedFactor = 1, packGap = 18, packGapMin = 6,
			packClose = 0.5, lungeFactor = 1.5, lungeTime = 1.2, restTime = 1.5, hiddenFactor = 0.6,
		},
		Hard = {
			patrolCount = 10, patrolSpeed = 7, coneAngle = 36, coneRange = 22, alertDelay = 0.5, lines = 4,
			chaseFactor = 1.25, chaseTime = 4, catch = 3,
			packCount = 6, packConeRange = 10, packSpeedFactor = 1.04, packGap = 15, packGapMin = 6,
			packClose = 0.55, lungeFactor = 1.5, lungeTime = 1.2, restTime = 1.5, hiddenFactor = 0.9,
		},
	},

	Hunters = {
		Practice = { patrolSpeed = 5, coneAngle = 28, coneRange = 18, alertDelay = 1, chaseFactor = 1.05, chaseTime = 2.5, catch = 3, hiddenFactor = 0.3 },
		Normal = { patrolSpeed = 5, coneAngle = 30, coneRange = 22, alertDelay = 0.8, chaseFactor = 1.1, chaseTime = 3, catch = 3, hiddenFactor = 0.3 },
		Hard = { patrolSpeed = 6, coneAngle = 32, coneRange = 24, alertDelay = 0.7, chaseFactor = 1.15, chaseTime = 3.5, catch = 3, hiddenFactor = 0.3 },
	},
	HuntByDay = { Hard = true },
	Seekers = { Practice = 1, Normal = 0, Hard = 1 },
	SeekEvery = 20,
	Hearts = { Practice = 3, Normal = 2, Hard = 3 },
	-- Each rescue raises the level up to Max
	Level = {
		Max = 10, dogsEvery = 2, maxDogs = 4, cone = 0.6, maxCone = 5, chase = 0.012,
		rats = 1, fleesEvery = 3, spotsEvery = 2, kittenTime = 6, carryTime = 3,
	},
	HideSpots = { Practice = 5, Normal = 7, Hard = 8 },
	HideSpotsMax = 12,
	RatSurprise = 0.125,
	BoneCount = { Practice = 4, Normal = 3, Hard = 3 },
	BoneMax = 3,
	BoneReach = 30,
	BoneEat = 6,
	BirdCount = { Practice = 2, Normal = 1, Hard = 0 },

	DayMinutes = 10,
	-- Every round starts in the late afternoon and gets dark soon
	DuskClock = 16.75,
	NightShare = 0.55,

	RatCount = { Practice = 4, Normal = 6, Hard = 8 },
	RatSpeed = { Practice = 11, Normal = 13, Hard = 14 },
	RatAggro = 26,
	RatLeash = 50,
	RatSafeRadius = 40,

	FishCount = 45,
	MushroomCount = { Practice = 8, Normal = 6, Hard = 4 },
	MudCount = { Practice = 8, Normal = 14, Hard = 20 },
	TeamBonus = 3,
	FishRespawn = 45,
	Reward = { Deliver = 5, Kitten = 1, Hard = 25, Rat = 2 },
	Shop = {
		{ id = "LanternPink", name = "Pink lantern", price = 25, kind = "lantern", color = Color3.fromRGB(255, 120, 200) },
		{ id = "LanternGreen", name = "Green lantern", price = 25, kind = "lantern", color = Color3.fromRGB(120, 255, 140) },
		{ id = "LanternBlue", name = "Blue lantern", price = 25, kind = "lantern", color = Color3.fromRGB(120, 180, 255) },
		{ id = "LanternRainbow", name = "Rainbow lantern", price = 150, kind = "lantern", color = Color3.fromRGB(255, 255, 255) },
		{ id = "Crown", name = "Crown", price = 200, kind = "crown", color = Color3.fromRGB(255, 210, 60) },
		{ id = "Pet", name = "Kitten pet", price = 300, kind = "pet", color = Color3.fromRGB(34, 34, 40) },
	},

	NeighborCount = 9,
	NeighborSpeed = 3,

	PatrickSpeed = 20,
	HeroOrder = { "Patrick", "Aurelia", "Milenkitka" },
	Heroes = {
		Patrick = { Emoji = "🏃", Skill = "Super fast" },
		Aurelia = { Emoji = "🐱", Skill = "Cat friend, more birds" },
		Milenkitka = { Emoji = "💡", Skill = "Big lantern, calm dogs" },
	},

	-- Upload music/PiankaMystery.mp3 to Roblox and paste its id here
	MusicId = 139972511482001,

	-- Game passes made in Creator Hub (Monetization, Passes). 0 hides the pass.
	Passes = {
		{ key = "LanternRainbow", name = "Rainbow lantern", price = 49, id = 2026821228 },
		{ key = "Pet", name = "Kitten pet", price = 99, id = 2026677293 },
		{ key = "Crown", name = "Golden crown", price = 149, id = 2026803237 },
		{ key = "ExtraHeart", name = "Extra heart", price = 99, id = 2025339356 },
	},

	-- Upload music/PiankaChase.mp3 to Roblox and paste its id here
	ChaseMusicId = 100600567252458,
	CallId = 0,
	-- Player and neighbor voices: start and length in seconds
	VoicesId = 0,
	Voices = {
		Call = { 0.3, 2.371 },
		Back = { 3.171, 2.201 },
		Ouch = { 5.871, 1.474 },
		Got = { 7.845, 2.208 },
		HeyYou = { 10.553, 1.487 },
	},
	Scream = { 12.541, 3.332 },
	-- Calling Pianka: she meows back, but dogs and neighbors this close hear it
	CallCooldown = 6,
	CallHeard = 45,

	-- Upload sounds/PiankaSounds.mp3 to Roblox and paste its id here
	SoundsId = 91539648212607,
	Meow = { 0.6, 2.55 },
	Mew = { 3.75, 2.05 },
	Bark = { 6.4, 2.28 },
	Lines = {
		{ 9.28, 2.736, "Hva gjør du her?", "What are you doing here?" },
		{ 12.616, 2.722, "Hvem er du?", "Who are you?" },
		{ 15.938, 3.203, "Dette er min skog.", "This is my forest." },
		{ 19.741, 3.642, "Gå hjem, barn.", "Go home, kid." },
		{ 23.983, 3.189, "Har du sett katten min?", "Have you seen my cat?" },
		{ 27.772, 5.358, "Det er sent. Du burde ikke være ute nå.", "It is late. You should not be out now." },
		{ 37.038, 4.381, "Hysj! Ikke vekk hundene.", "Shh! Do not wake the dogs." },
	},
	Hunt = { "Hei du!", "Hey you!" },
	Chase = { "Stopp!", "Stop!" },
	Grab = { "Ut herfra!", "Get out of here!" },
}
