#!/usr/bin/env python3
"""Upload sounds and publish the place with Roblox Open Cloud.

python3 tools/roblox.py audio    uploads sounds whose id is 0 in Config.luau
python3 tools/roblox.py publish  publishes FindPianka.rbxlx
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com"
KEY = os.environ.get("ROBLOX_API_KEY", "")
CONFIG = "src/shared/Config.luau"
AUDIO = [
    ("MusicId", "music/PiankaMystery.mp3", "Find Pianka music"),
    ("SoundsId", "sounds/PiankaSounds.mp3", "Find Pianka sounds"),
]


def call(method, url, data=None, headers=None, auth=True):
    all_headers = dict(headers or {})
    if auth:
        all_headers["x-api-key"] = KEY
    req = urllib.request.Request(url, data=data, method=method, headers=all_headers)
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read() or b"{}")
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {url} failed: {err.code} {err.read().decode(errors='replace')}")


def user_id():
    if os.environ.get("ROBLOX_USER_ID"):
        return os.environ["ROBLOX_USER_ID"]
    name = os.environ.get("ROBLOX_USERNAME") or "mrscientist84"
    body = json.dumps({"usernames": [name], "excludeBannedUsers": True}).encode()
    res = call("POST", "https://users.roblox.com/v1/usernames/users", body, {"Content-Type": "application/json"}, auth=False)
    return str(res["data"][0]["id"])


def upload_audio(path, name, uid):
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": "Audio",
        "displayName": name,
        "description": name,
        "creationContext": {"creator": {"userId": uid}},
    }
    with open(path, "rb") as f:
        content = f.read()
    body = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n"
        f"Content-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n"
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; "
        f"filename=\"{os.path.basename(path)}\"\r\nContent-Type: audio/mpeg\r\n\r\n"
    ).encode() + content + f"\r\n--{boundary}--\r\n".encode()
    op = call("POST", f"{API}/assets/v1/assets", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    op_path = op.get("path") or f"operations/{op['operationId']}"
    for _ in range(100):
        if op.get("done"):
            return op["response"]["assetId"]
        time.sleep(3)
        op = call("GET", f"{API}/assets/v1/{op_path}")
    sys.exit(f"Upload timed out: {path}")


def audio():
    with open(CONFIG) as f:
        config = f.read()
    uid = None
    for key, path, name in AUDIO:
        if not re.search(rf"\b{key} = 0,", config):
            print(f"{key} already set")
            continue
        uid = uid or user_id()
        asset = upload_audio(path, name, uid)
        config = re.sub(rf"\b{key} = 0,", f"{key} = {asset},", config)
        print(f"{key} = {asset}")
    with open(CONFIG, "w") as f:
        f.write(config)


def universe_id(place):
    if os.environ.get("UNIVERSE_ID"):
        return os.environ["UNIVERSE_ID"]
    res = call("GET", f"{API}/universes/v1/places/{place}/universe", auth=False)
    return str(res["universeId"])


def place_id():
    if os.environ.get("PLACE_ID"):
        return os.environ["PLACE_ID"]
    universe = os.environ["UNIVERSE_ID"]
    for url in (
        f"https://games.roblox.com/v1/games?universeIds={universe}",
        f"https://develop.roblox.com/v1/universes/{universe}",
    ):
        try:
            with urllib.request.urlopen(url) as res:
                body = json.loads(res.read())
        except urllib.error.URLError as err:
            print(f"Could not read {url}: {err}")
            continue
        item = body["data"][0] if body.get("data") else body
        if item.get("rootPlaceId"):
            print("Place id", item["rootPlaceId"])
            return str(item["rootPlaceId"])
    sys.exit("Could not find the place id. Add a PLACE_ID variable in GitHub.")


def publish():
    place = place_id()
    universe = universe_id(place)
    with open("FindPianka.rbxlx", "rb") as f:
        data = f.read()
    url = f"{API}/universes/v1/{universe}/places/{place}/versions?versionType=Published"
    res = call("POST", url, data, {"Content-Type": "application/xml"})
    print("Published version", res.get("versionNumber"))


if __name__ == "__main__":
    {"audio": audio, "publish": publish}[sys.argv[1]]()
