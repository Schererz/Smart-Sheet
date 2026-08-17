"""
Parsing das mensagens de apostas recebidas via Telegram.

O formato esperado é o que grupos de tipster costumam postar — uma linha
por campo, cada uma com um emoji fixo no início. Exemplo real:

    🏠 Esportiva Bet
    🆚 Mirassol x LDU
    ⚽ Futebol
    📌 Mais de 9.5 - Total de chutes a gol
    🏷️ 3.00
    🚦 Limite da aposta: R$50,00
    🛑 1,27%
    💰 R$50,00
    🆓 Não

A gente só se importa com casa, confronto, mercado/seleção, odd e o
percentual da banca — o resto (limite, admin, link, disclaimers) é
ignorado de propósito.
"""
import re
from dataclasses import dataclass


@dataclass
class ApostaTelegram:
    casa: str | None = None
    confronto: str | None = None
    mercado: str | None = None
    odd: float | None = None
    percentual: float | None = None

    @property
    def descricao(self) -> str | None:
        partes = [p for p in (self.confronto, self.mercado) if p]
        return " - ".join(partes) if partes else None

    @property
    def completa(self) -> bool:
        """Tem o mínimo pra virar uma aposta de verdade."""
        return bool(self.casa and self.odd and self.percentual is not None)

    def campos_faltando(self) -> list[str]:
        faltando = []
        if not self.casa:
            faltando.append("casa (🏠)")
        if self.odd is None:
            faltando.append("odd (🏷️)")
        if self.percentual is None:
            faltando.append("percentual da banca (a linha com '%')")
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
        elif linha.startswith("🏷️") or linha.startswith("🏷"):
            m = re.search(r'(\d+[.,]\d+)', linha)
            if m:
                aposta.odd = _num(m.group(1))
        elif aposta.percentual is None:
            # o emoji da linha de percentual varia de grupo pra grupo (🛑,
            # ⚠️, etc) — em vez de fixar um, procura qualquer linha com
            # "número%" que ainda não tenha sido processada como outra coisa
            m = re.search(r'(\d+[.,]\d+)\s*%', linha)
            if m:
                aposta.percentual = _num(m.group(1))

    return aposta


def calcular_valor_apostado(percentual: float, banca_inicial: float) -> float:
    return round(banca_inicial * percentual / 100, 2)
