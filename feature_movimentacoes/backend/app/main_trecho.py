# No main.py, trocar a linha de import dos routers pra incluir "movimentacoes":

from ....backend.app.routers import movimentacoes
from .routers import auth, bets, casas, configuracao, importacao, ocr_web, parsing, telegram

# E adicionar essa linha junto dos outros app.include_router(...):

app.include_router(movimentacoes.router)
