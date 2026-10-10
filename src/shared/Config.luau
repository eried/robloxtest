return {
	GameName = "Find Pianka",
	Creator = "Mr. Scientist 84",
	CatName = "Pianka",
	CatColor = Color3.fromRGB(34, 34, 40),
	EyeColor = Color3.fromRGB(255, 210, 40),

	ForestSize = 600,
	TreeCount = 350,
	BushCount = 150,
	RockCount = 60,
	SpawnClearRadius = 30,
	MinCatDistance = 150,
	HomePosition = Vector3.new(10, 0, 0),
	HomeRadius = 8,
	CarryTime = 150,

	GpsRange = 200,

	FleeDistance = 20,
	HardFlees = 3,
	KittenCount = 7,
	KittenTime = 150,
	KittenHomeMin = 120,

	DogCount = 8,
	DogSpeedFactor = 1.18,
	DogCatch = 3.5,
	DogSpawnMin = 60,
	DogSpawnMax = 100,

	DayMinutes = 10,
	NightShare = 0.55,

	RatCount = { Easy = 10, Normal = 14, Umulig = 18 },
	RatSpeed = { Easy = 11, Normal = 13, Umulig = 14 },
	RatAggro = 26,
	RatLeash = 50,
	RatBite = 8,
	RatSafeRadius = 40,

	FishCount = 25,
	MushroomCount = { Easy = 8, Normal = 6, Umulig = 4 },
	MudCount = { Easy = 8, Normal = 14, Umulig = 20 },
	TeamBonus = 3,
	FishRespawn = 45,
	Reward = { Deliver = 5, Kitten = 1, Umulig = 25, Rat = 2 },
	Shop = {
		{ id = "LanternPink", name = "Pink lantern", price = 25, kind = "lantern", color = Color3.fromRGB(255, 120, 200) },
		{ id = "LanternGreen", name = "Green lantern", price = 25, kind = "lantern", color = Color3.fromRGB(120, 255, 140) },
		{ id = "LanternBlue", name = "Blue lantern", price = 25, kind = "lantern", color = Color3.fromRGB(120, 180, 255) },
		{ id = "LanternRainbow", name = "Rainbow lantern", price = 150, kind = "lantern", color = Color3.fromRGB(255, 255, 255) },
		{ id = "Crown", name = "Crown", price = 200, kind = "crown", color = Color3.fromRGB(255, 210, 60) },
		{ id = "Pet", name = "Kitten pet", price = 300, kind = "pet", color = Color3.fromRGB(34, 34, 40) },
	},

	NeighborCount = 6,
	NeighborSpeed = 3,

	PatrickSpeed = 20,
	HeroOrder = { "Patrick", "Aurelia", "Milena" },
	Heroes = {
		Patrick = { Emoji = "🏃", Skill = "Super fast" },
		Aurelia = { Emoji = "🐱", Skill = "Cat friend" },
		Milena = { Emoji = "🏮", Skill = "Big lantern, calm dogs" },
	},

	-- Upload music/PiankaMystery.mp3 to Roblox and paste its id here
	MusicId = 139972511482001,

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
}
