# Public game stats and age rating. No key needed: python3 tools/stats.py
import json
import os
import urllib.error
import urllib.request

UNIVERSE = os.environ.get("UNIVERSE_ID") or "10770167426"


def get(url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            return json.loads(res.read())
    except (urllib.error.URLError, ValueError) as err:
        print(f"Could not read {url}: {err}")
        return None


def main():
    lines = ["## Find Pianka stats", ""]
    games = get(f"https://games.roblox.com/v1/games?universeIds={UNIVERSE}")
    game = (games or {}).get("data", [{}])[0] if games else {}
    if game:
        lines += [
            f"- Name: {game.get('name')}",
            f"- Visits: {game.get('visits')}",
            f"- Playing now: {game.get('playing')}",
            f"- Favorites: {game.get('favoritedCount')}",
            f"- Max players per server: {game.get('maxPlayers')}",
            f"- Created: {game.get('created')}",
            f"- Updated: {game.get('updated')}",
            f"- Genre: {game.get('genre')}",
        ]
    votes = get(f"https://games.roblox.com/v1/games/votes?universeIds={UNIVERSE}")
    vote = (votes or {}).get("data", [{}])[0] if votes else {}
    if vote:
        lines.append(f"- Likes: {vote.get('upVotes')} up, {vote.get('downVotes')} down")
    age = get("https://apis.roblox.com/experience-guidelines-api/experience-guidelines/get-age-recommendation", {"universeId": UNIVERSE})
    details = (age or {}).get("ageRecommendationDetails") or {}
    summary = (details.get("summary") or {}).get("ageRecommendation") or {}
    if summary:
        lines.append(f"- Age rating: {summary.get('displayName')} (min age {summary.get('minimumAge')}, maturity {summary.get('contentMaturity')})")
        for use in details.get("descriptorUsages") or []:
            name = (use.get("descriptor") or {}).get("displayName") or use.get("name")
            lines.append(f"  - {name}: {(use.get('contains'))}")
    else:
        lines.append("- Age rating: none yet (maturity questionnaire not done?)")
    lines.append(f"- Raw age data: {json.dumps(age)[:600]}")
    text = "\n".join(lines)
    print(text)
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    main()
