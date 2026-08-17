"""
Endpoint que recebe os blocos de texto que o OCR detectou numa imagem e
tenta estruturar isso nos campos da aposta.

Diferente da primeira versão (que tentava adivinhar por zona/posição na
tela), essa aqui usa REGRAS ESPECÍFICAS POR CASA baseadas nos rótulos de
texto reais que cada app mostra (ex: "Valor da Aposta", "Ganho total",
"Potencial ganho"). Isso é bem mais confiável que posição, porque essas
casas quase sempre rotulam os campos explicitamente — o problema nunca foi
achar o número, foi saber qual rótulo cada casa usa pra cada campo.

Casas calibradas até agora (com prints reais): Betano, Bet365, Betnacional,
EsportivaBet, EstrelaBet, Novibet. Qualquer casa fora dessa lista cai no
parser genérico (baseado em zona/posição), que é mais fraco mas serve de
ponto de partida até termos prints reais dela também.

IMPORTANTE: por enquanto só extrai a PRIMEIRA aposta encontrada na imagem,
mesmo que a imagem tenha várias (ex: telas de histórico com lista). Suporte
a múltiplas apostas por imagem é o próximo passo.
"""
import re
from datetime import date, datetime
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from .. import crud, models
from ..database import get_db
from ..deps import obter_usuario_atual
from ..schemas import BlocoOCR, RascunhoAposta

router = APIRouter(prefix="/parsing", tags=["parsing"])


class TextoParaAnalisar(BaseModel):
    casa: str
    blocos: list[BlocoOCR]


# ---------------------------------------------------------------------------
# Helpers gerais
# ---------------------------------------------------------------------------

MOJIBAKE_MAP = {
    'Ã¡': 'á', 'Ã ': 'à', 'Ã¢': 'â', 'Ã£': 'ã',
    'Ã©': 'é', 'Ãª': 'ê',
    'Ã­': 'í',
    'Ã³': 'ó', 'Ã´': 'ô', 'Ãµ': 'õ',
    'Ãº': 'ú', 'Ã¼': 'ü',
    'Ã§': 'ç',
}


def _reparar_mojibake(texto: str) -> str:
    """Às vezes SÓ PARTE do texto vem com acentos corrompidos (tipo
    "GoiÃ¡s" em vez de "Goiás") — sintoma clássico de bytes UTF-8
    decodificados como se fossem Latin-1. Corrige só as sequências
    corrompidas conhecidas (troca direta, não um re-encode do texto
    inteiro) — assim não estraga os trechos que já estavam certos,
    mesmo quando o texto tem uma mistura dos dois (o que acontece na
    prática, aparentemente por causa de como cada bloco de texto é
    processado pela Cloud Vision)."""
    for errado, certo in MOJIBAKE_MAP.items():
        texto = texto.replace(errado, certo)
    return texto


def _num(texto: str) -> float | None:
    """Converte texto tipo 'R$ 1.234,56', 'R $ 6.00' (com espaço) ou '23,80' em float."""
    if not texto:
        return None
    s = re.sub(r'^\s*R\s*\$?\s*', '', texto.strip(), flags=re.IGNORECASE).strip()
    if ',' in s and '.' in s:
        s = s.replace('.', '').replace(',', '.')
    elif ',' in s:
        s = s.replace(',', '.')
    try:
        return float(s)
    except ValueError:
        return None


def _buscar(regex: str, texto: str) -> float | None:
    m = re.search(regex, texto, re.IGNORECASE)
    return _num(m.group(1)) if m else None


PALAVRAS_EXCLUIDAS_DESCRICAO = {
    "criar aposta", "simples", "dupla", "múltipla", "multipla", "aposta",
    "retorno", "retornos", "valor", "odd", "compartilhar", "cashout",
    "reusar as seleções", "reusar as selecoes", "resultado final",
    "total de gols", "total de escanteios", "chance dupla", "combinada",
}


# Badges promocionais (tipo "TURBINADA", "BOOST OURO") que várias casas
# colocam NO MEIO do bilhete, entre as linhas de mercado/seleção. Elas não
# carregam informação útil pra descrição — só atrapalham (podem confundir
# a lógica de pares mercado/seleção, deslocando tudo). Por isso removemos
# ANTES de qualquer extração de descrição, não casa por casa.
PADRAO_BADGE_PROMOCIONAL = re.compile(
    r'^(TURBINADA|SUPER\s*TURBINADA|BOOST\s*(OURO|PRATA|BRONZE)?|ODDS?\s*DE\s*OURO|\d+%\s*(SUPER\s*)?TURBINADA|\d+%\s*BOOST|CA)$',
    re.IGNORECASE,
)


def _linhas_uteis(texto: str) -> list[str]:
    """Quebra o texto em linhas não-vazias, já sem as badges promocionais
    que não ajudam em nada na descrição (TURBINADA, BOOST OURO, etc)."""
    linhas = [l.strip() for l in texto.split('\n') if l.strip()]
    return [l for l in linhas if not PADRAO_BADGE_PROMOCIONAL.match(l)]


