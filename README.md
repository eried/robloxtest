# Find Pianka the Cat L2

A Roblox game by Mr. Scientist 84.

Pianka the cat is lost in the dark forest. Use your GPS to find her!

When you join, a short clip shows Pianka running out of the house at sunset. Every round starts in the late afternoon and soon gets dark. Pick a hero, pick a mode, press **▶ Play**. Search music plays while you look for her, chase music when you carry her home.

## Heroes

- **Patrick** 🏃 super fast
- **Aurelia** 🐱 cat friend: her GPS never gets fuzzy, Pianka runs from her only once and leaves her more birds
- **Milenkitka** 💡 big lantern, and dogs rest longer when chasing her
- **Oskar** 👫 a bit bigger, walks hand in hand with his little sister **Nikola**. Two lives: when the hearts run out, one of them runs home and the other goes on with full hearts

## Seasons and birthdays

The game changes with the date:

- **October, Halloween** 🎃: every bush is a round jack-o'-lantern, some glowing, and Pianka hides inside one of them. Autumn trees, graves, spider webs, a bubbling cauldron, ghosts and bats around you, ghostly moans and sinister laughs in the dark, a purple night, Pianka in a witch hat, a wolf howls in the clip and the music is a spooky waltz.
- **December, Christmas** 🎄: snow everywhere and snowing, Pianka hides in presents and snow piles, tiny evil nisser replace the rats and giggle when they are close, Santa laughs "Ho ho ho!" somewhere in the forest, Pianka wears a Santa hat. In the clip a voice asks "Have you been nice?", sometimes in Norwegian ("Har du vært snill?"), and the music is a carol with sleigh bells.
- **Birthdays** 🎂: Patrick on August 18, Milenkitka on September 6 and Aurelia on September 21. Balloons all over the forest, party hats, confetti and Happy Birthday in the clip.

The game owner sees an **Admin** part at the bottom of the shop to switch the season live for everyone (Halloween, Christmas, a birthday, Auto or None) and to replay the intro or Pianka's pop. More admins go in `Admins` in `src/shared/Config.luau`. `Season` there sets the start: "auto", "Halloween", "Christmas", "Birthday:Patrick" or "None".

## Modes (same for everyone on a server)

- **Practice**: one round to learn. Find Pianka with the GPS and bring her home, then the menu opens with Normal ready.
- **Normal**: Pianka is far away behind thorn hedges, guard dogs walk lines across the way, thick fog, she runs away 3 times. When you catch her she screams and pops into confetti, and her 7 kittens run off. Find them all.
- **Hard**: like Normal, but the GPS only tells the distance, with a faint glitchy hint now and then. Press **📣 Call** (C) to shout "Piaaaanka!": she or a kitten meows back and the GPS shows the way for a few seconds, but dogs and neighbors nearby hear you and come to look. Then run home with the kittens while a pack of dogs follows you. It starts with a short clip: a love tune for the full tower, then a kennel gate bursts open, the pack runs out barking and the escape music kicks in.

Pianka hides in a bush, barrel, log, crate, pile of leaves or basket. The GPS only shows the area. Up close her hiding place rustles. Wrong spots can hide a frog, a rat or a fish gift. Any bush in the forest can be searched once per round for a fish.

In Normal and Hard, Pianka jumps on your head when you find her, and every kitten you pick up stacks on top of her. In Normal everyone close by watches her swell up, jiggle and struggle, then pop into 7 kittens in slow motion, safe while it plays.

Tap the **GPS** (or press M) to open the map and plan your way: hedges, guard dog lines, neighbors with lanterns, cabins, home and the area where Pianka is.

In Normal and Hard every rescue is one level up (up to 10): more dogs, wider lights, more rats, less time, more hiding spots and Pianka runs more. Picking a mode starts again at level 1.

Pick up bones 🦴 (up to 3). Tap the bone button or press G: it flies to the closest dog, and every guard dog near it stops to eat. Save one for a friend in trouble. The Hard pack does not care about bones.

