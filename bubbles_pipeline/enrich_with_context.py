import json
import os
from typing import Dict

from openai import OpenAI

# =========================
# CONFIGURAÇÃO
# =========================

client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY")
)

INPUT_FILE = "bubbles.json"
OUTPUT_FILE = "bubbles_enriched.json"

MODEL = "gpt-4.1-mini"

# =========================
# PROMPTS
# =========================

SYSTEM_PROMPT = """
Você escreve contextos explicativos para um aplicativo que ajuda
pessoas comuns a entenderem assuntos em debate público.

O tom deve ser claro, acessível e informativo,
sem linguagem jornalística e sem assumir conhecimento prévio.
"""

USER_PROMPT_TEMPLATE = """
A partir do título abaixo, gere DUAS coisas em português,
usando EXATAMENTE este formato:

LABEL:
<texto curto>

CONTEXTO:
<parágrafo explicativo>

Regras para o CONTEXTO:
- Explique o que está acontecendo de forma clara e acessível
- Não use tom jornalístico ou manchetes
- Não presuma que o leitor conheça termos técnicos
- Quando um termo for essencial para entender o assunto,
  inclua uma breve explicação entre parênteses (3 a 6 palavras)
- Não explique tudo, apenas o necessário
- Tom neutro e factual
- No máximo 3 frases
- Não explique termos cujo significado já seja amplamente conhecido
- Evite explicações que introduzam causalidade social, moral ou política

Exemplos de explicação curta:
- Ozempic (medicamento para diabetes)
- Federal Reserve (banco central dos EUA)
- Hamas (grupo político-militar palestino)

Título original: "{title}"
Subreddit: {subreddit}
"""

# =========================
# FUNÇÕES
# =========================

def parse_structured_text(text: str) -> Dict[str, str]:
    label = ""
    context = ""

    lines = [line.strip() for line in text.splitlines() if line.strip()]

    current = None
    buffer = []

    for line in lines:
        if line.upper().startswith("LABEL:"):
            if current == "context":
                context = " ".join(buffer).strip()
                buffer = []
            current = "label"
            continue

        if line.upper().startswith("CONTEXTO:"):
            if current == "label":
                label = " ".join(buffer).strip()
                buffer = []
            current = "context"
            continue

        buffer.append(line)

    if current == "label":
        label = " ".join(buffer).strip()
    elif current == "context":
        context = " ".join(buffer).strip()

    return {
        "label": label,
        "context": context,
    }


def generate_label_and_context(title: str, subreddit: str) -> Dict[str, str]:
    response = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT.strip()},
            {
                "role": "user",
                "content": USER_PROMPT_TEMPLATE.format(
                    title=title,
                    subreddit=subreddit,
                ).strip(),
            },
        ],
        temperature=0.1,
        max_tokens=200,
    )

    raw = response.choices[0].message.content.strip()
    return parse_structured_text(raw)


def main():
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", [])
    enriched_items = []

    for i, item in enumerate(items, start=1):
        source_title = item.get("title", "")
        subreddit = item.get("subreddit", "reddit")

        print(f"({i}/{len(items)}) Processando: {source_title[:60]}")

        try:
            result = generate_label_and_context(source_title, subreddit)
            label = result["label"]
            context = result["context"]
        except Exception as e:
            print("❌ Erro ao gerar label/context:", e)
            label = ""
            context = ""

        new_item = dict(item)
        new_item["label"] = label
        new_item["context"] = context
        new_item["sourceTitle"] = source_title

        enriched_items.append(new_item)

    output = {
        "generatedAt": data.get("generatedAt"),
        "count": len(enriched_items),
        "items": enriched_items,
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Arquivo gerado com sucesso: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