PADRAO_TEM_DINHEIRO = re.compile(r'R\s*\$\s*\d')

RUIDO_GENERICO_INICIO = re.compile(
    r'^('
    r'\d+([.,]\d+)?\s*[»>]*\s*\d*[.,]?\d*$|'  # linha só com número/odd (com ou sem boost)
    r'\d{1,2}\s*[/\-]\s*\d{1,2}|'             # data
    r'ID\s*[:#]|#\s*\d+|'
    r'Reusar as seleç|Compartilhar|Cashout|Reapostar|'
    r'Cota[çc][õo]es totais|Valor (?:da|total de) aposta|Ganho total|'
    r'Retorno(?:s)?(?:\s+(?:Total|Obtido))?|Aposta\b|'
    r'Tipo de Dispositivo|'
    r'Simples\b|Dupla\b|M[úu]ltipla\b|Criar Aposta|CRIAR APOSTA|'
    r'ABERTO|PERDID[AO]|GANH[OA]|VENCIDO|AO VIVO|'
    r'Seleç(?:ões|ão)|'
    r'@\s*\d|'
    r'Pontuação|Resultado\s*:|Cotação|'
    r'Super\s*Aumentada|Super\s*Odds|Odds?\s*de\s*Ouro|'
    r'\d+%'
    r')',
    re.IGNORECASE,
)


def _texto_limpo_generico(texto: str) -> str | None:
    """Filtro genérico (não depende de saber qual é a casa) que tira o que
    reconhecidamente é ruído — odds soltas, valores em R$, datas, rótulos
    de UI, IDs, badges — deixando só o que parece descrição de verdade.

    Serve como alternativa manual: se a extração automática de algum campo
    falhar, dá pra copiar esse texto (bem mais enxuto que o bruto inteiro)
    e colar direto no campo de descrição, ajustando à mão o que sobrar."""
    linhas = _linhas_uteis(texto)
    resultado = [
        l for l in linhas
        if not RUIDO_GENERICO_INICIO.search(l) and not PADRAO_TEM_DINHEIRO.search(l)
    ]
    return "\n".join(resultado) if resultado else None


def _parece_nome_time(linha: str) -> bool:
    if re.search(r'\d', linha):
        return False
    if linha.lower() in PALAVRAS_EXCLUIDAS_DESCRICAO:
        return False
    palavras = linha.split()
    if not (1 <= len(palavras) <= 5):
        return False
    return linha[0].isupper()


SUFIXO_STATUS = r'(?:\s+(?:ABERTO|AO VIVO|GANHOU|GANHA|GANHADA|PERDIDA|PERDEU))?'

SUFIXO_STATUS_E_DATA = SUFIXO_STATUS + r'(?:\s+\d{1,2}\s*/\s*\d{1,2}.*)?'

PADROES_CONFRONTO_LINHA_INTEIRA = [
    r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]+?)\s+(?:vs\.?|x)\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]+?)' + SUFIXO_STATUS_E_DATA + r'$',
    r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]+?)\s+\d+\s*-\s*\d+\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]+?)' + SUFIXO_STATUS + r'$',
    r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]+?)\s+-\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]+?)' + SUFIXO_STATUS + r'$',
]


def _encontrar_linha_confronto(linhas: list[str]) -> tuple[int, str] | None:
    """Acha a linha "Time A vs Time B" (ou variações), tolerando uma palavra
    de status colada no final. Devolve (índice da linha, "Time A x Time B").
    Se houver mais de uma ocorrência (comum: o cabeçalho da tela repete o
    confronto de novo mais limpo, sem o "ABERTO" grudado), fica com a
    ÚLTIMA ocorrência — normalmente é a mais "limpa" e a mais perto de
    onde ficam as seleções da aposta."""
    encontrado = None
    for i, linha in enumerate(linhas):
        for padrao in PADROES_CONFRONTO_LINHA_INTEIRA:
            m = re.match(padrao, linha)
            if m and not re.search(r'\d', m.group(1)) and not re.search(r'\d', m.group(2)):
                encontrado = (i, f"{m.group(1).strip()} x {m.group(2).strip()}")
    return encontrado


def _descricao_generica(texto: str) -> str | None:
    linhas = _linhas_uteis(texto)

    # Primeiro tenta achar uma linha INTEIRA que seja só "Time A vs Time B"
    # (ancorada do início ao fim da linha, tolerando uma palavra de status
    # no final tipo "ABERTO") — isso evita cortar nomes de time com mais
    # de uma palavra (ex: "Universidad Católica"), que aconteceria se
    # parasse no primeiro espaço em vez de ir até o fim.
    confronto = _encontrar_linha_confronto(linhas)
    if confronto:
        return confronto[1]

    # Fallback: mesma coisa mas sem exigir a linha inteira (pode acontecer
    # de cortar um nome de time com mais de uma palavra nesse caminho,
    # mas é melhor que nada quando não existe uma linha "limpa").
    padroes_parciais = [
        r'([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)\s+(?:vs\.?|x)\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)(?=\s|$|\|)',
    ]
    for linha in linhas:
        for padrao in padroes_parciais:
            m = re.search(padrao, linha)
            if m and not re.search(r'\d', m.group(1)) and not re.search(r'\d', m.group(2)):
                return f"{m.group(1).strip()} x {m.group(2).strip()}"

    # Último fallback: duas linhas curtas seguidas que parecem nome de time
    for i in range(len(linhas) - 1):
        if _parece_nome_time(linhas[i]) and _parece_nome_time(linhas[i + 1]):
            return f"{linhas[i]} x {linhas[i + 1]}"
    return None


