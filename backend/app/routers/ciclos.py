from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db
from ..deps import obter_usuario_atual

router = APIRouter(prefix="/ciclos", tags=["ciclos"])


@router.get("/modo-mensal")
def obter_modo_mensal(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return {"ativado": crud.obter_modo_mensal(db, usuario.id)}


@router.put("/modo-mensal")
def definir_modo_mensal(
    dados: schemas.ModoMensalUpdate,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return {"ativado": crud.definir_modo_mensal(db, usuario.id, dados.ativado)}


@router.get("/atual", response_model=schemas.CicloMensalOut | None)
def ciclo_atual(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return crud.obter_ciclo_atual(db, usuario.id)


@router.post("/iniciar", response_model=schemas.CicloMensalOut)
def iniciar_ciclo(
    dados: schemas.IniciarCicloRequest,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    return crud.iniciar_novo_ciclo(db, usuario.id, dados.nome)


@router.get("/", response_model=list[schemas.CicloMensalOut])
def listar_ciclos(db: Session = Depends(get_db), usuario: models.Usuario = Depends(obter_usuario_atual)):
    return crud.listar_ciclos(db, usuario.id)


@router.get("/{ciclo_id}/dashboard", response_model=schemas.DashboardCiclo)
def dashboard_ciclo(
    ciclo_id: int,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    resultado = crud.calcular_dashboard_ciclo(db, usuario.id, ciclo_id)
    if not resultado:
        raise HTTPException(status_code=404, detail="Ciclo não encontrado")
    return resultado
