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
