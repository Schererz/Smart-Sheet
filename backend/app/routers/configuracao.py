from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..database import get_db

router = APIRouter(prefix="/configuracao", tags=["configuracao"])


@router.get("/", response_model=schemas.ConfiguracaoOut)
def obter_configuracao(db: Session = Depends(get_db)):
    return crud.obter_configuracao(db)


@router.put("/", response_model=schemas.ConfiguracaoOut)
def atualizar_configuracao(dados: schemas.ConfiguracaoUpdate, db: Session = Depends(get_db)):
    return crud.atualizar_banca_inicial(db, dados.banca_inicial)
