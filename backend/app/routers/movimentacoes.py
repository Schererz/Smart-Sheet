from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual

router = APIRouter(prefix="/movimentacoes", tags=["movimentacoes"])


@router.post("/", response_model=schemas.MovimentacaoOut)
def criar_movimentacao(
    dados: schemas.MovimentacaoCreate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    nova = crud.criar_movimentacao(db, usuario.id, dados)
    if not nova:
        raise HTTPException(status_code=404, detail="Casa não encontrada")
    return nova


@router.get("/", response_model=list[schemas.MovimentacaoOut])
def listar_movimentacoes(
    casa_id: int | None = None,
    data_inicio: date | None = None,
    data_fim: date | None = None,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.listar_movimentacoes(db, usuario.id, casa_id, data_inicio, data_fim)


@router.delete("/{movimentacao_id}")
def deletar_movimentacao(
    movimentacao_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    deletada = crud.deletar_movimentacao(db, usuario.id, movimentacao_id)
    if not deletada:
        raise HTTPException(status_code=404, detail="Movimentação não encontrada")
    return {"ok": True}


@router.get("/banca-por-localizacao", response_model=schemas.BancaPorLocalizacao)
def banca_por_localizacao(
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.calcular_banca_por_localizacao(db, usuario.id)
