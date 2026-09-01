# ADICIONAR ao schemas.py — perto dos schemas de Casa. Também precisa
# importar TipoMovimentacao junto de ResultadoAposta/OrigemRegistro no
# topo do arquivo: "from .models import ResultadoAposta, OrigemRegistro, TipoMovimentacao"

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
