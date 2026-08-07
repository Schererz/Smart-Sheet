from datetime import date
from sqlalchemy.orm import Session
from sqlalchemy import func

from . import models, schemas


def obter_configuracao(db: Session) -> models.Configuracao:
    config = db.query(models.Configuracao).filter(models.Configuracao.id == 1).first()
    if not config:
        config = models.Configuracao(id=1, banca_inicial=0.0, definida=False)
        db.add(config)
        db.commit()
        db.refresh(config)
    return config


def atualizar_banca_inicial(db: Session, valor: float) -> models.Configuracao:
    config = obter_configuracao(db)
    config.banca_inicial = valor
    config.definida = True
    db.commit()
    db.refresh(config)
    return config


def obter_evolucao_banca(db: Session):
    """Monta a curva da banca ao longo do tempo: começa na banca inicial e
    soma o lucro de cada aposta resolvida (green/red), em ordem cronológica."""
    config = obter_configuracao(db)
    resolvidas = (
        db.query(models.Bet)
        .filter(models.Bet.resultado.in_([models.ResultadoAposta.green, models.ResultadoAposta.red]))
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


def criar_casa(db: Session, nome: str):
    existente = db.query(models.Casa).filter(func.lower(models.Casa.nome) == nome.strip().lower()).first()
    if existente:
        return existente, False
    nova = models.Casa(nome=nome.strip())
    db.add(nova)
    db.commit()
    db.refresh(nova)
    return nova, True


def listar_casas(db: Session):
    return (
        db.query(models.Casa)
        .order_by(models.Casa.vezes_usada.desc(), models.Casa.nome.asc())
        .all()
    )


def deletar_casa(db: Session, casa_id: int):
    casa = db.query(models.Casa).filter(models.Casa.id == casa_id).first()
    if not casa:
        return None
    db.delete(casa)
    db.commit()
    return casa


def registrar_uso_casa(db: Session, nome: str):
    """Sobe o contador de uso da casa. Se por algum motivo a casa ainda não
    existir (app desatualizado, etc.), cria ela na hora — não trava o fluxo."""
    casa, _ = criar_casa(db, nome)
    casa.vezes_usada += 1
    db.commit()


def criar_aposta(db: Session, aposta: schemas.BetCreate):
    dados = aposta.model_dump()
    if dados.get("aumento_percentual"):
        dados["retorno_potencial"] = models.calcular_retorno_com_aumento(
            dados["valor_apostado"], dados["odd"], dados["aumento_percentual"]
        )
    if dados["resultado"] == models.ResultadoAposta.green and dados["retorno_potencial"] is None:
        dados["retorno_potencial"] = round(dados["valor_apostado"] * dados["odd"], 2)
    lucro = models.calcular_lucro(dados["valor_apostado"], dados["retorno_potencial"], dados["resultado"], dados["odd"])
    db_aposta = models.Bet(**dados, lucro=lucro)
    db.add(db_aposta)
    registrar_uso_casa(db, aposta.casa_de_apostas)
    db.commit()
    db.refresh(db_aposta)
    return db_aposta


def listar_apostas(db: Session, skip: int = 0, limit: int = 200):
    return (
        db.query(models.Bet)
        .order_by(models.Bet.data.desc(), models.Bet.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


def obter_aposta(db: Session, aposta_id: int):
    return db.query(models.Bet).filter(models.Bet.id == aposta_id).first()


def atualizar_aposta(db: Session, aposta_id: int, aposta_update: schemas.BetUpdate):
    db_aposta = obter_aposta(db, aposta_id)
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


def ciclar_status(db: Session, aposta_id: int):
    """Avança o status da aposta: aberto -> green -> red -> aberto ..."""
    db_aposta = obter_aposta(db, aposta_id)
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


def deletar_aposta(db: Session, aposta_id: int):
    db_aposta = obter_aposta(db, aposta_id)
    if not db_aposta:
        return None
    db.delete(db_aposta)
    db.commit()
    return db_aposta


def obter_dataset_treino(db: Session, casa: str | None = None):
    """Monta os exemplos de treino: blocos que o OCR detectou + o que foi
    sugerido + o que realmente estava certo (os campos finais da aposta).
    Só considera apostas que vieram de OCR e têm os blocos guardados."""
    query = db.query(models.Bet).filter(
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


def calcular_resumo(db: Session) -> dict:
    total_apostas = db.query(func.count(models.Bet.id)).scalar() or 0
    total_apostado = db.query(func.sum(models.Bet.valor_apostado)).scalar() or 0.0
    lucro_total = db.query(func.sum(models.Bet.lucro)).scalar() or 0.0
    odd_media = db.query(func.avg(models.Bet.odd)).scalar()
    valor_medio_apostado = db.query(func.avg(models.Bet.valor_apostado)).scalar()
    maior_lucro = db.query(func.max(models.Bet.lucro)).scalar()
    maior_prejuizo = db.query(func.min(models.Bet.lucro)).scalar()
    apostas_em_aberto = (
        db.query(func.count(models.Bet.id)).filter(models.Bet.resultado == models.ResultadoAposta.aberto).scalar() or 0
    )

    resolvidas = (
        db.query(models.Bet)
        .filter(models.Bet.resultado.in_([models.ResultadoAposta.green, models.ResultadoAposta.red]))
        .all()
    )
    ganhas = sum(1 for a in resolvidas if a.resultado == models.ResultadoAposta.green)
    taxa_acerto = round(100 * ganhas / len(resolvidas), 1) if resolvidas else None
    roi = round(100 * lucro_total / total_apostado, 1) if total_apostado else None

    config = obter_configuracao(db)

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
