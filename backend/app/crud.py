from datetime import date, datetime, timedelta
import re
import secrets

from sqlalchemy.orm import Session
from sqlalchemy import func

from . import models, schemas


def obter_configuracao(db: Session, usuario_id: int) -> models.Configuracao:
    config = db.query(models.Configuracao).filter(models.Configuracao.usuario_id == usuario_id).first()
    if not config:
        config = models.Configuracao(usuario_id=usuario_id, banca_inicial=0.0, definida=False)
        db.add(config)
        db.commit()
        db.refresh(config)
    return config


def atualizar_banca_inicial(db: Session, usuario_id: int, valor: float) -> models.Configuracao:
    config = obter_configuracao(db, usuario_id)
    config.banca_inicial = valor
    config.definida = True
    db.commit()
    db.refresh(config)
    return config


def obter_evolucao_banca(db: Session, usuario_id: int):
    
    config = obter_configuracao(db, usuario_id)
    resolvidas = (
        db.query(models.Bet)
        .filter(
            models.Bet.usuario_id == usuario_id,
            models.Bet.resultado.in_([models.ResultadoAposta.green, models.ResultadoAposta.red]),
        )
        .order_by(models.Bet.data.asc(), models.Bet.id.asc())
        .all()
    )

    data_inicial = resolvidas[0].data if resolvidas else date.today()
    pontos = [{"data": data_inicial, "banca": config.banca_inicial, "descricao": "Banca inicial"}]

    acumulado = config.banca_inicial
    for aposta in resolvidas:
        acumulado += aposta.lucro or 0
        pontos.append({"data": aposta.data, "banca": round(acumulado, 2), "descricao": aposta.descricao})
    return pontos


def _chave_normalizada(nome: str) -> str:
    return re.sub(r'\s+', '', nome.strip().lower())


def canonicalizar_nome_casa(db: Session, usuario_id: int, nome_bruto: str) -> str:

    chave = _chave_normalizada(nome_bruto)
    casas = db.query(models.Casa).filter(models.Casa.usuario_id == usuario_id).all()
    for casa in casas:
        if _chave_normalizada(casa.nome) == chave:
            return casa.nome
    return nome_bruto.strip()


def criar_casa(db: Session, usuario_id: int, nome: str):
    nome_canonico = canonicalizar_nome_casa(db, usuario_id, nome)
    existente = (
        db.query(models.Casa)
        .filter(models.Casa.usuario_id == usuario_id, func.lower(models.Casa.nome) == nome_canonico.lower())
        .first()
    )
    if existente:
        return existente, False
    nova = models.Casa(usuario_id=usuario_id, nome=nome_canonico)
    db.add(nova)
    db.commit()
    db.refresh(nova)
    return nova, True


def listar_casas(db: Session, usuario_id: int):
    return (
        db.query(models.Casa)
        .filter(models.Casa.usuario_id == usuario_id)
        .order_by(models.Casa.vezes_usada.desc(), models.Casa.nome.asc())
        .all()
    )


def deletar_casa(db: Session, usuario_id: int, casa_id: int):
    casa = db.query(models.Casa).filter(models.Casa.id == casa_id, models.Casa.usuario_id == usuario_id).first()
    if not casa:
        return None
    db.delete(casa)
    db.commit()
    return casa


def atualizar_banca_casa(db: Session, usuario_id: int, casa_id: int, valor: float):
    casa = db.query(models.Casa).filter(models.Casa.id == casa_id, models.Casa.usuario_id == usuario_id).first()
    if not casa:
        return None
    casa.banca_inicial = valor
    db.commit()
    db.refresh(casa)
    return casa


def registrar_uso_casa(db: Session, usuario_id: int, nome: str):
    """Sobe o contador de uso da casa. Se por algum motivo a casa ainda não
    existir (app desatualizado, etc.), cria ela na hora — não trava o fluxo."""
    casa, _ = criar_casa(db, usuario_id, nome)
    casa.vezes_usada += 1
    db.commit()


