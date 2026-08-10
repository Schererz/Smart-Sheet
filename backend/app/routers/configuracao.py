from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual

router = APIRouter(prefix="/configuracao", tags=["configuracao"])


@router.get("/", response_model=schemas.ConfiguracaoOut)
def obter_configuracao(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return crud.obter_configuracao(db, usuario.id)


@router.put("/", response_model=schemas.ConfiguracaoOut)
def atualizar_configuracao(
    dados: schemas.ConfiguracaoUpdate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.atualizar_banca_inicial(db, usuario.id, dados.banca_inicial)
