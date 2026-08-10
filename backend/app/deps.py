"""
Dependência do FastAPI que identifica QUEM está fazendo a requisição, a
partir do token mandado no cabeçalho Authorization (formato "Bearer TOKEN").

Toda rota que mexe com dado de usuário (apostas, casas, configuração)
usa essa dependência pra saber de quem é o dado, e nunca deixa um usuário
ver/editar dado de outro.
"""
from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session

from . import models
from .database import get_db


def obter_usuario_atual(
    authorization: str | None = Header(None),
    db: Session = Depends(get_db),
) -> models.Usuario:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Não autenticado")

    token = authorization[7:].strip()
    usuario = db.query(models.Usuario).filter(models.Usuario.token == token).first()
    if not usuario:
        raise HTTPException(status_code=401, detail="Sessão inválida, faça login de novo")
    return usuario
