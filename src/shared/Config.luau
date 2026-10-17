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
	-- Pianka pops into kittens: belly grows, pop, slow motion, then they run (seconds)
	KittenBurst = { pop = 4.4, slow = 2.6, total = 9.4 },

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
		Practice = { patrolSpeed = 5, coneAngle = 28, coneRange = 18, alertDelay = 1, chaseFactor = 1.05, chaseTime = 2.5, catch = 3, hiddenFactor = 0, darkHides = true },
		Normal = { patrolSpeed = 5, coneAngle = 30, coneRange = 22, alertDelay = 0.8, chaseFactor = 1.1, chaseTime = 3, catch = 3, hiddenFactor = 0, darkHides = true },
		Hard = { patrolSpeed = 6, coneAngle = 32, coneRange = 24, alertDelay = 0.7, chaseFactor = 1.15, chaseTime = 3.5, catch = 3, hiddenFactor = 0, darkHides = true },
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
	MushroomCount = { Practice = 10, Normal = 8, Hard = 7 },
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
		{ id = "HatParty", name = "Party hat", price = 40, kind = "hat", color = Color3.fromRGB(255, 90, 160) },
		{ id = "HatTop", name = "Top hat", price = 60, kind = "hat", color = Color3.fromRGB(30, 30, 35) },
		{ id = "HatWitch", name = "Witch hat", price = 70, kind = "hat", color = Color3.fromRGB(110, 50, 140) },
		{ id = "HatPirate", name = "Pirate hat", price = 80, kind = "hat", color = Color3.fromRGB(60, 40, 30) },
		{ id = "TrailSparkle", name = "Sparkle trail", price = 120, kind = "trail", color = Color3.fromRGB(255, 230, 120) },
		-- Power ups work right away, buy them again for the next one
		{ id = "PowerShield", name = "🛡️ Shield bubble", price = 20, kind = "power", power = "shield", time = 0, color = Color3.fromRGB(120, 230, 255) },
		{ id = "PowerDouble", name = "🦘 Double jump", price = 25, kind = "power", power = "double", time = 600, color = Color3.fromRGB(120, 255, 140) },
		{ id = "PowerGhost", name = "👻 Ghost 15 s", price = 30, kind = "power", power = "ghost", time = 15, color = Color3.fromRGB(235, 235, 255) },
		{ id = "PowerFreeze", name = "❄️ Freeze dogs", price = 30, kind = "power", power = "freeze", time = 8, color = Color3.fromRGB(150, 200, 255) },
	},
	-- Players who can switch the season from the shop to test it (the game owner always can)
	Admins = {},

	NeighborCount = 9,
	NeighborSpeed = 3,

	PatrickSpeed = 20,
	HeroOrder = { "Patrick", "Aurelia", "Milenkitka", "Oskar" },
	Heroes = {
		Patrick = { Emoji = "🏃", Skill = "Super fast" },
		Aurelia = { Emoji = "🐱", Skill = "Cat friend, more birds" },
		Milenkitka = { Emoji = "💡", Skill = "Big lantern, calm dogs" },
		Oskar = { Emoji = "👫", Skill = "With sister Nikola: 2 lives" },
	},

	-- Seasons: "auto" is a hero's birthday, Halloween in October, Christmas in December.
	-- Or "Halloween", "Christmas", "Birthday:Patrick", "None"
	Season = "auto",
	Birthdays = { Patrick = { 8, 18 }, Aurelia = { 9, 21 }, Milenkitka = { 9, 6 } },
	HalloweenMusicId = 94126609707368,
	ChristmasMusicId = 107040817150467,
	SeasonSfxId = 81307958921304,
	SeasonSfx = { NiceEn = { 0.3, 2.69 }, NiceNo = { 3.49, 2.588 }, Howl = { 6.577, 5 }, Birthday = { 12.077, 10.96 } },
	-- Pianka straining and popping, ghosts, sinister laughs, Santa, nisse giggles and a ghostly Happy Halloween
	ExtraSfxId = 0,
	ExtraSfx = {
		Strain = { 0.3, 4.427 },
		Pop = { 5.027, 1.719 },
		Ghost = { { 7.046, 4.414 }, { 11.76, 4.572 }, { 16.633, 4.141 } },
		Laugh = { { 21.074, 3.665 }, { 25.039, 2.976 }, { 28.315, 1.961 } },
		HoHo = { { 30.576, 1.912 }, { 32.788, 2.351 }, { 35.439, 2.104 } },
		Giggle = { { 37.843, 1.18 }, { 39.323, 1.138 } },
		Halloween = { 40.761, 3.306 },
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
	CallId = 112612503374928,
	-- Player and neighbor voices: start and length in seconds
	VoicesId = 97571276201632,
	Voices = {
		Call = { { 0.3, 2.729 }, { 3.529, 2.985 }, { 7.014, 2.112 } },
		Back = { 9.626, 2.549 },
		Ouch = { 12.675, 1.38 },
		Got = { 14.555, 1.843 },
		Hey = { { 16.899, 1.725 }, { 19.123, 2.038 }, { 21.662, 2.178 } },
	},
	Scream = { 24.34, 3.305 },
	-- Hard escape clip: love tune, then the kennel gate bursts open
	EscapeMusicId = 125147046958456,
	EscapeSfxId = 119398113740050,
	Escape = { Love = { 0.3, 3.4 }, Release = { 4.2, 4.2 } },
	EscapeClip = { open = 3.6, total = 7.6 },
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
