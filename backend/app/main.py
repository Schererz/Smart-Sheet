from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine
from .routers import bets, casas, configuracao, importacao, ocr_web, parsing

# cria as tabelas no banco (se ainda não existirem) toda vez que sobe a API
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API - Planilha de Apostas",
    description="Backend do app pessoal de controle e análise de apostas esportivas.",
    version="0.1.0",
)

# Libera acesso do app Flutter (rodando no celular/emulador) para a API.
# Em produção, troque "*" pela URL/IP real do backend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(bets.router)
app.include_router(casas.router)
app.include_router(configuracao.router)
app.include_router(importacao.router)
app.include_router(ocr_web.router)
app.include_router(parsing.router)


@app.get("/")
def raiz():
    return {"status": "ok", "mensagem": "API da planilha de apostas rodando"}
