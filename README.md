# Find Pianka

A Roblox game by Mr. Scientist 84.

Pianka the cat is lost in the dark forest. Use your GPS to find her!

## Heroes

- **Patrick** 🏃 super fast
- **Aurelia** 🐱 cat friend: her GPS never gets fuzzy, Pianka runs from her only once and leaves her more birds
- **Milenkitka** 💡 big lantern, and dogs rest longer when chasing her

## Modes (same for everyone on a server)

- **Easy**: find Pianka with the GPS and bring her home.
- **Normal**: thick fog, Pianka runs away 3 times. And there is a surprise when you catch her!
- **Umulig** (almost impossible): like Normal, then run home with the kittens while a pack of dogs follows you.

You have 3 hearts (2 in Normal). A dog bite or a neighbor grab costs one. Out of hearts? You faint 😵 until the next round. If everyone faints, the round is lost. Pianka leaves a trail of birds 🐦 that leads to her, like a cat gift. Each one gives a heart back.

The GPS always shows Pianka. Enemies show up only when you can see them, and the GPS gets fuzzy when they are close. Guard dogs walk back and forth with a light in front of them. Stay out of the light, or hide behind trees! If a dog sees you it barks and chases you.

In Umulig a pack of dogs follows behind you in a V. They only attack if you get into their light, so keep running and avoid mud.

Watch out for rats! They nibble and slow you down. Jump on them to squash them, or click your lantern to scare them away.

Collect glowing fish and spend them in the **Shop**: colored lanterns, a crown and a kitten pet.

Every round can have a twist: Pianka up a tree or hiding in a shaking bush, zoomies, a rat party, a full moon or a golden Pianka.

Tap the lantern button (or press F) to flash rats away. Glowing mushrooms give super speed (blue), super light that scares rats (yellow) or a super jump (pink). Mud puddles slow you down. Neighbors sometimes point the way. Rescue 5, 25 or 100 times to earn ⭐ 🏅 👑 next to your name.

Spooky neighbors live in cabins and talk in Norwegian. At night they come out with lanterns and hunt you. Stay out of their light! Listen for meows. Your rescues are saved and the best show on the camp leaderboard.

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
