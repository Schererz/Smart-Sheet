"""
Parsing das mensagens de apostas recebidas via Telegram.

Suporta DOIS formatos, que podem inclusive vir colados na mesma
mensagem (cada linha é processada independente, então não importa de
qual "bloco" ela veio):

1) Formato do grupo original — uma linha por campo, cada uma com um
   emoji fixo no início:

    🏠 Esportiva Bet
    🆚 Mirassol x LDU
    📌 Mais de 9.5 - Total de chutes a gol
    🏷️ 3.00
    🚦 Limite da aposta: R$50,00
    🛑 1,27%

   Aqui o VALOR é calculado (banca × percentual), respeitando o limite
   se a mensagem trouxer um.

2) Formato de bots relay tipo "Shark Track" — já vem com o valor e o
   retorno PRONTOS (calculados com a banca de quem configurou lá):

    🆚 Jaime Faria x Jenson Brooksby
    🏆 US Open, New York, USA
    🏠 bet365
    🏷️ Odd: 2.38
    💵 Valor: R$ 12,30
    🤑 Retorno: R$ 29,21

   Aqui o valor/retorno vêm DIRETO da mensagem, sem precisar calcular.
"""
import re
from dataclasses import dataclass


@dataclass
class ApostaTelegram:
    casa: str | None = None
    confronto: str | None = None
    mercado: str | None = None
    competicao: str | None = None  # ex: "US Open, New York, USA" — formato Shark Track
    odd: float | None = None
    percentual: float | None = None
    limite: float | None = None
    valor_direto: float | None = None  # quando a mensagem já traz o valor calculado (ex: Shark Track)
    retorno_direto: float | None = None

    @property
    def descricao(self) -> str | None:
        partes = [p for p in (self.confronto, self.mercado, self.competicao) if p]
        return " - ".join(partes) if partes else None

    @property
    def completa(self) -> bool:
        """Tem o mínimo pra virar uma aposta de verdade — precisa de casa,
        odd, e ALGUMA forma de saber o valor (percentual da banca OU um
        valor já calculado, tipo quando vem de outro bot que já faz essa
        conta usando a sua própria banca)."""
        tem_valor = self.percentual is not None or self.valor_direto is not None
        return bool(self.casa and self.odd and tem_valor)

    def campos_faltando(self) -> list[str]:
        faltando = []
        if not self.casa:
            faltando.append("casa (🏠)")
        if self.odd is None:
            faltando.append("odd (🏷️)")
        if self.percentual is None and self.valor_direto is None:
            faltando.append("percentual da banca (linha com '%') ou valor da aposta (💵)")
        return faltando


def _num(texto: str) -> float | None:
    texto = texto.strip().replace(",", ".")
    try:
        return float(texto)
    except ValueError:
        return None


def parsear_mensagem(texto: str) -> ApostaTelegram:
    aposta = ApostaTelegram()
    for linha_bruta in texto.split("\n"):
        linha = linha_bruta.strip()
        if not linha:
            continue

        if linha.startswith("🏠"):
            aposta.casa = linha.lstrip("🏠").strip()
        elif linha.startswith("🆚"):
            aposta.confronto = linha.lstrip("🆚").strip()
        elif linha.startswith("📌"):
            aposta.mercado = linha.lstrip("📌").strip()
        elif linha.startswith("🏆"):
            aposta.competicao = linha.lstrip("🏆").strip()
        elif linha.startswith("🏷️") or linha.startswith("🏷"):
            m = re.search(r'(\d+[.,]\d+)', linha)
            if m:
                aposta.odd = _num(m.group(1))
        elif linha.startswith("💵"):
            m = re.search(r'(\d+[.,]\d+)', linha)
            if m:
                aposta.valor_direto = _num(m.group(1))
        elif linha.startswith("🤑"):
            m = re.search(r'(\d+[.,]\d+)', linha)
            if m:
                aposta.retorno_direto = _num(m.group(1))
        elif linha.startswith("🚦") or (aposta.limite is None and re.search(r'limite', linha, re.IGNORECASE)):
            # o 🚦 costuma ser sempre o mesmo nesse tipo de mensagem — mas
            # mantém o texto "limite" como reforço, caso outro grupo use
            # um emoji diferente pra esse campo
            m = re.search(r'R\$?\s*(\d+[.,]\d+)', linha)
            if m:
                aposta.limite = _num(m.group(1))
        elif aposta.percentual is None:
            # o emoji da linha de percentual varia de grupo pra grupo (🛑,
            # ⚠️, etc) — em vez de fixar um, procura qualquer linha com
            # "número%" que ainda não tenha sido processada como outra coisa.
            # A casa decimal é OPCIONAL (aceita tanto "5,1%" quanto "2%").
            m = re.search(r'(\d+(?:[.,]\d+)?)\s*%', linha)
            if m:
                aposta.percentual = _num(m.group(1))

    return aposta


def calcular_valor_apostado(percentual: float, banca_inicial: float, limite: float | None = None) -> float:
    """Calcula quanto apostar com base no percentual da banca — e, se a
    mensagem trouxer um limite máximo por aposta, nunca ultrapassa ele."""
    valor = round(banca_inicial * percentual / 100, 2)
    if limite is not None:
        valor = min(valor, limite)
    return valor
