# Pianka the Escape

A Roblox game by Mr. Scientist 84. You are Pianka, the black cat from Find Pianka the Cat.

Pianka sleeps in her bed and dreams of catching a mouse for Milenkitka. Tonight she escapes to make it come true.

## The house (stage 1)

- Everyone else is asleep upstairs: Patrick, Aurelia and Milenkitka. You hear them snore.
- Near a sleeper Pianka sneaks on her own, slow and quiet. Sprinting (Shift, the right trigger or 💨 on phones) is loud.
- Squeaky toys and the ball track make noise when you bump them. Too much noise and someone wakes up: "PIANKA!" and she is carried back to bed. The keys go back too.
- Downstairs nobody sleeps, but every few noises someone calls "Piaaaanka?" from upstairs.
- Find the 3 keys. They are mostly upstairs, sometimes one is downstairs. On beds and furniture you have to jump.
- With all 3 keys the front door opens. Out you go!

Coming next: the backyard with cameras and the gate keys, the town with cars and the bridge, the forest and the mouse.

## Plans

The house, yard and town come from `plans/*.json`, drawn in the Pianka Escape Planner. After changing a plan run `python3 tools/plan2luau.py` to update `src/shared/Plan.luau`. 1 square is 50 cm, 4 studs.

## Files

- `src/shared/Config.luau` speeds, noise, timers, sound clips, who sleeps where
- `src/shared/Cat.luau` Pianka, same as in the first game
- `src/server/Escape.server.luau` builds the house from the plan, keys, noise, waking up, the door
- `src/client/Escape.client.luau` screen, snoring, sneaking, cat walk, clips
- `tools/make_audio.py` makes the sounds and the sneaky music

## Tests and publish

`lune run tests/escape.spec.luau` (from this folder) runs the real scripts with bots: keys, a wake up, running near a sleeper, the open door and the escape. It runs before every publish.

Pushing changes in `escape/` runs the **Publish Pianka the Escape** action: test, upload new sounds, build and publish to the game.
