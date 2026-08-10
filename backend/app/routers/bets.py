from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual

router = APIRouter(prefix="/apostas", tags=["apostas"])


@router.post("/", response_model=schemas.BetOut)
def criar_aposta(
    aposta: schemas.BetCreate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.criar_aposta(db, usuario.id, aposta)


@router.get("/", response_model=list[schemas.BetOut])
def listar_apostas(
    skip: int = 0,
    limit: int = 200,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.listar_apostas(db, usuario.id, skip, limit)


@router.get("/resumo", response_model=schemas.ResumoStats)
def resumo(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return crud.calcular_resumo(db, usuario.id)


@router.get("/evolucao-banca", response_model=list[schemas.PontoEvolucaoBanca])
def evolucao_banca(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return crud.obter_evolucao_banca(db, usuario.id)


@router.post("/calcular-retorno-turbinado", response_model=schemas.CalcularRetornoResponse)
def calcular_retorno_turbinado(dados: schemas.CalcularRetornoRequest):
    """Calcula o retorno de uma aposta com ganhos aumentados (turbinada),
    sem precisar salvar nada — só pra mostrar o valor em tempo real no
    formulário enquanto o usuário digita. Não depende de login: é só uma
    conta, não mexe em dado de ninguém."""
    retorno = models.calcular_retorno_com_aumento(dados.valor_apostado, dados.odd, dados.aumento_percentual)
    return {"retorno_potencial": retorno}


@router.get("/{aposta_id}", response_model=schemas.BetOut)
def obter_aposta(
    aposta_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    aposta = crud.obter_aposta(db, usuario.id, aposta_id)
    if not aposta:
        raise HTTPException(status_code=404, detail="Aposta não encontrada")
    return aposta


@router.patch("/{aposta_id}", response_model=schemas.BetOut)
def atualizar_aposta(
    aposta_id: int,
    aposta: schemas.BetUpdate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    atualizada = crud.atualizar_aposta(db, usuario.id, aposta_id, aposta)
    if not atualizada:
        raise HTTPException(status_code=404, detail="Aposta não encontrada")
    return atualizada


@router.post("/{aposta_id}/ciclar-status", response_model=schemas.BetOut)
def ciclar_status(
    aposta_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    """Avança o status da aposta: aberto -> green -> red -> aberto ...
    É isso que o botão de status no app deve chamar a cada clique."""
    atualizada = crud.ciclar_status(db, usuario.id, aposta_id)
    if not atualizada:
        raise HTTPException(status_code=404, detail="Aposta não encontrada")
    return atualizada


@router.delete("/{aposta_id}")
def deletar_aposta(
    aposta_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    deletada = crud.deletar_aposta(db, usuario.id, aposta_id)
    if not deletada:
        raise HTTPException(status_code=404, detail="Aposta não encontrada")
    return {"ok": True}
