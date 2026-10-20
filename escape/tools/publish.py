#!/usr/bin/env python3
"""Upload sounds and publish Pianka the Escape, reusing tools/roblox.py.

python3 escape/tools/publish.py audio | grant | publish | restart | name | status | public | sounds | art
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import roblox  # noqa: E402

roblox.CONFIG = "escape/src/shared/Config.luau"
roblox.AUDIO = [
    ("SfxId", "escape/sounds/PiankaEscapeSfx.mp3", "Pianka Escape sounds"),
    ("MusicId", "escape/music/PiankaSneak.mp3", "Pianka Escape sneaky music"),
    ("TenseId", "escape/music/PiankaTense.mp3", "Pianka Escape tense music"),
    ("DreamId", "escape/music/PiankaDream.mp3", "Pianka Escape dream music box"),
]
PLACE_FILE = "escape/PiankaEscape.rbxlx"
ART = [
    ("icon", "escape/art/icon.png", "game-icon/games/{u}/language-codes/en"),
    ("thumbnail", "escape/art/thumbnail.png", "game-thumbnails/games/{u}/language-codes/en/image"),
]


def publish():
    place = roblox.place_id()
    universe = roblox.universe_id(place)
    with open(PLACE_FILE, "rb") as f:
        data = f.read()
    url = f"{roblox.API}/universes/v1/{universe}/places/{place}/versions?versionType=Published"
    res = roblox.call("POST", url, data, {"Content-Type": "application/xml"})
    print("Published version", res.get("versionNumber"))


def art():
    """Uploads the game icon and thumbnail. Each run adds a thumbnail, so it only runs when asked."""
    universe = roblox.universe_id(roblox.place_id())
    for kind, path, route in ART:
        with open(path, "rb") as f:
            image = f.read()
        url = f"{roblox.API}/legacy-game-internationalization/v1/{route.format(u=universe)}"
        for field in ("request.files", "files"):
            body, headers = roblox.multipart({}, {field: (os.path.basename(path), image, "image/png")})
            try:
                print(f"{kind} uploaded:", roblox.call("POST", url, body, headers))
                break
            except SystemExit as err:
                print(f"{kind} ({field}) failed: {err}")


if __name__ == "__main__":
    actions = {"audio": roblox.audio, "publish": publish, "restart": roblox.restart, "status": roblox.status, "public": roblox.make_public, "name": roblox.set_name, "sounds": roblox.sounds, "grant": roblox.grant, "art": art}
    actions[sys.argv[1]]()
