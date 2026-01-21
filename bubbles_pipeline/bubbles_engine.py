import json
import math
import os
import re
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from urllib.parse import quote

import requests
from openai import OpenAI

# =========================
# CONFIG
# =========================

SUBREDDITS = ["worldnews", "technology", "science", "economics", "geopolitics"]

MIN_UPVOTES = 300
MIN_COMMENTS = 100
TOP_N = 20

USER_AGENT = "BubblesMVP/0.2 (contact: your_email_or_handle)"
OUTPUT_FILE = "bubbles_enriched.json"

MODEL = "gpt-4.1-mini"
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

REDDIT_BASE = "https://www.reddit.com"

MAX_COMMENTS_PER_POST = 40
MIN_COMMENT_CHARS = 30

SLEEP_BETWEEN_SUBS = 1.0
SLEEP_BETWEEN_POSTS_COMMENTS = 0.3

# Clusterização / agregação
CLUSTER_MIN_OVERLAP = 1               # número mínimo de keywords em comum para agrupar
CLUSTER_MAX_POSTS_TO_MERGE = 4        # quantos posts por cluster usar para juntar comentários (cap)
CLUSTER_MAX_TOTAL_COMMENTS = 60       # total máximo de candidatos de comentários (após merge)

# =========================
# CLIENTS
# =========================

client = OpenAI(api_key=OPENAI_API_KEY)

session = requests.Session()
session.headers.update({"User-Agent": USER_AGENT})

# =========================
# DATA MODELS
# =========================

@dataclass
class RedditPost:
    id: str
    subreddit: str
    title: str
    score: int
    num_comments: int
    created_utc: float
    permalink: str
    image: Optional[str] = None

@dataclass
class BubbleItem:
    id: str
    title: str
    source: str
    subreddit: str
    permalink: str
    createdAt: str
    rawScore: float
    relevanceScore: float = 0.0
    suggestedRadius: float = 0.0
    rank: int = 0
    label: str = ""
    context: str = ""
    opinions: Optional[List[Dict[str, Any]]] = None
    image: Optional[str] = None

@dataclass
class BubbleCluster:
    key: str
    items: List[BubbleItem]
    rawScore: float = 0.0
    relevanceScore: float = 0.0

# =========================
# HELPERS
# =========================

def now_utc() -> datetime:
    return datetime.now(timezone.utc)

def hours_since(created_utc: float) -> float:
    age_seconds = max(1.0, time.time() - created_utc)
    return age_seconds / 3600.0

def is_relevant(score: int, num_comments: int) -> bool:
    return (score >= MIN_UPVOTES) or (num_comments >= MIN_COMMENTS)

def compute_raw_score(score: int, num_comments: int, created_utc: float) -> float:
    volume = 1.0
    depth = min(float(num_comments), 1000.0)
    speed = (float(score) + float(num_comments)) / hours_since(created_utc)
    return (volume * 0.35) + (depth * 0.30) + (speed * 0.35)

def normalize_scores(items: List[BubbleItem]) -> None:
    vals = [it.rawScore for it in items]
    if not vals:
        return
    mn = min(vals)
    mx = max(vals)
    if mx - mn < 1e-9:
        for it in items:
            it.relevanceScore = 0.5
        return
    for it in items:
        it.relevanceScore = (it.rawScore - mn) / (mx - mn)

def suggested_radius(relevance_score: float) -> float:
    min_radius = 36.0
    max_radius = 96.0
    r = min_radius + (math.sqrt(max(0.0, relevance_score)) * (max_radius - min_radius))
    return round(r, 2)

def safe_text(s: str) -> str:
    s = (s or "").strip()
    s = re.sub(r"\s+", " ", s)
    return s

