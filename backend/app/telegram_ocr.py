"""
OCR usado pelo bot do Telegram — quando o grupo bloqueia copiar/encaminhar
texto, a pessoa manda um PRINT em vez de colar a mensagem. Aqui a gente lê
esse print (via Google Cloud Vision, a mesma API já usada na versão web
do app) e devolve o texto pronto pra passar pelo parser normal
(telegram_parsing.parsear_mensagem), como se tivesse sido digitado.
"""
import base64
import io
import os

import httpx
from PIL import Image

GOOGLE_VISION_URL = "https://vision.googleapis.com/v1/images:annotate"


def _agrupar_palavras_em_linhas(anotacoes_palavras: list) -> list[dict]:
    """Agrupa palavras detectadas pela Cloud Vision em linhas, com base na
    proximidade vertical — mesma lógica usada em ocr_web.py."""
    palavras = []
    for item in anotacoes_palavras:
        vertices = item.get("boundingPoly", {}).get("vertices", [])
        if len(vertices) < 4:
            continue
        xs = [v.get("x", 0) for v in vertices]
        ys = [v.get("y", 0) for v in vertices]
        palavras.append({
            "texto": item.get("description", ""),
            "x_min": min(xs), "x_max": max(xs),
            "y_min": min(ys), "y_max": max(ys),
            "y_centro": (min(ys) + max(ys)) / 2,
        })
    palavras.sort(key=lambda p: (p["y_centro"], p["x_min"]))

    linhas: list[list[dict]] = []
    for palavra in palavras:
        colocada = False
        for linha in linhas:
            altura_media = sum(p["y_max"] - p["y_min"] for p in linha) / len(linha)
            y_centro_linha = sum(p["y_centro"] for p in linha) / len(linha)
            if abs(palavra["y_centro"] - y_centro_linha) < max(altura_media * 0.6, 1):
                linha.append(palavra)
                colocada = True
                break
        if not colocada:
            linhas.append([palavra])

    linhas.sort(key=lambda linha: sum(p["y_centro"] for p in linha) / len(linha))

    resultado = []
    for linha in linhas:
        linha.sort(key=lambda p: p["x_min"])
        resultado.append({"texto": " ".join(p["texto"] for p in linha)})
    return resultado


async def ler_texto_da_imagem(imagem_bytes: bytes) -> str | None:
    """Manda a imagem pra Cloud Vision e devolve o texto já organizado em
    linhas (join com \\n) — ou None se não conseguir ler (sem chave
    configurada, erro na API, ou nenhum texto detectado)."""
    api_key = os.getenv("GOOGLE_VISION_API_KEY")
    if not api_key:
        return None

    try:
        Image.open(io.BytesIO(imagem_bytes)).verify()  # confirma que é uma imagem válida
    except Exception:
        return None

    imagem_base64 = base64.b64encode(imagem_bytes).decode("utf-8")
    corpo_requisicao = {
        "requests": [
            {
                "image": {"content": imagem_base64},
                "features": [{"type": "TEXT_DETECTION"}],
            }
        ]
    }

    async with httpx.AsyncClient(timeout=30) as client:
        resposta = await client.post(f"{GOOGLE_VISION_URL}?key={api_key}", json=corpo_requisicao)

    if resposta.status_code >= 400:
        return None

    dados = resposta.json()
    anotacoes = dados.get("responses", [{}])[0].get("textAnnotations", [])
    if not anotacoes:
        return None

    linhas = _agrupar_palavras_em_linhas(anotacoes[1:])  # [0] é o texto inteiro concatenado, não interessa aqui
    if not linhas:
        return None

    return "\n".join(l["texto"] for l in linhas)
