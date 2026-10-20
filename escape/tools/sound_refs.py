# Writes escape/place/Sounds.model.json: one Sound per sound id in Config.luau, placed in SoundService.
# Publishing a place that holds the sounds lets the game use them.
# Run: python3 escape/tools/sound_refs.py
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")


def main():
    with open(os.path.join(ROOT, "src", "shared", "Config.luau")) as f:
        ids = re.findall(r"\b(\w+)Id = (\d{6,}),", f.read())
    children = [{"Name": name, "ClassName": "Sound", "Properties": {"SoundId": f"rbxassetid://{asset}", "Volume": 0}} for name, asset in ids]
    os.makedirs(os.path.join(ROOT, "place"), exist_ok=True)
    with open(os.path.join(ROOT, "place", "Sounds.model.json"), "w") as f:
        json.dump({"ClassName": "Folder", "Children": children}, f, indent=2)
    print("Sounds in the place:", ", ".join(f"{n} {a}" for n, a in ids))


if __name__ == "__main__":
    main()