def norm_key(s: str) -> str:
    s = safe_text(s).lower()
    s = re.sub(r"[^a-z0-9áàâãéêíóôõúç\s-]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

from urllib.parse import quote

def extract_image_from_post(d: Dict[str, Any]) -> Optional[str]:
    # 1️⃣ imagem direta válida (APENAS i.redd.it)
    url = d.get("url_overridden_by_dest")
    if isinstance(url, str) and url.startswith("https://i.redd.it"):
        return url

    # 2️⃣ preview: aceita SOMENTE se não for external-preview
    preview = d.get("preview")
    if isinstance(preview, dict):
        images = preview.get("images")
        if isinstance(images, list) and images:
            src = images[0].get("source", {})
            url = src.get("url")
            if isinstance(url, str):
                url = url.replace("&amp;", "&")
                if url.startswith("https://i.redd.it"):
                    return url

    # 3️⃣ qualquer coisa external-preview → DESCARTA
    return None

# --- cluster helpers

STOPWORDS = {
    "the", "and", "for", "with", "from", "this", "that", "into", "over", "after",
    "sobre", "entre", "para", "como", "quando", "onde", "isso", "essa", "este",
    "says", "said", "saying",
    "diz", "afirma", "declara", "anuncia", "fala",
    "meetings", "meeting", "says", "tell", "tells",
    "sobre", "contra", "após", "antes", "durante"
}

def extract_keywords(title: str) -> List[str]:
    # palavras com 4+ letras, mantém acentos
    words = re.findall(r"[a-zA-ZÀ-ÿ]{4,}", (title or "").lower())
    kws = [w for w in words if w not in STOPWORDS]
    # dedupe mantendo ordem aproximada
    seen = set()
    out = []
    for w in kws:
        if w not in seen:
            seen.add(w)
            out.append(w)
    return out

def cluster_key_from_title(title: str) -> str:
    kws = extract_keywords(title)
    return "|".join(sorted(kws[:10]))  # chave um pouco mais “rica” para reduzir colisões

def cluster_bubbles(items: List[BubbleItem]) -> List[BubbleCluster]:
    """
    Agrupa posts por sobreposição de keywords.
    Mantém clusterização simples/interpretável.
    """
    clusters: List[BubbleCluster] = []

    for it in items:
        kws = set(extract_keywords(it.title))
        matched: Optional[BubbleCluster] = None

        for c in clusters:
            ckws = set(c.key.split("|")) if c.key else set()
            if len(kws & ckws) >= CLUSTER_MIN_OVERLAP:
                matched = c
                break

        if matched:
            matched.items.append(it)
        else:
            clusters.append(
                BubbleCluster(
                    key=cluster_key_from_title(it.title),
                    items=[it],
                )
            )

    # score do cluster: usa o maior rawScore (mais estável e evita “superinflar” por repetição)
    for c in clusters:
        c.rawScore = max(x.rawScore for x in c.items)

    return clusters

def select_cluster_image(cluster: BubbleCluster) -> Optional[str]:
    items_sorted = sorted(cluster.items, key=lambda x: x.rawScore, reverse=True)
    for it in items_sorted:
        if it.image:
            return it.image
    return None

# =========================
# REDDIT FETCH
# =========================

def fetch_hot_posts(subreddit: str, limit: int = 50) -> List[RedditPost]:
    url = f"{REDDIT_BASE}/r/{subreddit}/hot.json"
    resp = session.get(url, params={"limit": limit}, timeout=20)
    resp.raise_for_status()

    posts: List[RedditPost] = []
    for c in resp.json().get("data", {}).get("children", []):
        d = c.get("data", {})
        if not d:
            continue

        pid = str(d.get("id") or "").strip()
        if not pid:
            continue

        posts.append(
            RedditPost(
                id=pid,
                subreddit=subreddit,
                title=safe_text(d.get("title", "")),
                score=int(d.get("score", 0) or 0),
                num_comments=int(d.get("num_comments", 0) or 0),
                created_utc=float(d.get("created_utc", 0.0) or 0.0),
                permalink=f"{REDDIT_BASE}{d.get('permalink', '')}",
                image=extract_image_from_post(d),
            )
        )
    return posts

def fetch_top_comments(post_id: str, subreddit: str, limit: int) -> List[Dict[str, Any]]:
    url = f"{REDDIT_BASE}/r/{subreddit}/comments/{post_id}.json"
    resp = session.get(url, params={"sort": "top", "limit": 50}, timeout=20)
    resp.raise_for_status()

    data = resp.json()
    if not isinstance(data, list) or len(data) < 2:
        return []

    out: List[Dict[str, Any]] = []
    for ch in data[1].get("data", {}).get("children", []):
        d = ch.get("data", {})
        body = safe_text(d.get("body", ""))
        if len(body) < MIN_COMMENT_CHARS or body in ("[deleted]", "[removed]"):
            continue
        out.append({"id": d.get("id"), "text": body, "score": int(d.get("score", 0) or 0)})

    out.sort(key=lambda x: x["score"], reverse=True)
    return out[:limit]


SYSTEM_PROMPT = """
Você escreve conteúdos para um aplicativo chamado Bubbles, que ajuda pessoas comuns
a entenderem assuntos em debate público de forma clara, acessível e equilibrada.

Princípios fundamentais:
- O aplicativo NÃO toma posição.
- O contexto deve ser neutro e informativo.
- As opiniões representam discursos reais existentes no debate público.
- Clareza é mais importante que literalidade.
- O conteúdo deve funcionar para pessoas sem conhecimento prévio do tema.

Regras gerais:
- Linguagem clara, direta e acessível em português do Brasil.
- Não usar tom jornalístico, manchetes ou sensacionalismo.
- Não inventar fatos que não estejam implícitos no título ou nos comentários.
- Não moralizar nem julgar no contexto.
- As opiniões podem ser mais fortes e polarizadas que o contexto.
""".strip()

USER_PROMPT_TEMPLATE = """
Você receberá:
- Um TÍTULO (tema principal)
- Um SUBREDDIT (contexto de origem)
- Uma lista de COMENTÁRIOS reais sobre o tema

Sua tarefa é gerar:

0) TÍTULO EM PORTUGUÊS (FOCO DO DEBATE)
- Reescreva o título em português do Brasil com clareza
- Se houver ambiguidade em português, reescreva para remover a ambiguidade
- NÃO forçar “conflito”, “tensão” ou “disputa” quando o evento for apenas uma decisão, declaração, mudança, investigação, acordo, sanção, anúncio ou reação
- Use palavras mais precisas quando couber: “decisão”, “anúncio”, “reação”, “debate”, “pressão”, “críticas”, “mudança”, “investigação”, “medida”, “acordo”, “votação”, “sanção”
- Nunca erre fatos básicos (ex: cargo/status atual de figuras públicas)

1) LABEL
- Curto, porém mais informativo (4 a 8 palavras)
- Pode usar estrutura “Tema · Qualificador” quando fizer sentido
- Evitar frases completas
- Deve diferenciar esta bolha de outras do mesmo cluster
- Sem ambiguidade de significado

2) CONTEXTO
- Máximo de 3 frases
- Explicar o que aconteceu para alguém que não conhece o assunto
- Responder implicitamente: o que aconteceu / quem está envolvido / por que isso importa
- Manter neutralidade total
- NÃO julgar, NÃO moralizar, NÃO tomar partido
- Se envolver política institucional, explique o evento concreto (ex: votação, derrota, decisão)
- Se houver termos essenciais, explique brevemente entre parênteses (3 a 6 palavras)

3) OPINIÕES (EXATAMENTE 3)
Cada opinião deve:
- Ser clara, curta (até 220 caracteres) e “votável”
- Representar discursos reais do debate
- Ter contraste real entre os lados

Estrutura obrigatória das opiniões:
- 1 opinião favorável a um dos lados do conflito
- 1 opinião contrária a esse lado
- 1 opinião neutra, cética ou ponderada (SEM fugir do tema)

Regras IMPORTANTES para as opiniões:
- Positiva e negativa NÃO podem estar do mesmo lado
- Polarize o máximo possivel para ficar bem claro qual é o lado assumido em cada uma das opiniões
- Sempre que houver agentes claros (presidentes, governos, empresas), cite-os explicitamente
- Quando o conflito for ideológico, explicite a ideologia (ex: capitalismo, comunismo, autoritarismo)
- Em temas ligados a direitos humanos, imigração, violência estatal ou repressão, as opiniões podem ser mais fortes
- A opinião neutra NÃO deve ser genérica nem metadiscursiva
- NÃO usar frases como “verifique as fontes” sem ligação direta com o fato
- Não usar usernames
- Não usar insultos ou palavrões (suavizar mantendo o sentido)

FORMATO DE SAÍDA:
- Retorne APENAS JSON válido
- NÃO use markdown
- Use EXATAMENTE esta estrutura:

{{
  "title": "....",
  "label": "....",
  "context": "....",
  "opinions": [
    {{
      "id": "op1",
      "tone": "positive",
      "text": "....",
      "source": "reddit"
    }},
    {{
      "id": "op2",
      "tone": "negative",
      "text": "....",
      "source": "reddit"
    }},
    {{
      "id": "op3",
      "tone": "neutral",
      "text": "....",
      "source": "reddit"
    }}
  ]
}}

TÍTULO (original): "{title}"
SUBREDDIT: {subreddit}

COMENTÁRIOS (candidatos):
{comments_block}
""".strip()

def _extract_json(text: str) -> Dict[str, Any]:
    text = (text or "").strip()

    # 1) tentativa direta
    try:
        return json.loads(text)
    except Exception:
        pass

    # 2) tentativa via bloco { ... }
    m = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if m:
        try:
            return json.loads(m.group(0))
        except Exception:
            pass

    # 3) fallback: modelo retornou JSON sem chaves externas
    # Ex:
    #   "title": "...",
    #   "label": "...",
    wrapped = "{\n" + text.strip().rstrip(",") + "\n}"
    try:
        return json.loads(wrapped)
    except Exception as e:
        raise ValueError(f"Resposta sem JSON válido detectável: {e}")

def _clean_opinions(opinions: Any) -> List[Dict[str, Any]]:
    if not isinstance(opinions, list):
        opinions = []
    cleaned: List[Dict[str, Any]] = []
    for op in opinions:
        if not isinstance(op, dict):
            continue
        tone = op.get("tone", "")
        txt = safe_text(op.get("text", ""))[:220]
        if tone not in ("positive", "negative", "neutral"):
            continue
        if not txt:
            continue
        cleaned.append(
            {
                "id": op.get("id", ""),
                "tone": tone,
                "text": txt,
                "source": "reddit",
                "votes": 0,
            }
        )
    if len(cleaned) == 3:
        return cleaned
    # fallback seguro
    return [
        {"id": "op1", "tone": "positive", "text": "Há quem defenda essa medida como necessária.", "source": "reddit", "votes": 0},
        {"id": "op2", "tone": "negative", "text": "Outros criticam e veem riscos ou consequências negativas.", "source": "reddit", "votes": 0},
        {"id": "op3", "tone": "neutral",  "text": "Também há quem prefira esperar mais informações antes de concluir.", "source": "reddit", "votes": 0},
    ]

def generate_context_and_opinions(title: str, subreddit: str, comments: List[Dict[str, Any]]) -> Dict[str, Any]:
    lines: List[str] = []
    for i, c in enumerate(comments[:MAX_COMMENTS_PER_POST], start=1):
        lines.append(f"{i:02d}) (+{c.get('score',0)}) {safe_text(c.get('text',''))[:350]}")
    comments_block = "\n".join(lines) if lines else "- sem comentários suficientes -"

    resp = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": USER_PROMPT_TEMPLATE.format(
                    title=title,
                    subreddit=subreddit,
                    comments_block=comments_block,
                ),
            },
        ],
        temperature=0.1,
        max_tokens=550,
    )

    raw = (resp.choices[0].message.content or "").strip()
    data = _extract_json(raw)

    out: Dict[str, Any] = {
        "title": safe_text(data.get("title", ""))[:160],
        "label": safe_text(data.get("label", ""))[:60],
        "context": safe_text(data.get("context", ""))[:700],
        "opinions": _clean_opinions(data.get("opinions")),
    }
    return out

