from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, field_validator

from .models import ResultadoAposta, OrigemRegistro, TipoMovimentacao


class UsuarioCreate(BaseModel):
    nome_usuario: str
    senha: str

    @field_validator("nome_usuario")
    @classmethod
    def validar_nome(cls, v):
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Nome de usuário precisa ter pelo menos 3 caracteres")
        return v

    @field_validator("senha")
    @classmethod
    def validar_senha(cls, v):
        if len(v) < 4:
            raise ValueError("Senha precisa ter pelo menos 4 caracteres")
        return v


class UsuarioLogin(BaseModel):
    nome_usuario: str
    senha: str


class UsuarioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome_usuario: str


class TokenOut(BaseModel):
    token: str
    usuario: UsuarioOut


class ConfiguracaoOut(BaseModel):
    banca_inicial: float
    definida: bool


class ConfiguracaoUpdate(BaseModel):
    banca_inicial: float


class PontoEvolucaoBanca(BaseModel):
    data: date
    banca: float
    descricao: str | None = None  # o que causou essa mudança, pra tooltip no gráfico


class CasaCreate(BaseModel):
    nome: str


class CasaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    vezes_usada: int
    banca_inicial: float | None = None
    criado_em: datetime


class CasaBancaUpdate(BaseModel):
    banca_inicial: float


class ResumoPorCasa(BaseModel):
    """Estatísticas de uma casa específica — pra comparar qual está indo melhor."""
    casa: str
    total_apostas: int
    total_apostado: float
    lucro_total: float
    taxa_acerto: float | None
    odd_media: float | None
    roi_apostado: float | None  # lucro / total apostado, em %
    banca_inicial: float | None
    banca_atual: float | None
    roi_banca: float | None  # lucro / banca inicial DA CASA, em % (só existe se a banca da casa foi definida)

class MovimentacaoCreate(BaseModel):
    casa_id: int
    tipo: TipoMovimentacao
    valor: float
    data: date = date.today()


class MovimentacaoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    casa_id: int
    tipo: TipoMovimentacao
    valor: float
    data: date
    criado_em: datetime


class ItemBancaLocalizacao(BaseModel):
    casa: str
    valor: float


class BancaPorLocalizacao(BaseModel):
    banco: float  # dinheiro fora de qualquer casa, disponível pra depositar
    casas: list[ItemBancaLocalizacao]
    total: float  # deve ser sempre igual à banca_atual global


class PontoLucroDia(BaseModel):
    data: date
    lucro: float
    total_apostas: int


class BlocoOCR(BaseModel):
    """Um bloco de texto detectado pelo OCR, com posição normalizada (0 a 1)
    em relação ao tamanho da imagem. É assim que o app deve mandar cada
    trecho de texto reconhecido, em vez de um texto corrido só."""
    texto: str
    x: float       # posição horizontal do canto esquerdo, 0 = borda esquerda, 1 = borda direita
    y: float       # posição vertical do topo, 0 = topo, 1 = base
    largura: float
    altura: float


class RascunhoAposta(BaseModel):
    """Sugestão de aposta extraída dos blocos — o usuário confirma/edita antes de salvar."""
    odd: float | None = None
    valor_apostado: float | None = None
    retorno_potencial: float | None = None
    aumento_percentual: float | None = None
    descricao: str | None = None
    resultado_sugerido: str | None = None  # "aberto" / "green" / "red", se a imagem já mostrar isso
    data_sugerida: date | None = None  # data extraída da imagem, se achou alguma
    texto_limpo: str | None = None  # texto sem ruído, pra copiar manualmente se a extração falhar


class BetBase(BaseModel):
    data: date = date.today()
    casa_de_apostas: str
    descricao: str | None = None
    odd: float
    valor_apostado: float
    retorno_potencial: float | None = None
    aumento_percentual: float | None = None  # ex: 30 = aposta turbinada com +30% no lucro
    resultado: ResultadoAposta = ResultadoAposta.aberto


