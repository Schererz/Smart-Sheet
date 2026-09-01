# ADICIONAR ao crud.py, no final do arquivo.

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
