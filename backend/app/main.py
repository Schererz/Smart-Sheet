from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import engine
from .routers import auth, bets, casas, ciclos, configuracao, importacao, movimentacoes, ocr_web, parsing, telegram

# cria as tabelas no banco (se ainda não existirem) toda vez que sobe a API
models.Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API - Planilha de Apostas",
    description="Backend do app pessoal de controle e análise de apostas esportivas.",
    version="0.1.0",
)

# Libera acesso de qualquer origem à API. Como a autenticação já é feita
# por token (não por cookie/sessão), manter aberto aqui é seguro — CORS
# não é a camada que protege os dados neste app.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(bets.router)
app.include_router(casas.router)
app.include_router(configuracao.router)
app.include_router(importacao.router)
app.include_router(ocr_web.router)
app.include_router(parsing.router)
app.include_router(telegram.router)
app.include_router(movimentacoes.router)
app.include_router(ciclos.router)


@app.get("/")
def raiz():
    return {"status": "ok", "mensagem": "API da planilha de apostas rodando"}
