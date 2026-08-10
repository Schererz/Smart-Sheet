from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from .. import models, schemas
from ..auth_utils import gerar_hash_senha, gerar_token, verificar_senha
from ..database import get_db
from ..deps import obter_usuario_atual

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/registrar", response_model=schemas.TokenOut)
def registrar(dados: schemas.UsuarioCreate, db: Session = Depends(get_db)):
    existente = (
        db.query(models.Usuario)
        .filter(func.lower(models.Usuario.nome_usuario) == dados.nome_usuario.lower())
        .first()
    )
    if existente:
        raise HTTPException(status_code=400, detail="Esse nome de usuário já está em uso")

    usuario = models.Usuario(
        nome_usuario=dados.nome_usuario,
        senha_hash=gerar_hash_senha(dados.senha),
        token=gerar_token(),
    )
    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    # cada usuário novo já começa com uma configuração de banca vazia
    db.add(models.Configuracao(usuario_id=usuario.id, banca_inicial=0.0, definida=False))
    db.commit()

    return {"token": usuario.token, "usuario": usuario}


@router.post("/login", response_model=schemas.TokenOut)
def login(dados: schemas.UsuarioLogin, db: Session = Depends(get_db)):
    usuario = (
        db.query(models.Usuario)
        .filter(func.lower(models.Usuario.nome_usuario) == dados.nome_usuario.lower())
        .first()
    )
    if not usuario or not verificar_senha(dados.senha, usuario.senha_hash):
        raise HTTPException(status_code=401, detail="Usuário ou senha incorretos")

    usuario.token = gerar_token()  # gera um token novo a cada login
    db.commit()
    db.refresh(usuario)

    return {"token": usuario.token, "usuario": usuario}


@router.post("/logout")
def logout(usuario: models.Usuario = Depends(obter_usuario_atual), db: Session = Depends(get_db)):
    usuario.token = None
    db.commit()
    return {"ok": True}


@router.get("/eu", response_model=schemas.UsuarioOut)
def eu(usuario: models.Usuario = Depends(obter_usuario_atual)):
    """Confirma quem é o usuário do token atual — útil pro app conferir
    se a sessão salva ainda é válida ao abrir."""
    return usuario