def _resultado_por_palavra_chave(texto: str, ganha: list[str], perdida: list[str]) -> str | None:
    for palavra in perdida:
        if re.search(rf'\b{palavra}\b', texto, re.IGNORECASE):
            return "red"
    for palavra in ganha:
        if re.search(rf'\b{palavra}\b', texto, re.IGNORECASE):
            return "green"
    return None


PARADA_SELECOES = re.compile(
    r'^(TURBINADA|\d+%\s*SUPER TURBINADA|BOOST|AO VIVO|Reusar as seleç|Cota[çc][õo]es totais|'
    r'Valor (?:da|total de) aposta|Odd\b|Potencial ganho|Ganho total|\d{1,2}/\d{1,2})',
    re.IGNORECASE,
)


PADRAO_MERCADO_COM_ODD_BOOST = re.compile(r'^(.+?)\s+\d+[.,]\d{2}\s*[»>]+\s*\d+[.,]\d{2}$')


def _parece_confronto_com_placar(linha: str) -> bool:
    """Detecta linha tipo 'Fluminense 1 : 3 Vasco da Gama' (placar com
    dois-pontos OU hífen) — sinaliza fim do bloco de mercados/seleções,
    não é conteúdo pra incluir na descrição."""
    return bool(re.search(r'\b\d{1,2}\s*[:-]\s*\d{1,2}\b', linha))


def _par_e_redundante(mercado: str, selecao: str) -> bool:
    """Detecta quando "seleção" é só o "mercado" repetido/estendido (ex:
    mercado="DUELO DE GOLS", seleção="DUELO DE GOLS vs.") — não é uma
    informação nova, é eco/ruído."""
    m, s = mercado.lower().strip(), selecao.lower().strip()
    return s.startswith(m) or m.startswith(s)


def _extrair_pares_mercado_selecao(linhas: list[str], indice_inicio: int) -> list[tuple[str, str]]:
    pares = []
    i = indice_inicio
    while i + 1 < len(linhas):
        mercado, selecao = linhas[i], linhas[i + 1]
        if (
            PARADA_SELECOES.match(mercado) or PARADA_SELECOES.match(selecao)
            or _parece_confronto_com_placar(mercado) or _parece_confronto_com_placar(selecao)
        ):
            break
        if not _par_e_redundante(mercado, selecao):
            pares.append((mercado, selecao))
        i += 2
    return pares


def _descricao_com_selecoes(texto: str) -> str | None:
    """Pra apostas de múltiplas seleções (ex: "criador de aposta"): tenta
    achar pares (mercado, seleção escolhida), de duas formas diferentes
    (a ordem varia de casa pra casa e até de tela pra tela na mesma casa):

    1) A PRIMEIRA linha já é "Mercado ODD » ODD_TURBINADO" (o próprio
       mercado com a odd colada) — as linhas seguintes alternam
       seleção/mercado/seleção/mercado a partir dali, tipo:
           Chance dupla 2.83 » 3.25
           Empate ou Vasco da Gama
           Chutes a Gol - Andres Gomez (VDG)
           Mais de 0.5

    2) Depois de uma linha de CONFRONTO limpa ("Time A x Time B"), as
       linhas alternam mercado/seleção, tipo:
           Vencedor do encontro
           Estudiantes de La Plata
           1° tempo - Estudiantes de La Plata total
           Mais de 0.5

    Se não achar nenhum par por nenhuma das duas formas, devolve None (o
    chamador decide o que fazer — geralmente cair pro confronto sozinho)."""
    linhas = _linhas_uteis(texto)

    # rótulos genéricos que às vezes colam na mesma linha da odd, mas não
    # são nome de mercado de verdade (ex: "Sim 1.90 » 2.25", "CA 3.14 >> 4.00")
    ROTULOS_NAO_SAO_MERCADO = {"ca", "sim", "não", "nao"}
    # se a "âncora" termina numa palavra dessas, não é um mercado — é uma
    # frase normal que quebrou de linha no meio (ex: "Fluminense faz mais
    # gols que o" / "Bolívar hoje."), não um par mercado+seleção de verdade
    PALAVRAS_DE_CONTINUACAO = {
        "que", "de", "do", "da", "dos", "das", "o", "a", "e", "em",
        "no", "na", "ao", "à", "para", "por", "com", "um", "uma",
    }

    for i, linha in enumerate(linhas):
        m = PADRAO_MERCADO_COM_ODD_BOOST.match(linha)
        if not m or i + 1 >= len(linhas):
            continue
        mercado_ancora = m.group(1).strip()
        if mercado_ancora.lower() in ROTULOS_NAO_SAO_MERCADO:
            continue

        ultima_palavra = mercado_ancora.split()[-1].lower().rstrip('.,:;') if mercado_ancora.split() else ""
        if ultima_palavra in PALAVRAS_DE_CONTINUACAO:
            # é uma frase só, que quebrou de linha — junta em vez de tratar como par
            frase_completa = f"{mercado_ancora} {linhas[i + 1]}".strip()
            pares_extras = _extrair_pares_mercado_selecao(linhas, i + 2)
            if pares_extras:
                return frase_completa + " | " + " | ".join(f"{s} ({m})" for m, s in pares_extras)
            return frase_completa

        pares = [(mercado_ancora, linhas[i + 1])] + _extrair_pares_mercado_selecao(linhas, i + 2)
        if len(pares) > 1:  # só confia se achou pelo menos 2 pares de verdade
            return " | ".join(f"{selecao} ({mercado})" for mercado, selecao in pares)

    confronto = _encontrar_linha_confronto(linhas)
    if not confronto:
        return None

    indice_confronto, _ = confronto
    pares = _extrair_pares_mercado_selecao(linhas, indice_confronto + 1)
    if not pares:
        return None
    return " | ".join(f"{selecao} ({mercado})" for mercado, selecao in pares)


