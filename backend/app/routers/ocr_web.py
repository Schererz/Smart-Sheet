"""
OCR via Google Cloud Vision — usado SÓ pela versão web do app.

No celular, o OCR roda local no aparelho (ML Kit), de graça e offline —
isso não muda. No navegador não existe equivalente ao ML Kit (é uma
biblioteca nativa Android/iOS), então a versão web manda a imagem pra cá,
a gente chama a Cloud Vision, e devolve os blocos de texto no MESMO
formato que o app já usa (schemas.BlocoOCR). Assim o resto do pipeline
(parsing.py, os parsers por casa) não precisa saber de onde veio o texto.

Precisa da variável de ambiente GOOGLE_VISION_API_KEY configurada (veja
o README pra como conseguir uma).
"""
import base64
import io
import os

import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile
from PIL import Image

from .schemas import BlocoOCR

router = APIRouter(prefix="/ocr", tags=["ocr"])

GOOGLE_VISION_URL = "https://vision.googleapis.com/v1/images:annotate"


@router.post("/ler-imagem", response_model=list[BlocoOCR])
async def ler_imagem(arquivo: UploadFile = File(...)):
    api_key = os.getenv("GOOGLE_VISION_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OCR do servidor não configurado (falta GOOGLE_VISION_API_KEY no backend).",
        )

    conteudo = await arquivo.read()
    imagem_base64 = base64.b64encode(conteudo).decode("utf-8")

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
        raise HTTPException(status_code=502, detail=f"Erro chamando a Google Vision: {resposta.text}")

    dados = resposta.json()
    anotacoes = dados.get("responses", [{}])[0].get("textAnnotations", [])
    if not anotacoes:
        return []

    # O primeiro item é o texto inteiro concatenado (não interessa aqui);
    # os itens seguintes são cada PALAVRA individual, com posição. A Cloud
    # Vision não agrupa em linhas como o ML Kit do celular faz — agrupamos
    # aqui pra manter o mesmo formato que os parsers por casa já esperam
    # (frases inteiras tipo "Valor da Aposta", não palavras soltas).
    larguraImg, alturaImg = Image.open(io.BytesIO(conteudo)).size
    linhas = _agrupar_palavras_em_linhas(anotacoes[1:])

    blocos = []
    for linha in linhas:
        blocos.append(
            BlocoOCR(
                texto=linha["texto"],
                x=linha["x_min"] / larguraImg if larguraImg else 0,
                y=linha["y_min"] / alturaImg if alturaImg else 0,
                largura=(linha["x_max"] - linha["x_min"]) / larguraImg if larguraImg else 0,
                altura=(linha["y_max"] - linha["y_min"]) / alturaImg if alturaImg else 0,
            )
        )
    return blocos


def _agrupar_palavras_em_linhas(anotacoes_palavras: list) -> list[dict]:
    """Agrupa palavras detectadas pela Cloud Vision em linhas, com base na
    proximidade vertical — palavras cujo centro Y está próximo o bastante
    (relativo à altura delas) são consideradas da mesma linha."""
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
        resultado.append({
            "texto": " ".join(p["texto"] for p in linha),
            "x_min": min(p["x_min"] for p in linha),
            "x_max": max(p["x_max"] for p in linha),
            "y_min": min(p["y_min"] for p in linha),
            "y_max": max(p["y_max"] for p in linha),
        })
    return resultado
