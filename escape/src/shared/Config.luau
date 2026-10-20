return {
	GameName = "Pianka the Escape",
	Creator = "Mr. Scientist 84",

	-- House size: 1 plan square is 50 cm
	Square = 4,
	WallHeight = 20,
	DoorHeight = 16,
	Floor2 = 22,

	-- Pianka moves like a cat, slow and quiet near sleepers
	WalkSpeed = 13,
	SneakSpeed = 6,
	JumpHeight = 7.6,

	-- Sleepers: Pianka sneaks within SnoreRange. Now and then they snort, then look around:
	-- moving while they look wakes them. One squeak upstairs wakes the closest one
	SnoreRange = 42,
	-- When on, moving while a sleeper peeks wakes them. Off: they only snort and peek
	LookWakes = false,
	StirEvery = { 9, 17 },
	StirWarn = 1.3,
	StirTime = 2.6,
	StirRange = 44,
	SightHalf = 70,
	MoveTolerance = 2.5,
	-- Small things on the floor can be jumped over, only a step on them makes noise
	Toys = {
		squeaky = { radius = 3.0, sound = "Squeak" },
		ballTrack = { radius = 4.2, sound = "Track" },
		controller = { radius = 1.1, sound = "Rumble", small = true },
		blocks = { radius = 1.0, sound = "Clack", small = true },
		lipstick = { radius = 1.0, sound = "Clatter", small = true },
		perfume = { radius = 1.0, sound = "Clink", small = true },
	},
	-- Pianka stands with her middle 1.4 above the floor: a bit higher means she is in the air
	StepHeight = 1.8,
	TeaseEvery = 3,
	LockedClipTime = 7.2,
	CaughtTime = 4.5,
	KeyCount = 3,
	DownstairsKeyChance = 0.35,
	WinRestart = 45,
	-- The ending plays this long before the score card can start a new night
	EndingTime = 16,
	-- Speed stars: under these many seconds for 3 and 2 stars
	Stars = { 240, 420 },
	MinRunTime = 120,

	-- Backyard cameras: how far and wide they see, how they sweep, how fast they catch you
	CameraRange = 60,
	CameraHalf = 26,
	CameraSweep = 38,
	CameraPeriod = 9,
	SpotTime = 1.6,
	SpottedTime = 7,
	ExitClipTime = 10,
	GateKeyCount = 3,
	-- The garage door: a button outside opens it, it closes slowly, a button inside opens it again
	GarageOpenTime = 1.2,
	GarageHold = 3.5,
	GarageCloseTime = 6,
	GarageClipTime = 1.6,

	-- Sounds made by escape/tools/make_audio.py, uploaded by the publish job
	SfxId = 81655363407748,
	Sfx = {
		Breath = { 0.3, 4.42 },
		BreathLight = { 5.02, 3.42 },
		Snort = { 8.74, 0.95 },
		Hmm = { 9.99, 1.164 },
		HmmKid = { 11.454, 1.088 },
		Grumble = { 12.843, 1.742 },
		Aww = { 14.885, 1.333 },
		Kiss = { 16.518, 1.078 },
		Squeak = { 17.896, 0.36 },
		Squeak2 = { 18.556, 0.58 },
		Track = { 19.436, 2.2 },
		Unlock = { 21.936, 1.0 },
		Lock = { 23.236, 1.5 },
		Rattle = { 25.036, 1.7 },
		Key = { 27.036, 2.6 },
		KeyFly = { 29.936, 2.9 },
		AllKeys = { 33.136, 4.2 },
		Purr = { 37.636, 2.6 },
		Pop = { 40.536, 0.25 },
		Mouse = { 41.086, 0.6 },
		Pounce = { 41.986, 0.7 },
		Hearts = { 42.986, 2.7 },
		Paw1 = { 45.986, 0.08 },
		Paw2 = { 46.366, 0.08 },
		Land = { 46.746, 0.25 },
		Clock = { 47.296, 1.0 },
		Creak = { 48.596, 1.3 },
		Whoosh = { 50.196, 0.4 },
		Beep = { 50.896, 0.14 },
		Alert = { 51.336, 3.2 },
		Buzz = { 54.836, 0.95 },
		Ding = { 56.086, 2.4 },
		Gate = { 58.786, 3.2 },
		Sigh = { 62.286, 1.6 },
		Crickets = { 64.186, 6.0 },
		Servo = { 70.486, 2.0 },
		Click = { 72.786, 0.12 },
		Rumble = { 73.206, 0.95 },
		Clack = { 74.456, 1.2 },
		Clatter = { 75.956, 1.6 },
		Clink = { 77.856, 2.0 },
		Scream = { 80.156, 3.08 },
		Scratch = { 83.536, 0.45 },
	},
	-- Music: the sneaky tune and its tense layer play together, the dream is the music box
	MusicId = 0,
	TenseId = 120718840884184,
	DreamId = 113091535685140,

	-- Voices and meows from Find Pianka the Cat
	VoicesId = 97571276201632,
	-- The long "Piaaanka!" call from the first game, when she is sent back to bed
	LongCallId = 112612503374928,
	Calls = { { 0.3, 2.729 }, { 3.529, 2.985 }, { 7.014, 2.112 } },
	Back = { 9.626, 2.549 },
	SoundsId = 91539648212607,
	Meow = { 0.6, 2.55 },
	Mew = { 3.75, 2.05 },

	-- The people asleep upstairs
	Sleepers = {
		bedKid = { name = "Patrick", skin = Color3.fromRGB(255, 205, 160), hair = Color3.fromRGB(110, 70, 40), blanket = Color3.fromRGB(70, 110, 200), snore = "BreathLight", pitch = 1.15 },
		bedGirl = { name = "Aurelia", skin = Color3.fromRGB(245, 210, 180), hair = Color3.fromRGB(30, 28, 32), blanket = Color3.fromRGB(240, 130, 190), snore = "BreathLight", pitch = 1.35 },
		bedMom = { name = "Milenkitka", skin = Color3.fromRGB(235, 195, 165), hair = Color3.fromRGB(95, 60, 35), blanket = Color3.fromRGB(70, 140, 110), snore = "Breath", pitch = 1.0 },
	},
}
