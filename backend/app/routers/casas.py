"""
Casas de apostas não são mais uma lista fixa no código — o usuário cadastra
as que usa. A lista cresce e se reordena sozinha: toda vez que uma casa é
usada numa aposta (veja crud.registrar_uso_casa), o contador dela sobe, e
`GET /casas` já devolve ordenado com as mais usadas primeiro. É isso que
o app deve chamar pra montar a tela de seleção antes do usuário mandar a
imagem.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..database import get_db

router = APIRouter(prefix="/casas", tags=["casas"])


@router.post("/", response_model=schemas.CasaOut)
def criar_casa(casa: schemas.CasaCreate, db: Session = Depends(get_db)):
    if not casa.nome.strip():
        raise HTTPException(status_code=400, detail="Nome da casa não pode ser vazio")
    nova, criada = crud.criar_casa(db, casa.nome)
    if not criada:
        raise HTTPException(status_code=400, detail="Essa casa já está cadastrada")
    return nova


@router.get("/", response_model=list[schemas.CasaOut])
def listar_casas(db: Session = Depends(get_db)):
    return crud.listar_casas(db)


@router.delete("/{casa_id}")
def deletar_casa(casa_id: int, db: Session = Depends(get_db)):
    deletada = crud.deletar_casa(db, casa_id)
    if not deletada:
        raise HTTPException(status_code=404, detail="Casa não encontrada")
    return {"ok": True}