# ---------------------------------------------------------------------------
# Parser genérico (fallback pra casas sem regra específica ainda)
# ---------------------------------------------------------------------------

REGEX_ODD_GENERICO = re.compile(r"^\d{1,3}[.,]\d{1,2}$")
REGEX_DINHEIRO_GENERICO = re.compile(r"R?\$?\s*(\d{1,6}(?:[.,]\d{1,2})?)$")


def _blocos_por_rotulo(blocos: list[BlocoOCR], *palavras_chave: str) -> BlocoOCR | None:
    rotulos = [b for b in blocos if any(p in b.texto.lower() for p in palavras_chave)]
    if not rotulos:
        return None
    rotulo = rotulos[0]
    candidatos = sorted(blocos, key=lambda b: (b.x - rotulo.x) ** 2 + (b.y - rotulo.y) ** 2)
    for c in candidatos:
        if c is not rotulo and _num(c.texto) is not None:
            return c
    return None


def _bloco_por_zona(blocos: list[BlocoOCR], y_min: float, y_max: float, regex: re.Pattern) -> BlocoOCR | None:
    candidatos = [b for b in blocos if y_min <= b.y <= y_max and regex.match(b.texto.strip())]
    return candidatos[0] if candidatos else None


def parser_generico(blocos: list[BlocoOCR], texto: str) -> RascunhoAposta:
    odd_bloco = _blocos_por_rotulo(blocos, "odd", "cotação", "cotacao") \
        or _bloco_por_zona(blocos, 0.0, 0.4, REGEX_ODD_GENERICO)
    valor_bloco = _blocos_por_rotulo(blocos, "valor", "aposta", "stake") \
        or _bloco_por_zona(blocos, 0.3, 0.65, REGEX_DINHEIRO_GENERICO)
    retorno_bloco = _blocos_por_rotulo(blocos, "retorno", "ganho", "possível", "potencial", "prêmio", "premio") \
        or _bloco_por_zona(blocos, 0.6, 1.0, REGEX_DINHEIRO_GENERICO)

    return RascunhoAposta(
        odd=_num(odd_bloco.texto) if odd_bloco else None,
        valor_apostado=_num(valor_bloco.texto) if valor_bloco else None,
        retorno_potencial=_num(retorno_bloco.texto) if retorno_bloco else None,
        descricao=_descricao_generica(texto),
    )


# ---------------------------------------------------------------------------
# Parsers específicos, calibrados com prints reais de cada casa
# ---------------------------------------------------------------------------

def _selecoes_multiplas_betano(texto: str) -> str | None:
    """Pra apostas de N seleções (ex: "7 - seleções"), cada uma com seu
    próprio confronto: acha trincas repetidas de (nome_seleção + odd) /
    (mercado, ex: "Resultado Final") / (confronto "Time A - Time B"),
    tolerando ícones mal lidos (tipo "(") no começo da linha. Funciona
    com qualquer quantidade de seleções, não só 7."""
    linhas = _linhas_uteis(texto)
    linhas = [re.sub(r'^[\(\)\[\]•·]+\s*', '', l) for l in linhas]

    padrao_selecao_odd = re.compile(r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]+?)\s+(\d+[.,]\d{1,2})$')
    padrao_confronto = re.compile(r'^[A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]+\s-\s[A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]+$')

    grupos = []
    i = 0
    while i < len(linhas) - 2:
        m = padrao_selecao_odd.match(linhas[i])
        mercado = linhas[i + 1]
        confronto = linhas[i + 2]
        if m and padrao_confronto.match(confronto) and not re.search(r'\d', mercado):
            grupos.append((m.group(1).strip(), confronto))
            i += 3
            continue
        i += 1

    if not grupos:
        return None
    return "; ".join(f"{selecao} ({confronto})" for selecao, confronto in grupos)


