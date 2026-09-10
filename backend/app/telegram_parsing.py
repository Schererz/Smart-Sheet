"""
Parsing das mensagens de apostas recebidas via Telegram.

Suporta TRÊS formas de saber o valor a apostar, que podem inclusive vir
coladas na mesma mensagem (cada linha é processada independente, então
não importa de qual "bloco" ela veio):

1) Percentual da banca (tipster "Girino", o formato padrão/original) —
   uma linha por campo, cada uma com um emoji fixo no início:

    🏠 Esportiva Bet
    🆚 Mirassol x LDU
    📌 Mais de 9.5 - Total de chutes a gol
    🏷️ 3.00
    🚦 Limite da aposta: R$50,00
    🛑 1,27%

   Aqui o VALOR é calculado (banca × percentual), respeitando o limite
   se a mensagem trouxer um.

2) Valor pronto (bots relay tipo "Shark Track") — já vem com o valor e
   o retorno CALCULADOS (usando a banca de quem configurou lá):

    🏷️ Odd: 2.38
    💵 Valor: R$ 12,30
    🤑 Retorno: R$ 29,21

3) Unidades (tipster "Props") — o valor vem em "u" (unidade), não em %
   nem em R$ direto. 1 unidade = R$5 fixo, não depende da banca:

    🏷️ 5.20
    💰 3u

Sempre que a mensagem tiver unidades, o tipster vira "Props"
automaticamente — em qualquer outro caso, o tipster padrão é "Girino"
(único usuário desse bot por enquanto, então não precisa perguntar).
"""
import re
import unicodedata
from dataclasses import dataclass

VALOR_POR_UNIDADE = 5.0  # 1u = R$5, fixo — não depende da banca
TIPSTER_PADRAO = "Girino"
TIPSTER_UNIDADES = "Props"

# Tipsters que mandam mensagem no MESMO formato do padrão (Girino), então
# não dá pra distinguir pelo conteúdo — o usuário escreve o nome numa
# linha antes de colar a mensagem, e a gente usa isso pra marcar de quem
# veio. A chave é o nome já normalizado (sem acento, minúsculo).
TIPSTERS_POR_PREFIXO = {
    "aguas": "Águas",
}


def _normalizar(texto: str) -> str:
    """Tira acento e deixa minúsculo — pra reconhecer "Águas", "aguas",
    "AGUAS" e "Aguas" todos como a mesma coisa."""
    sem_acento = unicodedata.normalize("NFKD", texto).encode("ASCII", "ignore").decode()
    return sem_acento.strip().lower()


def extrair_tipster_do_prefixo(texto: str) -> tuple[str | None, str]:
    """Se a primeira linha for só o nome de um tipster conhecido (ex:
    "aguas"), devolve (nome oficial, resto da mensagem sem essa linha).
    Senão, devolve (None, texto original inteiro)."""
    linhas = texto.split("\n")
    if not linhas:
        return None, texto
    primeira = re.sub(r"[:\-–—]\s*$", "", _normalizar(linhas[0])).strip()
    if primeira in TIPSTERS_POR_PREFIXO:
        return TIPSTERS_POR_PREFIXO[primeira], "\n".join(linhas[1:])
    return None, texto


@dataclass
class ApostaTelegram:
    casa: str | None = None
    confronto: str | None = None
    mercado: str | None = None
    competicao: str | None = None  # ex: "US Open, New York, USA"
    odd: float | None = None
    percentual: float | None = None
    limite: float | None = None
    valor_direto: float | None = None  # quando a mensagem já traz o valor calculado (ex: Shark Track)
    retorno_direto: float | None = None
    unidades: float | None = None  # formato "3u" — tipster Props
    tipster_informado: str | None = None  # veio escrito antes da mensagem (ex: "aguas")

    @property
    def descricao(self) -> str | None:
        partes = [p for p in (self.confronto, self.mercado, self.competicao) if p]
        return " - ".join(partes) if partes else None

    @property
    def tipster(self) -> str:
        """Prioridade: o que o usuário escreveu antes da mensagem (ex:
        "aguas") > detecção automática por unidades (Props) > padrão
        (Girino)."""
        if self.tipster_informado:
            return self.tipster_informado
        return TIPSTER_UNIDADES if self.unidades is not None else TIPSTER_PADRAO

    @property
    def completa(self) -> bool:
        """Tem o mínimo pra virar uma aposta de verdade — precisa de casa,
        odd, e ALGUMA forma de saber o valor (percentual da banca, um
        valor já calculado, ou unidades)."""
        tem_valor = self.percentual is not None or self.valor_direto is not None or self.unidades is not None
        return bool(self.casa and self.odd and tem_valor)

    def campos_faltando(self) -> list[str]:
        faltando = []
        if not self.casa:
            faltando.append("casa (🏠)")
        if self.odd is None:
            faltando.append("odd (🏷️)")
        if self.percentual is None and self.valor_direto is None and self.unidades is None:
            faltando.append("percentual da banca (%), unidades (u), ou valor da aposta (💵)")
        return faltando


def _num(texto: str) -> float | None:
    texto = texto.strip().replace(",", ".")
    try:
        return float(texto)
    except ValueError:
        return None


def parsear_mensagem(texto: str) -> ApostaTelegram:
    tipster_informado, texto = extrair_tipster_do_prefixo(texto)
    aposta = ApostaTelegram(tipster_informado=tipster_informado)
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
        elif linha.startswith("💰"):
            # o 💰 tem dois significados possíveis: "3u" (unidades, tipster
            # Props) ou "R$X,XX" (só informativo no formato Girino — o
            # valor de verdade vem do percentual, esse aqui é ignorado).
            m_unidades = re.search(r'(\d+(?:[.,]\d+)?)\s*u\b', linha, re.IGNORECASE)
            if m_unidades:
                aposta.unidades = _num(m_unidades.group(1))
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


def calcular_valor_por_unidades(unidades: float, limite: float | None = None, valor_unidade: float = VALOR_POR_UNIDADE) -> float:
    """1 unidade = R$ valor_unidade (por padrão R$5, mas configurável por
    comando no bot — "Unidade = 4"). Não depende da banca. Ainda assim
    respeita um limite máximo, se a mensagem trouxer um."""
    valor = round(unidades * valor_unidade, 2)
    if limite is not None:
        valor = min(valor, limite)
    return valor