# =========================
# PIPELINE
# =========================

def build_bubbles_from_reddit() -> List[BubbleItem]:
    collected: List[BubbleItem] = []
    for sub in SUBREDDITS:
        try:
            posts = fetch_hot_posts(sub)
        except Exception as e:
            print(f"[WARN] Falha ao buscar r/{sub}: {e}")
            continue

        posts = [p for p in posts if is_relevant(p.score, p.num_comments)]
        for p in posts:
            collected.append(
                BubbleItem(
                    id=f"reddit_{p.id}",
                    title=p.title,
                    source="reddit",
                    subreddit=p.subreddit,
                    permalink=p.permalink,
                    createdAt=datetime.fromtimestamp(p.created_utc, tz=timezone.utc).isoformat(),
                    rawScore=compute_raw_score(p.score, p.num_comments, p.created_utc),
                    image=p.image,
                )
            )
        time.sleep(SLEEP_BETWEEN_SUBS)
    return collected

def dedupe_bubbles(items: List[BubbleItem]) -> List[BubbleItem]:
    seen_permalink = set()
    seen_title = set()
    out: List[BubbleItem] = []
    for b in items:
        pk = safe_text(b.permalink)
        tk = norm_key(b.title)
        if pk and pk in seen_permalink:
            continue
        if tk and tk in seen_title:
            continue
        if pk:
            seen_permalink.add(pk)
        if tk:
            seen_title.add(tk)
        out.append(b)
    return out

