import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# URL de Conexão com o Neon PostgreSQL
# Para testar localmente no momento, você pode colar a string direta entre aspas
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://neondb_owner:npg_njguS9c8hpoL@ep-winter-dream-acj3b7sn.sa-east-1.aws.neon.tech/neondb?sslmode=require"
)

# O SQLAlchemy exige que a URL comece com 'postgresql://' (o Neon já entrega nesse padrão)
if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace("postgres://", "postgresql://", 1)

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True  # Mantém a conexão saudável em bancos serverless
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()