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


# ---------------- Unidade ----------------

def _calcular_unidade(banca: float) -> float:
    return round(banca / 100, 2)


def obter_status_unidade(db: Session, usuario_id: int) -> dict:
    config = obter_configuracao(db, usuario_id)
    resumo = calcular_resumo(db, usuario_id)
    banca_atual = resumo["banca_atual"]

    proxima_data = None
    pendente = False
    if config.data_ultimo_recalculo_unidade is not None:
        proxima_data = config.data_ultimo_recalculo_unidade + timedelta(days=config.intervalo_recalculo_dias)
        pendente = date.today() >= proxima_data
    else:
        pendente = True  # nunca foi calculada ainda

    return {
        "unidade_atual": config.unidade_atual,
        "data_ultimo_recalculo": config.data_ultimo_recalculo_unidade,
        "intervalo_dias": config.intervalo_recalculo_dias,
        "proxima_data_recalculo": proxima_data,
        "recalculo_pendente": pendente,
        "unidade_se_recalcular_agora": _calcular_unidade(banca_atual),
    }


def recalcular_unidade(db: Session, usuario_id: int) -> dict:
    config = obter_configuracao(db, usuario_id)
    resumo = calcular_resumo(db, usuario_id)
    config.unidade_atual = _calcular_unidade(resumo["banca_atual"])
    config.data_ultimo_recalculo_unidade = date.today()
    db.commit()
    return obter_status_unidade(db, usuario_id)


def definir_intervalo_unidade(db: Session, usuario_id: int, dias: int) -> dict:
    config = obter_configuracao(db, usuario_id)
    config.intervalo_recalculo_dias = dias
    db.commit()
    return obter_status_unidade(db, usuario_id)


# ---------------- Sugestão de depósito ----------------

def _arredondar_50(valor: float) -> float:
    return round(valor / 50) * 50


def _arredondar_10_baixo(valor: float) -> float:
    import math
    return math.floor(valor / 10) * 10


def calcular_sugestao_deposito(
    db: Session,
    usuario_id: int,
    banca_total_mes: float,
    dias_periodo: int = 30,
    fator_retencao: float = 0.7,
    valor_minimo: float = 50,
    valor_maximo: float = 300,
) -> dict:
    """Reproduz o método que o usuário já usava manualmente na planilha:
    cada casa recebe uma fatia da banca do próximo período PROPORCIONAL
    à participação dela no lucro total (só contam as casas que deram
    lucro positivo) — multiplicada por um fator de retenção (ex: 70%),
    porque a ideia é depositar um pouco MENOS que a participação de
    lucro, deixando uma folga guardada como reserva. Casas que
    participaram mas não lucraram recebem só o mínimo. Tudo é limitado
    entre um piso e um teto (nenhuma casa fica muito subfinanciada nem
    concentra demais)."""
    data_corte = date.today() - timedelta(days=dias_periodo)

    apostas = (
        db.query(models.Bet)
        .filter(models.Bet.usuario_id == usuario_id, models.Bet.data >= data_corte)
        .all()
    )

    lucro_por_casa: dict[str, float] = {}
    for aposta in apostas:
        lucro_por_casa[aposta.casa_de_apostas] = lucro_por_casa.get(aposta.casa_de_apostas, 0.0) + (aposta.lucro or 0.0)

    casas_com_atividade = list(lucro_por_casa.keys())
    if not casas_com_atividade:
        return {
            "sugestoes": [],
            "banco_sugerido": round(banca_total_mes, 2),
            "nova_unidade_sugerida": _calcular_unidade(banca_total_mes),
            "banca_insuficiente_para_minimos": False,
        }

    lucro_total_positivo = sum(l for l in lucro_por_casa.values() if l > 0)

    brutos: dict[str, float] = {}
    participacoes: dict[str, float] = {}
    for casa in casas_com_atividade:
        lucro = lucro_por_casa[casa]
        if lucro > 0 and lucro_total_positivo > 0:
            participacao = lucro / lucro_total_positivo
            bruto = banca_total_mes * participacao * fator_retencao
        else:
            participacao = 0.0
            bruto = valor_minimo
        participacoes[casa] = round(participacao * 100, 1)
        brutos[casa] = max(valor_minimo, min(valor_maximo, _arredondar_50(bruto)))

    soma = sum(brutos.values())
    banca_insuficiente = False
    if soma > banca_total_mes:
        fator = banca_total_mes / soma
        # na redução de emergência, arredonda mais fino (10 em vez de 50)
        # e pra baixo — nesse cenário extremo pode não dar pra garantir
        # o mínimo pra todo mundo, e isso fica sinalizado na resposta
        brutos = {c: max(0.0, _arredondar_10_baixo(v * fator)) for c, v in brutos.items()}
        banca_insuficiente = True

    banco_sugerido = round(banca_total_mes - sum(brutos.values()), 2)

    itens = [
        {
            "casa": casa,
            "lucro_periodo": round(lucro_por_casa[casa], 2),
            "participacao_pct": participacoes[casa],
            "sugerido": brutos[casa],
        }
        for casa in sorted(brutos, key=lambda c: brutos[c], reverse=True)
    ]

    return {
        "sugestoes": itens,
        "banco_sugerido": banco_sugerido,
        "nova_unidade_sugerida": _calcular_unidade(banca_total_mes),
        "banca_insuficiente_para_minimos": banca_insuficiente,
    }


