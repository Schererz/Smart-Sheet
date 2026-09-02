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

class TipoMovimentacao(str, enum.Enum):
    deposito = "deposito"
    saque = "saque"


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
    """Uma linha por usuário, com ajustes gerais do app. Guarda a banca
    inicial (definida na primeira vez que abre o app), a unidade de
    apostas (recalculada periodicamente com base na banca atual), e o
    modo mensal (visão "zerada" por ciclo, opcional)."""
    __tablename__ = "configuracao"

    id = Column(Integer, primary_key=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), unique=True, nullable=False, index=True)
    banca_inicial = Column(Float, default=0.0, nullable=False)
    definida = Column(Boolean, default=False, nullable=False)  # já foi configurada pelo usuário?

    unidade_atual = Column(Float, nullable=True)
    data_ultimo_recalculo_unidade = Column(Date, nullable=True)
    intervalo_recalculo_dias = Column(Integer, default=7, nullable=False)  # 7 = semanal, 30 = mensal

    modo_mensal_ativado = Column(Boolean, default=False, nullable=False)


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

class MovimentacaoCasa(Base):
    """Um saque ou depósito entre o usuário e uma casa específica — é
    dinheiro TROCANDO DE LUGAR (do "banco" pra casa, ou o contrário), não
    lucro/prejuízo de aposta. A banca TOTAL não muda com isso, só a
    distribuição de onde ela está guardada no momento."""
    __tablename__ = "movimentacoes_casa"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False, index=True)
    casa_id = Column(Integer, ForeignKey("casas.id"), nullable=False, index=True)
    tipo = Column(Enum(TipoMovimentacao), nullable=False)
    valor = Column(Float, nullable=False)
    data = Column(Date, default=date.today, nullable=False)
    criado_em = Column(DateTime, default=datetime.utcnow, nullable=False)

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

    tipster = Column(String(50), nullable=True)  # de qual grupo/pessoa veio a indicação (ex: "Girino", "Props")

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


class CicloMensal(Base):
    """Um período (normalmente um mês) quando o modo mensal está ativado.
    Guarda a banca REAL acumulada no momento em que o ciclo começou —
    é o que permite mostrar "banca zerada" (só o que rolou nesse ciclo)
    sem perder o histórico de verdade."""
    __tablename__ = "ciclos_mensais"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False, index=True)
    nome = Column(String(50), nullable=False)
    data_inicio = Column(Date, nullable=False)
    data_fim = Column(Date, nullable=True)  # None = é o ciclo ATUAL, ainda em andamento
    banca_inicial_ciclo = Column(Float, nullable=False)
    criado_em = Column(DateTime, default=datetime.utcnow, nullable=False)
