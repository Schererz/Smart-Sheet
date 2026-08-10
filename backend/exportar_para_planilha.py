"""
Exporta as apostas do banco local (apostas.db) pra um .xlsx pronto
pra importar no site (na tela "Importar planilha").

Como usar:
    cd backend
    venv\\Scripts\\activate
    pip install openpyxl  (só se ainda não tiver — já deve ter, tá no requirements.txt)
    python exportar_para_planilha.py

Gera o arquivo "apostas_exportadas.xlsx" na mesma pasta.
"""
import sqlite3
import openpyxl

CAMINHO_BANCO = "apostas.db"
ARQUIVO_SAIDA = "apostas_exportadas.xlsx"

conexao = sqlite3.connect(CAMINHO_BANCO)
conexao.row_factory = sqlite3.Row
cursor = conexao.execute(
    "SELECT data, casa_de_apostas, descricao, odd, valor_apostado, retorno_potencial, resultado FROM bets"
)
linhas = cursor.fetchall()

wb = openpyxl.Workbook()
ws = wb.active
ws.append(["Data", "Casa", "Descrição", "Odd", "Valor", "Retorno", "Resultado"])

for linha in linhas:
    ws.append([
        linha["data"],
        linha["casa_de_apostas"],
        linha["descricao"],
        linha["odd"],
        linha["valor_apostado"],
        linha["retorno_potencial"],
        linha["resultado"],
    ])

wb.save(ARQUIVO_SAIDA)
print(f"Exportado {len(linhas)} apostas pra {ARQUIVO_SAIDA}")
conexao.close()