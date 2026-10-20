return {
	GameName = "Pianka the Escape",
	Creator = "Mr. Scientist 84",

	-- House size: 1 plan square is 50 cm
	Square = 4,
	WallHeight = 20,
	DoorHeight = 16,
	Floor2 = 22,

	-- Pianka moves like a cat
	WalkSpeed = 13,
	SneakSpeed = 6,
	SprintSpeed = 21,
	JumpHeight = 7.6,

	-- Sleepers: how far they hear, how fast they calm down
	SnoreRange = 42,
	HearRange = 56,
	SleepCalm = 6,
	RunNoise = 26,
	Toys = {
		squeaky = { loud = 38, radius = 2.6 },
		ballTrack = { loud = 58, radius = 4.2 },
	},
	TeaseEvery = 3,
	CaughtTime = 4.5,
	KeyCount = 3,
	DownstairsKeyChance = 0.35,
	WinRestart = 25,

	-- Sounds made by escape/tools/make_audio.py, uploaded by the publish job
	SfxId = 123219985977884,
	Sfx = {
		SnoreDeep = { 0.3, 3.42 },
		SnoreLight = { 4.02, 3.42 },
		Squeak = { 7.74, 0.36 },
		Squeak2 = { 8.4, 0.58 },
		Track = { 9.28, 2.2 },
		Unlock = { 11.78, 1.0 },
		Key = { 13.08, 2.6 },
		AllKeys = { 15.98, 4.2 },
		Purr = { 20.48, 2.6 },
		Snort = { 23.38, 0.95 },
		Dream = { 24.63, 4.4 },
	},
	MusicId = 87567301857264,

	-- Voices and meows from Find Pianka the Cat
	VoicesId = 97571276201632,
	Calls = { { 0.3, 2.729 }, { 3.529, 2.985 }, { 7.014, 2.112 } },
	Back = { 9.626, 2.549 },
	SoundsId = 91539648212607,
	Meow = { 0.6, 2.55 },
	Mew = { 3.75, 2.05 },

	-- The people asleep upstairs
	Sleepers = {
		bedKid = { name = "Patrick", skin = Color3.fromRGB(255, 205, 160), hair = Color3.fromRGB(110, 70, 40), blanket = Color3.fromRGB(70, 110, 200), snore = "SnoreLight", pitch = 1.15 },
		bedGirl = { name = "Aurelia", skin = Color3.fromRGB(245, 210, 180), hair = Color3.fromRGB(30, 28, 32), blanket = Color3.fromRGB(240, 130, 190), snore = "SnoreLight", pitch = 1.35 },
		bedMom = { name = "Milenkitka", skin = Color3.fromRGB(235, 195, 165), hair = Color3.fromRGB(95, 60, 35), blanket = Color3.fromRGB(70, 140, 110), snore = "SnoreDeep", pitch = 1.0 },
	},
}
