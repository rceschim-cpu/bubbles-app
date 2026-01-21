import json
import math
import time
from datetime import datetime, timezone

import requests

SUBREDDITS = ["worldnews", "technology", "science", "economics", "geopolitics"]

# Filtros MVP
MIN_UPVOTES = 300
MIN_COMMENTS = 100

# Seleção final
TOP_N = 10

USER_AGENT = "BubblesMVP/0.1 (by u/your_username_or_contact)"

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def fetch_hot_posts(subreddit: str, limit: int = 50) -> list[dict]:
    url = f"https://www.reddit.com/r/{subreddit}/hot.json"
    params = {"limit": limit}
    headers = {"User-Agent": USER_AGENT}

    resp = requests.get(url, params=params, headers=headers, timeout=20)
    resp.raise_for_status()

    data = resp.json()
    children = data.get("data", {}).get("children", [])
    posts = []
    for c in children:
        d = c.get("data", {})
        if not d:
            continue
        posts.append({
            "id": d.get("id"),
            "subreddit": subreddit,
            "title": d.get("title", "").strip(),
            "score": int(d.get("score", 0)),  # upvotes
            "num_comments": int(d.get("num_comments", 0)),
            "created_utc": float(d.get("created_utc", 0.0)),
            "permalink": "https://www.reddit.com" + str(d.get("permalink", "")),
        })
    return posts

def is_relevant(post: dict) -> bool:
    return (post["score"] >= MIN_UPVOTES) or (post["num_comments"] >= MIN_COMMENTS)

def hours_since(created_utc: float) -> float:
    age_seconds = max(1.0, time.time() - created_utc)
    return age_seconds / 3600.0

def compute_raw_score(post: dict) -> float:
    # v0.1: 1 post = 1 bolha provisória
    volume = 1.0
    depth = min(float(post["num_comments"]), 1000.0)
    speed = (float(post["score"]) + float(post["num_comments"])) / hours_since(post["created_utc"])

    raw = (volume * 0.35) + (depth * 0.30) + (speed * 0.35)
    return raw

def normalize_scores(items: list[dict], key_raw: str = "rawScore", key_norm: str = "relevanceScore") -> None:
    vals = [it[key_raw] for it in items]
    if not vals:
        return
    mn = min(vals)
    mx = max(vals)
    if mx - mn < 1e-9:
        for it in items:
            it[key_norm] = 0.5
        return
    for it in items:
        it[key_norm] = (it[key_raw] - mn) / (mx - mn)

def main():
    collected = []
    for sub in SUBREDDITS:
        try:
            posts = fetch_hot_posts(sub, limit=50)
        except Exception as e:
            print(f"[ERRO] Falha ao buscar r/{sub}: {e}")
            continue

        # filtra relevantes
        posts = [p for p in posts if is_relevant(p)]

        # cria bolhas provisórias (1 post = 1 bolha)
        for p in posts:
            raw = compute_raw_score(p)

            bubble = {
                "id": f"reddit_{p['id']}",
                "title": p["title"],
                "source": "reddit",
                "subreddit": p["subreddit"],
                "permalink": p["permalink"],
                "createdAt": datetime.fromtimestamp(p["created_utc"], tz=timezone.utc).isoformat(),
                "rawScore": raw,
                # relevanceScore entra depois (normalização)
            }
            collected.append(bubble)

        # descanso pequeno pra não ser agressivo
        time.sleep(1.0)

    if not collected:
        print("Nenhum post relevante encontrado. Tente baixar os thresholds.")
        return

    # normaliza e pega top N
    normalize_scores(collected, "rawScore", "relevanceScore")
    collected.sort(key=lambda x: x["relevanceScore"], reverse=True)
    top = collected[:TOP_N]

    # gera tamanho sugerido (opcional, pode deixar pro app)
    min_radius = 36.0
    max_radius = 96.0
    for b in top:
        s = float(b["relevanceScore"])
        radius = min_radius + (math.sqrt(s) * (max_radius - min_radius))
        b["suggestedRadius"] = round(radius, 2)

    output = {
        "generatedAt": now_utc().isoformat(),
        "count": len(top),
        "items": top,
    }

    with open("bubbles.json", "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print("OK! Arquivo gerado: bubbles.json")
    print("Top itens:")
    for i, b in enumerate(top, start=1):
        print(f"{i:02d}. ({b['subreddit']}) score={b['relevanceScore']:.2f} | {b['title'][:80]}")

if __name__ == "__main__":
    main()