def pick_representative(cluster: BubbleCluster) -> BubbleItem:
    # escolhe o item com maior relevanceScore; fallback rawScore
    best = sorted(cluster.items, key=lambda x: (x.relevanceScore, x.rawScore), reverse=True)[0]
    return best

def merge_cluster_comments(cluster: BubbleCluster) -> List[Dict[str, Any]]:
    """
    Agrega comentários de múltiplos posts do cluster para enriquecer melhor o “assunto”.
    Mantém cap e dedupe por texto.
    """
    # usa os melhores posts do cluster (maior score) para puxar comentários
    items_sorted = sorted(cluster.items, key=lambda x: x.rawScore, reverse=True)[:CLUSTER_MAX_POSTS_TO_MERGE]

    merged: List[Dict[str, Any]] = []
    seen_text = set()

    for it in items_sorted:
        try:
            post_id = it.id.replace("reddit_", "", 1)
            comments = fetch_top_comments(post_id, it.subreddit, MAX_COMMENTS_PER_POST)
        except Exception:
            comments = []

        # dedupe por texto normalizado
        for c in comments:
            t = norm_key(c.get("text", ""))
            if not t or t in seen_text:
                continue
            seen_text.add(t)
            merged.append(c)

        time.sleep(SLEEP_BETWEEN_POSTS_COMMENTS)

        if len(merged) >= CLUSTER_MAX_TOTAL_COMMENTS:
            break

    # ordena por score desc e limita
    merged.sort(key=lambda x: int(x.get("score", 0) or 0), reverse=True)
    return merged[:CLUSTER_MAX_TOTAL_COMMENTS]

