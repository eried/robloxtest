# Turns the planner sheets in escape/plans into escape/src/shared/Plan.luau
# Run: python3 escape/tools/plan2luau.py
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")


def luau_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def sheet(key):
    with open(os.path.join(ROOT, "plans", key + ".json")) as f:
        d = json.load(f)
    w, h, cells = d["w"], d["h"], d["cells"]
    rows = [cells[y * w : (y + 1) * w] for y in range(h)]
    lines = [f"\t{key} = {{", f"\t\tw = {w},", f"\t\th = {h},", "\t\trows = {"]
    lines += [f"\t\t\t{luau_string(r)}," for r in rows]
    lines.append("\t\t},")
    lines.append("\t\titems = {")
    for it in d["items"]:
        lines.append(f'\t\t\t{{ t = "{it["t"]}", x = {int(it["x"])}, y = {int(it["y"])}, r = {int(it.get("r", 0))} }},')
    lines.append("\t\t},")
    lines.append("\t\tlabels = {")
    for lb in d["labels"]:
        lines.append(f"\t\t\t{{ text = {luau_string(lb['text'])}, x = {lb['x']}, y = {lb['y']} }},")
    lines.append("\t\t},")
    lines.append("\t},")
    return lines


def main():
    out = ["-- Made from escape/plans by escape/tools/plan2luau.py. Edit the plans, not this file", "return {"]
    for key in ("floor1", "floor2", "yard", "outside"):
        out += sheet(key)
    out.append("}")
    path = os.path.join(ROOT, "src", "shared", "Plan.luau")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("Wrote", path)


if __name__ == "__main__":
    main()