def criar_aposta(db: Session, usuario_id: int, aposta: schemas.BetCreate):
    dados = aposta.model_dump()


    dados["casa_de_apostas"] = canonicalizar_nome_casa(db, usuario_id, dados["casa_de_apostas"])

    if dados.get("aumento_percentual"):
        dados["retorno_potencial"] = models.calcular_retorno_com_aumento(
            dados["valor_apostado"], dados["odd"], dados["aumento_percentual"]
        )
    if dados["resultado"] == models.ResultadoAposta.green and dados["retorno_potencial"] is None:
        dados["retorno_potencial"] = round(dados["valor_apostado"] * dados["odd"], 2)
    lucro = models.calcular_lucro(dados["valor_apostado"], dados["retorno_potencial"], dados["resultado"], dados["odd"])
    db_aposta = models.Bet(**dados, usuario_id=usuario_id, lucro=lucro)
    db.add(db_aposta)
    registrar_uso_casa(db, usuario_id, dados["casa_de_apostas"])
    db.commit()
    db.refresh(db_aposta)
    return db_aposta


def listar_apostas(db: Session, usuario_id: int, skip: int = 0, limit: int = 10_000):
    return (
        db.query(models.Bet)
        .filter(models.Bet.usuario_id == usuario_id)
        .order_by(models.Bet.data.desc(), models.Bet.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def obter_aposta(db: Session, usuario_id: int, aposta_id: int):
    return db.query(models.Bet).filter(models.Bet.id == aposta_id, models.Bet.usuario_id == usuario_id).first()


def atualizar_aposta(db: Session, usuario_id: int, aposta_id: int, aposta_update: schemas.BetUpdate):
    db_aposta = obter_aposta(db, usuario_id, aposta_id)
    if not db_aposta:
        return None

    dados = aposta_update.model_dump(exclude_unset=True)
    for campo, valor in dados.items():
        setattr(db_aposta, campo, valor)

    if db_aposta.aumento_percentual:
        db_aposta.retorno_potencial = models.calcular_retorno_com_aumento(
            db_aposta.valor_apostado, db_aposta.odd, db_aposta.aumento_percentual
        )
    if db_aposta.resultado == models.ResultadoAposta.green and db_aposta.retorno_potencial is None:
        db_aposta.retorno_potencial = round(db_aposta.valor_apostado * db_aposta.odd, 2)

    db_aposta.lucro = models.calcular_lucro(
        db_aposta.valor_apostado, db_aposta.retorno_potencial, db_aposta.resultado, db_aposta.odd
    )

    db.commit()
    db.refresh(db_aposta)
    return db_aposta


def ciclar_status(db: Session, usuario_id: int, aposta_id: int):
    """Avança o status da aposta: aberto -> green -> red -> aberto ..."""
    db_aposta = obter_aposta(db, usuario_id, aposta_id)
    if not db_aposta:
        return None

    db_aposta.resultado = models.proximo_status(db_aposta.resultado)
    if db_aposta.resultado == models.ResultadoAposta.green and db_aposta.retorno_potencial is None:
        db_aposta.retorno_potencial = round(db_aposta.valor_apostado * db_aposta.odd, 2)
    db_aposta.lucro = models.calcular_lucro(
        db_aposta.valor_apostado, db_aposta.retorno_potencial, db_aposta.resultado, db_aposta.odd
    )

    db.commit()
    db.refresh(db_aposta)
    return db_aposta


def deletar_aposta(db: Session, usuario_id: int, aposta_id: int):
    db_aposta = obter_aposta(db, usuario_id, aposta_id)
    if not db_aposta:
        return None
    db.delete(db_aposta)
    db.commit()
    return db_aposta


def deletar_todas_apostas(db: Session, usuario_id: int) -> int:

    apagadas = db.query(models.Bet).filter(models.Bet.usuario_id == usuario_id).delete()
    db.commit()
    return apagadas


def obter_dataset_treino(db: Session, usuario_id: int, casa: str | None = None):
    
    query = db.query(models.Bet).filter(
        models.Bet.usuario_id == usuario_id,
        models.Bet.origem == models.OrigemRegistro.ocr,
        models.Bet.blocos_ocr.isnot(None),
    )
    if casa:
        query = query.filter(models.Bet.casa_de_apostas == casa)

    exemplos = []
    for aposta in query.all():
        exemplos.append({
            "casa": aposta.casa_de_apostas,
            "blocos_ocr": aposta.blocos_ocr,
            "sugestao_original": aposta.sugestao_original,
            "valores_corretos": {
                "odd": aposta.odd,
                "valor_apostado": aposta.valor_apostado,
                "retorno_potencial": aposta.retorno_potencial,
                "descricao": aposta.descricao,
            },
        })
    return exemplos


def calcular_resumo(db: Session, usuario_id: int) -> dict:
    base = db.query(models.Bet).filter(models.Bet.usuario_id == usuario_id)

    total_apostas = base.count()
    total_apostado = db.query(func.sum(models.Bet.valor_apostado)).filter(models.Bet.usuario_id == usuario_id).scalar() or 0.0
    lucro_total = db.query(func.sum(models.Bet.lucro)).filter(models.Bet.usuario_id == usuario_id).scalar() or 0.0
    odd_media = db.query(func.avg(models.Bet.odd)).filter(models.Bet.usuario_id == usuario_id).scalar()
    valor_medio_apostado = db.query(func.avg(models.Bet.valor_apostado)).filter(models.Bet.usuario_id == usuario_id).scalar()
    maior_lucro = db.query(func.max(models.Bet.lucro)).filter(models.Bet.usuario_id == usuario_id).scalar()
    maior_prejuizo = db.query(func.min(models.Bet.lucro)).filter(models.Bet.usuario_id == usuario_id).scalar()
    apostas_em_aberto = base.filter(models.Bet.resultado == models.ResultadoAposta.aberto).count()

    resolvidas = base.filter(models.Bet.resultado.in_([models.ResultadoAposta.green, models.ResultadoAposta.red])).all()
    ganhas = sum(1 for a in resolvidas if a.resultado == models.ResultadoAposta.green)
    taxa_acerto = round(100 * ganhas / len(resolvidas), 1) if resolvidas else None
    roi = round(100 * lucro_total / total_apostado, 1) if total_apostado else None

    config = obter_configuracao(db, usuario_id)

    return {
        "total_apostas": total_apostas,
        "total_apostado": round(total_apostado, 2),
        "lucro_total": round(lucro_total, 2),
        "taxa_acerto": taxa_acerto,
        "roi": roi,
        "banca_inicial": config.banca_inicial,
        "banca_atual": round(config.banca_inicial + lucro_total, 2),
        "odd_media": round(odd_media, 2) if odd_media else None,
        "valor_medio_apostado": round(valor_medio_apostado, 2) if valor_medio_apostado else None,
        "maior_lucro": round(maior_lucro, 2) if maior_lucro is not None and maior_lucro > 0 else None,
        "maior_prejuizo": round(maior_prejuizo, 2) if maior_prejuizo is not None and maior_prejuizo < 0 else None,
        "apostas_em_aberto": apostas_em_aberto,
    }


def obter_resumo_por_casa(db: Session, usuario_id: int) -> list[dict]:
    """Estatísticas separadas por casa — pra comparar qual está indo melhor."""
    casas = listar_casas(db, usuario_id)
    resultado = []

    for casa in casas:
        apostas_da_casa = (
            db.query(models.Bet)
            .filter(models.Bet.usuario_id == usuario_id, models.Bet.casa_de_apostas == casa.nome)
            .all()
        )
        if not apostas_da_casa:
            continue  # casa cadastrada mas sem apostas ainda — não mostra no resumo

        total_apostas = len(apostas_da_casa)
        total_apostado = sum(a.valor_apostado for a in apostas_da_casa)
        lucro_total = sum(a.lucro or 0 for a in apostas_da_casa if a.lucro is not None)
        odd_media = sum(a.odd for a in apostas_da_casa) / total_apostas

        resolvidas = [a for a in apostas_da_casa if a.resultado in (models.ResultadoAposta.green, models.ResultadoAposta.red)]
        ganhas = sum(1 for a in resolvidas if a.resultado == models.ResultadoAposta.green)
        taxa_acerto = round(100 * ganhas / len(resolvidas), 1) if resolvidas else None
        roi_apostado = round(100 * lucro_total / total_apostado, 1) if total_apostado else None

        banca_atual = round(casa.banca_inicial + lucro_total, 2) if casa.banca_inicial is not None else None
        roi_banca = (
            round(100 * lucro_total / casa.banca_inicial, 1)
            if casa.banca_inicial else None
        )

        resultado.append({
            "casa": casa.nome,
            "total_apostas": total_apostas,
            "total_apostado": round(total_apostado, 2),
            "lucro_total": round(lucro_total, 2),
            "taxa_acerto": taxa_acerto,
            "odd_media": round(odd_media, 2),
            "roi_apostado": roi_apostado,
            "banca_inicial": casa.banca_inicial,
            "banca_atual": banca_atual,
            "roi_banca": roi_banca,
        })

    # mais lucrativa primeiro
    resultado.sort(key=lambda r: r["lucro_total"], reverse=True)
    return resultado


def obter_lucro_por_dia(db: Session, usuario_id: int) -> list[dict]:
    
    apostas = (
        db.query(models.Bet)
        .filter(
            models.Bet.usuario_id == usuario_id,
            models.Bet.resultado.in_([models.ResultadoAposta.green, models.ResultadoAposta.red]),
        )
        .order_by(models.Bet.data.asc())
        .all()
    )

    por_dia: dict = {}
    for aposta in apostas:
        chave = aposta.data
        if chave not in por_dia:
            por_dia[chave] = {"lucro": 0.0, "total_apostas": 0}
        por_dia[chave]["lucro"] += aposta.lucro or 0
        por_dia[chave]["total_apostas"] += 1

    return [
        {"data": dia, "lucro": round(dados["lucro"], 2), "total_apostas": dados["total_apostas"]}
        for dia, dados in sorted(por_dia.items())
    ]


# ---------------- Vínculo com o bot do Telegram ----------------

def gerar_codigo_vinculo_telegram(db: Session, usuario_id: int) -> tuple[str, datetime]:

    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    codigo = f"{secrets.randbelow(1_000_000):06d}"
    expira_em = datetime.utcnow() + timedelta(minutes=10)
    usuario.telegram_codigo_vinculo = codigo
    usuario.telegram_codigo_expira_em = expira_em
    db.commit()
    return codigo, expira_em


def status_telegram(db: Session, usuario_id: int) -> bool:
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    return usuario.telegram_chat_id is not None


def desconectar_telegram(db: Session, usuario_id: int) -> None:
    usuario = db.query(models.Usuario).filter(models.Usuario.id == usuario_id).first()
    usuario.telegram_chat_id = None
    usuario.telegram_codigo_vinculo = None
    usuario.telegram_codigo_expira_em = None
    db.commit()


def vincular_telegram_por_codigo(db: Session, codigo: str, chat_id: str) -> models.Usuario | None:

    usuario = db.query(models.Usuario).filter(models.Usuario.telegram_codigo_vinculo == codigo).first()
    if not usuario or not usuario.telegram_codigo_expira_em:
        return None
    if usuario.telegram_codigo_expira_em < datetime.utcnow():
        return None
    usuario.telegram_chat_id = str(chat_id)
    usuario.telegram_codigo_vinculo = None
    usuario.telegram_codigo_expira_em = None
    db.commit()
    return usuario


def obter_usuario_por_chat_id(db: Session, chat_id) -> models.Usuario | None:
    return db.query(models.Usuario).filter(models.Usuario.telegram_chat_id == str(chat_id)).first()


def criar_movimentacao(db: Session, usuario_id: int, movimentacao: schemas.MovimentacaoCreate):
    casa = db.query(models.Casa).filter(
        models.Casa.id == movimentacao.casa_id, models.Casa.usuario_id == usuario_id
    ).first()
    if not casa:
        return None

    nova = models.MovimentacaoCasa(
        usuario_id=usuario_id,
        casa_id=movimentacao.casa_id,
        tipo=movimentacao.tipo,
        valor=movimentacao.valor,
        data=movimentacao.data,
    )
    db.add(nova)
    db.commit()
    db.refresh(nova)
    return nova


def listar_movimentacoes(
    db: Session,
    usuario_id: int,
    casa_id: int | None = None,
    data_inicio=None,
    data_fim=None,
):
    query = db.query(models.MovimentacaoCasa).filter(models.MovimentacaoCasa.usuario_id == usuario_id)
    if casa_id is not None:
        query = query.filter(models.MovimentacaoCasa.casa_id == casa_id)
    if data_inicio is not None:
        query = query.filter(models.MovimentacaoCasa.data >= data_inicio)
    if data_fim is not None:
        query = query.filter(models.MovimentacaoCasa.data <= data_fim)
    return query.order_by(models.MovimentacaoCasa.data.desc(), models.MovimentacaoCasa.id.desc()).all()


def deletar_movimentacao(db: Session, usuario_id: int, movimentacao_id: int):
    mov = db.query(models.MovimentacaoCasa).filter(
        models.MovimentacaoCasa.id == movimentacao_id, models.MovimentacaoCasa.usuario_id == usuario_id
    ).first()
    if not mov:
        return None
    db.delete(mov)
    db.commit()
    return mov


def calcular_banca_por_localizacao(db: Session, usuario_id: int) -> dict:
    """Divide a banca atual (mesma conta de sempre: banca_inicial + lucro
    total) entre "quanto está em cada casa" e "quanto está fora, disponível
    pra depositar". Saldo de cada casa = depósitos - saques + lucro das
    apostas daquela casa. O "banco" é sempre o que sobra — por construção,
    banco + soma das casas sempre bate com a banca atual total."""
    resumo_geral = calcular_resumo(db, usuario_id)
    banca_atual_global = resumo_geral["banca_atual"]

    casas = listar_casas(db, usuario_id)
    resultado_casas = []
    total_alocado = 0.0

    for casa in casas:
        depositos = (
            db.query(func.sum(models.MovimentacaoCasa.valor))
            .filter(
                models.MovimentacaoCasa.usuario_id == usuario_id,
                models.MovimentacaoCasa.casa_id == casa.id,
                models.MovimentacaoCasa.tipo == models.TipoMovimentacao.deposito,
            )
            .scalar() or 0.0
        )
        saques = (
            db.query(func.sum(models.MovimentacaoCasa.valor))
            .filter(
                models.MovimentacaoCasa.usuario_id == usuario_id,
                models.MovimentacaoCasa.casa_id == casa.id,
                models.MovimentacaoCasa.tipo == models.TipoMovimentacao.saque,
            )
            .scalar() or 0.0
        )
        lucro_casa = (
            db.query(func.sum(models.Bet.lucro))
            .filter(models.Bet.usuario_id == usuario_id, models.Bet.casa_de_apostas == casa.nome)
            .scalar() or 0.0
        )

        saldo = depositos - saques + lucro_casa
        if depositos or saques or lucro_casa:  # só mostra casas com alguma movimentação/aposta
            total_alocado += saldo
            resultado_casas.append({"casa": casa.nome, "valor": round(saldo, 2)})

    banco = round(banca_atual_global - total_alocado, 2)

    return {
        "banco": banco,
        "casas": resultado_casas,
        "total": round(banca_atual_global, 2),
    }

