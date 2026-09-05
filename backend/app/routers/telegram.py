"""
Integração com o Telegram.

Fluxo de vínculo:
1. Usuário logado no app pede um código (POST /telegram/gerar-codigo)
2. Manda esse código pro bot no Telegram
3. O webhook recebe a mensagem, reconhece o código, vincula o chat_id
   à conta do usuário

Depois de vinculado, toda mensagem que bater no formato esperado (ver
telegram_parsing.py — dois formatos suportados, podem até vir colados
juntos numa mensagem só) vira uma aposta automaticamente, com status
"Aberto".

Se o grupo de origem bloquear copiar/encaminhar texto, a pessoa pode
mandar um PRINT em vez de colar a mensagem — nesse caso a gente lê o
texto da imagem via OCR (telegram_ocr.py) antes de passar pelo parser,
exatamente como se tivesse sido digitado.
"""
import os
import re
from datetime import date

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual
from ..telegram_client import baixar_arquivo, enviar_mensagem
from ..telegram_ocr import ler_texto_da_imagem
from ..telegram_parsing import calcular_valor_apostado, calcular_valor_por_unidades, parsear_mensagem

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
    if not chat_id:
        return {"ok": True}

    usuario = crud.obter_usuario_por_chat_id(db, chat_id)
    texto = (mensagem.get("text") or mensagem.get("caption") or "").strip()

    # Se não veio texto mas veio uma FOTO (print do bilhete, usado quando o
    # grupo de origem bloqueia copiar/encaminhar), lê o texto por OCR.
    # Só faz isso pra quem já está vinculado — o código de vínculo sempre
    # vem digitado, nunca por print.
    fotos = mensagem.get("photo")
    if not texto and fotos and usuario:
        await enviar_mensagem(chat_id, "🔎 Lendo o print...")
        file_id = fotos[-1]["file_id"]  # a última da lista é a de maior resolução
        imagem_bytes = await baixar_arquivo(file_id)
        texto_lido = await ler_texto_da_imagem(imagem_bytes) if imagem_bytes else None
        if texto_lido:
            texto = texto_lido
        else:
            await enviar_mensagem(
                chat_id,
                "Não consegui ler o texto dessa imagem — tenta um print mais "
                "nítido, ou digita/cola os campos manualmente.",
            )
            return {"ok": True}

    if not texto:
        return {"ok": True}

    if not usuario:
        await _tentar_vincular(db, chat_id, texto)
        return {"ok": True}

    if await _tentar_comando_configuracao(db, usuario, chat_id, texto):
        return {"ok": True}

    await _processar_aposta(db, usuario, chat_id, texto)
    return {"ok": True}


PADRAO_COMANDO_PERCENTUAL = re.compile(r'^%\s*=\s*(\d+(?:[.,]\d+)?)$')
PADRAO_COMANDO_UNIDADE = re.compile(r'^unidade\s*=\s*(\d+(?:[.,]\d+)?)$', re.IGNORECASE)


