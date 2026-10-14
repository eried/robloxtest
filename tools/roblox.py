#!/usr/bin/env python3
"""Upload sounds and publish the place with Roblox Open Cloud.

python3 tools/roblox.py audio    uploads sounds whose id is 0 in Config.luau
python3 tools/roblox.py passes   creates game passes whose id is 0 in Config.luau
python3 tools/roblox.py publish  publishes FindPianka.rbxlx
python3 tools/roblox.py restart  restarts running servers so players get the new version
python3 tools/roblox.py name     sets the game name to GameName in Config.luau
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
    ("ChaseMusicId", "music/PiankaChase.mp3", "Find Pianka chase music"),
    ("CallId", "sounds/PiankaCall.mp3", "Find Pianka call"),
    ("VoicesId", "sounds/PiankaVoices.mp3", "Find Pianka voices"),
    ("EscapeMusicId", "music/PiankaEscape.mp3", "Find Pianka escape music"),
    ("EscapeSfxId", "sounds/PiankaEscapeSfx.mp3", "Find Pianka escape sounds"),
]


def call(method, url, data=None, headers=None, auth=True):
    all_headers = dict(headers or {})
    if auth:
        all_headers["x-api-key"] = KEY
    for attempt in range(6):
        req = urllib.request.Request(url, data=data, method=method, headers=all_headers)
        try:
            with urllib.request.urlopen(req) as res:
                return json.loads(res.read() or b"{}")
        except urllib.error.HTTPError as err:
            body = err.read().decode(errors="replace")
            if err.code in (409, 429, 500, 503) and attempt < 5:
                print(f"Roblox is busy ({err.code}), trying again in 30 s")
                time.sleep(30)
                continue
            sys.exit(f"{method} {url} failed: {err.code} {body}")


def key_info():
    body = json.dumps({"apiKey": KEY}).encode()
    info = None
    for path in ("api-keys/v1/introspect", "api-key/v1/introspect"):
        req = urllib.request.Request(f"{API}/{path}", data=body, method="POST", headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req) as res:
                info = json.loads(res.read())
                break
        except urllib.error.HTTPError as err:
            print(f"Key check {path}: {err.code}")
    if info is None:
        return {}
    scopes = [f"{s.get('name')}:{','.join(s.get('operations', []))}" for s in info.get("scopes", [])]
    print("Key owner:", info.get("authorizedUserId"), "enabled:", info.get("enabled"), "expired:", info.get("expired"))
    print("Key scopes:", scopes or info.get("scopes"))
    return info


def user_id():
    if os.environ.get("ROBLOX_USER_ID"):
        return os.environ["ROBLOX_USER_ID"]
    owner = key_info().get("authorizedUserId")
    if owner:
        return str(owner)
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


def status():
    place = place_id()
    universe = universe_id(place)
    try:
        with urllib.request.urlopen(f"https://develop.roblox.com/v1/universes/{universe}") as res:
            info = json.loads(res.read())
        state = "Public" if info.get("isActive") else "Private"
        print(f"{info.get('name')}: {state} ({info.get('privacyType')})")
    except urllib.error.URLError as err:
        print(f"Could not read the game status: {err}")
    print(f"https://www.roblox.com/games/{place}")


PASS_IMAGES = {
    "LanternRainbow": ("art/passes/rainbow-lantern.png", "A rainbow lantern that glows in every color."),
    "Pet": ("art/passes/kitten-pet.png", "A little black kitten that rides on your shoulder."),
    "Crown": ("art/passes/golden-crown.png", "A shiny golden crown."),
    "ExtraHeart": ("art/passes/extra-heart.png", "One more heart in every round."),
}


def multipart(fields, files):
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode()
    for name, (filename, content, kind) in files.items():
        body += (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\n"
            f"Content-Type: {kind}\r\n\r\n"
        ).encode() + content + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return body, {"Content-Type": f"multipart/form-data; boundary={boundary}"}


def passes():
    key_info()
    universe = universe_id(place_id())
    with open(CONFIG) as f:
        config = f.read()
    pattern = re.compile(r'\{ key = "(\w+)", name = "([^"]+)", price = (\d+), id = 0 \}')
    found = pattern.findall(config)
    if not found:
        print("All game passes already have ids")
        return
    for key, name, price in found:
        path, description = PASS_IMAGES[key]
        with open(path, "rb") as f:
            image = f.read()
        body, headers = multipart(
            {"name": name, "description": description, "isForSale": "true", "price": price},
            {"imageFile": (os.path.basename(path), image, "image/png")},
        )
        res = call("POST", f"{API}/game-passes/v1/universes/{universe}/game-passes", body, headers)
        pass_id = res.get("gamePassId") or res.get("id")
        if not pass_id:
            sys.exit(f"Unexpected answer for {name}: {res}")
        print(f"{name} = {pass_id} ({price} R$)")
        config = config.replace(f'{{ key = "{key}", name = "{name}", price = {price}, id = 0 }}', f'{{ key = "{key}", name = "{name}", price = {price}, id = {pass_id} }}')
        with open(CONFIG, "w") as f:
            f.write(config)


def restart():
    universe = universe_id(place_id())
    call("POST", f"{API}/cloud/v2/universes/{universe}:restartServers", b"{}", {"Content-Type": "application/json"})
    print("Servers restarting, players get the new version")


def make_public():
    universe = universe_id(place_id())
    body = json.dumps({"visibility": "PUBLIC"}).encode()
    url = f"{API}/cloud/v2/universes/{universe}?updateMask=visibility"
    res = call("PATCH", url, body, {"Content-Type": "application/json"})
    print("Visibility:", res.get("visibility"))


def set_name():
    with open(CONFIG) as f:
        name = re.search(r'GameName = "([^"]+)"', f.read()).group(1)
    place = place_id()
    universe = universe_id(place)
    body = json.dumps({"displayName": name}).encode()
    url = f"{API}/cloud/v2/universes/{universe}/places/{place}?updateMask=displayName"
    res = call("PATCH", url, body, {"Content-Type": "application/json"})
    print("Game name:", res.get("displayName"))


if __name__ == "__main__":
    {"audio": audio, "passes": passes, "publish": publish, "restart": restart, "status": status, "public": make_public, "name": set_name}[sys.argv[1]]()
