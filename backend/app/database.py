"""
Configuração do banco de dados.

Por padrão usa SQLite local (arquivo apostas.db), ótimo para desenvolver
e para rodar o backend na sua própria máquina/rede doméstica.

Quando você quiser subir isso num servidor de verdade, é só trocar
DATABASE_URL por uma URL do Postgres, ex:
    postgresql://usuario:senha@host:5432/apostas
Nenhum outro arquivo precisa mudar.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./apostas.db")

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    """Dependency do FastAPI: abre uma sessão do banco e garante que ela fecha depois."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