PARADA_MERCADOS_BETANO = re.compile(
    r'^(ID\s*:|Ganhos|Compartilhar|Aposta\b|Retorno|Cashout|Reusar|\d{1,2}\s*/\s*\d{1,2})',
    re.IGNORECASE,
)


def _indice_linha_confronto_permissivo(linhas: list[str]) -> int | None:
    """Acha a linha do confronto sem se importar em separar os dois times
    perfeitamente (nomes com hífen dentro, tipo "Londrina-PR", quebrariam
    uma tentativa de separação exata) — só precisa saber ONDE ela está,
    pra começar a procurar os mercados logo depois."""
    for i, linha in enumerate(linhas):
        if re.match(r'^(Total|Mais|Menos|Intervalo|Ambas)', linha, re.IGNORECASE):
            continue
        if re.search(r'[A-ZÀ-Ú][\wéãçóáíúÀ-Ú]+\s+-\s+[A-ZÀ-Ú]', linha):
            return i
    return None


def _mercados_multiplos_betano(texto: str) -> str | None:
    """Pra apostas com UMA seleção de jogo mas VÁRIOS mercados (bet builder
    no mesmo confronto): as linhas alternam seleção/mercado, tipo:
        Mais de 0.5 ✔
        Total de gols - 1° Tempo
        Mais de 0.5 x
        Total de gols Mais/Menos - 2° Tempo
    Vira "Mais de 0.5 (Total de gols - 1° Tempo); Mais de 0.5 (Total de
    gols Mais/Menos - 2° Tempo); ..."."""
    linhas = _linhas_uteis(texto)
    # remove ícone de check/x solto no final da linha (o OCR às vezes lê
    # o ícone de "certo"/"errado" como caractere de verdade)
    linhas = [re.sub(r'\s+[✔✓✗]\s*$', '', l) for l in linhas]
    linhas = [re.sub(r'\s+[xX]$', '', l) for l in linhas]

    indice_confronto = _indice_linha_confronto_permissivo(linhas)
    if indice_confronto is None:
        return None

    pares = []
    i = indice_confronto + 1
    while i + 1 < len(linhas):
        selecao, mercado = linhas[i], linhas[i + 1]
        if PARADA_MERCADOS_BETANO.match(selecao) or PARADA_MERCADOS_BETANO.match(mercado):
            break
        pares.append((selecao, mercado))
        i += 2

    if not pares:
        return None
    return "; ".join(f"{selecao} ({mercado})" for selecao, mercado in pares)


def _descricao_por_linha_com_boost(texto: str) -> str | None:
    """Quando a seleção inteira vem numa linha só, com um ícone na frente
    e o odd original + turbinado no final (ex: "◆ Todos ganham: Fulano e
    Ciclano 3.95 4.90" — comum em combinações especiais tipo tênis, sem
    um confronto "Time A x Time B" de verdade pra ancorar). Extrai só o
    texto da seleção, sem o ícone nem os números."""
    for linha in _linhas_uteis(texto):
        m = re.match(r'^\W*(.+?)\s+\d+[.,]\d{2}\s+\d+[.,]\d{2}$', linha)
        if m:
            candidato = m.group(1).strip()
            if len(candidato) > 8:  # evita pegar lixo curto por engano
                return candidato
    return None


def _odd_com_boost(texto: str) -> float | None:
    """Extrai a odd TURBINADA/final quando aparece no formato "odd original
    »/>> odd final" (ex: "2.60 >>> 3.60") — a Betano e a Bet365 usam esse
    mesmo padrão visual de boost, então esse helper é usado pelas duas."""
    m = re.search(r'(\d+[.,]\d{2})\s*[»>]+\s*(\d+[.,]\d{2})', texto)
    return _num(m.group(2)) if m else None