def enrich_clusters(clusters: List[BubbleCluster]) -> List[BubbleItem]:
    """
    Enriquecemos 1 bolha por cluster (representante),
    mas o LLM recebe comentários agregados de vários posts daquele cluster.
    """
    out: List[BubbleItem] = []
    for idx, c in enumerate(clusters, start=1):
        rep = pick_representative(c)
        rep.image = select_cluster_image(c)

        print(f"({idx}/{len(clusters)}) Enriquecendo cluster: {rep.title[:80]}  |  posts={len(c.items)}")

        comments = []
        try:
            comments = merge_cluster_comments(c)
        except Exception as e:
            print(f"[WARN] Falha ao agregar comentários do cluster: {e}")
            comments = []

        try:
            result = generate_context_and_opinions(rep.title, rep.subreddit, comments)
        except Exception as e:
            print(f"[WARN] Falha OpenAI: {e}")
            result = {"title": "", "label": "", "context": "", "opinions": []}

        # aplica resultado ao representante
        if result.get("title"):
            rep.title = safe_text(result["title"])
        rep.label = safe_text(result.get("label", ""))
        rep.context = safe_text(result.get("context", ""))
        rep.opinions = result.get("opinions") or []

        out.append(rep)

    return out

def main():
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY não encontrada.")

    print("🔎 Coletando posts do Reddit...")
    bubbles = build_bubbles_from_reddit()
    bubbles = dedupe_bubbles(bubbles)

    if not bubbles:
        print("Nenhum post relevante encontrado.")
        return

    # normaliza scores em nível de post
    normalize_scores(bubbles)
    bubbles.sort(key=lambda x: x.relevanceScore, reverse=True)

    # clusteriza usando uma janela maior (melhor para reduzir repetição)
    # (não corta antes, para permitir formar clusters)
    print(f"🧩 Clusterizando {len(bubbles)} posts...")
    clusters = cluster_bubbles(bubbles)

    if not clusters:
        print("Nenhum cluster criado.")
        return

    # calcula relevanceScore do cluster por normalização do rawScore do cluster
    cluster_raws = [c.rawScore for c in clusters]
    mn = min(cluster_raws)
    mx = max(cluster_raws)
    for c in clusters:
        if mx - mn < 1e-9:
            c.relevanceScore = 0.5
        else:
            c.relevanceScore = (c.rawScore - mn) / (mx - mn)

    clusters.sort(key=lambda c: c.relevanceScore, reverse=True)
    top_clusters = clusters[:TOP_N]

    # monta a lista final de bolhas (representantes) com rank + radius baseados no cluster score
    reps: List[BubbleItem] = []
    for i, c in enumerate(top_clusters, start=1):
        rep = pick_representative(c)

        # rank e tamanho são do cluster (não do post individual)
        rep.rank = i
        rep.relevanceScore = c.relevanceScore
        rep.suggestedRadius = suggested_radius(rep.relevanceScore)
        reps.append(rep)

    print(f"✨ Enriquecendo TOP {len(reps)} clusters (1 bolha por cluster)...")
    reps = enrich_clusters(top_clusters)

    # garante rank/radius após enrich (caso rep tenha sido reusado internamente)
    for i, b in enumerate(reps, start=1):
        b.rank = i
        b.suggestedRadius = suggested_radius(b.relevanceScore)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(
            {
                "generatedAt": now_utc().isoformat(),
                "count": len(reps),
                "items": [
                    {
                        "id": b.id,
                        "rank": b.rank,
                        "title": b.title,
                        "label": b.label,
                        "context": b.context,
                        "source": b.source,
                        "subreddit": b.subreddit,
                        "permalink": b.permalink,
                        "createdAt": b.createdAt,
                        "rawScore": b.rawScore,
                        "relevanceScore": b.relevanceScore,
                        "suggestedRadius": b.suggestedRadius,
                        "imageUrl": b.image,
                        "opinions": b.opinions or [],
                    }
                    for b in reps
                ],
            },
            f,
            ensure_ascii=False,
            indent=2,
        )

    print("✅ bubbles_enriched.json gerado (títulos PT + cluster + agregação)")

if __name__ == "__main__":
    main()
