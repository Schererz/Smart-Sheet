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
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from .. import crud
from ..database import get_db
from ..schemas import BlocoOCR, RascunhoAposta

router = APIRouter(prefix="/parsing", tags=["parsing"])


class TextoParaAnalisar(BaseModel):
    casa: str
    blocos: list[BlocoOCR]


# ---------------------------------------------------------------------------
# Helpers gerais
# ---------------------------------------------------------------------------

def _num(texto: str) -> float | None:
    """Converte texto tipo 'R$ 1.234,56' ou '23,80' ou '2.77' em float."""
    if not texto:
        return None
    s = re.sub(r'^\s*R\$?\s*', '', texto.strip(), flags=re.IGNORECASE).strip()
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


def _parece_nome_time(linha: str) -> bool:
    if re.search(r'\d', linha):
        return False
    if linha.lower() in PALAVRAS_EXCLUIDAS_DESCRICAO:
        return False
    palavras = linha.split()
    if not (1 <= len(palavras) <= 5):
        return False
    return linha[0].isupper()


def _descricao_generica(texto: str) -> str | None:
    linhas = [l.strip() for l in texto.split('\n') if l.strip()]

    padroes = [
        r'([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)\s+(?:vs\.?|x)\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)(?=\s|$|\|)',
        r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)\s+\d+\s*-\s*\d+\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .\-]{2,35}?)$',
        r'^([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]{2,35}?)\s+-\s+([A-ZÀ-Ú][\wéãçóáíúÀ-Ú .]{2,35}?)$',
    ]
    for linha in linhas:
        for padrao in padroes:
            m = re.search(padrao, linha)
            if m and not re.search(r'\d', m.group(1)) and not re.search(r'\d', m.group(2)):
                return f"{m.group(1).strip()} x {m.group(2).strip()}"

    # Fallback: duas linhas curtas seguidas que parecem nome de time
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

def parser_betano(texto: str) -> RascunhoAposta:
    valor = _buscar(r'(?:Simples|Dupla|M[úu]ltipla)\s*R\$\s*([\d.,]+)', texto)

    m_turbo = re.search(r'turbinada\s*\+?(\d+)%\s*\+?R\$\s*([\d.,]+)', texto, re.IGNORECASE)
    if m_turbo:
        aumento = float(m_turbo.group(1))
        bonus = _num(m_turbo.group(2))
    else:
        aumento = _buscar(r'(\d+)%\s*SUPER TURBINADA', texto)
        bonus = None

    m_odd_boost = re.search(r'(\d+[.,]\d{2})\s*(?:»>|>>|»)\s*(\d+[.,]\d{2})', texto)
    if m_odd_boost:
        odd = _num(m_odd_boost.group(2))
    else:
        m_odd = re.search(r'Criar Aposta\D{0,20}?(\d+[.,]\d{2})', texto, re.IGNORECASE)
        odd = _num(m_odd.group(1)) if m_odd else None

    retorno_base = _buscar(r'(?:Ganhos Potenciais|Pr[êe]mios)\s*R\$\s*([\d.,]+)', texto)
    retorno = None
    if retorno_base is not None:
        retorno = round(retorno_base + (bonus or 0), 2)

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        aumento_percentual=aumento,
        descricao=_descricao_generica(texto),
        resultado_sugerido=_resultado_por_palavra_chave(texto, ganha=["Ganhou"], perdida=["Perdida"]),
    )


def parser_bet365(texto: str) -> RascunhoAposta:
    valor = _buscar(r'R\$\s*([\d.,]+)\s*(?:Criar Aposta|Simples|Dupla|M[úu]ltipla)', texto) \
        or _buscar(r'Aposta\s*R\$\s*([\d.,]+)', texto)

    m_odd_boost = re.search(r'(\d+[.,]\d{2})\s*(?:»>|>>|»)\s*(\d+[.,]\d{2})', texto)
    if m_odd_boost:
        odd = _num(m_odd_boost.group(2))
    else:
        m_odd = re.search(r'CRIAR APOSTA\D{0,15}?(\d+[.,]\d{2})', texto, re.IGNORECASE)
        odd = _num(m_odd.group(1)) if m_odd else None

    retorno = _buscar(r'Retorno Total\s*R\$\s*([\d.,]+)', texto)

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=_descricao_generica(texto),
        resultado_sugerido=_resultado_por_palavra_chave(texto, ganha=["Ganha", "Ganhou"], perdida=["Perdida"]),
    )


def parser_betnacional(texto: str) -> RascunhoAposta:
    valor = _buscar(r'Valor da Aposta\s*R\$\s*([\d.,]+)', texto)
    odd = _buscar(r'(?<!\w)Odd\s*([\d.,]+)', texto)
    retorno = _buscar(r'Potencial ganho\s*R\$\s*([\d.,]+)', texto)

    resultado_sugerido = "aberto" if re.search(r'Encerrar por', texto, re.IGNORECASE) else None

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=_descricao_generica(texto),
        resultado_sugerido=resultado_sugerido,
    )


def parser_esportivabet_estrelabet(texto: str) -> RascunhoAposta:
    odd = _buscar(r'Cota[çc][õo]es totais\s*([\d.,]+)', texto)
    valor = _buscar(r'Valor total de aposta\s*R\$\s*([\d.,]+)', texto)
    retorno = _buscar(r'Ganho total\s*R\$\s*([\d.,]+)', texto)

    resultado_sugerido = "aberto" if re.search(r'\bABERTO\b', texto, re.IGNORECASE) else None

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=_descricao_generica(texto),
        resultado_sugerido=resultado_sugerido,
    )


def parser_novibet(texto: str) -> RascunhoAposta:
    odd = _buscar(r'@\s*([\d.,]+)', texto)
    valor = _buscar(r'Valor\s*R\$\s*([\d.,]+)', texto)
    retorno = _buscar(r'Retorno[s]?\s*R\$\s*([\d.,]+)', texto)

    # A Novibet só mostra "Retornos" quando a aposta ganhou — se achou o
    # valor, já sabemos que foi green. Perdida não dá pra confirmar só pelo
    # texto (o ícone de X é gráfico, o OCR não lê ícone).
    resultado_sugerido = "green" if retorno is not None else None

    return RascunhoAposta(
        odd=odd,
        valor_apostado=valor,
        retorno_potencial=retorno,
        descricao=_descricao_generica(texto),
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
    "novibet": parser_novibet,
}


def _escolher_parser(nome_casa: str):
    chave = _normalizar(nome_casa)
    for palavra_chave, parser in PARSERS_POR_CASA.items():
        if palavra_chave in chave:
            return parser
    return None


@router.post("/analisar", response_model=RascunhoAposta)
def analisar_blocos(payload: TextoParaAnalisar):
    texto_completo = "\n".join(b.texto for b in payload.blocos)
    parser = _escolher_parser(payload.casa)
    if parser:
        return parser(texto_completo)
    return parser_generico(payload.blocos, texto_completo)


@router.get("/dataset-treino")
def dataset_treino(casa: str | None = None, db: Session = Depends(get_db)):
    """Exporta os exemplos acumulados (blocos + sugestão + valores corretos)
    pra usar num script de treino/calibração futuro. Filtra por casa se informado."""
    return crud.obter_dataset_treino(db, casa)