def parser_betano(texto: str) -> RascunhoAposta:
    # Apostas de "N seleções" (múltiplas apostas combinadas, cada uma com
    # confronto próprio) têm um cabeçalho diferente das Simples/Dupla/
    # Múltipla normais — tenta esse formato primeiro.
    m_multiplas = re.search(r'\d+\s*-?\s*seleç[õo]es\s*R\s*\$\s*([\d.,]+)', texto, re.IGNORECASE)
    if m_multiplas:
        valor = _num(m_multiplas.group(1))
        # a odd total do combo costuma vir sozinha na linha logo depois do cabeçalho
        resto = texto[m_multiplas.end():]
        m_odd_total = re.search(r'^\s*(\d+[.,]\d{2})\s*$', resto, re.MULTILINE)
        odd = _num(m_odd_total.group(1)) if m_odd_total else None
    else:
        valor = _buscar(r'(?:Simples|Dupla|M[úu]ltipla)\s*R\s*\$\s*([\d.,]+)', texto)
        odd = None

    m_turbo = re.search(r'turbinada\s*\+?(\d+)%\s*\+?R\s*\$\s*([\d.,]+)', texto, re.IGNORECASE)
    if m_turbo:
        aumento = float(m_turbo.group(1))
        bonus = _num(m_turbo.group(2))
    else:
        aumento = _buscar(r'(\d+)%\s*SUPER TURBINADA', texto)
        bonus = None

    if odd is None:
        odd = _odd_com_boost(texto)
    if odd is None:
        m_odd = re.search(r'Criar Aposta\D{0,20}?(\d+[.,]\d{2})', texto, re.IGNORECASE)
        odd = _num(m_odd.group(1)) if m_odd else None

    if odd is None:
        # formato "◆ Seleção... 3.95 4.90" — pega o segundo número (o turbinado/final)
        m_odd_linha = re.search(r'\d+[.,]\d{2}\s+(\d+[.,]\d{2})\s*$', texto, re.MULTILINE)
        odd = _num(m_odd_linha.group(1)) if m_odd_linha else None

    retorno_base = _buscar(r'(?:Ganhos Potenciais|Pr[êe]mios)\s*R\s*\$\s*([\d.,]+)', texto)
    retorno = None
    if retorno_base is not None:
        retorno = round(retorno_base + (bonus or 0), 2)

    descricao = (
        _descricao_por_linha_com_boost(texto)
        or _selecoes_multiplas_betano(texto)
        or _mercados_multiplos_betano(texto)
        or _descricao_generica(texto)
    )

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        aumento_percentual=aumento,
        descricao=descricao,
        resultado_sugerido=_resultado_por_palavra_chave(texto, ganha=["Ganhou"], perdida=["Perdida"]),
    )


def _valor_e_retorno_tabela_bet365(texto: str) -> tuple[float | None, float | None]:
    """Alguns recibos da Bet365 mostram os rótulos "Aposta" e "Retorno
    Total" juntos numa linha, e os valores em R$ todos juntos na linha
    seguinte, tipo:
        Aposta Retorno Total
        R $ 23,00 R $ 82,80 R $ 82,80 Retorno Obtido
    Nesse formato, pegar só "depois do rótulo X" dá errado (pega o
    primeiro R$ que aparece, não o que corresponde de verdade). Aqui a
    gente pega TODOS os valores dessa linha e usa a ORDEM: 1º = aposta,
    2º = retorno."""
    m = re.search(r'Aposta\s+Retorno Total\s*\n\s*(.+)', texto, re.IGNORECASE)
    if not m:
        return None, None
    valores = re.findall(r'R\s*\$\s*([\d.,]+)', m.group(1))
    valor = _num(valores[0]) if len(valores) > 0 else None
    retorno = _num(valores[1]) if len(valores) > 1 else None
    return valor, retorno


def _selecoes_multiplas_bet365(texto: str) -> str | None:
    """Pra apostas com vários mercados no mesmo jogo (bet builder): logo
    depois da linha "Super Aumentada >>>" ou "CRIAR APOSTA odd", as linhas
    alternam (descrição da seleção, categoria curta repetida), tipo:
        Resultado Final : Goiás
        Resultado Final
        Mais de 9 Escanteios
        Escanteios
    Aqui só pega a primeira linha de cada par (a mais descritiva) — a
    segunda é só uma repetição curta da categoria, sem informação nova."""
    linhas = _linhas_uteis(texto)
    indice_inicio = None
    for i, linha in enumerate(linhas):
        if re.match(r'^(Super\s+Aumentada|CRIAR APOSTA)', linha, re.IGNORECASE):
            indice_inicio = i + 1
    if indice_inicio is None:
        return None

    padrao_placar = re.compile(r'^[A-ZÀ-Ú].+\s\d+$')  # tipo "Goiás 1"
    conteudos = []
    i = indice_inicio
    while i + 1 < len(linhas):
        linha1, linha2 = linhas[i], linhas[i + 1]
        if padrao_placar.match(linha1) or padrao_placar.match(linha2):
            break
        if re.match(r'^(Aposta|Retorno)', linha1, re.IGNORECASE):
            break
        conteudos.append(linha1)
        i += 2

    if not conteudos:
        return None
    return " | ".join(conteudos)


def parser_bet365(texto: str) -> RascunhoAposta:
    valor = _buscar(r'R\s*\$\s*([\d.,]+)\s*(?:Criar Aposta|Simples|Dupla|M[úu]ltipla)', texto) \
        or _buscar(r'Aposta\s*R\s*\$\s*([\d.,]+)', texto)

    odd = _odd_com_boost(texto)
    if odd is None:
        m_odd = re.search(r'CRIAR APOSTA\D{0,15}?(\d+[.,]\d{2})', texto, re.IGNORECASE)
        odd = _num(m_odd.group(1)) if m_odd else None

    retorno = _buscar(r'Retorno Total\s*R\s*\$\s*([\d.,]+)', texto)

    # Layout de tabela (rótulos numa linha, valores juntos na seguinte)
    # tem prioridade quando existir — é mais confiável nesse caso.
    valor_tabela, retorno_tabela = _valor_e_retorno_tabela_bet365(texto)
    valor = valor_tabela if valor_tabela is not None else valor
    retorno = retorno_tabela if retorno_tabela is not None else retorno

    descricao = _selecoes_multiplas_bet365(texto) or _descricao_generica(texto)

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=descricao,
        resultado_sugerido=_resultado_por_palavra_chave(texto, ganha=["Ganha", "Ganhou"], perdida=["Perdida"]),
    )


