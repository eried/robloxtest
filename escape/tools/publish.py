#!/usr/bin/env python3
"""Upload sounds and publish Pianka the Escape, reusing tools/roblox.py.

python3 escape/tools/publish.py audio | publish | restart | name | status | public | sounds
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "tools"))
import roblox  # noqa: E402

roblox.CONFIG = "escape/src/shared/Config.luau"
roblox.AUDIO = [
    ("SfxId", "escape/sounds/PiankaEscapeSfx.mp3", "Pianka Escape sounds"),
    ("MusicId", "escape/music/PiankaSneak.mp3", "Pianka Escape sneaky music"),
]
PLACE_FILE = "escape/PiankaEscape.rbxlx"


def publish():
    place = roblox.place_id()
    universe = roblox.universe_id(place)
    with open(PLACE_FILE, "rb") as f:
        data = f.read()
    url = f"{roblox.API}/universes/v1/{universe}/places/{place}/versions?versionType=Published"
    res = roblox.call("POST", url, data, {"Content-Type": "application/xml"})
    print("Published version", res.get("versionNumber"))


if __name__ == "__main__":
    actions = {"audio": roblox.audio, "publish": publish, "restart": roblox.restart, "status": roblox.status, "public": roblox.make_public, "name": roblox.set_name, "sounds": roblox.sounds}
    actions[sys.argv[1]]()
