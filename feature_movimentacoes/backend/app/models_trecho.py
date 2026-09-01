# ADICIONAR ao models.py — o enum TipoMovimentacao vai junto dos outros
# enums (perto de ResultadoAposta/OrigemRegistro), e a classe
# MovimentacaoCasa vai depois da classe Casa.

class TipoMovimentacao(str, enum.Enum):
    deposito = "deposito"
    saque = "saque"


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