def parser_betnacional(texto: str) -> RascunhoAposta:
    valor = _buscar(r'Valor da Aposta\s*R\s*\$\s*([\d.,]+)', texto)
    odd = _buscar(r'(?<!\w)Odd\s*([\d.,]+)', texto)
    retorno = _buscar(r'Potencial ganho\s*R\s*\$\s*([\d.,]+)', texto)

    resultado_sugerido = "aberto" if re.search(r'Encerrar por', texto, re.IGNORECASE) else None

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=_descricao_generica(texto),
        resultado_sugerido=resultado_sugerido,
    )


def _descricao_esportivabet(texto: str) -> str | None:
    """A EsportivaBet/EstrelaBet costuma repetir o confronto duas vezes
    (uma no cabeçalho, outra "limpa" perto da descrição do mercado — às
    vezes com a data grudada na mesma linha, tipo "Time A vs Time B
    12/08 • 19:00"). A linha logo ANTES dessa segunda ocorrência costuma
    ser a descrição real do mercado escolhido (ex: "Ambos os tempos mais
    de 0.5 gols") — junta as duas quando faz sentido."""
    linhas = _linhas_uteis(texto)
    confronto = _encontrar_linha_confronto(linhas)
    if not confronto:
        return None

    indice_final, confronto_texto = confronto

    if indice_final > 0:
        candidato = linhas[indice_final - 1]
        eh_rotulo_tecnico = bool(re.match(
            r'^(Sim|N[ãa]o|Cota[çc][õo]es totais|Valor|Ganho|Cashout|Reusar|ID\s*:)',
            candidato, re.IGNORECASE,
        )) or bool(re.search(r'\d+[.,]\d{2}', candidato))
        if not eh_rotulo_tecnico and candidato.lower() != confronto_texto.lower():
            return f"{candidato} — {confronto_texto}"

    return confronto_texto


def parser_esportivabet_estrelabet(texto: str) -> RascunhoAposta:
    odd = _buscar(r'Cota[çc][õo]es totais\s*([\d.,]+)', texto)
    valor = _buscar(r'Valor total de aposta\s*R\s*\$\s*([\d.,]+)', texto)
    retorno = _buscar(r'Ganho total\s*R\s*\$\s*([\d.,]+)', texto)

    resultado_sugerido = "aberto" if re.search(r'\bABERTO\b', texto, re.IGNORECASE) else None

    descricao = _descricao_com_selecoes(texto) or _descricao_esportivabet(texto) or _descricao_generica(texto)

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=descricao,
        resultado_sugerido=resultado_sugerido,
    )


def _confrontos_multiplos_novibet(texto: str) -> str | None:
    """Pra apostas "COMBINADA" com N jogos DIFERENTES (não mercados do
    mesmo jogo): cada grupo de 4 linhas é (seleção, mercado, placar,
    confronto), tipo:
        Luton Town
        Resultado Final
        0-3
        Gillingham - Luton Town"""
    linhas = _linhas_uteis(texto)
    linhas = [re.sub(r'^(?:[>oO◆✪]\s*)+', '', l) for l in linhas]

    padrao_texto = re.compile(r'^[A-ZÀ-Ú].{1,40}$')
    padrao_placar = re.compile(r'^\d+([.,]\d+)?-\d+([.,]\d+)?$')
    padrao_confronto = re.compile(r'^([A-ZÀ-Ú].+?)\s-\s([A-ZÀ-Ú].+)$')

    grupos = []
    i = 0
    while i < len(linhas) - 3:
        selecao, mercado, placar, confronto_linha = linhas[i], linhas[i + 1], linhas[i + 2], linhas[i + 3]
        m_confronto = padrao_confronto.match(confronto_linha)
        if padrao_texto.match(selecao) and padrao_texto.match(mercado) and padrao_placar.match(placar) and m_confronto:
            confronto = f"{m_confronto.group(1).strip()} x {m_confronto.group(2).strip()}"
            grupos.append((selecao, mercado, confronto))
            i += 4
            continue
        i += 1

    if not grupos:
        return None
    return " | ".join(f"{confronto}: {selecao} ({mercado})" for selecao, mercado, confronto in grupos)


