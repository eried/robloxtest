# Find Pianka

A Roblox game by Mr. Scientist 84.

Pianka the cat is lost in the forest. Use your GPS to find her and bring her home!

## Modes

- **Easy**: find Pianka with the GPS and bring her home.
- **Hard**: thick fog, the GPS loses signal sometimes, and Pianka runs away 3 times. When you catch her she explodes into 7 black kittens. Find them all before the timer ends.

- **Umulig** (almost impossible): like Hard, but the kittens stack on your head and 8 dogs chase you home. If a dog catches you, you lose.

Night falls after a while. Use your lantern.

## Music

1. Upload `music/PiankaMystery.mp3` at create.roblox.com (Creations > Audio).
2. Copy its id into `MusicId` in `src/shared/Config.luau`.
3. Rebuild, or in Studio edit `ReplicatedStorage > Shared > Config` directly.

## Play it

1. Open `FindPianka.rbxlx` in Roblox Studio.
2. Press **Play** to test.
3. **File > Publish to Roblox** to put it on your account.

## Edit it

- `src/shared/Config.luau` cat name, colors, forest size, Hard mode settings
- `src/server/ForestGame.server.luau` forest and cat
- `src/client/GPS.client.luau` GPS, timer, menus, Easy/Hard

Rebuild after changes: `rojo build -o FindPianka.rbxlx`
