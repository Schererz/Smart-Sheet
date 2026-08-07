"""
Funções de apoio pra importar planilhas (.xlsx ou .csv) prontas de quem já
vinha controlando as apostas manualmente.

A abordagem aqui é simples de propósito: em vez de uma tela de mapeamento
manual (arrastar coluna pra campo), a gente tenta reconhecer os nomes das
colunas mais comuns automaticamente (ex: "Odd", "Valor", "Casa"). A
expectativa é que a pessoa limpe a planilha antes — apague colunas extras
que não têm a ver com o nosso app (tipster, esporte, etc.) e deixe só as
que interessam, com nomes parecidos com os que a gente já reconhece.
Colunas com nomes muito diferentes simplesmente não são encontradas, e a
linha correspondente fica sem aquele campo (ou é pulada, se for campo
obrigatório).
"""
import csv
import io
import re
import unicodedata
from datetime import date, datetime

import openpyxl

CAMPOS_ALIASES = {
    "data": {"data", "date", "dia"},
    "casa": {"casa", "casadeapostas", "bookmaker", "corretora", "site", "operadora"},
    "descricao": {"descricao", "evento", "jogo", "selecao", "aposta", "mercado", "partida", "jogos"},
    "odd": {"odd", "odds", "cotacao", "cotacoes"},
    "valor": {"valor", "valorapostado", "stake", "valordaaposta", "valoraposta"},
    "retorno": {"retorno", "retornopotencial", "ganho", "ganhopotencial", "payout", "premio", "premios", "retornototal"},
    "resultado": {"resultado", "status"},
}

PALAVRAS_GREEN = {"green", "ganhou", "ganha", "ganho", "win", "w", "1", "certo", "vitoria"}
PALAVRAS_RED = {"red", "perdeu", "perdida", "perdido", "loss", "lose", "l", "0", "errado", "derrota"}


def _normalizar_texto(s: str) -> str:
    """minusculas, sem acento, sem espaço/pontuação — pra comparar nomes de coluna e valores com folga."""
    s = unicodedata.normalize("NFKD", str(s)).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]", "", s.lower())


def mapear_colunas(cabecalhos: list) -> dict:
    """Recebe a linha de cabeçalho da planilha e devolve {campo: indice_da_coluna}
    pros campos que conseguiu reconhecer."""
    normalizados = [_normalizar_texto(h) if h is not None else "" for h in cabecalhos]
    mapa = {}
    for campo, aliases in CAMPOS_ALIASES.items():
        for indice, cabecalho in enumerate(normalizados):
            if cabecalho in aliases:
                mapa[campo] = indice
                break
    return mapa


def converter_numero(valor) -> float | None:
    """Converte o valor de uma célula (pode vir como float, int, str formatada, ou vazio) pra float."""
    if valor is None:
        return None
    if isinstance(valor, (int, float)):
        return float(valor)
    texto = str(valor).strip()
    if not texto:
        return None
    texto = re.sub(r"^R\$?\s*", "", texto, flags=re.IGNORECASE)
    if "," in texto and "." in texto:
        texto = texto.replace(".", "").replace(",", ".")
    elif "," in texto:
        texto = texto.replace(",", ".")
    try:
        return float(texto)
    except ValueError:
        return None


def converter_data(valor) -> date | None:
    """Converte o valor de uma célula de data (openpyxl já entrega datetime pra
    células formatadas como data; strings soltas tentamos alguns formatos comuns)."""
    if valor is None:
        return None
    if isinstance(valor, datetime):
        return valor.date()
    if isinstance(valor, date):
        return valor
    texto = str(valor).strip()
    if not texto:
        return None
    formatos = ["%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y", "%d/%m/%y"]
    for formato in formatos:
        try:
            return datetime.strptime(texto, formato).date()
        except ValueError:
            continue
    return None


def normalizar_resultado(valor) -> str:
    """Traduz qualquer variação de texto pra 'aberto'/'green'/'red'."""
    if valor is None:
        return "aberto"
    texto = _normalizar_texto(valor)
    if texto in PALAVRAS_GREEN:
        return "green"
    if texto in PALAVRAS_RED:
        return "red"
    return "aberto"


def ler_linhas_csv(conteudo: bytes) -> list:
    """Lê um .csv e devolve uma lista de listas (linhas de célula), cabeçalho incluso."""
    texto = conteudo.decode("utf-8-sig", errors="replace")
    amostra = texto[:2048]
    try:
        dialeto = csv.Sniffer().sniff(amostra, delimiters=",;\t")
    except csv.Error:
        dialeto = csv.excel  # separador vírgula, o padrão
    leitor = csv.reader(io.StringIO(texto), dialeto)
    return [linha for linha in leitor if any(c.strip() for c in linha)]


def ler_linhas_xlsx(conteudo: bytes) -> list:
    """Lê a primeira aba de um .xlsx e devolve uma lista de listas (linhas de célula)."""
    pasta = openpyxl.load_workbook(io.BytesIO(conteudo), data_only=True)
    aba = pasta.active
    linhas = []
    for linha in aba.iter_rows(values_only=True):
        if any(c is not None and str(c).strip() for c in linha):
            linhas.append(list(linha))
    return linhas
