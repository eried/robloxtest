# Pianka: The Escape

A Roblox game by Mr. Scientist 84. You are Pianka, the black cat from Find Pianka the Cat.

Pianka sleeps in her bed and dreams: out of the door, a mouse caught, and Milenkitka so happy she hugs her. Tonight she escapes to make it come true. The game tells its story with pictures and sounds, no text.

## The house (stage 1)

- Everyone else is asleep upstairs: Patrick, Aurelia and Milenkitka. Upstairs you hear them breathe softly. In their room the music fades away and only the breathing is left.
- The front door is locked. The first time Pianka walks into the hall, it rattles, three locks clunk and three keys fly off to where they hide.
- Near a sleeper Pianka walks low and slow on her own.
- Now and then a sleeper snorts, then opens their eyes and looks around. Moving where they can see turns the screen edges red with a low drone: stop within 2 seconds or they wake up.
- One squeak of a toy upstairs wakes the closest sleeper. Downstairs a squeak only gets a grumble, and every few someone calls "Piaaaanka?".
- Woken up: "PIANKA!", back to bed, and the keys go back.
- Find the 3 keys, one in each bedroom, deep inside behind the toys. They glow, bronze like the keys on the screen. With all 3 the door opens.
- The music is a sneaky detective tune. When someone stirs, a toy squeaks or a camera gets close, a tense layer fades in on top.

## The backyard (stage 2)

- Out of the door Pianka sees the cameras and meows a warning.
- 9 cameras sweep the yard with red light cones, each at its own speed. Walls, bushes and the car block their view.
- Gate keys hide where two cameras cross, so sometimes both look at the same spot.
- A moment in the light and Milenkitka's phone buzzes: she wakes up and everything starts over from the cat bed.
- One gate key is always in the little back room of the garage. The garage button out in the yard is watched by cameras. Press it, the door rolls up, then it closes slowly: hurry. A button inside opens it again.
- With 3 gate keys the gate by the driveway opens and Pianka is free.

Coming next: the town with cars and the bridge, the forest and the mouse.

## Icon and thumbnail

`art/icon.png` and `art/thumbnail.png`. Run the publish action by hand with "Upload the icon and thumbnail" to send them to Roblox.

## Controls

- Move, jump and look like any Roblox game. No run button: sneaking is the game
- Skip a clip: ⏭, or A, B or X on a controller

## Plans

The house, yard and town come from `plans/*.json`, drawn in the Pianka Escape Planner. After changing a plan run `python3 tools/plan2luau.py` to update `src/shared/Plan.luau`. 1 square is 50 cm, 4 studs.

## Files

- `src/shared/Config.luau` speeds, noise, timers, sound clips, who sleeps where
- `src/shared/Cat.luau` Pianka, same as in the first game
- `src/shared/Watch.luau` where the backyard cameras look and what they see
- `src/server/Escape.server.luau` builds the house and yard from the plan and makes it a home, keys, toys, stirring sleepers, cameras, the doors and the gate
- `src/client/Escape.client.luau` screen, snoring, sneaking, cat walk, clips
- `tools/make_audio.py` makes the sounds, the sneaky music, its tense layer and the dream music box. Voice lines in `sounds/voice` were made once with Piper. The snoring in `sounds/snore.mp3` is "b8_snoring" by iamgiorgio on freesound.org (371299)

## Tests and publish

`lune run tests/escape.spec.luau` (from this folder) runs the real scripts with bots: keys, a wake up, running near a sleeper, the open door, the cameras, the gate keys and the way out. It runs before every publish.

Pushing changes in `escape/` runs the **Publish Pianka the Escape** action: test, upload new sounds, build and publish to the game.
