# Find Pianka

A Roblox game by Mr. Scientist 84.

Pianka the cat is lost in the dark forest. Use your GPS to find her!

## Heroes

- **Patrick** 🏃 super fast
- **Aurelia** 🐱 cat friend: her GPS never loses signal and Pianka runs from her only once
- **Milena** 🏮 big lantern, and dogs rest longer when chasing her

## Modes (same for everyone on a server)

- **Easy**: find Pianka with the GPS and bring her home.
- **Normal**: thick fog, the GPS loses signal sometimes, Pianka runs away 3 times. And there is a surprise when you catch her!
- **Umulig** (almost impossible): like Normal, plus dogs.

Night lasts most of the time. Spooky neighbors live in cabins and talk in Norwegian. Listen for meows. Your rescues are saved and the best show on the camp leaderboard.

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