class BetCreate(BetBase):
    origem: OrigemRegistro = OrigemRegistro.manual
    # Os dois campos abaixo só vêm preenchidos quando origem = ocr.
    # É o par (entrada, saída correta) que vira exemplo de treino.
    blocos_ocr: list[BlocoOCR] | None = None
    sugestao_original: RascunhoAposta | None = None


class BetUpdate(BaseModel):
    """Todos os campos opcionais: só manda o que quer mudar."""
    data: date | None = None
    casa_de_apostas: str | None = None
    descricao: str | None = None
    odd: float | None = None
    valor_apostado: float | None = None
    retorno_potencial: float | None = None
    aumento_percentual: float | None = None
    resultado: ResultadoAposta | None = None


class BetOut(BetBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    lucro: float | None
    origem: OrigemRegistro
    blocos_ocr: list[BlocoOCR] | None = None
    sugestao_original: RascunhoAposta | None = None
    criado_em: datetime
    atualizado_em: datetime


class CalcularRetornoRequest(BaseModel):
    """Pra pedir ao backend que calcule o retorno de uma aposta turbinada,
    em vez do usuário fazer a conta na mão."""
    valor_apostado: float
    odd: float
    aumento_percentual: float


class CalcularRetornoResponse(BaseModel):
    retorno_potencial: float


class ResumoStats(BaseModel):
    """Estatísticas gerais da planilha, pra tela inicial do app."""
    total_apostas: int
    total_apostado: float
    lucro_total: float
    taxa_acerto: float | None
    roi: float | None
    banca_inicial: float
    banca_atual: float
    odd_media: float | None
    valor_medio_apostado: float | None
    maior_lucro: float | None
    maior_prejuizo: float | None
    apostas_em_aberto: int


# ---------------- Unidade ----------------

class StatusUnidade(BaseModel):
    unidade_atual: float | None
    data_ultimo_recalculo: date | None
    intervalo_dias: int
    proxima_data_recalculo: date | None
    recalculo_pendente: bool
    unidade_se_recalcular_agora: float


class IntervaloUnidadeUpdate(BaseModel):
    intervalo_dias: int  # 7 = semanal, 30 = mensal


# ---------------- Sugestão de depósito ----------------

class SugestaoDepositoRequest(BaseModel):
    banca_total_mes: float
    dias_periodo: int = 30        # período de onde vem o lucro considerado (padrão: mês passado)
    fator_retencao: float = 0.7   # quanto da participação no lucro vira % de depósito (0.7 = 70%)
    valor_minimo: float = 50
    valor_maximo: float = 300


class ItemSugestaoDeposito(BaseModel):
    casa: str
    lucro_periodo: float
    participacao_pct: float  # % que essa casa teve do lucro total positivo do período
    sugerido: float


class SugestaoDepositoResponse(BaseModel):
    sugestoes: list[ItemSugestaoDeposito]
    banco_sugerido: float
    nova_unidade_sugerida: float
    banca_insuficiente_para_minimos: bool  # caso extremo: nem o mínimo coube em todas as casas


# ---------------- Ciclos mensais ----------------

class CicloMensalOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nome: str
    data_inicio: date
    data_fim: date | None
    banca_inicial_ciclo: float


class ResumoPorCasaCiclo(BaseModel):
    casa: str
    total_apostas: int
    lucro_total: float
    taxa_acerto: float | None


class DashboardCiclo(BaseModel):
    ciclo: CicloMensalOut
    banca_atual_ciclo: float
    lucro_ciclo: float
    total_apostas_ciclo: int
    evolucao: list[dict]  # [{"data": date, "banca": float}, ...]
    resumo_por_casa: list[ResumoPorCasaCiclo]


class ModoMensalUpdate(BaseModel):
    ativado: bool


class IniciarCicloRequest(BaseModel):
    nome: str | None = None  # se não vier, gera automático tipo "Agosto 2026"