You have 3 hearts (2 in Normal). A dog bite or a neighbor grab costs one. Out of hearts? You are a ghost 👻 until the next round. If everyone is out, it is game over: press **▶ Play again** or wait for the next round. Pianka leaves a trail of birds 🐦 that leads to her, like a cat gift. Each one gives a heart back.

The GPS shows Pianka (in Hard only how far). Enemies show up only when you can see them, and the GPS fades and gets fuzzy when they are close. You hear what happens: you shout when she runs off, neighbors yell a robotic "Hey! Hey!" when they spot you. Guard dogs walk back and forth with a light in front of them. Stay out of the light, or hide behind trees! If a dog sees you it barks and chases you.

In Hard a pack of dogs follows behind you in a V. They only attack if you get into their light, so keep running and avoid mud.

Watch out for rats! A bite costs a heart. Jump on them to squash them, or click your lantern to scare them away.

Collect glowing fish and spend them in the **🛒 Shop** (scroll for more): colored lanterns, hats, a sparkle trail, a crown, a kitten that rides on your shoulder and power ups.

Every round can have a twist: Pianka up a tree, zoomies, a rat party, a full moon or a golden Pianka.

Turning the lantern back on flashes and scares rats. Glowing mushrooms give a power:

- ⚡ super speed, 💡 super light that scares rats, 🦘 super jump
- 🛡️ shield bubble: saves you from one bite or grab
- 🦘🦘 double jump: jump again in the air
- 👻 ghost: nothing can touch you for a few seconds
- ❄️ freeze: dogs and neighbors close by stop for a moment

The new powers can also be bought in the shop. Mud puddles slow you down. Neighbors sometimes point the way. Rescue 5, 25 or 100 times to earn ⭐ 🏅 👑 next to your name.

Spooky neighbors live in cabins and talk in Norwegian. At night they come out with lanterns and hunt you. Tap the lantern button (or press F) to turn your light off: it gets really dark and you only see shapes, but neighbors and rats can not spot you and dogs see you less. If they already saw you, they keep chasing. If a neighbor catches you, he holds you up and it is game over for you this round. Listen for meows. Your rescues are saved and the best show on the camp leaderboard.

Each hero has a look: Patrick wears a red cap, Aurelia has cat ears and a tail, Milenkitka has a hair bun and a yellow scarf. When you carry Pianka home the chase music plays and the screen rushes.

## Game passes

Make them in Creator Hub: the game, **Monetization**, **Passes**, **Create a Pass**. Use the images in `art/passes`. Put each pass id in `Passes` in `src/shared/Config.luau`. Rainbow lantern, kitten pet and golden crown can also be bought with fish; the extra heart is Robux only.

## Publish

1. Open `FindPianka.rbxlx` in Roblox Studio and use **File > Publish to Roblox** once.
2. Make an API key at create.roblox.com/dashboard/credentials with **universe-places** (Write) for the game and **assets** (Read, Write). Accepted IP: `0.0.0.0/0`.
3. In GitHub: **Settings > Secrets and variables > Actions**. Add secret `ROBLOX_API_KEY`, and variables `UNIVERSE_ID` and `PLACE_ID`.
4. Run the **Publish to Roblox** action. It uploads the music and sounds, sets their ids and publishes. Later pushes publish automatically.

## Edit it

- `src/shared/Config.luau` names, colors, speeds, timers, heroes, sound ids
- `src/server/ForestGame.server.luau` forest, cabins, neighbors, cat, kittens, dogs
- `src/client/GPS.client.luau` GPS, menus, night, sounds

Rebuild after changes: `rojo build -o FindPianka.rbxlx`

## Tests

`lune run tests/dogs.spec.luau 200` plays thousands of full rounds with bots (careful, naive and wandering kid) against dogs, night neighbors, rats and hearts, and checks that every mode can be won and lost. `lune run tests/play.spec.luau 12` runs the real server and GPS scripts headless with bot players who click the menus, pick heroes and modes, and play solo and team rounds, including leaving and joining. It fails on any script error or stuck round. Both run before every publish.
