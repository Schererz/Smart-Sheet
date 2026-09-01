"""
Cliente mínimo da API do Telegram — só o necessário pra esse bot (mandar
mensagem de texto). Usa httpx puro em vez de uma lib de bot completa,
que traria muita coisa que a gente não precisa (polling, handlers,
state machine) pra um bot que só recebe via webhook e responde na hora.
"""
import os

import httpx

TELEGRAM_API_URL = "https://api.telegram.org/bot{token}/{metodo}"


def _token() -> str | None:
    return os.getenv("TELEGRAM_BOT_TOKEN")


async def enviar_mensagem(chat_id: str, texto: str) -> None:
    token = _token()
    if not token:
        return  # sem token configurado, não tem como responder — falha em silêncio
    url = TELEGRAM_API_URL.format(token=token, metodo="sendMessage")
    async with httpx.AsyncClient(timeout=10) as client:
        await client.post(url, json={"chat_id": chat_id, "text": texto})


async def baixar_arquivo(file_id: str) -> bytes | None:
    """Baixa um arquivo do Telegram (usado pra pegar o print que a pessoa
    manda quando não pode mais copiar texto do grupo). O Telegram entrega
    isso em duas etapas: primeiro pede o "caminho" do arquivo, depois
    baixa o conteúdo de verdade desse caminho."""
    token = _token()
    if not token:
        return None

    async with httpx.AsyncClient(timeout=15) as client:
        resposta = await client.get(
            TELEGRAM_API_URL.format(token=token, metodo="getFile"),
            params={"file_id": file_id},
        )
        if resposta.status_code >= 400:
            return None
        file_path = resposta.json().get("result", {}).get("file_path")
        if not file_path:
            return None

        url_arquivo = f"https://api.telegram.org/file/bot{token}/{file_path}"
        resposta_arquivo = await client.get(url_arquivo)
        if resposta_arquivo.status_code >= 400:
            return None
        return resposta_arquivo.content
