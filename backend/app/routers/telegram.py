"""
Integração com o Telegram.

Fluxo de vínculo:
1. Usuário logado no app pede um código (POST /telegram/gerar-codigo)
2. Manda esse código pro bot no Telegram
3. O webhook recebe a mensagem, reconhece o código, vincula o chat_id
   à conta do usuário

Depois de vinculado, toda mensagem que bater no formato esperado (ver
telegram_parsing.py) vira uma aposta automaticamente, com status "Aberto".
"""
import os
import re
from datetime import date

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual
from ..telegram_client import enviar_mensagem
from ..telegram_parsing import calcular_valor_apostado, parsear_mensagem

router = APIRouter(prefix="/telegram", tags=["telegram"])


@router.post("/gerar-codigo")
def gerar_codigo(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    codigo, expira_em = crud.gerar_codigo_vinculo_telegram(db, usuario.id)
    return {"codigo": codigo, "expira_em": expira_em}


@router.get("/status")
def status(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return {"conectado": crud.status_telegram(db, usuario.id)}


@router.post("/desconectar")
def desconectar(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    crud.desconectar_telegram(db, usuario.id)
    return {"ok": True}


@router.post("/webhook")
async def webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_telegram_bot_api_secret_token: str | None = Header(None),
):
    """Chamado pelo próprio Telegram a cada mensagem nova (configurado via
    setWebhook — veja o README). Confere o token secreto pra garantir que
    a chamada é mesmo do Telegram, não de qualquer um que descobrir a URL."""
    segredo_esperado = os.getenv("TELEGRAM_WEBHOOK_SECRET")
    if segredo_esperado and x_telegram_bot_api_secret_token != segredo_esperado:
        raise HTTPException(status_code=403, detail="Token de webhook inválido")

    corpo = await request.json()
    mensagem = corpo.get("message") or corpo.get("edited_message")
    if not mensagem:
        return {"ok": True}  # outros tipos de update (callback, etc) — ignora

    chat_id = mensagem.get("chat", {}).get("id")
    texto = (mensagem.get("text") or mensagem.get("caption") or "").strip()
    if not chat_id or not texto:
        return {"ok": True}

    usuario = crud.obter_usuario_por_chat_id(db, chat_id)

    if not usuario:
        await _tentar_vincular(db, chat_id, texto)
        return {"ok": True}

    await _processar_aposta(db, usuario, chat_id, texto)
    return {"ok": True}


async def _tentar_vincular(db: Session, chat_id, texto: str) -> None:
    codigo_digitado = re.sub(r"\D", "", texto)
    if len(codigo_digitado) != 6:
        await enviar_mensagem(
            chat_id,
            "Oi! Pra conectar sua conta, gera um código no app "
            "(Dashboard → ícone de conta → Conectar Telegram) e manda ele aqui.",
        )
        return

    usuario = crud.vincular_telegram_por_codigo(db, codigo_digitado, chat_id)
    if usuario:
        await enviar_mensagem(
            chat_id,
            f"✅ Conectado à conta {usuario.nome_usuario}! Agora é só encaminhar "
            "as apostas aqui que elas entram sozinhas.",
        )
    else:
        await enviar_mensagem(
            chat_id,
            "❌ Código inválido ou expirado. Gera um novo no app (ele vale por 10 minutos).",
        )


async def _processar_aposta(db: Session, usuario: models.Usuario, chat_id, texto: str) -> None:
    aposta = parsear_mensagem(texto)
    if not aposta.completa:
        faltando = ", ".join(aposta.campos_faltando())
        await enviar_mensagem(chat_id, f"Não consegui entender essa mensagem — faltou: {faltando}.")
        return

    config = crud.obter_configuracao(db, usuario.id)
    if not config.definida:
        await enviar_mensagem(
            chat_id,
            "Você ainda não definiu a banca inicial no app — sem ela não dá "
            "pra calcular quanto apostar.",
        )
        return

    valor = calcular_valor_apostado(aposta.percentual, config.banca_inicial)
    retorno = round(valor * aposta.odd, 2)

    nova_aposta = schemas.BetCreate(
        data=date.today(),
        casa_de_apostas=aposta.casa,
        descricao=aposta.descricao,
        odd=aposta.odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        origem=schemas.OrigemRegistro.telegram,
    )
    crud.criar_aposta(db, usuario.id, nova_aposta)

    await enviar_mensagem(
        chat_id,
        "✅ Aposta registrada!\n"
        f"🏠 {aposta.casa}\n"
        f"📝 {aposta.descricao}\n"
        f"🏷️ Odd {aposta.odd}\n"
        f"💰 R$ {valor:.2f} ({aposta.percentual}% da banca)\n"
        f"🎯 Retorno potencial: R$ {retorno:.2f}",
    )