def _selecoes_multiplas_novibet(texto: str) -> str | None:
    """Pra apostas de "criador" com N seleções no MESMO jogo: cada trinca
    é (seleção, mercado, resultado do mercado no jogo), tipo:
        Sim
        Ambas equipes Marcam
        1-1
    O terceiro item (resultado, tipo "1-1" ou "2") só serve pra confirmar
    que achamos uma trinca de verdade — não entra na descrição final."""
    linhas = _linhas_uteis(texto)
    # remove ícone solto no início da linha de seleção (ex: "o Sim" -> "Sim")
    linhas = [re.sub(r'^[oO>◆✪]\s+', '', l) for l in linhas]

    padrao_texto = re.compile(r'^[A-ZÀ-Ú].{1,40}$')
    padrao_resultado = re.compile(r'^\d+([.,]\d+)?(-\d+([.,]\d+)?)?$')

    grupos = []
    i = 0
    while i < len(linhas) - 2:
        selecao, mercado, resultado = linhas[i], linhas[i + 1], linhas[i + 2]
        if padrao_texto.match(selecao) and padrao_texto.match(mercado) and padrao_resultado.match(resultado):
            grupos.append((selecao, mercado))
            i += 3
            continue
        i += 1

    if not grupos:
        return None
    return " | ".join(f"{selecao} ({mercado})" for selecao, mercado in grupos)


def parser_novibet(texto: str) -> RascunhoAposta:
    odd = _buscar(r'@\s*([\d.,]+)', texto)
    if odd is None:
        # formatos tipo "COMBINADA 4.39" (sem o @ na frente da odd)
        odd = _buscar(r'(?:CRIADOR DE APOSTA|COMBINADA|SIMPLES|DUPLA)\D{0,5}?(\d+[.,]\d{2})', texto)

    valor = _buscar(r'Valor\s*R\s*\$\s*([\d.,]+)', texto)
    retorno = _buscar(r'Retorno[s]?\s*R\s*\$\s*([\d.,]+)', texto)

    # A Novibet só mostra "Retornos" quando a aposta ganhou — se achou o
    # valor, já sabemos que foi green. Perdida não dá pra confirmar só pelo
    # texto (o ícone de X é gráfico, o OCR não lê ícone).
    resultado_sugerido = "green" if retorno is not None else None

    descricao = _confrontos_multiplos_novibet(texto) or _selecoes_multiplas_novibet(texto) or _descricao_generica(texto)

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=descricao,
        resultado_sugerido=resultado_sugerido,
    )


def _normalizar(nome: str) -> str:
    return re.sub(r'[^a-z0-9]', '', nome.lower())


PARSERS_POR_CASA = {
    "betano": parser_betano,
    "bet365": parser_bet365,
    "betnacional": parser_betnacional,
    "esportivabet": parser_esportivabet_estrelabet,
    "estrelabet": parser_esportivabet_estrelabet,
    "jogodeouro": parser_esportivabet_estrelabet,  # mesma plataforma/template da EsportivaBet/EstrelaBet
    "novibet": parser_novibet,
}


def _escolher_parser(nome_casa: str):
    chave = _normalizar(nome_casa)
    for palavra_chave, parser in PARSERS_POR_CASA.items():
        if palavra_chave in chave:
            return parser
    return None


def _extrair_data(texto: str) -> date | None:
    """Tenta achar a data da aposta em qualquer lugar do texto (formatos
    tipo "11/08", "10/08/2026", "05/08 • 14:04 ID: ..."). Prioriza a
    ÚLTIMA ocorrência no texto — nos recibos que vimos até agora, a data
    do RODAPÉ (quando a aposta foi feita/registrada) é a mais relevante
    pra planilha, e ela costuma vir depois da data do JOGO em si (que às
    vezes nem aconteceu ainda, pra apostas em aberto)."""
    candidatos = list(re.finditer(r'(\d{1,2})\s*/\s*(\d{1,2})(?:\s*/\s*(\d{4}))?', texto))
    for m in reversed(candidatos):
        dia, mes = int(m.group(1)), int(m.group(2))
        ano = int(m.group(3)) if m.group(3) else datetime.now().year
        try:
            return date(ano, mes, dia)
        except ValueError:
            continue
    return None


@router.post("/analisar", response_model=RascunhoAposta)
def analisar_blocos(payload: TextoParaAnalisar):
    texto_completo = "\n".join(b.texto for b in payload.blocos)
    texto_completo = _reparar_mojibake(texto_completo)
    parser = _escolher_parser(payload.casa)
    resultado = parser(texto_completo) if parser else parser_generico(payload.blocos, texto_completo)
    if resultado.data_sugerida is None:
        resultado.data_sugerida = _extrair_data(texto_completo)
    resultado.texto_limpo = _texto_limpo_generico(texto_completo)
    return resultado


@router.get("/dataset-treino")
def dataset_treino(
    casa: str | None = None,
    db: Session = Depends(get_db),
    usuario: models.Usuario = Depends(obter_usuario_atual),
):
    """Exporta os exemplos acumulados (blocos + sugestão + valores corretos)
    pra usar num script de treino/calibração futuro. Filtra por casa se informado."""
    return crud.obter_dataset_treino(db, usuario.id, casa)
