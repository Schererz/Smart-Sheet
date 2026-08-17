"""
Modelo de dados da planilha de apostas.

Campos alinhados com o fluxo real de uso: o usuário escolhe a casa de
apostas ANTES de mandar a imagem (evita o OCR confundir casas com
layouts parecidos), e a imagem só precisa fornecer odd, valor, retorno
possível e a descrição da aposta.
"""
import enum
from datetime import datetime, date

from sqlalchemy import Column, Integer, String, Float, Date, DateTime, Enum, Text, JSON, Boolean, ForeignKey, UniqueConstraint
from .database import Base


class ResultadoAposta(str, enum.Enum):
    aberto = "aberto"
    green = "green"
    red = "red"


# ordem do ciclo do botão de status: aberto -> green -> red -> aberto ...
CICLO_STATUS = [ResultadoAposta.aberto, ResultadoAposta.green, ResultadoAposta.red]


def proximo_status(atual: ResultadoAposta) -> ResultadoAposta:
    idx = CICLO_STATUS.index(atual)
    return CICLO_STATUS[(idx + 1) % len(CICLO_STATUS)]


class OrigemRegistro(str, enum.Enum):
    manual = "manual"
    ocr = "ocr"
    telegram = "telegram"


class Usuario(Base):
    """Uma conta do app. Login simples: usuário + senha, gera um token que
    fica salvo no aparelho/navegador (não precisa logar de novo toda vez)."""
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nome_usuario = Column(String(50), unique=True, nullable=False, index=True)
    senha_hash = Column(String(200), nullable=False)
    token = Column(String(64), nullable=True, unique=True, index=True)
    criado_em = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Vínculo com o bot do Telegram (opcional). O chat_id só é preenchido
    # depois que o usuário confirma o código gerado no app. O código de
    # vínculo é temporário — expira sozinho depois de alguns minutos.
    telegram_chat_id = Column(String(64), nullable=True, unique=True, index=True)
    telegram_codigo_vinculo = Column(String(10), nullable=True)
    telegram_codigo_expira_em = Column(DateTime, nullable=True)


class Configuracao(Base):
    """Uma linha por usuário, com ajustes gerais do app. Hoje só guarda
    a banca inicial, que o usuário informa na primeira vez que abre o app —
    é a base pra calcular a evolução da banca ao longo do tempo."""
    __tablename__ = "configuracao"

    id = Column(Integer, primary_key=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), unique=True, nullable=False, index=True)
    banca_inicial = Column(Float, default=0.0, nullable=False)
    definida = Column(Boolean, default=False, nullable=False)  # já foi configurada pelo usuário?


class Casa(Base):
    """Uma casa de apostas cadastrada pelo usuário. Cresce com o tempo:
    cada vez que é usada numa aposta, o contador sobe (pra ordenar as
    mais usadas primeiro na tela de seleção). O campo zonas_calibradas
    é reservado pra fase 2 do parsing: quando essa casa acumular
    exemplos suficientes, guarda ali o que foi aprendido sobre onde
    cada campo costuma aparecer nas imagens dela."""
    __tablename__ = "casas"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False, index=True)
    nome = Column(String(100), nullable=False, index=True)
    vezes_usada = Column(Integer, default=0, nullable=False)
    banca_inicial = Column(Float, nullable=True)  # quanto foi depositado nessa casa, pra calcular banca/ROI por casa
    zonas_calibradas = Column(JSON, nullable=True)
    criado_em = Column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("usuario_id", "nome", name="uq_casa_por_usuario"),)


class Bet(Base):
    __tablename__ = "bets"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False, index=True)

    data = Column(Date, default=date.today, nullable=False)
    casa_de_apostas = Column(String(100), nullable=False)  # escolhida pelo usuário antes do upload
    descricao = Column(Text, nullable=True)  # ex: "Flamengo x Palmeiras - Over 2.5 gols"

    odd = Column(Float, nullable=False)
    valor_apostado = Column(Float, nullable=False)
    retorno_potencial = Column(Float, nullable=True)  # o que a casa mostra como retorno possível
    aumento_percentual = Column(Float, nullable=True)  # ex: 30 = aposta turbinada com +30% no lucro

    resultado = Column(Enum(ResultadoAposta), default=ResultadoAposta.aberto, nullable=False)
    lucro = Column(Float, nullable=True)  # calculado a partir do resultado

    origem = Column(Enum(OrigemRegistro), default=OrigemRegistro.manual, nullable=False)
    # Os dois campos abaixo só existem quando origem = ocr. Juntos formam o
    # par (entrada, saída correta) que vira exemplo de treino: os blocos
    # de texto que o OCR detectou na imagem (com posição), e o que o
    # parser sugeriu antes do usuário confirmar/corrigir. Os valores finais
    # corretos já são os próprios campos da aposta (odd, valor_apostado etc).
    blocos_ocr = Column(JSON, nullable=True)
    sugestao_original = Column(JSON, nullable=True)

    criado_em = Column(DateTime, default=datetime.utcnow, nullable=False)
    atualizado_em = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


def calcular_lucro(
    valor_apostado: float,
    retorno_potencial: float | None,
    resultado: ResultadoAposta,
    odd: float | None = None,
) -> float | None:
    """Calcula o lucro/prejuízo de uma aposta a partir do resultado.

    Se a aposta virar green mas não tiver retorno_potencial preenchido
    (comum quando foi cadastrada manual sem esse campo opcional), calcula
    o retorno padrão pela odd (valor * odd) em vez de deixar o lucro em
    branco pra sempre.
    """
    if resultado == ResultadoAposta.green:
        retorno = retorno_potencial
        if retorno is None and odd is not None:
            retorno = round(valor_apostado * odd, 2)
        if retorno is None:
            return None
        return round(retorno - valor_apostado, 2)
    if resultado == ResultadoAposta.red:
        return round(-valor_apostado, 2)
    return None  # aberto: ainda não tem lucro definido


def calcular_retorno_com_aumento(valor_apostado: float, odd: float, aumento_percentual: float) -> float:
    """Calcula o retorno de uma aposta "turbinada" (odds/ganhos aumentados).

    O aumento é aplicado sobre o LUCRO da aposta, não sobre o retorno total
    inteiro — é assim que as casas costumam anunciar (ex: "+30% de lucro
    nessa aposta"), não "+30% no valor que volta pra você".

    Exemplo: aposta de R$100 na odd 2.00 (lucro normal = R$100) com 30% de
    aumento -> lucro aumentado = R$130 -> retorno = 100 + 130 = R$230.
    """
    lucro_normal = valor_apostado * (odd - 1)
    lucro_aumentado = lucro_normal * (1 + aumento_percentual / 100)
    return round(valor_apostado + lucro_aumentado, 2)