async def _tentar_comando_configuracao(db: Session, usuario: models.Usuario, chat_id, texto: str) -> bool:
    """Comandos de configuração mandados direto no chat, sem precisar
    abrir o app:
      "% = 20"      -> define a banca de forma que 1% dela valha esse
                       tanto (ex: "% = 20" quer dizer 1% = R$20, então a
                       banca vira R$2000)
      "Unidade = 4" -> muda quanto vale 1 unidade (tipster Props),
                       daqui pra frente

    Devolve True se a mensagem era um desses comandos (e já tratou tudo),
    False se não era — nesse caso o chamador segue tentando interpretar
    como aposta normalmente."""
    texto_limpo = texto.strip()

    m_pct = PADRAO_COMANDO_PERCENTUAL.match(texto_limpo)
    if m_pct:
        valor_pct = float(m_pct.group(1).replace(",", "."))
        nova_banca = round(valor_pct * 100, 2)
        crud.atualizar_banca_inicial(db, usuario.id, nova_banca)
        await enviar_mensagem(
            chat_id,
            f"✅ Banca atualizada! 1% = R$ {valor_pct:.2f} → banca definida em R$ {nova_banca:.2f}.",
        )
        return True

    m_un = PADRAO_COMANDO_UNIDADE.match(texto_limpo)
    if m_un:
        novo_valor = float(m_un.group(1).replace(",", "."))
        crud.atualizar_valor_por_unidade(db, usuario.id, novo_valor)
        await enviar_mensagem(
            chat_id,
            f"✅ Unidade atualizada! A partir de agora, 1u = R$ {novo_valor:.2f}.",
        )
        return True

    return False


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
            "as apostas aqui (ou mandar um print, se não der pra copiar texto) "
            "que elas entram sozinhas.",
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

    if aposta.unidades is not None:
        # tipster Props: valor fixo por unidade (configurável por comando
        # "Unidade = X", padrão R$5), não depende da banca — mas ainda
        # respeita o limite, se a mensagem trouxer um
        config = crud.obter_configuracao(db, usuario.id)
        valor_unidade = config.valor_por_unidade
        valor = calcular_valor_por_unidades(aposta.unidades, aposta.limite, valor_unidade)
        retorno = aposta.retorno_direto if aposta.retorno_direto is not None else round(valor * aposta.odd, 2)
        aviso_limite = ""
        valor_sem_limite = round(aposta.unidades * valor_unidade, 2)
        if aposta.limite is not None and valor_sem_limite > aposta.limite:
            aviso_limite = f" (seria R$ {valor_sem_limite:.2f}, mas o limite da aposta é R$ {aposta.limite:.2f})"
    elif aposta.valor_direto is not None:
        # a mensagem já trouxe o valor calculado (ex: formato de outro bot
        # que já faz essa conta usando a sua própria banca) — usa direto,
        # só aplicando o limite (se tiver) como teto de segurança
        valor = aposta.valor_direto
        if aposta.limite is not None:
            valor = min(valor, aposta.limite)
        retorno = aposta.retorno_direto if aposta.retorno_direto is not None else round(valor * aposta.odd, 2)
        aviso_limite = ""
    else:
        config = crud.obter_configuracao(db, usuario.id)
        if not config.definida:
            await enviar_mensagem(
                chat_id,
                "Você ainda não definiu a banca inicial no app — sem ela não dá "
                "pra calcular quanto apostar.",
            )
            return
        valor = calcular_valor_apostado(aposta.percentual, config.banca_inicial, aposta.limite)
        retorno = round(valor * aposta.odd, 2)

        valor_sem_limite = round(config.banca_inicial * aposta.percentual / 100, 2)
        aviso_limite = ""
        if aposta.limite is not None and valor_sem_limite > aposta.limite:
            aviso_limite = f" (seria R$ {valor_sem_limite:.2f}, mas o limite da aposta é R$ {aposta.limite:.2f})"

    nova_aposta = schemas.BetCreate(
        data=date.today(),
        casa_de_apostas=aposta.casa,
        descricao=aposta.descricao,
        odd=aposta.odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        tipster=aposta.tipster,
        origem=schemas.OrigemRegistro.telegram,
    )
    crud.criar_aposta(db, usuario.id, nova_aposta)

    detalhe_valor = ""
    if aposta.unidades is not None:
        detalhe_valor = f" ({aposta.unidades}u)"
    elif aposta.percentual is not None and aposta.valor_direto is None:
        detalhe_valor = f" ({aposta.percentual}% da banca)"

    await enviar_mensagem(
        chat_id,
        "✅ Aposta registrada!\n"
        f"🎙️ Tipster: {aposta.tipster}\n"
        f"🏠 {aposta.casa}\n"
        f"📝 {aposta.descricao}\n"
        f"🏷️ Odd {aposta.odd}\n"
        f"💰 R$ {valor:.2f}{detalhe_valor}{aviso_limite}\n"
        f"🎯 Retorno potencial: R$ {retorno:.2f}",
    )
