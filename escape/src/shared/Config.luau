return {
	GameName = "Pianka: The Escape",
	Creator = "Mr. Scientist 84",

	-- House size: 1 plan square is 50 cm
	Square = 4,
	WallHeight = 20,
	DoorHeight = 16,
	Floor2 = 22,

	-- Pianka moves like a cat, slow and quiet near sleepers
	WalkSpeed = 13,
	SneakSpeed = 4,
	-- In the air she moves a bit faster, so a hop clears small things
	HopSpeed = 8,
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
	SfxId = 125644797079879,
	Sfx = {
		Breath = { 0.3, 12.76 },
		BreathLight = { 13.36, 10.6 },
		Snort = { 24.26, 0.95 },
		Hmm = { 25.51, 1.164 },
		HmmKid = { 26.974, 1.088 },
		Grumble = { 28.363, 1.742 },
		Aww = { 30.405, 1.333 },
		Kiss = { 32.038, 1.078 },
		Squeak = { 33.416, 0.36 },
		Squeak2 = { 34.076, 0.58 },
		Track = { 34.956, 2.2 },
		Unlock = { 37.456, 1.0 },
		Lock = { 38.756, 1.5 },
		Rattle = { 40.556, 1.7 },
		Key = { 42.556, 2.6 },
		KeyFly = { 45.456, 2.9 },
		AllKeys = { 48.656, 4.2 },
		Purr = { 53.156, 2.6 },
		Pop = { 56.056, 0.25 },
		Mouse = { 56.606, 0.6 },
		Pounce = { 57.506, 0.7 },
		Hearts = { 58.506, 2.7 },
		Paw1 = { 61.506, 0.08 },
		Paw2 = { 61.886, 0.08 },
		Land = { 62.266, 0.25 },
		Clock = { 62.816, 1.0 },
		Creak = { 64.116, 1.3 },
		Whoosh = { 65.716, 0.4 },
		Beep = { 66.416, 0.14 },
		Alert = { 66.856, 3.2 },
		Buzz = { 70.356, 0.95 },
		Ding = { 71.606, 2.4 },
		Gate = { 74.306, 3.2 },
		Sigh = { 77.806, 1.6 },
		Crickets = { 79.706, 6.0 },
		Servo = { 86.006, 2.0 },
		Click = { 88.306, 0.12 },
		Rumble = { 88.726, 0.95 },
		Clack = { 89.976, 1.2 },
		Clatter = { 91.476, 1.6 },
		Clink = { 93.376, 2.0 },
		Scream = { 95.676, 3.08 },
		Scratch = { 99.056, 0.45 },
	},
	-- Music: the sneaky tune and its tense layer play together, the dream is the music box
	MusicId = 76864357160068,
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
		bedKid = { name = "Patrick", skin = Color3.fromRGB(255, 205, 160), hair = Color3.fromRGB(110, 70, 40), blanket = Color3.fromRGB(70, 110, 200), snore = "BreathLight", pitch = 1.0 },
		bedGirl = { name = "Aurelia", skin = Color3.fromRGB(245, 210, 180), hair = Color3.fromRGB(30, 28, 32), blanket = Color3.fromRGB(240, 130, 190), snore = "BreathLight", pitch = 1.08 },
		bedMom = { name = "Milenkitka", skin = Color3.fromRGB(235, 195, 165), hair = Color3.fromRGB(95, 60, 35), blanket = Color3.fromRGB(70, 140, 110), snore = "Breath", pitch = 1.0 },
	},
}