# ---------------- Ciclos mensais ----------------

MESES_PT = {
    1: "Janeiro", 2: "Fevereiro", 3: "Março", 4: "Abril", 5: "Maio", 6: "Junho",
    7: "Julho", 8: "Agosto", 9: "Setembro", 10: "Outubro", 11: "Novembro", 12: "Dezembro",
}


def obter_modo_mensal(db: Session, usuario_id: int) -> bool:
    config = obter_configuracao(db, usuario_id)
    return config.modo_mensal_ativado


def definir_modo_mensal(db: Session, usuario_id: int, ativado: bool) -> bool:
    config = obter_configuracao(db, usuario_id)
    config.modo_mensal_ativado = ativado
    db.commit()
    return ativado


def obter_ciclo_atual(db: Session, usuario_id: int) -> models.CicloMensal | None:
    return (
        db.query(models.CicloMensal)
        .filter(models.CicloMensal.usuario_id == usuario_id, models.CicloMensal.data_fim.is_(None))
        .first()
    )


def listar_ciclos(db: Session, usuario_id: int) -> list[models.CicloMensal]:
    return (
        db.query(models.CicloMensal)
        .filter(models.CicloMensal.usuario_id == usuario_id)
        .order_by(models.CicloMensal.data_inicio.desc())
        .all()
    )


def iniciar_novo_ciclo(db: Session, usuario_id: int, nome: str | None = None) -> models.CicloMensal:
    """Fecha o ciclo atual (se existir) e abre um novo, capturando a
    banca REAL acumulada nesse exato momento como ponto de partida."""
    hoje = date.today()

    ciclo_atual = obter_ciclo_atual(db, usuario_id)
    if ciclo_atual:
        ciclo_atual.data_fim = hoje - timedelta(days=1) if hoje > ciclo_atual.data_inicio else hoje

    resumo = calcular_resumo(db, usuario_id)
    banca_agora = resumo["banca_atual"]

    nome_final = nome or f"{MESES_PT[hoje.month]} {hoje.year}"

    novo_ciclo = models.CicloMensal(
        usuario_id=usuario_id,
        nome=nome_final,
        data_inicio=hoje,
        data_fim=None,
        banca_inicial_ciclo=banca_agora,
    )
    db.add(novo_ciclo)
    db.commit()
    db.refresh(novo_ciclo)
    return novo_ciclo


def calcular_dashboard_ciclo(db: Session, usuario_id: int, ciclo_id: int) -> dict | None:
    ciclo = (
        db.query(models.CicloMensal)
        .filter(models.CicloMensal.id == ciclo_id, models.CicloMensal.usuario_id == usuario_id)
        .first()
    )
    if not ciclo:
        return None

    query = db.query(models.Bet).filter(
        models.Bet.usuario_id == usuario_id, models.Bet.data >= ciclo.data_inicio
    )
    if ciclo.data_fim is not None:
        query = query.filter(models.Bet.data <= ciclo.data_fim)
    apostas_ciclo = query.order_by(models.Bet.data).all()

    lucro_ciclo = sum(a.lucro or 0.0 for a in apostas_ciclo)
    banca_atual_ciclo = ciclo.banca_inicial_ciclo + lucro_ciclo

    por_dia: dict[date, float] = {}
    for a in apostas_ciclo:
        por_dia[a.data] = por_dia.get(a.data, 0.0) + (a.lucro or 0.0)

    evolucao = [{"data": ciclo.data_inicio, "banca": round(ciclo.banca_inicial_ciclo, 2)}]
    acumulado = ciclo.banca_inicial_ciclo
    for dia in sorted(por_dia):
        acumulado += por_dia[dia]
        evolucao.append({"data": dia, "banca": round(acumulado, 2)})

    por_casa: dict[str, dict] = {}
    for a in apostas_ciclo:
        c = por_casa.setdefault(a.casa_de_apostas, {"total_apostas": 0, "lucro_total": 0.0, "green": 0, "resolvidas": 0})
        c["total_apostas"] += 1
        c["lucro_total"] += a.lucro or 0.0
        if a.resultado in (models.ResultadoAposta.green, models.ResultadoAposta.red):
            c["resolvidas"] += 1
            if a.resultado == models.ResultadoAposta.green:
                c["green"] += 1

    resumo_por_casa = [
        {
            "casa": casa,
            "total_apostas": dados["total_apostas"],
            "lucro_total": round(dados["lucro_total"], 2),
            "taxa_acerto": round(100 * dados["green"] / dados["resolvidas"], 1) if dados["resolvidas"] else None,
        }
        for casa, dados in por_casa.items()
    ]
    resumo_por_casa.sort(key=lambda c: c["lucro_total"], reverse=True)

    return {
        "ciclo": ciclo,
        "banca_atual_ciclo": round(banca_atual_ciclo, 2),
        "lucro_ciclo": round(lucro_ciclo, 2),
        "total_apostas_ciclo": len(apostas_ciclo),
        "evolucao": evolucao,
        "resumo_por_casa": resumo_por_casa,
    }

